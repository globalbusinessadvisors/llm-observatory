use crate::{
    config::Config,
    error::{Error, Result},
    models::AppState,
    routes,
};
use axum::{
    http::{header, HeaderValue, Method, StatusCode},
    routing::get,
    Json, Router,
};
use chrono::Utc;
use metrics_exporter_prometheus::{Matcher, PrometheusBuilder, PrometheusHandle};
use redis::Client as RedisClient;
use serde_json::json;
use sqlx::postgres::PgPoolOptions;
use std::{sync::Arc, time::Duration};
use tower_http::{
    cors::CorsLayer,
    timeout::TimeoutLayer,
    trace::{DefaultMakeSpan, DefaultOnResponse, TraceLayer},
};
use tracing::{info, Level};

/// Build the complete Axum application with all routes and middleware
pub async fn build_app(config: Config) -> Result<Router> {
    // Initialize Prometheus metrics exporter
    let prometheus_handle = setup_metrics_recorder()?;
    info!("Metrics exporter initialized");

    // Connect to TimescaleDB (PostgreSQL)
    info!("Connecting to TimescaleDB...");
    let db_pool = PgPoolOptions::new()
        .max_connections(config.database.max_connections)
        .min_connections(config.database.min_connections)
        .acquire_timeout(Duration::from_secs(config.database.connect_timeout))
        .idle_timeout(Duration::from_secs(config.database.idle_timeout))
        .max_lifetime(Duration::from_secs(config.database.max_lifetime))
        .connect(&config.database.url)
        .await
        .map_err(|e| Error::Database(format!("Failed to connect to database: {}", e)))?;

    // Test database connection
    sqlx::query("SELECT 1")
        .execute(&db_pool)
        .await
        .map_err(|e| Error::Database(format!("Database health check failed: {}", e)))?;
    info!("Database connection established and verified");

    // Connect to Redis cache
    info!("Connecting to Redis...");
    let redis_client = RedisClient::open(config.redis.url.clone())
        .map_err(|e| Error::Cache(format!("Failed to create Redis client: {}", e)))?;

    // Test Redis connection
    let mut redis_conn = redis_client
        .get_async_connection()
        .await
        .map_err(|e| Error::Cache(format!("Failed to connect to Redis: {}", e)))?;
    redis::cmd("PING")
        .query_async::<_, String>(&mut redis_conn)
        .await
        .map_err(|e| Error::Cache(format!("Redis health check failed: {}", e)))?;
    info!("Redis connection established and verified");

    // Create application state
    let app_state = Arc::new(AppState {
        db_pool,
        redis_client,
        config: config.clone(),
    });

    // Build the router
    let app = create_router(app_state, prometheus_handle, &config);

    info!("Application initialized successfully");
    Ok(app)
}

/// Create the router with all routes and middleware
fn create_router(state: Arc<AppState>, prometheus_handle: PrometheusHandle, config: &Config) -> Router {
    // Configure CORS
    let cors = CorsLayer::new()
        .allow_origin(
            config
                .app
                .cors_origins
                .iter()
                .filter_map(|origin| origin.parse::<HeaderValue>().ok())
                .collect::<Vec<_>>(),
        )
        .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
        .allow_headers([header::CONTENT_TYPE, header::AUTHORIZATION])
        .max_age(Duration::from_secs(3600));

    // Build API routes
    let api_routes = Router::new()
        .merge(routes::metrics::routes())
        .merge(routes::costs::routes())
        .merge(routes::performance::routes());

    // Build main router with middleware
    Router::new()
        .route("/health", get(health_check))
        .route("/ready", get(readiness_check))
        .route("/metrics", get(move || async move { prometheus_handle.render() }))
        .nest("/api/v1", api_routes)
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::new().level(Level::INFO))
                .on_response(DefaultOnResponse::new().level(Level::INFO)),
        )
        .layer(TimeoutLayer::new(Duration::from_secs(30)))
        .layer(cors)
        .with_state(state)
}

/// Health check endpoint - checks if service is alive
async fn health_check() -> (StatusCode, Json<serde_json::Value>) {
    (
        StatusCode::OK,
        Json(json!({
            "status": "healthy",
            "timestamp": Utc::now(),
            "service": "analytics-api"
        })),
    )
}

/// Readiness check endpoint - checks if service is ready to handle requests
async fn readiness_check(
    axum::extract::State(state): axum::extract::State<Arc<AppState>>,
) -> (StatusCode, Json<serde_json::Value>) {
    // Check database
    let db_ready = sqlx::query("SELECT 1")
        .execute(&state.db_pool)
        .await
        .is_ok();

    // Check Redis
    let redis_ready = state
        .redis_client
        .get_async_connection()
        .await
        .and_then(|mut conn| {
            redis::cmd("PING")
                .query_async::<_, String>(&mut conn)
                .now_or_never()
                .unwrap_or(Err(redis::RedisError::from((
                    redis::ErrorKind::IoError,
                    "Timeout",
                ))))
        })
        .is_ok();

    let ready = db_ready && redis_ready;
    let status = if ready {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };

    (
        status,
        Json(json!({
            "ready": ready,
            "database": db_ready,
            "redis": redis_ready,
            "timestamp": Utc::now(),
        })),
    )
}

/// Setup Prometheus metrics recorder
fn setup_metrics_recorder() -> Result<PrometheusHandle> {
    let builder = PrometheusBuilder::new();

    // Configure histogram buckets for HTTP request latency
    let builder = builder
        .set_buckets_for_metric(
            Matcher::Full("http_request_duration_seconds".to_string()),
            &[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
        )
        .map_err(|e| Error::Metrics(format!("Failed to set HTTP buckets: {}", e)))?;

    // Configure histogram buckets for database query latency
    let builder = builder
        .set_buckets_for_metric(
            Matcher::Full("db_query_duration_seconds".to_string()),
            &[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
        )
        .map_err(|e| Error::Metrics(format!("Failed to set DB buckets: {}", e)))?;

    let handle = builder
        .install_recorder()
        .map_err(|e| Error::Metrics(format!("Failed to install metrics recorder: {}", e)))?;

    Ok(handle)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_health_check_response() {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            let (status, _body) = health_check().await;
            assert_eq!(status, StatusCode::OK);
        });
    }
}

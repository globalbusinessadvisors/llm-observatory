use crate::{
    error::Result,
    models::{requests::AnalyticsQuery, responses::PerformanceMetrics, AppState},
    services::AnalyticsService,
};
use axum::{
    extract::{Query, State},
    routing::get,
    Json, Router,
};
use redis::AsyncCommands;
use std::sync::Arc;
use tracing::{info, instrument};

/// Create performance routes
pub fn routes() -> Router<Arc<AppState>> {
    Router::new().route("/performance", get(get_performance_metrics))
}

/// GET /api/v1/performance - Get performance metrics
///
/// Returns performance metrics including latency percentiles,
/// throughput, and token usage statistics.
///
/// Query Parameters:
/// - start_time: Start of time range (ISO 8601)
/// - end_time: End of time range (ISO 8601)
/// - provider: Filter by provider (optional)
/// - model: Filter by model (optional)
/// - environment: Filter by environment (optional)
/// - granularity: Time bucket granularity (1min, 1hour, 1day) - default: 1hour
#[instrument(skip(state))]
async fn get_performance_metrics(
    State(state): State<Arc<AppState>>,
    Query(query): Query<AnalyticsQuery>,
) -> Result<Json<PerformanceMetrics>> {
    info!(
        "Fetching performance metrics: provider={:?}, model={:?}, granularity={}",
        query.provider, query.model, query.granularity
    );

    // Generate cache key
    let cache_key = query.cache_key("performance:metrics");

    // Try to get from cache if enabled
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(cached) = conn.get::<_, String>(&cache_key).await {
                if let Ok(result) = serde_json::from_str::<PerformanceMetrics>(&cached) {
                    info!("Returning cached performance metrics");
                    return Ok(Json(result));
                }
            }
        }
    }

    // Query database
    let service = AnalyticsService::new(state.db_pool.clone());
    let metrics = service.get_performance_metrics(&query).await?;

    // Cache the result
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(serialized) = serde_json::to_string(&metrics) {
                let _: std::result::Result<(), _> =
                    conn.set_ex(&cache_key, serialized, state.cache_ttl()).await;
            }
        }
    }

    info!(
        "Performance metrics fetched: avg_latency={:.2}ms, requests={}, tokens={}",
        metrics.avg_latency_ms, metrics.request_count, metrics.total_tokens
    );

    Ok(Json(metrics))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_routes_creation() {
        let _router = routes();
        assert!(true);
    }
}

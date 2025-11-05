use crate::models::*;
use crate::services::timescaledb::TimescaleDBService;
use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    Json, Router,
};
use redis::AsyncCommands;
use serde_json::json;
use std::sync::Arc;
use tracing::{error, info, instrument};

/// Create costs routes
pub fn routes() -> Router<Arc<AppState>> {
    Router::new()
        .route("/api/v1/analytics/costs", get(get_cost_analytics))
        .route("/api/v1/analytics/costs/breakdown", get(get_cost_breakdown))
}

/// GET /api/v1/analytics/costs - Get cost analytics
///
/// Returns cost analytics including total cost, breakdown by prompt/completion,
/// and time series data.
///
/// Query Parameters:
/// - start_time: Start of time range (ISO 8601)
/// - end_time: End of time range (ISO 8601)
/// - provider: Filter by provider (optional)
/// - model: Filter by model (optional)
/// - environment: Filter by environment (optional)
/// - granularity: Time bucket granularity (1min, 1hour, 1day) - default: 1hour
#[instrument(skip(state))]
async fn get_cost_analytics(
    State(state): State<Arc<AppState>>,
    Query(query): Query<AnalyticsQuery>,
) -> Result<Json<CostAnalytics>, ApiError> {
    info!(
        "Fetching cost analytics: provider={:?}, model={:?}, granularity={}",
        query.provider, query.model, query.granularity
    );

    // Generate cache key
    let cache_key = format!(
        "cost:analytics:{}:{}:{}:{}:{}",
        query.start_time.map(|t| t.to_rfc3339()).unwrap_or_default(),
        query.end_time.map(|t| t.to_rfc3339()).unwrap_or_default(),
        query.provider.as_deref().unwrap_or("all"),
        query.model.as_deref().unwrap_or("all"),
        query.granularity
    );

    // Try to get from cache
    let mut redis_conn = state.redis_client.get_async_connection().await.map_err(|e| {
        error!("Redis connection error: {}", e);
        ApiError::Internal("Failed to connect to cache".to_string())
    })?;

    // Check cache
    if let Ok(cached) = redis_conn.get::<_, String>(&cache_key).await {
        if let Ok(result) = serde_json::from_str::<CostAnalytics>(&cached) {
            info!("Returning cached cost analytics");
            return Ok(Json(result));
        }
    }

    // Query database
    let service = TimescaleDBService::new(state.db_pool.clone());
    let analytics = service
        .get_cost_analytics(&query)
        .await
        .map_err(|e| {
            error!("Database query error: {}", e);
            ApiError::Internal(format!("Failed to fetch cost analytics: {}", e))
        })?;

    // Cache the result
    let serialized = serde_json::to_string(&analytics).unwrap();
    let _: Result<(), _> = redis_conn
        .set_ex(&cache_key, serialized, state.cache_ttl)
        .await;

    info!(
        "Cost analytics fetched: total_cost=${:.4}, requests={}",
        analytics.total_cost, analytics.request_count
    );

    Ok(Json(analytics))
}

/// GET /api/v1/analytics/costs/breakdown - Get cost breakdown
///
/// Returns detailed cost breakdown by model, user, provider, and time.
///
/// Query Parameters:
/// - start_time: Start of time range (ISO 8601)
/// - end_time: End of time range (ISO 8601)
/// - environment: Filter by environment (optional)
/// - granularity: Time bucket granularity (1min, 1hour, 1day) - default: 1hour
#[instrument(skip(state))]
async fn get_cost_breakdown(
    State(state): State<Arc<AppState>>,
    Query(query): Query<AnalyticsQuery>,
) -> Result<Json<CostBreakdown>, ApiError> {
    info!(
        "Fetching cost breakdown: environment={:?}, granularity={}",
        query.environment, query.granularity
    );

    // Generate cache key
    let cache_key = format!(
        "cost:breakdown:{}:{}:{}:{}",
        query.start_time.map(|t| t.to_rfc3339()).unwrap_or_default(),
        query.end_time.map(|t| t.to_rfc3339()).unwrap_or_default(),
        query.environment.as_deref().unwrap_or("all"),
        query.granularity
    );

    // Try to get from cache
    let mut redis_conn = state.redis_client.get_async_connection().await.map_err(|e| {
        error!("Redis connection error: {}", e);
        ApiError::Internal("Failed to connect to cache".to_string())
    })?;

    // Check cache
    if let Ok(cached) = redis_conn.get::<_, String>(&cache_key).await {
        if let Ok(result) = serde_json::from_str::<CostBreakdown>(&cached) {
            info!("Returning cached cost breakdown");
            return Ok(Json(result));
        }
    }

    // Query database
    let service = TimescaleDBService::new(state.db_pool.clone());
    let breakdown = service
        .get_cost_breakdown(&query)
        .await
        .map_err(|e| {
            error!("Database query error: {}", e);
            ApiError::Internal(format!("Failed to fetch cost breakdown: {}", e))
        })?;

    // Cache the result
    let serialized = serde_json::to_string(&breakdown).unwrap();
    let _: Result<(), _> = redis_conn
        .set_ex(&cache_key, serialized, state.cache_ttl)
        .await;

    info!(
        "Cost breakdown fetched: {} models, {} providers, {} users",
        breakdown.by_model.len(),
        breakdown.by_provider.len(),
        breakdown.by_user.len()
    );

    Ok(Json(breakdown))
}

/// API error type
#[derive(Debug)]
pub enum ApiError {
    BadRequest(String),
    Internal(String),
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            ApiError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            ApiError::Internal(msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg),
        };

        let body = Json(json!({
            "error": status.canonical_reason().unwrap_or("Unknown"),
            "message": error_message,
        }));

        (status, body).into_response()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    #[test]
    fn test_analytics_query_defaults() {
        let query = AnalyticsQuery {
            start_time: None,
            end_time: None,
            provider: None,
            model: None,
            environment: None,
            user_id: None,
            granularity: "1hour".to_string(),
        };

        assert_eq!(query.granularity, "1hour");
    }

    #[test]
    fn test_cache_key_generation() {
        let query = AnalyticsQuery {
            start_time: Some(Utc::now()),
            end_time: Some(Utc::now()),
            provider: Some("openai".to_string()),
            model: Some("gpt-4".to_string()),
            environment: Some("production".to_string()),
            user_id: None,
            granularity: "1hour".to_string(),
        };

        let cache_key = format!(
            "cost:analytics:{}:{}:{}:{}:{}",
            query.start_time.map(|t| t.to_rfc3339()).unwrap_or_default(),
            query.end_time.map(|t| t.to_rfc3339()).unwrap_or_default(),
            query.provider.as_deref().unwrap_or("all"),
            query.model.as_deref().unwrap_or("all"),
            query.granularity
        );

        assert!(cache_key.contains("openai"));
        assert!(cache_key.contains("gpt-4"));
    }
}

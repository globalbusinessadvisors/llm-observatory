use crate::{
    error::Result,
    models::{requests::AnalyticsQuery, responses::*, AppState},
    services::CostService,
};
use axum::{
    extract::{Query, State},
    routing::get,
    Json, Router,
};
use redis::AsyncCommands;
use std::sync::Arc;
use tracing::{info, instrument};

/// Create costs routes
pub fn routes() -> Router<Arc<AppState>> {
    Router::new()
        .route("/costs", get(get_cost_analytics))
        .route("/costs/breakdown", get(get_cost_breakdown))
}

/// GET /api/v1/costs - Get cost analytics
///
/// Returns comprehensive cost analytics including total cost,
/// breakdown by prompt/completion, and time series data.
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
) -> Result<Json<CostAnalytics>> {
    info!(
        "Fetching cost analytics: provider={:?}, model={:?}, granularity={}",
        query.provider, query.model, query.granularity
    );

    // Generate cache key
    let cache_key = query.cache_key("cost:analytics");

    // Try to get from cache if enabled
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(cached) = conn.get::<_, String>(&cache_key).await {
                if let Ok(result) = serde_json::from_str::<CostAnalytics>(&cached) {
                    info!("Returning cached cost analytics");
                    return Ok(Json(result));
                }
            }
        }
    }

    // Query database
    let service = CostService::new(state.db_pool.clone());
    let analytics = service.get_cost_analytics(&query).await?;

    // Cache the result
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(serialized) = serde_json::to_string(&analytics) {
                let _: std::result::Result<(), _> =
                    conn.set_ex(&cache_key, serialized, state.cache_ttl()).await;
            }
        }
    }

    info!(
        "Cost analytics fetched: total_cost=${:.4}, requests={}",
        analytics.total_cost, analytics.request_count
    );

    Ok(Json(analytics))
}

/// GET /api/v1/costs/breakdown - Get cost breakdown
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
) -> Result<Json<CostBreakdown>> {
    info!(
        "Fetching cost breakdown: environment={:?}, granularity={}",
        query.environment, query.granularity
    );

    // Generate cache key
    let cache_key = query.cache_key("cost:breakdown");

    // Try cache
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(cached) = conn.get::<_, String>(&cache_key).await {
                if let Ok(result) = serde_json::from_str::<CostBreakdown>(&cached) {
                    info!("Returning cached cost breakdown");
                    return Ok(Json(result));
                }
            }
        }
    }

    // Query database
    let service = CostService::new(state.db_pool.clone());
    let breakdown = service.get_cost_breakdown(&query).await?;

    // Cache the result
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(serialized) = serde_json::to_string(&breakdown) {
                let _: std::result::Result<(), _> =
                    conn.set_ex(&cache_key, serialized, state.cache_ttl()).await;
            }
        }
    }

    info!(
        "Cost breakdown fetched: {} models, {} providers",
        breakdown.by_model.len(),
        breakdown.by_provider.len()
    );

    Ok(Json(breakdown))
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

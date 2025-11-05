use crate::{
    error::Result,
    models::{
        requests::{AnalyticsQuery, ModelComparisonQuery},
        responses::*,
        AppState,
    },
    services::AnalyticsService,
};
use axum::{
    extract::{Query, State},
    routing::get,
    Json, Router,
};
use redis::AsyncCommands;
use std::sync::Arc;
use tracing::{info, warn, instrument};

/// Create metrics routes
pub fn routes() -> Router<Arc<AppState>> {
    Router::new()
        .route("/metrics/summary", get(get_metrics_summary))
        .route("/metrics/conversations", get(get_conversations))
        .route("/metrics/models", get(compare_models))
        .route("/metrics/trends", get(get_trends))
}

/// GET /api/v1/metrics/summary - Get metrics overview
///
/// Returns a comprehensive summary of all key metrics including cost,
/// performance, and usage statistics.
#[instrument(skip(state))]
async fn get_metrics_summary(
    State(state): State<Arc<AppState>>,
    Query(query): Query<AnalyticsQuery>,
) -> Result<Json<MetricsSummary>> {
    info!("Fetching metrics summary");

    // Generate cache key
    let cache_key = query.cache_key("metrics:summary");

    // Try to get from cache if enabled
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(cached) = conn.get::<_, String>(&cache_key).await {
                if let Ok(result) = serde_json::from_str::<MetricsSummary>(&cached) {
                    info!("Returning cached metrics summary");
                    return Ok(Json(result));
                }
            }
        }
    }

    // Query from database
    let service = AnalyticsService::new(state.db_pool.clone());
    let summary = service.get_metrics_summary(&query).await?;

    // Cache the result
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(serialized) = serde_json::to_string(&summary) {
                let _: std::result::Result<(), _> =
                    conn.set_ex(&cache_key, serialized, state.cache_ttl()).await;
            }
        }
    }

    info!("Metrics summary fetched successfully");
    Ok(Json(summary))
}

/// GET /api/v1/metrics/conversations - Get conversation metrics
///
/// Returns metrics about conversations including message counts,
/// token usage, and costs per conversation.
#[instrument(skip(state))]
async fn get_conversations(
    State(state): State<Arc<AppState>>,
    Query(query): Query<AnalyticsQuery>,
) -> Result<Json<ConversationMetrics>> {
    info!("Fetching conversation metrics");

    let cache_key = query.cache_key("metrics:conversations");

    // Try cache
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(cached) = conn.get::<_, String>(&cache_key).await {
                if let Ok(result) = serde_json::from_str::<ConversationMetrics>(&cached) {
                    info!("Returning cached conversation metrics");
                    return Ok(Json(result));
                }
            }
        }
    }

    let (start_time, end_time) = crate::db::DatabaseService::get_time_range(&query);
    let service = AnalyticsService::new(state.db_pool.clone());
    let metrics = service.get_conversation_metrics(start_time, end_time).await?;

    // Cache the result
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(serialized) = serde_json::to_string(&metrics) {
                let _: std::result::Result<(), _> =
                    conn.set_ex(&cache_key, serialized, state.cache_ttl()).await;
            }
        }
    }

    Ok(Json(metrics))
}

/// GET /api/v1/metrics/models - Compare multiple models
///
/// Compare performance, cost, and quality metrics across multiple models.
///
/// Query Parameters:
/// - models: Comma-separated list of models to compare (at least 2)
/// - start_time: Start of time range (ISO 8601)
/// - end_time: End of time range (ISO 8601)
#[instrument(skip(state))]
async fn compare_models(
    State(state): State<Arc<AppState>>,
    Query(query): Query<ModelComparisonQuery>,
) -> Result<Json<ModelComparison>> {
    info!("Comparing {} models", query.models.len());

    if query.models.len() < 2 {
        warn!("Model comparison requires at least 2 models");
        return Err(crate::error::Error::Validation(
            "At least 2 models are required for comparison".to_string(),
        ));
    }

    let service = AnalyticsService::new(state.db_pool.clone());
    let comparison = service.compare_models(&query).await?;

    info!("Model comparison completed successfully");
    Ok(Json(comparison))
}

/// GET /api/v1/metrics/trends - Get trend data
///
/// Returns time-series trend data for cost, performance, and usage metrics.
#[instrument(skip(state))]
async fn get_trends(
    State(state): State<Arc<AppState>>,
    Query(query): Query<AnalyticsQuery>,
) -> Result<Json<TrendsData>> {
    info!("Fetching trends data");

    let cache_key = query.cache_key("metrics:trends");

    // Try cache
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(cached) = conn.get::<_, String>(&cache_key).await {
                if let Ok(result) = serde_json::from_str::<TrendsData>(&cached) {
                    info!("Returning cached trends data");
                    return Ok(Json(result));
                }
            }
        }
    }

    let service = AnalyticsService::new(state.db_pool.clone());
    let trends = service.get_trends(&query).await?;

    // Cache the result
    if state.config.cache.enabled {
        if let Ok(mut conn) = state.redis_client.get_async_connection().await {
            if let Ok(serialized) = serde_json::to_string(&trends) {
                let _: std::result::Result<(), _> =
                    conn.set_ex(&cache_key, serialized, state.cache_ttl()).await;
            }
        }
    }

    Ok(Json(trends))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_routes_creation() {
        let _router = routes();
        // Router created successfully
        assert!(true);
    }
}

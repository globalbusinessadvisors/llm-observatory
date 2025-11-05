use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Common query parameters for analytics endpoints
#[derive(Debug, Deserialize, Clone)]
pub struct AnalyticsQuery {
    /// Start time for the query range
    pub start_time: Option<DateTime<Utc>>,
    /// End time for the query range
    pub end_time: Option<DateTime<Utc>>,
    /// Filter by provider (e.g., "openai", "anthropic")
    pub provider: Option<String>,
    /// Filter by model (e.g., "gpt-4", "claude-3-opus")
    pub model: Option<String>,
    /// Filter by environment (e.g., "production", "staging")
    pub environment: Option<String>,
    /// Filter by user ID
    pub user_id: Option<String>,
    /// Time bucket/granularity (e.g., "1min", "1hour", "1day")
    #[serde(default = "default_granularity")]
    pub granularity: String,
}

fn default_granularity() -> String {
    "1hour".to_string()
}

/// Cost analytics response
#[derive(Debug, Serialize, Deserialize)]
pub struct CostAnalytics {
    /// Total cost in USD
    pub total_cost: f64,
    /// Prompt cost in USD
    pub prompt_cost: f64,
    /// Completion cost in USD
    pub completion_cost: f64,
    /// Number of requests
    pub request_count: i64,
    /// Average cost per request
    pub avg_cost_per_request: f64,
    /// Time series data points
    pub time_series: Vec<CostDataPoint>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CostDataPoint {
    pub timestamp: DateTime<Utc>,
    pub total_cost: f64,
    pub prompt_cost: f64,
    pub completion_cost: f64,
    pub request_count: i64,
}

/// Cost breakdown response
#[derive(Debug, Serialize, Deserialize)]
pub struct CostBreakdown {
    /// Breakdown by model
    pub by_model: Vec<CostBreakdownItem>,
    /// Breakdown by user
    pub by_user: Vec<CostBreakdownItem>,
    /// Breakdown by provider
    pub by_provider: Vec<CostBreakdownItem>,
    /// Breakdown over time
    pub by_time: Vec<CostDataPoint>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CostBreakdownItem {
    pub dimension: String,
    pub total_cost: f64,
    pub request_count: i64,
    pub percentage: f64,
}

/// Performance metrics response
#[derive(Debug, Serialize, Deserialize)]
pub struct PerformanceMetrics {
    /// Total number of requests
    pub request_count: i64,
    /// Average latency in milliseconds
    pub avg_latency_ms: f64,
    /// Minimum latency in milliseconds
    pub min_latency_ms: i32,
    /// Maximum latency in milliseconds
    pub max_latency_ms: i32,
    /// 50th percentile (median) latency
    pub p50_latency_ms: Option<f64>,
    /// 95th percentile latency
    pub p95_latency_ms: Option<f64>,
    /// 99th percentile latency
    pub p99_latency_ms: Option<f64>,
    /// Throughput (requests per second)
    pub throughput_rps: f64,
    /// Total tokens processed
    pub total_tokens: i64,
    /// Tokens per second
    pub tokens_per_second: f64,
    /// Time series data
    pub time_series: Vec<PerformanceDataPoint>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PerformanceDataPoint {
    pub timestamp: DateTime<Utc>,
    pub avg_latency_ms: f64,
    pub min_latency_ms: i32,
    pub max_latency_ms: i32,
    pub request_count: i64,
    pub total_tokens: i64,
}

/// Percentile metrics (computed from raw data)
#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct PercentileMetrics {
    pub p50: Option<f64>,
    pub p95: Option<f64>,
    pub p99: Option<f64>,
}

/// Quality metrics response
#[derive(Debug, Serialize, Deserialize)]
pub struct QualityMetrics {
    /// Total number of requests
    pub total_requests: i64,
    /// Number of successful requests
    pub successful_requests: i64,
    /// Number of failed requests
    pub failed_requests: i64,
    /// Success rate (0-1)
    pub success_rate: f64,
    /// Error rate (0-1)
    pub error_rate: f64,
    /// Average feedback score (if available)
    pub avg_feedback_score: Option<f64>,
    /// Resolution rate for issues
    pub resolution_rate: Option<f64>,
    /// Error breakdown by type
    pub error_breakdown: Vec<ErrorBreakdownItem>,
    /// Time series data
    pub time_series: Vec<QualityDataPoint>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ErrorBreakdownItem {
    pub error_type: String,
    pub count: i64,
    pub percentage: f64,
    pub sample_message: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct QualityDataPoint {
    pub timestamp: DateTime<Utc>,
    pub success_rate: f64,
    pub error_rate: f64,
    pub request_count: i64,
}

/// Model comparison request
#[derive(Debug, Deserialize)]
pub struct ModelComparisonQuery {
    /// Models to compare (at least 2)
    pub models: Vec<String>,
    /// Metrics to compare
    #[serde(default)]
    pub metrics: Vec<ComparisonMetric>,
    /// Time range
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    /// Filter by environment
    pub environment: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(rename_all = "snake_case")]
pub enum ComparisonMetric {
    Latency,
    Cost,
    Quality,
    Throughput,
    TokenUsage,
}

/// Model comparison response
#[derive(Debug, Serialize)]
pub struct ModelComparison {
    pub models: Vec<ModelComparisonResult>,
    pub summary: ModelComparisonSummary,
}

#[derive(Debug, Serialize)]
pub struct ModelComparisonResult {
    pub model: String,
    pub provider: String,
    pub metrics: ModelMetrics,
}

#[derive(Debug, Serialize)]
pub struct ModelMetrics {
    pub avg_latency_ms: f64,
    pub p95_latency_ms: Option<f64>,
    pub avg_cost_usd: f64,
    pub total_cost_usd: f64,
    pub success_rate: f64,
    pub request_count: i64,
    pub total_tokens: i64,
    pub throughput_rps: f64,
}

#[derive(Debug, Serialize)]
pub struct ModelComparisonSummary {
    pub fastest_model: String,
    pub cheapest_model: String,
    pub most_reliable_model: String,
    pub recommendations: Vec<String>,
}

/// Optimization recommendations response
#[derive(Debug, Serialize)]
pub struct OptimizationRecommendations {
    pub cost_optimizations: Vec<Recommendation>,
    pub performance_optimizations: Vec<Recommendation>,
    pub quality_optimizations: Vec<Recommendation>,
    pub overall_score: f64,
}

#[derive(Debug, Serialize)]
pub struct Recommendation {
    pub title: String,
    pub description: String,
    pub impact: ImpactLevel,
    pub potential_savings: Option<f64>,
    pub effort: EffortLevel,
    pub priority: i32,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ImpactLevel {
    High,
    Medium,
    Low,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum EffortLevel {
    High,
    Medium,
    Low,
}

/// Database row types for internal use
#[derive(Debug, sqlx::FromRow)]
pub struct CostRow {
    pub bucket: DateTime<Utc>,
    pub provider: String,
    pub model: String,
    pub total_cost_usd: Option<f64>,
    pub prompt_cost_usd: Option<f64>,
    pub completion_cost_usd: Option<f64>,
    pub request_count: i64,
}

#[derive(Debug, sqlx::FromRow)]
pub struct CostBreakdownRow {
    pub dimension: String,
    pub total_cost_usd: Option<f64>,
    pub request_count: i64,
}

#[derive(Debug, sqlx::FromRow)]
pub struct PerformanceRow {
    pub bucket: DateTime<Utc>,
    pub avg_duration_ms: Option<f64>,
    pub min_duration_ms: Option<i32>,
    pub max_duration_ms: Option<i32>,
    pub request_count: i64,
    pub total_tokens: Option<i64>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct QualityRow {
    pub bucket: DateTime<Utc>,
    pub request_count: i64,
    pub success_count: Option<i64>,
    pub error_count: Option<i64>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct ErrorBreakdownRow {
    pub status_code: String,
    pub error_count: i64,
    pub sample_error_message: Option<String>,
}

#[derive(Debug, sqlx::FromRow)]
pub struct ModelMetricsRow {
    pub provider: String,
    pub model: String,
    pub avg_duration_ms: Option<f64>,
    pub total_cost_usd: Option<f64>,
    pub request_count: i64,
    pub success_count: Option<i64>,
    pub total_tokens: Option<i64>,
}

/// Application state
#[derive(Clone)]
pub struct AppState {
    pub db_pool: sqlx::PgPool,
    pub redis_client: redis::Client,
    pub cache_ttl: u64,
}

/// API error response
#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub error: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub details: Option<String>,
}

/// Health check response
#[derive(Debug, Serialize)]
pub struct HealthResponse {
    pub status: String,
    pub database: String,
    pub redis: String,
    pub timestamp: DateTime<Utc>,
}

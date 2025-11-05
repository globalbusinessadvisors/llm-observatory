use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Cost analytics response
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct CostAnalytics {
    /// Total cost in USD
    pub total_cost: f64,
    /// Prompt/input cost in USD
    pub prompt_cost: f64,
    /// Completion/output cost in USD
    pub completion_cost: f64,
    /// Number of requests
    pub request_count: i64,
    /// Average cost per request
    pub avg_cost_per_request: f64,
    /// Time series data points
    pub time_series: Vec<CostDataPoint>,
}

/// Cost data point in time series
#[derive(Debug, Serialize, Deserialize, Clone)]
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

/// Cost breakdown item
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

/// Performance data point in time series
#[derive(Debug, Serialize, Deserialize)]
pub struct PerformanceDataPoint {
    pub timestamp: DateTime<Utc>,
    pub avg_latency_ms: f64,
    pub min_latency_ms: i32,
    pub max_latency_ms: i32,
    pub request_count: i64,
    pub total_tokens: i64,
}

/// Metrics summary response
#[derive(Debug, Serialize)]
pub struct MetricsSummary {
    pub cost: CostSummary,
    pub performance: PerformanceSummary,
    pub usage: UsageSummary,
}

/// Cost summary
#[derive(Debug, Serialize)]
pub struct CostSummary {
    pub total_cost: f64,
    pub cost_by_provider: Vec<ProviderCost>,
    pub top_models_by_cost: Vec<ModelCost>,
}

/// Performance summary
#[derive(Debug, Serialize)]
pub struct PerformanceSummary {
    pub avg_latency_ms: f64,
    pub p95_latency_ms: Option<f64>,
    pub success_rate: f64,
}

/// Usage summary
#[derive(Debug, Serialize)]
pub struct UsageSummary {
    pub total_requests: i64,
    pub total_tokens: i64,
    pub requests_by_model: Vec<ModelUsage>,
}

/// Provider cost breakdown
#[derive(Debug, Serialize)]
pub struct ProviderCost {
    pub provider: String,
    pub cost: f64,
    pub percentage: f64,
}

/// Model cost breakdown
#[derive(Debug, Serialize)]
pub struct ModelCost {
    pub model: String,
    pub provider: String,
    pub cost: f64,
}

/// Model usage statistics
#[derive(Debug, Serialize)]
pub struct ModelUsage {
    pub model: String,
    pub provider: String,
    pub requests: i64,
    pub tokens: i64,
}

/// Conversation metrics response
#[derive(Debug, Serialize)]
pub struct ConversationMetrics {
    pub total_conversations: i64,
    pub avg_messages_per_conversation: f64,
    pub avg_tokens_per_conversation: i64,
    pub avg_cost_per_conversation: f64,
    pub conversations: Vec<ConversationDetail>,
}

/// Individual conversation detail
#[derive(Debug, Serialize)]
pub struct ConversationDetail {
    pub conversation_id: String,
    pub user_id: Option<String>,
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
    pub message_count: i64,
    pub total_tokens: i64,
    pub total_cost: f64,
}

/// Model comparison response
#[derive(Debug, Serialize)]
pub struct ModelComparison {
    pub models: Vec<ModelComparisonResult>,
    pub summary: ModelComparisonSummary,
}

/// Model comparison result
#[derive(Debug, Serialize)]
pub struct ModelComparisonResult {
    pub model: String,
    pub provider: String,
    pub metrics: ModelMetrics,
}

/// Model metrics for comparison
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

/// Model comparison summary
#[derive(Debug, Serialize)]
pub struct ModelComparisonSummary {
    pub fastest_model: String,
    pub cheapest_model: String,
    pub most_reliable_model: String,
    pub recommendations: Vec<String>,
}

/// Trends response
#[derive(Debug, Serialize)]
pub struct TrendsData {
    pub cost_trend: Vec<TrendDataPoint>,
    pub performance_trend: Vec<TrendDataPoint>,
    pub usage_trend: Vec<TrendDataPoint>,
}

/// Trend data point
#[derive(Debug, Serialize)]
pub struct TrendDataPoint {
    pub timestamp: DateTime<Utc>,
    pub value: f64,
    pub change_percentage: Option<f64>,
}

/// API error response
#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub error: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub details: Option<String>,
}

impl ErrorResponse {
    pub fn new(error: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            error: error.into(),
            message: message.into(),
            details: None,
        }
    }

    pub fn with_details(mut self, details: impl Into<String>) -> Self {
        self.details = Some(details.into());
        self
    }
}

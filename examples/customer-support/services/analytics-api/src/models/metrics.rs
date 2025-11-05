use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

/// Database row types for TimescaleDB queries

/// Cost aggregation row from TimescaleDB
#[derive(Debug, FromRow)]
pub struct CostRow {
    pub bucket: DateTime<Utc>,
    pub provider: String,
    pub model: String,
    pub total_cost_usd: Option<f64>,
    pub prompt_cost_usd: Option<f64>,
    pub completion_cost_usd: Option<f64>,
    pub request_count: i64,
}

/// Cost breakdown row
#[derive(Debug, FromRow)]
pub struct CostBreakdownRow {
    pub dimension: String,
    pub total_cost_usd: Option<f64>,
    pub request_count: i64,
}

/// Performance aggregation row from TimescaleDB
#[derive(Debug, FromRow)]
pub struct PerformanceRow {
    pub bucket: DateTime<Utc>,
    pub avg_duration_ms: Option<f64>,
    pub min_duration_ms: Option<i32>,
    pub max_duration_ms: Option<i32>,
    pub request_count: i64,
    pub total_tokens: Option<i64>,
}

/// Percentile metrics row
#[derive(Debug, FromRow)]
pub struct PercentileMetrics {
    pub p50: Option<f64>,
    pub p95: Option<f64>,
    pub p99: Option<f64>,
}

/// Model metrics row for comparison
#[derive(Debug, FromRow)]
pub struct ModelMetricsRow {
    pub provider: String,
    pub model: String,
    pub avg_duration_ms: Option<f64>,
    pub total_cost_usd: Option<f64>,
    pub request_count: i64,
    pub success_count: Option<i64>,
    pub total_tokens: Option<i64>,
}

/// Conversation aggregation row
#[derive(Debug, FromRow)]
pub struct ConversationRow {
    pub conversation_id: String,
    pub user_id: Option<String>,
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
    pub message_count: i64,
    pub total_tokens: Option<i64>,
    pub total_cost: Option<f64>,
}

/// Provider summary row
#[derive(Debug, FromRow)]
pub struct ProviderSummaryRow {
    pub provider: String,
    pub total_cost: Option<f64>,
    pub request_count: i64,
}

/// Model summary row
#[derive(Debug, FromRow)]
pub struct ModelSummaryRow {
    pub provider: String,
    pub model: String,
    pub total_cost: Option<f64>,
    pub request_count: i64,
    pub total_tokens: Option<i64>,
}

/// Time bucket for aggregation
#[derive(Debug, Clone, Copy)]
pub enum TimeBucket {
    OneMinute,
    OneHour,
    OneDay,
}

impl TimeBucket {
    pub fn from_granularity(granularity: &str) -> Self {
        match granularity {
            "1min" => Self::OneMinute,
            "1hour" => Self::OneHour,
            "1day" => Self::OneDay,
            _ => Self::OneHour, // default
        }
    }

    pub fn table_name(&self) -> &'static str {
        match self {
            Self::OneMinute => "llm_metrics_1min",
            Self::OneHour => "llm_metrics_1hour",
            Self::OneDay => "llm_metrics_1day",
        }
    }

    pub fn interval_sql(&self) -> &'static str {
        match self {
            Self::OneMinute => "1 minute",
            Self::OneHour => "1 hour",
            Self::OneDay => "1 day",
        }
    }
}

/// Query filter builder for constructing WHERE clauses
#[derive(Debug, Default)]
pub struct QueryFilter {
    conditions: Vec<String>,
    param_index: usize,
}

impl QueryFilter {
    pub fn new() -> Self {
        Self {
            conditions: Vec::new(),
            param_index: 1,
        }
    }

    pub fn add_time_range(&mut self, field: &str) -> &mut Self {
        self.conditions
            .push(format!("{} >= ${}", field, self.param_index));
        self.param_index += 1;
        self.conditions
            .push(format!("{} <= ${}", field, self.param_index));
        self.param_index += 1;
        self
    }

    pub fn add_optional(&mut self, field: &str, has_value: bool) -> &mut Self {
        if has_value {
            self.conditions
                .push(format!("{} = ${}", field, self.param_index));
            self.param_index += 1;
        }
        self
    }

    pub fn build(&self) -> String {
        if self.conditions.is_empty() {
            String::new()
        } else {
            format!("WHERE {}", self.conditions.join(" AND "))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_time_bucket_from_granularity() {
        assert!(matches!(
            TimeBucket::from_granularity("1min"),
            TimeBucket::OneMinute
        ));
        assert!(matches!(
            TimeBucket::from_granularity("1hour"),
            TimeBucket::OneHour
        ));
        assert!(matches!(
            TimeBucket::from_granularity("1day"),
            TimeBucket::OneDay
        ));
        assert!(matches!(
            TimeBucket::from_granularity("invalid"),
            TimeBucket::OneHour
        ));
    }

    #[test]
    fn test_query_filter_builder() {
        let mut filter = QueryFilter::new();
        filter.add_time_range("bucket");
        let sql = filter.build();
        assert!(sql.contains("bucket >= $1"));
        assert!(sql.contains("bucket <= $2"));
    }

    #[test]
    fn test_query_filter_with_optional() {
        let mut filter = QueryFilter::new();
        filter.add_time_range("bucket");
        filter.add_optional("provider", true);
        filter.add_optional("model", false);
        let sql = filter.build();
        assert!(sql.contains("provider = $3"));
        assert!(!sql.contains("model ="));
    }
}

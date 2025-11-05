use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Common query parameters for analytics endpoints
#[derive(Debug, Deserialize, Clone)]
pub struct AnalyticsQuery {
    /// Start time for the query range (ISO 8601)
    pub start_time: Option<DateTime<Utc>>,
    /// End time for the query range (ISO 8601)
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

impl AnalyticsQuery {
    /// Generate a cache key from the query parameters
    pub fn cache_key(&self, prefix: &str) -> String {
        format!(
            "{}:{}:{}:{}:{}:{}:{}",
            prefix,
            self.start_time
                .map(|t| t.to_rfc3339())
                .unwrap_or_default(),
            self.end_time.map(|t| t.to_rfc3339()).unwrap_or_default(),
            self.provider.as_deref().unwrap_or("all"),
            self.model.as_deref().unwrap_or("all"),
            self.environment.as_deref().unwrap_or("all"),
            self.granularity
        )
    }
}

/// Model comparison request parameters
#[derive(Debug, Deserialize)]
pub struct ModelComparisonQuery {
    /// Models to compare (at least 2)
    pub models: Vec<String>,
    /// Metrics to compare
    #[serde(default)]
    pub metrics: Vec<ComparisonMetric>,
    /// Time range start
    pub start_time: Option<DateTime<Utc>>,
    /// Time range end
    pub end_time: Option<DateTime<Utc>>,
    /// Filter by environment
    pub environment: Option<String>,
}

/// Metrics available for model comparison
#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(rename_all = "snake_case")]
pub enum ComparisonMetric {
    Latency,
    Cost,
    Quality,
    Throughput,
    TokenUsage,
}

/// Time range query parameters
#[derive(Debug, Deserialize)]
pub struct TimeRangeQuery {
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
}

/// Conversation metrics query parameters
#[derive(Debug, Deserialize)]
pub struct ConversationQuery {
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    pub conversation_id: Option<String>,
    pub user_id: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_analytics_query_defaults() {
        let query = AnalyticsQuery {
            start_time: None,
            end_time: None,
            provider: None,
            model: None,
            environment: None,
            user_id: None,
            granularity: default_granularity(),
        };

        assert_eq!(query.granularity, "1hour");
    }

    #[test]
    fn test_cache_key_generation() {
        let query = AnalyticsQuery {
            start_time: None,
            end_time: None,
            provider: Some("openai".to_string()),
            model: Some("gpt-4".to_string()),
            environment: None,
            user_id: None,
            granularity: "1hour".to_string(),
        };

        let key = query.cache_key("cost");
        assert!(key.contains("cost"));
        assert!(key.contains("openai"));
        assert!(key.contains("gpt-4"));
    }
}

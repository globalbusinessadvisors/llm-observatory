/// SQL query templates for TimescaleDB

/// Query for cost time series aggregation
pub const COST_TIME_SERIES: &str = r#"
    SELECT
        bucket,
        provider,
        model,
        COALESCE(SUM(total_cost_usd), 0) as total_cost_usd,
        COALESCE(SUM(prompt_cost_usd), 0) as prompt_cost_usd,
        COALESCE(SUM(completion_cost_usd), 0) as completion_cost_usd,
        SUM(request_count) as request_count
    FROM {table}
    {where_clause}
    GROUP BY bucket, provider, model
    ORDER BY bucket
"#;

/// Query for cost breakdown by dimension
pub const COST_BREAKDOWN: &str = r#"
    SELECT
        {dimension} as dimension,
        COALESCE(SUM(total_cost_usd), 0) as total_cost_usd,
        SUM(request_count) as request_count
    FROM {table}
    {where_clause}
    GROUP BY {dimension}
    ORDER BY total_cost_usd DESC
    LIMIT 20
"#;

/// Query for performance time series aggregation
pub const PERFORMANCE_TIME_SERIES: &str = r#"
    SELECT
        bucket,
        AVG(avg_duration_ms) as avg_duration_ms,
        MIN(min_duration_ms) as min_duration_ms,
        MAX(max_duration_ms) as max_duration_ms,
        SUM(request_count) as request_count,
        COALESCE(SUM(total_tokens), 0) as total_tokens
    FROM {table}
    {where_clause}
    GROUP BY bucket
    ORDER BY bucket
"#;

/// Query for percentile calculation from raw traces
pub const PERCENTILES: &str = r#"
    SELECT
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_ms) as p50,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99
    FROM llm_traces
    {where_clause}
"#;

/// Query for model comparison
pub const MODEL_METRICS: &str = r#"
    SELECT
        provider,
        model,
        AVG(duration_ms) as avg_duration_ms,
        COALESCE(SUM(total_cost_usd), 0) as total_cost_usd,
        COUNT(*) as request_count,
        SUM(CASE WHEN status_code = 'OK' THEN 1 ELSE 0 END) as success_count,
        SUM(total_tokens) as total_tokens
    FROM llm_traces
    WHERE ts >= $1 AND ts <= $2 AND model = $3
    GROUP BY provider, model
"#;

/// Query for conversation aggregation
pub const CONVERSATION_METRICS: &str = r#"
    SELECT
        conversation_id,
        user_id,
        MIN(ts) as start_time,
        MAX(ts) as end_time,
        COUNT(*) as message_count,
        COALESCE(SUM(total_tokens), 0) as total_tokens,
        COALESCE(SUM(total_cost_usd), 0) as total_cost
    FROM llm_traces
    WHERE ts >= $1 AND ts <= $2
        AND conversation_id IS NOT NULL
    GROUP BY conversation_id, user_id
    ORDER BY start_time DESC
    LIMIT 100
"#;

/// Query for provider summary
pub const PROVIDER_SUMMARY: &str = r#"
    SELECT
        provider,
        COALESCE(SUM(total_cost_usd), 0) as total_cost,
        SUM(request_count) as request_count
    FROM {table}
    WHERE bucket >= $1 AND bucket <= $2
    GROUP BY provider
    ORDER BY total_cost DESC
"#;

/// Query for model summary
pub const MODEL_SUMMARY: &str = r#"
    SELECT
        provider,
        model,
        COALESCE(SUM(total_cost_usd), 0) as total_cost,
        SUM(request_count) as request_count,
        COALESCE(SUM(total_tokens), 0) as total_tokens
    FROM {table}
    WHERE bucket >= $1 AND bucket <= $2
    GROUP BY provider, model
    ORDER BY total_cost DESC
    LIMIT 10
"#;

/// Query for total cost
pub const TOTAL_COST: &str = r#"
    SELECT COALESCE(SUM(total_cost_usd), 0) as total
    FROM {table}
    {where_clause}
"#;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_queries_not_empty() {
        assert!(!COST_TIME_SERIES.is_empty());
        assert!(!PERFORMANCE_TIME_SERIES.is_empty());
        assert!(!MODEL_METRICS.is_empty());
    }
}

pub mod queries;

use crate::{
    error::Result,
    models::{
        metrics::*,
        requests::AnalyticsQuery,
        responses::{CostDataPoint, PerformanceDataPoint},
    },
};
use chrono::{DateTime, Duration, Utc};
use sqlx::PgPool;
use tracing::{debug, instrument};

/// Database service for executing queries against TimescaleDB
pub struct DatabaseService {
    pool: PgPool,
}

impl DatabaseService {
    /// Create a new database service
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// Get time range from query or use defaults
    pub fn get_time_range(query: &AnalyticsQuery) -> (DateTime<Utc>, DateTime<Utc>) {
        let end_time = query.end_time.unwrap_or_else(Utc::now);
        let start_time = query
            .start_time
            .unwrap_or_else(|| end_time - Duration::days(7));
        (start_time, end_time)
    }

    /// Get table name based on granularity
    pub fn get_table_name(granularity: &str) -> &'static str {
        TimeBucket::from_granularity(granularity).table_name()
    }

    /// Query cost data with aggregation
    #[instrument(skip(self))]
    pub async fn query_cost_data(&self, query: &AnalyticsQuery) -> Result<Vec<CostRow>> {
        let (start_time, end_time) = Self::get_time_range(query);
        let table = Self::get_table_name(&query.granularity);

        debug!(
            "Querying cost data from {} to {} using table {}",
            start_time, end_time, table
        );

        let mut filter = QueryFilter::new();
        filter.add_time_range("bucket");
        filter.add_optional("provider", query.provider.is_some());
        filter.add_optional("model", query.model.is_some());
        filter.add_optional("environment", query.environment.is_some());

        let sql = format!(
            r#"
            SELECT
                bucket,
                provider,
                model,
                COALESCE(SUM(total_cost_usd), 0) as total_cost_usd,
                COALESCE(SUM(prompt_cost_usd), 0) as prompt_cost_usd,
                COALESCE(SUM(completion_cost_usd), 0) as completion_cost_usd,
                SUM(request_count) as request_count
            FROM {}
            {}
            GROUP BY bucket, provider, model
            ORDER BY bucket
            "#,
            table,
            filter.build()
        );

        let mut query_builder = sqlx::query_as::<_, CostRow>(&sql)
            .bind(start_time)
            .bind(end_time);

        if let Some(ref provider) = query.provider {
            query_builder = query_builder.bind(provider);
        }
        if let Some(ref model) = query.model {
            query_builder = query_builder.bind(model);
        }
        if let Some(ref environment) = query.environment {
            query_builder = query_builder.bind(environment);
        }

        Ok(query_builder.fetch_all(&self.pool).await?)
    }

    /// Query cost breakdown by dimension
    #[instrument(skip(self))]
    pub async fn query_cost_breakdown(
        &self,
        query: &AnalyticsQuery,
        dimension: &str,
    ) -> Result<Vec<CostBreakdownRow>> {
        let (start_time, end_time) = Self::get_time_range(query);
        let table = Self::get_table_name(&query.granularity);

        let mut filter = QueryFilter::new();
        filter.add_time_range("bucket");
        filter.add_optional("environment", query.environment.is_some());

        let sql = format!(
            r#"
            SELECT
                {} as dimension,
                COALESCE(SUM(total_cost_usd), 0) as total_cost_usd,
                SUM(request_count) as request_count
            FROM {}
            {}
            GROUP BY {}
            ORDER BY total_cost_usd DESC
            LIMIT 20
            "#,
            dimension, table, filter.build(), dimension
        );

        let mut query_builder = sqlx::query_as::<_, CostBreakdownRow>(&sql)
            .bind(start_time)
            .bind(end_time);

        if let Some(ref environment) = query.environment {
            query_builder = query_builder.bind(environment);
        }

        Ok(query_builder.fetch_all(&self.pool).await?)
    }

    /// Query performance data with aggregation
    #[instrument(skip(self))]
    pub async fn query_performance_data(
        &self,
        query: &AnalyticsQuery,
    ) -> Result<Vec<PerformanceRow>> {
        let (start_time, end_time) = Self::get_time_range(query);
        let table = Self::get_table_name(&query.granularity);

        let mut filter = QueryFilter::new();
        filter.add_time_range("bucket");
        filter.add_optional("provider", query.provider.is_some());
        filter.add_optional("model", query.model.is_some());
        filter.add_optional("environment", query.environment.is_some());

        let sql = format!(
            r#"
            SELECT
                bucket,
                AVG(avg_duration_ms) as avg_duration_ms,
                MIN(min_duration_ms) as min_duration_ms,
                MAX(max_duration_ms) as max_duration_ms,
                SUM(request_count) as request_count,
                COALESCE(SUM(total_tokens), 0) as total_tokens
            FROM {}
            {}
            GROUP BY bucket
            ORDER BY bucket
            "#,
            table,
            filter.build()
        );

        let mut query_builder = sqlx::query_as::<_, PerformanceRow>(&sql)
            .bind(start_time)
            .bind(end_time);

        if let Some(ref provider) = query.provider {
            query_builder = query_builder.bind(provider);
        }
        if let Some(ref model) = query.model {
            query_builder = query_builder.bind(model);
        }
        if let Some(ref environment) = query.environment {
            query_builder = query_builder.bind(environment);
        }

        Ok(query_builder.fetch_all(&self.pool).await?)
    }

    /// Calculate percentiles from raw trace data
    #[instrument(skip(self))]
    pub async fn query_percentiles(&self, query: &AnalyticsQuery) -> Result<PercentileMetrics> {
        let (start_time, end_time) = Self::get_time_range(query);

        let mut filter = QueryFilter::new();
        filter.add_time_range("ts");
        filter.add_optional("provider", query.provider.is_some());
        filter.add_optional("model", query.model.is_some());
        filter.add_optional("environment", query.environment.is_some());

        let sql = format!(
            r#"
            SELECT
                PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_ms) as p50,
                PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95,
                PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99
            FROM llm_traces
            {}
            "#,
            filter.build()
        );

        let mut query_builder = sqlx::query_as::<_, PercentileMetrics>(&sql)
            .bind(start_time)
            .bind(end_time);

        if let Some(ref provider) = query.provider {
            query_builder = query_builder.bind(provider);
        }
        if let Some(ref model) = query.model {
            query_builder = query_builder.bind(model);
        }
        if let Some(ref environment) = query.environment {
            query_builder = query_builder.bind(environment);
        }

        Ok(query_builder.fetch_one(&self.pool).await?)
    }

    /// Query model metrics for comparison
    #[instrument(skip(self))]
    pub async fn query_model_metrics(
        &self,
        model: &str,
        start_time: DateTime<Utc>,
        end_time: DateTime<Utc>,
    ) -> Result<Option<ModelMetricsRow>> {
        let sql = r#"
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

        Ok(sqlx::query_as::<_, ModelMetricsRow>(sql)
            .bind(start_time)
            .bind(end_time)
            .bind(model)
            .fetch_optional(&self.pool)
            .await?)
    }

    /// Query provider summary
    #[instrument(skip(self))]
    pub async fn query_provider_summary(
        &self,
        query: &AnalyticsQuery,
    ) -> Result<Vec<ProviderSummaryRow>> {
        let (start_time, end_time) = Self::get_time_range(query);
        let table = Self::get_table_name(&query.granularity);

        let sql = format!(
            r#"
            SELECT
                provider,
                COALESCE(SUM(total_cost_usd), 0) as total_cost,
                SUM(request_count) as request_count
            FROM {}
            WHERE bucket >= $1 AND bucket <= $2
            GROUP BY provider
            ORDER BY total_cost DESC
            "#,
            table
        );

        Ok(sqlx::query_as::<_, ProviderSummaryRow>(&sql)
            .bind(start_time)
            .bind(end_time)
            .fetch_all(&self.pool)
            .await?)
    }

    /// Query model summary
    #[instrument(skip(self))]
    pub async fn query_model_summary(
        &self,
        query: &AnalyticsQuery,
    ) -> Result<Vec<ModelSummaryRow>> {
        let (start_time, end_time) = Self::get_time_range(query);
        let table = Self::get_table_name(&query.granularity);

        let sql = format!(
            r#"
            SELECT
                provider,
                model,
                COALESCE(SUM(total_cost_usd), 0) as total_cost,
                SUM(request_count) as request_count,
                COALESCE(SUM(total_tokens), 0) as total_tokens
            FROM {}
            WHERE bucket >= $1 AND bucket <= $2
            GROUP BY provider, model
            ORDER BY total_cost DESC
            LIMIT 10
            "#,
            table
        );

        Ok(sqlx::query_as::<_, ModelSummaryRow>(&sql)
            .bind(start_time)
            .bind(end_time)
            .fetch_all(&self.pool)
            .await?)
    }

    /// Convert cost rows to data points
    pub fn cost_rows_to_data_points(rows: Vec<CostRow>) -> Vec<CostDataPoint> {
        rows.into_iter()
            .map(|row| CostDataPoint {
                timestamp: row.bucket,
                total_cost: row.total_cost_usd.unwrap_or(0.0),
                prompt_cost: row.prompt_cost_usd.unwrap_or(0.0),
                completion_cost: row.completion_cost_usd.unwrap_or(0.0),
                request_count: row.request_count,
            })
            .collect()
    }

    /// Convert performance rows to data points
    pub fn performance_rows_to_data_points(rows: Vec<PerformanceRow>) -> Vec<PerformanceDataPoint> {
        rows.into_iter()
            .map(|row| PerformanceDataPoint {
                timestamp: row.bucket,
                avg_latency_ms: row.avg_duration_ms.unwrap_or(0.0),
                min_latency_ms: row.min_duration_ms.unwrap_or(0),
                max_latency_ms: row.max_duration_ms.unwrap_or(0),
                request_count: row.request_count,
                total_tokens: row.total_tokens.unwrap_or(0),
            })
            .collect()
    }
}

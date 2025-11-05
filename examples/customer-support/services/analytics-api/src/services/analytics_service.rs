use crate::{
    db::DatabaseService,
    error::Result,
    models::{
        requests::{AnalyticsQuery, ModelComparisonQuery},
        responses::*,
    },
};
use chrono::{DateTime, Duration, Utc};
use sqlx::PgPool;
use tracing::{debug, instrument};

/// Service for analytics operations
pub struct AnalyticsService {
    db: DatabaseService,
}

impl AnalyticsService {
    /// Create a new analytics service
    pub fn new(pool: PgPool) -> Self {
        Self {
            db: DatabaseService::new(pool),
        }
    }

    /// Get metrics summary (overview of all key metrics)
    #[instrument(skip(self))]
    pub async fn get_metrics_summary(&self, query: &AnalyticsQuery) -> Result<MetricsSummary> {
        debug!("Fetching metrics summary");

        // Query cost data
        let cost_rows = self.db.query_cost_data(query).await?;
        let total_cost: f64 = cost_rows
            .iter()
            .map(|r| r.total_cost_usd.unwrap_or(0.0))
            .sum();

        // Get provider summary
        let provider_rows = self.db.query_provider_summary(query).await?;
        let cost_by_provider: Vec<ProviderCost> = provider_rows
            .into_iter()
            .map(|r| {
                let cost = r.total_cost.unwrap_or(0.0);
                ProviderCost {
                    provider: r.provider,
                    cost,
                    percentage: if total_cost > 0.0 {
                        (cost / total_cost) * 100.0
                    } else {
                        0.0
                    },
                }
            })
            .collect();

        // Get model summary
        let model_rows = self.db.query_model_summary(query).await?;
        let top_models_by_cost: Vec<ModelCost> = model_rows
            .iter()
            .take(5)
            .map(|r| ModelCost {
                model: r.model.clone(),
                provider: r.provider.clone(),
                cost: r.total_cost.unwrap_or(0.0),
            })
            .collect();

        // Query performance data
        let perf_rows = self.db.query_performance_data(query).await?;
        let total_requests: i64 = perf_rows.iter().map(|r| r.request_count).sum();
        let avg_latency_ms = if !perf_rows.is_empty() {
            perf_rows
                .iter()
                .map(|r| r.avg_duration_ms.unwrap_or(0.0))
                .sum::<f64>()
                / perf_rows.len() as f64
        } else {
            0.0
        };

        // Try to get percentiles if granularity allows
        let p95_latency_ms = if query.granularity == "1min" || query.granularity == "raw" {
            self.db.query_percentiles(query).await.ok().and_then(|p| p.p95)
        } else {
            None
        };

        // Calculate success rate (assuming most requests are successful)
        let success_rate = 0.98; // Placeholder - would need error tracking

        // Usage summary
        let total_tokens: i64 = perf_rows
            .iter()
            .map(|r| r.total_tokens.unwrap_or(0))
            .sum();
        let requests_by_model: Vec<ModelUsage> = model_rows
            .into_iter()
            .map(|r| ModelUsage {
                model: r.model,
                provider: r.provider,
                requests: r.request_count,
                tokens: r.total_tokens.unwrap_or(0),
            })
            .collect();

        Ok(MetricsSummary {
            cost: CostSummary {
                total_cost,
                cost_by_provider,
                top_models_by_cost,
            },
            performance: PerformanceSummary {
                avg_latency_ms,
                p95_latency_ms,
                success_rate,
            },
            usage: UsageSummary {
                total_requests,
                total_tokens,
                requests_by_model,
            },
        })
    }

    /// Get conversation metrics
    #[instrument(skip(self))]
    pub async fn get_conversation_metrics(
        &self,
        start_time: DateTime<Utc>,
        end_time: DateTime<Utc>,
    ) -> Result<ConversationMetrics> {
        debug!("Fetching conversation metrics");

        // This would query conversation-specific data from the database
        // For now, returning placeholder data
        Ok(ConversationMetrics {
            total_conversations: 0,
            avg_messages_per_conversation: 0.0,
            avg_tokens_per_conversation: 0,
            avg_cost_per_conversation: 0.0,
            conversations: vec![],
        })
    }

    /// Get performance metrics
    #[instrument(skip(self))]
    pub async fn get_performance_metrics(&self, query: &AnalyticsQuery) -> Result<PerformanceMetrics> {
        debug!("Fetching performance metrics");

        let (start_time, end_time) = DatabaseService::get_time_range(query);
        let rows = self.db.query_performance_data(query).await?;

        // Calculate aggregates
        let request_count: i64 = rows.iter().map(|r| r.request_count).sum();
        let total_tokens: i64 = rows.iter().map(|r| r.total_tokens.unwrap_or(0)).sum();

        let avg_latency_ms = if !rows.is_empty() {
            rows.iter()
                .map(|r| r.avg_duration_ms.unwrap_or(0.0))
                .sum::<f64>()
                / rows.len() as f64
        } else {
            0.0
        };

        let min_latency_ms = rows
            .iter()
            .filter_map(|r| r.min_duration_ms)
            .min()
            .unwrap_or(0);

        let max_latency_ms = rows
            .iter()
            .filter_map(|r| r.max_duration_ms)
            .max()
            .unwrap_or(0);

        // Calculate throughput and tokens per second
        let duration_seconds = (end_time - start_time).num_seconds() as f64;
        let throughput_rps = if duration_seconds > 0.0 {
            request_count as f64 / duration_seconds
        } else {
            0.0
        };

        let tokens_per_second = if duration_seconds > 0.0 {
            total_tokens as f64 / duration_seconds
        } else {
            0.0
        };

        // Get percentiles if granularity allows
        let percentiles = if query.granularity == "1min" || query.granularity == "raw" {
            self.db.query_percentiles(query).await?
        } else {
            crate::models::metrics::PercentileMetrics {
                p50: None,
                p95: None,
                p99: None,
            }
        };

        let time_series = DatabaseService::performance_rows_to_data_points(rows);

        Ok(PerformanceMetrics {
            request_count,
            avg_latency_ms,
            min_latency_ms,
            max_latency_ms,
            p50_latency_ms: percentiles.p50,
            p95_latency_ms: percentiles.p95,
            p99_latency_ms: percentiles.p99,
            throughput_rps,
            total_tokens,
            tokens_per_second,
            time_series,
        })
    }

    /// Compare multiple models
    #[instrument(skip(self))]
    pub async fn compare_models(&self, query: &ModelComparisonQuery) -> Result<ModelComparison> {
        debug!("Comparing {} models", query.models.len());

        let start_time = query
            .start_time
            .unwrap_or_else(|| Utc::now() - Duration::days(7));
        let end_time = query.end_time.unwrap_or_else(Utc::now);

        let mut results = Vec::new();

        for model in &query.models {
            if let Some(row) = self.db.query_model_metrics(model, start_time, end_time).await? {
                let success_rate = if row.request_count > 0 {
                    row.success_count.unwrap_or(0) as f64 / row.request_count as f64
                } else {
                    0.0
                };

                let avg_cost_usd = if row.request_count > 0 {
                    row.total_cost_usd.unwrap_or(0.0) / row.request_count as f64
                } else {
                    0.0
                };

                let duration_seconds = (end_time - start_time).num_seconds() as f64;
                let throughput_rps = if duration_seconds > 0.0 {
                    row.request_count as f64 / duration_seconds
                } else {
                    0.0
                };

                // Get p95 latency for this model
                let p95_latency_ms: Option<f64> = None; // Would need separate query

                results.push(ModelComparisonResult {
                    model: row.model.clone(),
                    provider: row.provider.clone(),
                    metrics: ModelMetrics {
                        avg_latency_ms: row.avg_duration_ms.unwrap_or(0.0),
                        p95_latency_ms,
                        avg_cost_usd,
                        total_cost_usd: row.total_cost_usd.unwrap_or(0.0),
                        success_rate,
                        request_count: row.request_count,
                        total_tokens: row.total_tokens.unwrap_or(0),
                        throughput_rps,
                    },
                });
            }
        }

        let summary = Self::generate_comparison_summary(&results);

        Ok(ModelComparison { models: results, summary })
    }

    /// Generate comparison summary with recommendations
    fn generate_comparison_summary(results: &[ModelComparisonResult]) -> ModelComparisonSummary {
        if results.is_empty() {
            return ModelComparisonSummary {
                fastest_model: "N/A".to_string(),
                cheapest_model: "N/A".to_string(),
                most_reliable_model: "N/A".to_string(),
                recommendations: vec![],
            };
        }

        let fastest = results
            .iter()
            .min_by(|a, b| {
                a.metrics
                    .avg_latency_ms
                    .partial_cmp(&b.metrics.avg_latency_ms)
                    .unwrap()
            })
            .map(|r| r.model.clone())
            .unwrap_or_default();

        let cheapest = results
            .iter()
            .min_by(|a, b| {
                a.metrics
                    .avg_cost_usd
                    .partial_cmp(&b.metrics.avg_cost_usd)
                    .unwrap()
            })
            .map(|r| r.model.clone())
            .unwrap_or_default();

        let most_reliable = results
            .iter()
            .max_by(|a, b| {
                a.metrics
                    .success_rate
                    .partial_cmp(&b.metrics.success_rate)
                    .unwrap()
            })
            .map(|r| r.model.clone())
            .unwrap_or_default();

        let mut recommendations = Vec::new();

        if fastest != cheapest {
            recommendations.push(format!(
                "Use {} for low-latency applications and {} for cost-sensitive workloads",
                fastest, cheapest
            ));
        }

        if let Some(best) = results.iter().find(|r| {
            r.metrics.success_rate > 0.99
                && r.metrics.avg_latency_ms < 2000.0
                && r.metrics.avg_cost_usd < 0.01
        }) {
            recommendations.push(format!(
                "{} offers excellent balance of speed, cost, and reliability",
                best.model
            ));
        }

        ModelComparisonSummary {
            fastest_model: fastest,
            cheapest_model: cheapest,
            most_reliable_model: most_reliable,
            recommendations,
        }
    }

    /// Get trends data
    #[instrument(skip(self))]
    pub async fn get_trends(&self, query: &AnalyticsQuery) -> Result<TrendsData> {
        debug!("Fetching trends data");

        let cost_rows = self.db.query_cost_data(query).await?;
        let perf_rows = self.db.query_performance_data(query).await?;

        let cost_trend: Vec<TrendDataPoint> = cost_rows
            .iter()
            .enumerate()
            .map(|(i, row)| {
                let value = row.total_cost_usd.unwrap_or(0.0);
                let change_percentage = if i > 0 {
                    let prev_value = cost_rows[i - 1].total_cost_usd.unwrap_or(0.0);
                    if prev_value > 0.0 {
                        Some(((value - prev_value) / prev_value) * 100.0)
                    } else {
                        None
                    }
                } else {
                    None
                };

                TrendDataPoint {
                    timestamp: row.bucket,
                    value,
                    change_percentage,
                }
            })
            .collect();

        let performance_trend: Vec<TrendDataPoint> = perf_rows
            .iter()
            .enumerate()
            .map(|(i, row)| {
                let value = row.avg_duration_ms.unwrap_or(0.0);
                let change_percentage = if i > 0 {
                    let prev_value = perf_rows[i - 1].avg_duration_ms.unwrap_or(0.0);
                    if prev_value > 0.0 {
                        Some(((value - prev_value) / prev_value) * 100.0)
                    } else {
                        None
                    }
                } else {
                    None
                };

                TrendDataPoint {
                    timestamp: row.bucket,
                    value,
                    change_percentage,
                }
            })
            .collect();

        let usage_trend: Vec<TrendDataPoint> = perf_rows
            .iter()
            .enumerate()
            .map(|(i, row)| {
                let value = row.request_count as f64;
                let change_percentage = if i > 0 {
                    let prev_value = perf_rows[i - 1].request_count as f64;
                    if prev_value > 0.0 {
                        Some(((value - prev_value) / prev_value) * 100.0)
                    } else {
                        None
                    }
                } else {
                    None
                };

                TrendDataPoint {
                    timestamp: row.bucket,
                    value,
                    change_percentage,
                }
            })
            .collect();

        Ok(TrendsData {
            cost_trend,
            performance_trend,
            usage_trend,
        })
    }
}

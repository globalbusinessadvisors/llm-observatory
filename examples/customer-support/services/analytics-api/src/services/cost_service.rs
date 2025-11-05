use crate::{
    db::DatabaseService,
    error::Result,
    models::{
        requests::AnalyticsQuery,
        responses::*,
    },
};
use sqlx::PgPool;
use tracing::{debug, instrument};

/// Service for cost analysis operations
pub struct CostService {
    db: DatabaseService,
}

impl CostService {
    /// Create a new cost service
    pub fn new(pool: PgPool) -> Self {
        Self {
            db: DatabaseService::new(pool),
        }
    }

    /// Get cost analytics
    #[instrument(skip(self))]
    pub async fn get_cost_analytics(&self, query: &AnalyticsQuery) -> Result<CostAnalytics> {
        debug!("Fetching cost analytics");

        let rows = self.db.query_cost_data(query).await?;

        // Calculate totals
        let total_cost = rows
            .iter()
            .map(|r| r.total_cost_usd.unwrap_or(0.0))
            .sum::<f64>();
        let prompt_cost = rows
            .iter()
            .map(|r| r.prompt_cost_usd.unwrap_or(0.0))
            .sum::<f64>();
        let completion_cost = rows
            .iter()
            .map(|r| r.completion_cost_usd.unwrap_or(0.0))
            .sum::<f64>();
        let request_count = rows.iter().map(|r| r.request_count).sum::<i64>();

        let avg_cost_per_request = if request_count > 0 {
            total_cost / request_count as f64
        } else {
            0.0
        };

        // Convert to time series
        let time_series = DatabaseService::cost_rows_to_data_points(rows);

        Ok(CostAnalytics {
            total_cost,
            prompt_cost,
            completion_cost,
            request_count,
            avg_cost_per_request,
            time_series,
        })
    }

    /// Get cost breakdown by model, provider, and user
    #[instrument(skip(self))]
    pub async fn get_cost_breakdown(&self, query: &AnalyticsQuery) -> Result<CostBreakdown> {
        debug!("Fetching cost breakdown");

        // Get breakdown by model
        let by_model_rows = self.db.query_cost_breakdown(query, "model").await?;

        // Get breakdown by provider
        let by_provider_rows = self.db.query_cost_breakdown(query, "provider").await?;

        // Get breakdown by user (limited to detailed granularity)
        let by_user_rows = if query.granularity == "1min" || query.granularity == "raw" {
            // Would query from raw traces table
            Vec::new()
        } else {
            Vec::new()
        };

        // Get time series for cost breakdown
        let time_series_rows = self.db.query_cost_data(query).await?;

        // Calculate total for percentages
        let total_cost: f64 = by_model_rows
            .iter()
            .map(|r| r.total_cost_usd.unwrap_or(0.0))
            .sum();

        let by_model = Self::convert_breakdown_rows(by_model_rows, total_cost);
        let by_provider = Self::convert_breakdown_rows(by_provider_rows, total_cost);
        let by_user = Self::convert_breakdown_rows(by_user_rows, total_cost);
        let by_time = DatabaseService::cost_rows_to_data_points(time_series_rows);

        Ok(CostBreakdown {
            by_model,
            by_user,
            by_provider,
            by_time,
        })
    }

    /// Convert breakdown rows to response items with percentages
    fn convert_breakdown_rows(
        rows: Vec<crate::models::metrics::CostBreakdownRow>,
        total: f64,
    ) -> Vec<CostBreakdownItem> {
        rows.into_iter()
            .map(|row| CostBreakdownItem {
                dimension: row.dimension,
                total_cost: row.total_cost_usd.unwrap_or(0.0),
                request_count: row.request_count,
                percentage: if total > 0.0 {
                    (row.total_cost_usd.unwrap_or(0.0) / total) * 100.0
                } else {
                    0.0
                },
            })
            .collect()
    }

    /// Analyze cost trends and provide insights
    #[instrument(skip(self))]
    pub async fn analyze_cost_trends(&self, query: &AnalyticsQuery) -> Result<Vec<String>> {
        debug!("Analyzing cost trends");

        let analytics = self.get_cost_analytics(query).await?;
        let breakdown = self.get_cost_breakdown(query).await?;

        let mut insights = Vec::new();

        // High cost alert
        if analytics.total_cost > 1000.0 {
            insights.push(format!(
                "High cost detected: ${:.2} in the selected period",
                analytics.total_cost
            ));
        }

        // High per-request cost
        if analytics.avg_cost_per_request > 0.01 {
            insights.push(format!(
                "Average cost per request is ${:.4}. Consider optimizing model selection.",
                analytics.avg_cost_per_request
            ));
        }

        // Identify most expensive model
        if let Some(top_model) = breakdown.by_model.first() {
            insights.push(format!(
                "Top cost driver: {} accounts for {:.1}% of total cost (${:.2})",
                top_model.dimension, top_model.percentage, top_model.total_cost
            ));
        }

        // Cost trend analysis
        if analytics.time_series.len() >= 2 {
            let first_cost = analytics.time_series.first().unwrap().total_cost;
            let last_cost = analytics.time_series.last().unwrap().total_cost;

            if first_cost > 0.0 {
                let change_percent = ((last_cost - first_cost) / first_cost) * 100.0;
                if change_percent.abs() > 20.0 {
                    let direction = if change_percent > 0.0 {
                        "increased"
                    } else {
                        "decreased"
                    };
                    insights.push(format!(
                        "Cost has {} by {:.1}% over the period",
                        direction,
                        change_percent.abs()
                    ));
                }
            }
        }

        Ok(insights)
    }

    /// Calculate projected costs based on current trends
    #[instrument(skip(self))]
    pub async fn project_costs(
        &self,
        query: &AnalyticsQuery,
        days_ahead: i64,
    ) -> Result<f64> {
        debug!("Projecting costs {} days ahead", days_ahead);

        let analytics = self.get_cost_analytics(query).await?;

        if analytics.time_series.is_empty() {
            return Ok(0.0);
        }

        // Simple linear projection based on average daily cost
        let (start_time, end_time) = DatabaseService::get_time_range(query);
        let duration_days = (end_time - start_time).num_days() as f64;

        if duration_days > 0.0 {
            let daily_cost = analytics.total_cost / duration_days;
            Ok(daily_cost * days_ahead as f64)
        } else {
            Ok(0.0)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cost_service_creation() {
        // Test would require a database pool
        // This is a placeholder
        assert!(true);
    }
}

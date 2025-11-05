/// Analytics API for LLM Observatory
///
/// This service provides high-performance analytics and aggregation
/// of LLM usage metrics stored in TimescaleDB. It offers:
///
/// - Cost analytics and breakdowns
/// - Performance metrics and percentiles
/// - Model comparison
/// - Trend analysis
/// - Redis caching for improved performance

pub mod app;
pub mod config;
pub mod db;
pub mod error;
pub mod models;
pub mod routes;
pub mod services;

pub use app::build_app;
pub use config::Config;
pub use error::{Error, Result};

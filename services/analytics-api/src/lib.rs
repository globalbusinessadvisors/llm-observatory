pub mod models;
pub mod routes;
pub mod services;

// Re-export commonly used types
pub use models::{AppState, AnalyticsQuery, ErrorResponse, HealthResponse};
pub use services::timescaledb::TimescaleDBService;

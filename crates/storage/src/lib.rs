//! # LLM Observatory Storage
//!
//! This crate provides the storage layer for LLM Observatory, handling persistence
//! of observability data including traces, metrics, and logs.
//!
//! ## Features
//!
//! - **PostgreSQL**: Primary storage backend for structured observability data
//! - **Redis**: Caching and real-time data streaming
//! - **Batch Writers**: Efficient bulk insert operations
//! - **Connection Pooling**: Managed database connections with automatic retry
//! - **Migrations**: Automated schema management
//!
//! ## Architecture
//!
//! The storage layer is organized into several modules:
//!
//! - `config`: Database configuration and connection settings
//! - `pool`: Connection pool management
//! - `models`: Data models representing database entities
//! - `repositories`: Query interfaces for reading data
//! - `writers`: Batch writing interfaces for inserting data
//! - `error`: Storage-specific error types
//!
//! ## Usage
//!
//! ```no_run
//! use llm_observatory_storage::{StorageConfig, StoragePool};
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!     // Load configuration
//!     let config = StorageConfig::from_env()?;
//!
//!     // Create connection pool
//!     let pool = StoragePool::new(config).await?;
//!
//!     // Use repositories and writers
//!     // TODO: Add usage examples once implemented
//!
//!     Ok(())
//! }
//! ```

pub mod config;
pub mod error;
pub mod health;
pub mod metrics;
pub mod models;
pub mod pool;
pub mod repositories;
pub mod validation;
pub mod writers;

// Re-exports for convenience
pub use config::StorageConfig;
pub use error::{StorageError, StorageResult};
pub use health::HealthServer;
pub use metrics::StorageMetrics;
pub use pool::{HealthCheckResult, PoolStats, StoragePool};
pub use validation::Validate;

/// Storage crate version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert!(!VERSION.is_empty());
    }
}

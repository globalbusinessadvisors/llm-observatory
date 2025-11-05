pub mod metrics;
pub mod requests;
pub mod responses;

use crate::config::Config;
use redis::Client as RedisClient;
use sqlx::PgPool;
use std::sync::Arc;

/// Application state shared across all request handlers
#[derive(Clone)]
pub struct AppState {
    /// PostgreSQL connection pool (TimescaleDB)
    pub db_pool: PgPool,
    /// Redis client for caching
    pub redis_client: RedisClient,
    /// Application configuration
    pub config: Config,
}

impl AppState {
    /// Get the cache TTL from configuration
    pub fn cache_ttl(&self) -> u64 {
        self.config.cache.default_ttl
    }
}

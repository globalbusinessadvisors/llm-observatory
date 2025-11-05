use crate::error::{Error, Result};
use serde::Deserialize;
use std::net::IpAddr;

/// Application configuration
#[derive(Debug, Clone, Deserialize)]
pub struct Config {
    pub app: AppConfig,
    pub database: DatabaseConfig,
    pub redis: RedisConfig,
    pub cache: CacheConfig,
}

/// Application server configuration
#[derive(Debug, Clone, Deserialize)]
pub struct AppConfig {
    #[serde(default = "default_host")]
    pub host: IpAddr,
    #[serde(default = "default_port")]
    pub port: u16,
    #[serde(default = "default_cors_origins")]
    pub cors_origins: Vec<String>,
}

/// Database configuration
#[derive(Debug, Clone, Deserialize)]
pub struct DatabaseConfig {
    pub url: String,
    #[serde(default = "default_max_connections")]
    pub max_connections: u32,
    #[serde(default = "default_min_connections")]
    pub min_connections: u32,
    #[serde(default = "default_connect_timeout")]
    pub connect_timeout: u64,
    #[serde(default = "default_idle_timeout")]
    pub idle_timeout: u64,
    #[serde(default = "default_max_lifetime")]
    pub max_lifetime: u64,
}

/// Redis configuration
#[derive(Debug, Clone, Deserialize)]
pub struct RedisConfig {
    pub url: String,
}

/// Cache configuration
#[derive(Debug, Clone, Deserialize)]
pub struct CacheConfig {
    #[serde(default = "default_cache_ttl")]
    pub default_ttl: u64,
    #[serde(default = "default_cache_enabled")]
    pub enabled: bool,
}

// Default values
fn default_host() -> IpAddr {
    "0.0.0.0".parse().unwrap()
}

fn default_port() -> u16 {
    8080
}

fn default_cors_origins() -> Vec<String> {
    vec!["*".to_string()]
}

fn default_max_connections() -> u32 {
    20
}

fn default_min_connections() -> u32 {
    5
}

fn default_connect_timeout() -> u64 {
    30
}

fn default_idle_timeout() -> u64 {
    300
}

fn default_max_lifetime() -> u64 {
    1800
}

fn default_cache_ttl() -> u64 {
    3600 // 1 hour
}

fn default_cache_enabled() -> bool {
    true
}

impl Config {
    /// Load configuration from environment variables
    pub fn from_env() -> Result<Self> {
        let app_host = std::env::var("APP_HOST")
            .unwrap_or_else(|_| "0.0.0.0".to_string())
            .parse()
            .map_err(|e| Error::Config(format!("Invalid APP_HOST: {}", e)))?;

        let app_port = std::env::var("API_PORT")
            .unwrap_or_else(|_| "8080".to_string())
            .parse()
            .map_err(|e| Error::Config(format!("Invalid API_PORT: {}", e)))?;

        let cors_origins = std::env::var("CORS_ORIGINS")
            .unwrap_or_else(|_| "*".to_string())
            .split(',')
            .map(|s| s.trim().to_string())
            .collect();

        // Database configuration
        let database_url = std::env::var("DATABASE_READONLY_URL")
            .or_else(|_| std::env::var("DATABASE_URL"))
            .map_err(|_| Error::Config("DATABASE_URL must be set".to_string()))?;

        let max_connections = std::env::var("DATABASE_MAX_CONNECTIONS")
            .unwrap_or_else(|_| "20".to_string())
            .parse()
            .unwrap_or(20);

        let min_connections = std::env::var("DATABASE_MIN_CONNECTIONS")
            .unwrap_or_else(|_| "5".to_string())
            .parse()
            .unwrap_or(5);

        // Redis configuration
        let redis_url = std::env::var("REDIS_URL").unwrap_or_else(|_| {
            let host = std::env::var("REDIS_HOST").unwrap_or_else(|_| "localhost".to_string());
            let port = std::env::var("REDIS_PORT").unwrap_or_else(|_| "6379".to_string());
            let password = std::env::var("REDIS_PASSWORD").unwrap_or_default();
            let db = std::env::var("REDIS_DB").unwrap_or_else(|_| "0".to_string());

            if password.is_empty() {
                format!("redis://{}:{}/{}", host, port, db)
            } else {
                format!("redis://:{}@{}:{}/{}", password, host, port, db)
            }
        });

        // Cache configuration
        let cache_ttl = std::env::var("CACHE_DEFAULT_TTL")
            .unwrap_or_else(|_| "3600".to_string())
            .parse()
            .unwrap_or(3600);

        let cache_enabled = std::env::var("CACHE_ENABLED")
            .unwrap_or_else(|_| "true".to_string())
            .parse()
            .unwrap_or(true);

        Ok(Config {
            app: AppConfig {
                host: app_host,
                port: app_port,
                cors_origins,
            },
            database: DatabaseConfig {
                url: database_url,
                max_connections,
                min_connections,
                connect_timeout: default_connect_timeout(),
                idle_timeout: default_idle_timeout(),
                max_lifetime: default_max_lifetime(),
            },
            redis: RedisConfig { url: redis_url },
            cache: CacheConfig {
                default_ttl: cache_ttl,
                enabled: cache_enabled,
            },
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_values() {
        assert_eq!(default_host().to_string(), "0.0.0.0");
        assert_eq!(default_port(), 8080);
        assert_eq!(default_max_connections(), 20);
        assert_eq!(default_cache_ttl(), 3600);
    }
}

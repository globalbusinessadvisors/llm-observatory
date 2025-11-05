//! Error types for the storage layer.
//!
//! This module defines all error types that can occur during storage operations,
//! including connection errors, query errors, and data validation errors.

use thiserror::Error;

/// Result type alias for storage operations.
pub type StorageResult<T> = Result<T, StorageError>;

/// Main error type for storage operations.
#[derive(Error, Debug)]
pub enum StorageError {
    /// Database connection error
    #[error("Database connection error: {0}")]
    ConnectionError(String),

    /// Query execution error
    #[error("Query execution error: {0}")]
    QueryError(String),

    /// Migration error
    #[error("Migration error: {0}")]
    MigrationError(String),

    /// Transaction error
    #[error("Transaction error: {0}")]
    TransactionError(String),

    /// Data validation error
    #[error("Data validation error: {0}")]
    ValidationError(String),

    /// Serialization/deserialization error
    #[error("Serialization error: {0}")]
    SerializationError(String),

    /// Record not found error
    #[error("Record not found: {0}")]
    NotFound(String),

    /// Configuration error
    #[error("Configuration error: {0}")]
    ConfigError(String),

    /// Pool error (connection pool issues)
    #[error("Pool error: {0}")]
    PoolError(String),

    /// Timeout error
    #[error("Operation timeout: {0}")]
    Timeout(String),

    /// Redis-specific error
    #[error("Redis error: {0}")]
    RedisError(String),

    /// Batch operation error
    #[error("Batch operation error: {0}")]
    BatchError(String),

    /// Internal error (unexpected conditions)
    #[error("Internal error: {0}")]
    Internal(String),
}

// Implement conversions from common error types

impl From<sqlx::Error> for StorageError {
    fn from(err: sqlx::Error) -> Self {
        match err {
            sqlx::Error::RowNotFound => StorageError::NotFound("Row not found".to_string()),
            sqlx::Error::PoolTimedOut => StorageError::Timeout("Pool timeout".to_string()),
            sqlx::Error::PoolClosed => StorageError::PoolError("Pool closed".to_string()),
            _ => StorageError::QueryError(err.to_string()),
        }
    }
}

impl From<sqlx::migrate::MigrateError> for StorageError {
    fn from(err: sqlx::migrate::MigrateError) -> Self {
        StorageError::MigrationError(err.to_string())
    }
}

impl From<redis::RedisError> for StorageError {
    fn from(err: redis::RedisError) -> Self {
        StorageError::RedisError(err.to_string())
    }
}

impl From<serde_json::Error> for StorageError {
    fn from(err: serde_json::Error) -> Self {
        StorageError::SerializationError(err.to_string())
    }
}

impl From<config::ConfigError> for StorageError {
    fn from(err: config::ConfigError) -> Self {
        StorageError::ConfigError(err.to_string())
    }
}

// Helper methods for creating specific error types

impl StorageError {
    /// Create a connection error with a custom message.
    pub fn connection<S: Into<String>>(msg: S) -> Self {
        StorageError::ConnectionError(msg.into())
    }

    /// Create a query error with a custom message.
    pub fn query<S: Into<String>>(msg: S) -> Self {
        StorageError::QueryError(msg.into())
    }

    /// Create a validation error with a custom message.
    pub fn validation<S: Into<String>>(msg: S) -> Self {
        StorageError::ValidationError(msg.into())
    }

    /// Create a not found error with a custom message.
    pub fn not_found<S: Into<String>>(msg: S) -> Self {
        StorageError::NotFound(msg.into())
    }

    /// Create an internal error with a custom message.
    pub fn internal<S: Into<String>>(msg: S) -> Self {
        StorageError::Internal(msg.into())
    }

    /// Check if the error is a "not found" error.
    pub fn is_not_found(&self) -> bool {
        matches!(self, StorageError::NotFound(_))
    }

    /// Check if the error is a connection-related error.
    pub fn is_connection_error(&self) -> bool {
        matches!(
            self,
            StorageError::ConnectionError(_) | StorageError::PoolError(_)
        )
    }

    /// Check if the error is retryable.
    ///
    /// Returns true for transient errors that might succeed on retry.
    pub fn is_retryable(&self) -> bool {
        matches!(
            self,
            StorageError::ConnectionError(_)
                | StorageError::PoolError(_)
                | StorageError::Timeout(_)
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_creation() {
        let err = StorageError::connection("test error");
        assert!(matches!(err, StorageError::ConnectionError(_)));
    }

    #[test]
    fn test_error_display() {
        let err = StorageError::NotFound("user with id 123".to_string());
        assert_eq!(err.to_string(), "Record not found: user with id 123");
    }

    #[test]
    fn test_is_not_found() {
        let err = StorageError::not_found("test");
        assert!(err.is_not_found());

        let err = StorageError::query("test");
        assert!(!err.is_not_found());
    }

    #[test]
    fn test_is_retryable() {
        let err = StorageError::connection("test");
        assert!(err.is_retryable());

        let err = StorageError::validation("test");
        assert!(!err.is_retryable());
    }

    #[test]
    fn test_sqlx_error_conversion() {
        let err: StorageError = sqlx::Error::RowNotFound.into();
        assert!(err.is_not_found());
    }
}

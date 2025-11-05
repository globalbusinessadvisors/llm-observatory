use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use std::fmt;

/// Application result type
pub type Result<T> = std::result::Result<T, Error>;

/// Application error types
#[derive(Debug)]
pub enum Error {
    /// Database error
    Database(String),
    /// Cache/Redis error
    Cache(String),
    /// Configuration error
    Config(String),
    /// Validation error
    Validation(String),
    /// Not found error
    NotFound(String),
    /// Server error
    Server(String),
    /// Metrics error
    Metrics(String),
    /// External service error
    External(String),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::Database(msg) => write!(f, "Database error: {}", msg),
            Error::Cache(msg) => write!(f, "Cache error: {}", msg),
            Error::Config(msg) => write!(f, "Configuration error: {}", msg),
            Error::Validation(msg) => write!(f, "Validation error: {}", msg),
            Error::NotFound(msg) => write!(f, "Not found: {}", msg),
            Error::Server(msg) => write!(f, "Server error: {}", msg),
            Error::Metrics(msg) => write!(f, "Metrics error: {}", msg),
            Error::External(msg) => write!(f, "External service error: {}", msg),
        }
    }
}

impl std::error::Error for Error {}

impl From<sqlx::Error> for Error {
    fn from(err: sqlx::Error) -> Self {
        Error::Database(err.to_string())
    }
}

impl From<redis::RedisError> for Error {
    fn from(err: redis::RedisError) -> Self {
        Error::Cache(err.to_string())
    }
}

impl From<std::io::Error> for Error {
    fn from(err: std::io::Error) -> Self {
        Error::Server(err.to_string())
    }
}

impl From<serde_json::Error> for Error {
    fn from(err: serde_json::Error) -> Self {
        Error::Validation(err.to_string())
    }
}

impl IntoResponse for Error {
    fn into_response(self) -> Response {
        let (status, error_type) = match &self {
            Error::Database(_) => (StatusCode::INTERNAL_SERVER_ERROR, "database_error"),
            Error::Cache(_) => (StatusCode::INTERNAL_SERVER_ERROR, "cache_error"),
            Error::Config(_) => (StatusCode::INTERNAL_SERVER_ERROR, "config_error"),
            Error::Validation(_) => (StatusCode::BAD_REQUEST, "validation_error"),
            Error::NotFound(_) => (StatusCode::NOT_FOUND, "not_found"),
            Error::Server(_) => (StatusCode::INTERNAL_SERVER_ERROR, "server_error"),
            Error::Metrics(_) => (StatusCode::INTERNAL_SERVER_ERROR, "metrics_error"),
            Error::External(_) => (StatusCode::BAD_GATEWAY, "external_error"),
        };

        let body = Json(json!({
            "error": error_type,
            "message": self.to_string(),
        }));

        (status, body).into_response()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_display() {
        let err = Error::Database("connection failed".to_string());
        assert_eq!(err.to_string(), "Database error: connection failed");

        let err = Error::Validation("invalid input".to_string());
        assert_eq!(err.to_string(), "Validation error: invalid input");
    }

    #[test]
    fn test_error_from_sqlx() {
        let sqlx_err = sqlx::Error::RowNotFound;
        let err = Error::from(sqlx_err);
        assert!(matches!(err, Error::Database(_)));
    }
}

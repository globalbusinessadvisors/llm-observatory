// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

//! LLM Observatory Rust SDK
//!
//! This SDK provides trait-based instrumentation for Large Language Model (LLM) applications,
//! enabling comprehensive observability through OpenTelemetry integration.
//!
//! # Features
//!
//! - Automatic tracing of LLM requests and responses
//! - Cost calculation based on token usage
//! - Support for streaming completions
//! - OpenTelemetry-based observability
//! - Provider-agnostic trait design
//! - Built-in support for OpenAI, Anthropic, and more
//!
//! # Quick Start
//!
//! ```rust,no_run
//! use llm_observatory_sdk::{LLMObservatory, InstrumentedLLM, OpenAIClient};
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!     // Initialize the observatory
//!     let observatory = LLMObservatory::builder()
//!         .with_service_name("my-app")
//!         .with_otlp_endpoint("http://localhost:4317")
//!         .build()?;
//!
//!     // Create an instrumented client
//!     let client = OpenAIClient::new("your-api-key")
//!         .with_observatory(observatory);
//!
//!     // Make an instrumented LLM call
//!     let response = client.chat_completion()
//!         .model("gpt-4")
//!         .message("user", "Hello, world!")
//!         .send()
//!         .await?;
//!
//!     println!("Response: {}", response.content);
//!     println!("Cost: ${:.6}", response.cost_usd);
//!
//!     Ok(())
//! }
//! ```
//!
//! # Architecture
//!
//! The SDK is built around several core concepts:
//!
//! - [`LLMObservatory`]: Central observability manager that handles OpenTelemetry setup
//! - [`InstrumentedLLM`]: Trait for LLM clients with automatic instrumentation
//! - [`OpenAIClient`]: OpenAI-specific implementation with full API support
//! - Cost calculation: Automatic cost tracking based on provider pricing
//!
//! # OpenTelemetry Integration
//!
//! All LLM operations are automatically traced using OpenTelemetry semantic conventions
//! for GenAI operations, making them compatible with standard observability tools like
//! Jaeger, Prometheus, and Grafana.

#![warn(missing_docs, rust_2018_idioms)]
#![deny(unsafe_code)]

pub mod cost;
pub mod error;
pub mod instrument;
pub mod observatory;
pub mod traits;

#[cfg(feature = "openai")]
pub mod openai;

// Re-export core types
pub use llm_observatory_core::{
    provider::Pricing,
    span::{ChatMessage, LlmInput, LlmOutput, LlmSpan, SpanStatus},
    types::{Cost, Latency, Metadata, Provider, TokenUsage},
    Error as CoreError, Result as CoreResult,
};

// Re-export SDK types
pub use error::{Error, Result};
pub use instrument::{InstrumentedSpan, SpanBuilder};
pub use observatory::{LLMObservatory, ObservatoryBuilder};
pub use traits::{ChatCompletionRequest, ChatCompletionResponse, InstrumentedLLM, StreamChunk};

#[cfg(feature = "openai")]
pub use openai::{OpenAIClient, OpenAIConfig};

// Re-export async_trait for convenience
pub use async_trait::async_trait;

/// SDK version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Initialize the SDK with default settings.
///
/// This is a convenience function that creates an [`LLMObservatory`] instance
/// with sensible defaults for local development.
///
/// # Example
///
/// ```rust,no_run
/// use llm_observatory_sdk::init;
///
/// #[tokio::main]
/// async fn main() -> Result<(), Box<dyn std::error::Error>> {
///     let observatory = init("my-service").await?;
///     // Use observatory with your LLM clients...
///     Ok(())
/// }
/// ```
pub async fn init(service_name: impl Into<String>) -> Result<LLMObservatory> {
    LLMObservatory::builder()
        .with_service_name(service_name)
        .build()
}

/// Initialize the SDK with a custom OTLP endpoint.
///
/// # Arguments
///
/// * `service_name` - Name of your service for tracing
/// * `otlp_endpoint` - OTLP gRPC endpoint (e.g., "http://localhost:4317")
///
/// # Example
///
/// ```rust,no_run
/// use llm_observatory_sdk::init_with_endpoint;
///
/// #[tokio::main]
/// async fn main() -> Result<(), Box<dyn std::error::Error>> {
///     let observatory = init_with_endpoint(
///         "my-service",
///         "http://collector:4317"
///     ).await?;
///     Ok(())
/// }
/// ```
pub async fn init_with_endpoint(
    service_name: impl Into<String>,
    otlp_endpoint: impl Into<String>,
) -> Result<LLMObservatory> {
    LLMObservatory::builder()
        .with_service_name(service_name)
        .with_otlp_endpoint(otlp_endpoint)
        .build()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert!(!VERSION.is_empty());
    }
}

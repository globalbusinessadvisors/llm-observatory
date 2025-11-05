// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

//! Core type definitions for LLM Observatory.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Unique identifier for a trace.
pub type TraceId = String;

/// Unique identifier for a span.
pub type SpanId = String;

/// LLM provider identifier.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Provider {
    /// OpenAI (GPT models)
    OpenAI,
    /// Anthropic (Claude models)
    Anthropic,
    /// Google (Gemini models)
    Google,
    /// Mistral AI
    Mistral,
    /// Cohere
    Cohere,
    /// Self-hosted (Ollama, vLLM, etc.)
    SelfHosted,
    /// Custom provider
    Custom(String),
}

impl Provider {
    /// Get the provider name as a string.
    pub fn as_str(&self) -> &str {
        match self {
            Provider::OpenAI => "openai",
            Provider::Anthropic => "anthropic",
            Provider::Google => "google",
            Provider::Mistral => "mistral",
            Provider::Cohere => "cohere",
            Provider::SelfHosted => "self-hosted",
            Provider::Custom(name) => name,
        }
    }
}

impl std::fmt::Display for Provider {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Token usage statistics for an LLM call.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TokenUsage {
    /// Number of tokens in the prompt
    pub prompt_tokens: u32,
    /// Number of tokens in the completion
    pub completion_tokens: u32,
    /// Total tokens (prompt + completion)
    pub total_tokens: u32,
}

impl TokenUsage {
    /// Create a new TokenUsage instance.
    pub fn new(prompt_tokens: u32, completion_tokens: u32) -> Self {
        Self {
            prompt_tokens,
            completion_tokens,
            total_tokens: prompt_tokens + completion_tokens,
        }
    }
}

/// Cost information for an LLM call.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Cost {
    /// Cost in USD
    pub amount_usd: f64,
    /// Currency (default: USD)
    #[serde(default = "default_currency")]
    pub currency: String,
    /// Prompt cost breakdown
    pub prompt_cost: Option<f64>,
    /// Completion cost breakdown
    pub completion_cost: Option<f64>,
}

fn default_currency() -> String {
    "USD".to_string()
}

impl Cost {
    /// Create a new Cost instance.
    pub fn new(amount_usd: f64) -> Self {
        Self {
            amount_usd,
            currency: "USD".to_string(),
            prompt_cost: None,
            completion_cost: None,
        }
    }

    /// Create a new Cost instance with breakdown.
    pub fn with_breakdown(prompt_cost: f64, completion_cost: f64) -> Self {
        Self {
            amount_usd: prompt_cost + completion_cost,
            currency: "USD".to_string(),
            prompt_cost: Some(prompt_cost),
            completion_cost: Some(completion_cost),
        }
    }
}

/// Metadata for an LLM request/response.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Metadata {
    /// User identifier
    pub user_id: Option<String>,
    /// Session identifier
    pub session_id: Option<String>,
    /// Request identifier
    pub request_id: Option<Uuid>,
    /// Environment (production, staging, development)
    pub environment: Option<String>,
    /// Custom tags
    #[serde(default)]
    pub tags: Vec<String>,
    /// Custom attributes
    #[serde(default)]
    pub attributes: std::collections::HashMap<String, String>,
}

/// Latency metrics for an LLM call.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Latency {
    /// Total duration in milliseconds
    pub total_ms: u64,
    /// Time to first token in milliseconds
    pub ttft_ms: Option<u64>,
    /// Start timestamp
    pub start_time: DateTime<Utc>,
    /// End timestamp
    pub end_time: DateTime<Utc>,
}

impl Latency {
    /// Create a new Latency instance.
    pub fn new(start_time: DateTime<Utc>, end_time: DateTime<Utc>) -> Self {
        let duration = end_time.signed_duration_since(start_time);
        let total_ms = duration.num_milliseconds() as u64;

        Self {
            total_ms,
            ttft_ms: None,
            start_time,
            end_time,
        }
    }

    /// Set time to first token.
    pub fn with_ttft(mut self, ttft_ms: u64) -> Self {
        self.ttft_ms = Some(ttft_ms);
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_token_usage_calculation() {
        let usage = TokenUsage::new(100, 200);
        assert_eq!(usage.prompt_tokens, 100);
        assert_eq!(usage.completion_tokens, 200);
        assert_eq!(usage.total_tokens, 300);
    }

    #[test]
    fn test_cost_with_breakdown() {
        let cost = Cost::with_breakdown(0.001, 0.002);
        assert_eq!(cost.amount_usd, 0.003);
        assert_eq!(cost.prompt_cost, Some(0.001));
        assert_eq!(cost.completion_cost, Some(0.002));
    }

    #[test]
    fn test_provider_display() {
        assert_eq!(Provider::OpenAI.to_string(), "openai");
        assert_eq!(Provider::Anthropic.to_string(), "anthropic");
        assert_eq!(Provider::Custom("test".to_string()).to_string(), "test");
    }
}

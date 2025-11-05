// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

//! Collector configuration.

use serde::{Deserialize, Serialize};
use std::net::SocketAddr;

/// Main collector configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CollectorConfig {
    /// Receiver configuration
    #[serde(default)]
    pub receiver: ReceiverConfig,

    /// Processor configurations
    #[serde(default)]
    pub processors: ProcessorConfig,

    /// Sampling configuration
    #[serde(default)]
    pub sampling: SamplingConfig,

    /// Metrics configuration
    #[serde(default)]
    pub metrics: MetricsConfig,
}

/// Receiver configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReceiverConfig {
    /// OTLP gRPC endpoint
    #[serde(default = "default_grpc_endpoint")]
    pub grpc_endpoint: SocketAddr,

    /// OTLP HTTP endpoint
    #[serde(default = "default_http_endpoint")]
    pub http_endpoint: SocketAddr,

    /// Enable gRPC receiver
    #[serde(default = "default_true")]
    pub enable_grpc: bool,

    /// Enable HTTP receiver
    #[serde(default = "default_true")]
    pub enable_http: bool,
}

fn default_grpc_endpoint() -> SocketAddr {
    "0.0.0.0:4317".parse().unwrap()
}

fn default_http_endpoint() -> SocketAddr {
    "0.0.0.0:4318".parse().unwrap()
}

fn default_true() -> bool {
    true
}

/// Processor configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessorConfig {
    /// Enable PII redaction
    #[serde(default = "default_true")]
    pub enable_pii_redaction: bool,

    /// Enable cost calculation
    #[serde(default = "default_true")]
    pub enable_cost_calculation: bool,

    /// Batch size for processing
    #[serde(default = "default_batch_size")]
    pub batch_size: usize,

    /// Batch timeout in milliseconds
    #[serde(default = "default_batch_timeout_ms")]
    pub batch_timeout_ms: u64,
}

fn default_batch_size() -> usize {
    1000
}

fn default_batch_timeout_ms() -> u64 {
    10000 // 10 seconds
}

/// Sampling configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SamplingConfig {
    /// Sampling strategy (head, tail, or both)
    #[serde(default)]
    pub strategy: SamplingStrategy,

    /// Head sampling rate (0.0 to 1.0)
    #[serde(default = "default_head_rate")]
    pub head_sampling_rate: f64,

    /// Always sample errors
    #[serde(default = "default_true")]
    pub always_sample_errors: bool,

    /// Always sample slow requests (threshold in ms)
    #[serde(default = "default_slow_threshold_ms")]
    pub slow_request_threshold_ms: u64,

    /// Always sample expensive requests (threshold in USD)
    #[serde(default = "default_expensive_threshold_usd")]
    pub expensive_request_threshold_usd: f64,
}

fn default_head_rate() -> f64 {
    0.01 // 1%
}

fn default_slow_threshold_ms() -> u64 {
    5000 // 5 seconds
}

fn default_expensive_threshold_usd() -> f64 {
    1.0 // $1
}

/// Sampling strategy.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SamplingStrategy {
    /// Head sampling (at SDK level)
    Head,
    /// Tail sampling (at collector level after trace completion)
    Tail,
    /// Both head and tail sampling
    Both,
}

impl Default for SamplingStrategy {
    fn default() -> Self {
        Self::Both
    }
}

/// Metrics configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsConfig {
    /// Enable Prometheus metrics export
    #[serde(default = "default_true")]
    pub enable_prometheus: bool,

    /// Prometheus metrics endpoint
    #[serde(default = "default_metrics_endpoint")]
    pub prometheus_endpoint: SocketAddr,
}

fn default_metrics_endpoint() -> SocketAddr {
    "0.0.0.0:9090".parse().unwrap()
}

impl Default for ReceiverConfig {
    fn default() -> Self {
        Self {
            grpc_endpoint: default_grpc_endpoint(),
            http_endpoint: default_http_endpoint(),
            enable_grpc: true,
            enable_http: true,
        }
    }
}

impl Default for ProcessorConfig {
    fn default() -> Self {
        Self {
            enable_pii_redaction: true,
            enable_cost_calculation: true,
            batch_size: default_batch_size(),
            batch_timeout_ms: default_batch_timeout_ms(),
        }
    }
}

impl Default for SamplingConfig {
    fn default() -> Self {
        Self {
            strategy: SamplingStrategy::Both,
            head_sampling_rate: default_head_rate(),
            always_sample_errors: true,
            slow_request_threshold_ms: default_slow_threshold_ms(),
            expensive_request_threshold_usd: default_expensive_threshold_usd(),
        }
    }
}

impl Default for MetricsConfig {
    fn default() -> Self {
        Self {
            enable_prometheus: true,
            prometheus_endpoint: default_metrics_endpoint(),
        }
    }
}

impl Default for CollectorConfig {
    fn default() -> Self {
        Self {
            receiver: ReceiverConfig::default(),
            processors: ProcessorConfig::default(),
            sampling: SamplingConfig::default(),
            metrics: MetricsConfig::default(),
        }
    }
}

impl CollectorConfig {
    /// Load configuration from file.
    pub fn from_file(path: &str) -> Result<Self, config::ConfigError> {
        config::Config::builder()
            .add_source(config::File::with_name(path))
            .add_source(config::Environment::with_prefix("LLMOBS"))
            .build()?
            .try_deserialize()
    }

    /// Load configuration from environment variables only.
    pub fn from_env() -> Result<Self, config::ConfigError> {
        config::Config::builder()
            .add_source(config::Environment::with_prefix("LLMOBS"))
            .build()?
            .try_deserialize()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = CollectorConfig::default();
        assert!(config.receiver.enable_grpc);
        assert!(config.receiver.enable_http);
        assert!(config.processors.enable_pii_redaction);
        assert_eq!(config.sampling.strategy, SamplingStrategy::Both);
    }

    #[test]
    fn test_sampling_strategy_serde() {
        let json = r#"{"strategy":"head","head_sampling_rate":0.1,"always_sample_errors":true,"slow_request_threshold_ms":1000,"expensive_request_threshold_usd":0.5}"#;
        let config: SamplingConfig = serde_json::from_str(json).unwrap();
        assert_eq!(config.strategy, SamplingStrategy::Head);
        assert_eq!(config.head_sampling_rate, 0.1);
    }
}

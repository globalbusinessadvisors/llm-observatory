// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

//! OTLP (OpenTelemetry Protocol) receiver implementation.
//!
//! Receives traces, metrics, and logs over gRPC and HTTP.

use super::Receiver;
use async_trait::async_trait;
use llm_observatory_core::Result;
use std::net::SocketAddr;

/// OTLP receiver configuration.
#[derive(Debug, Clone)]
pub struct OtlpReceiver {
    /// gRPC endpoint
    grpc_endpoint: SocketAddr,
    /// HTTP endpoint
    http_endpoint: SocketAddr,
    /// Enable gRPC
    enable_grpc: bool,
    /// Enable HTTP
    enable_http: bool,
}

impl OtlpReceiver {
    /// Create a new OTLP receiver.
    pub fn new(grpc_endpoint: SocketAddr, http_endpoint: SocketAddr) -> Self {
        Self {
            grpc_endpoint,
            http_endpoint,
            enable_grpc: true,
            enable_http: true,
        }
    }

    /// Enable or disable gRPC receiver.
    pub fn with_grpc(mut self, enable: bool) -> Self {
        self.enable_grpc = enable;
        self
    }

    /// Enable or disable HTTP receiver.
    pub fn with_http(mut self, enable: bool) -> Self {
        self.enable_http = enable;
        self
    }
}

#[async_trait]
impl Receiver for OtlpReceiver {
    async fn start(&mut self) -> Result<()> {
        tracing::info!("Starting OTLP receiver");

        if self.enable_grpc {
            tracing::info!("OTLP gRPC receiver listening on {}", self.grpc_endpoint);
            // TODO: Start gRPC server
        }

        if self.enable_http {
            tracing::info!("OTLP HTTP receiver listening on {}", self.http_endpoint);
            // TODO: Start HTTP server
        }

        Ok(())
    }

    async fn stop(&mut self) -> Result<()> {
        tracing::info!("Stopping OTLP receiver");
        // TODO: Gracefully shutdown servers
        Ok(())
    }

    fn name(&self) -> &str {
        "otlp"
    }
}

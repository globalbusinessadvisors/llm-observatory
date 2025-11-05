// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

//! Receivers for ingesting telemetry data.

pub mod otlp;

use async_trait::async_trait;
use llm_observatory_core::Result;

/// Trait for telemetry receivers.
#[async_trait]
pub trait Receiver: Send + Sync {
    /// Start the receiver.
    async fn start(&mut self) -> Result<()>;

    /// Stop the receiver.
    async fn stop(&mut self) -> Result<()>;

    /// Get receiver name.
    fn name(&self) -> &str;
}

//! Repository layer for querying stored data.
//!
//! This module provides repository interfaces for querying traces, metrics,
//! and logs from the database.

pub mod trace;
pub mod metric;
pub mod log;
pub mod instrumented;

// Re-exports
pub use trace::TraceRepository;
pub use metric::MetricRepository;
pub use log::LogRepository;
pub use instrumented::{InstrumentedTraceRepository, InstrumentedMetricRepository, InstrumentedLogRepository};

//! Data models for storage entities.
//!
//! This module contains the data models that represent database entities
//! for traces, metrics, and logs.

pub mod trace;
pub mod metric;
pub mod log;

// Re-exports
pub use trace::{Trace, TraceSpan, TraceEvent};
pub use metric::{Metric, MetricDataPoint, MetricType};
pub use log::{LogRecord, LogLevel};

//! PostgreSQL COPY protocol implementation for high-performance batch inserts.
//!
//! This module provides high-performance batch insertion using PostgreSQL's COPY protocol
//! in binary format. This can be 10-100x faster than standard INSERT statements for large
//! batches.
//!
//! # Performance
//!
//! - INSERT with QueryBuilder: ~5,000-10,000 rows/sec
//! - COPY binary protocol: ~50,000-100,000 rows/sec
//!
//! # Usage
//!
//! ```no_run
//! use llm_observatory_storage::writers::copy::CopyWriter;
//! use llm_observatory_storage::models::Trace;
//!
//! # async fn example() -> Result<(), Box<dyn std::error::Error>> {
//! // Get a tokio-postgres client from the connection string
//! let (client, connection) = tokio_postgres::connect(
//!     "host=localhost user=postgres",
//!     tokio_postgres::NoTls
//! ).await?;
//!
//! // Spawn the connection in the background
//! tokio::spawn(async move {
//!     if let Err(e) = connection.await {
//!         eprintln!("connection error: {}", e);
//!     }
//! });
//!
//! // Create traces
//! let traces = vec![/* ... */];
//!
//! // Write using COPY protocol
//! CopyWriter::write_traces(&client, traces).await?;
//! # Ok(())
//! # }
//! ```

use crate::error::{StorageError, StorageResult};
use crate::models::{LogRecord, Metric, MetricDataPoint, Trace, TraceEvent, TraceSpan};
use tokio_postgres::binary_copy::BinaryCopyInWriter;
use tokio_postgres::types::{ToSql, Type};
use tokio_postgres::Client;

/// High-performance writer using PostgreSQL COPY protocol.
///
/// This provides static methods for writing different data types using COPY.
pub struct CopyWriter;

impl CopyWriter {
    /// Write traces using COPY protocol.
    ///
    /// This is significantly faster than INSERT for large batches.
    /// Expected throughput: 50,000-100,000 rows/sec vs 5,000-10,000 with INSERT.
    ///
    /// # Arguments
    ///
    /// * `client` - tokio-postgres client
    /// * `traces` - Vector of traces to insert
    ///
    /// # Returns
    ///
    /// Number of rows written
    ///
    /// # Errors
    ///
    /// Returns `StorageError` if the COPY operation fails
    pub async fn write_traces(client: &Client, traces: Vec<Trace>) -> StorageResult<u64> {
        if traces.is_empty() {
            return Ok(0);
        }

        let start = std::time::Instant::now();
        let row_count = traces.len() as u64;

        tracing::debug!("Writing {} traces using COPY protocol", row_count);

        // Create COPY FROM STDIN statement
        let copy_stmt = "COPY traces (
            id, trace_id, service_name, start_time, end_time, duration_us,
            status, status_message, root_span_name, attributes, resource_attributes,
            span_count, created_at, updated_at
        ) FROM STDIN BINARY";

        // Get a sink for the COPY operation
        let sink = client.copy_in(copy_stmt).await.map_err(|e| {
            StorageError::Database(format!("Failed to start COPY operation: {}", e))
        })?;

        // Create binary writer with column types
        let writer = BinaryCopyInWriter::new(
            sink,
            &[
                Type::UUID,        // id
                Type::TEXT,        // trace_id
                Type::TEXT,        // service_name
                Type::TIMESTAMPTZ, // start_time
                Type::TIMESTAMPTZ, // end_time (nullable)
                Type::INT8,        // duration_us (nullable)
                Type::TEXT,        // status
                Type::TEXT,        // status_message (nullable)
                Type::TEXT,        // root_span_name (nullable)
                Type::JSONB,       // attributes
                Type::JSONB,       // resource_attributes
                Type::INT4,        // span_count
                Type::TIMESTAMPTZ, // created_at
                Type::TIMESTAMPTZ, // updated_at
            ],
        );

        // Pin the writer for async operations
        tokio::pin!(writer);

        // Write each trace as a row
        for trace in &traces {
            let row: Vec<&(dyn ToSql + Sync)> = vec![
                &trace.id,
                &trace.trace_id,
                &trace.service_name,
                &trace.start_time,
                &trace.end_time,
                &trace.duration_us,
                &trace.status,
                &trace.status_message,
                &trace.root_span_name,
                &trace.attributes,
                &trace.resource_attributes,
                &trace.span_count,
                &trace.created_at,
                &trace.updated_at,
            ];

            writer
                .as_mut()
                .write(&row)
                .await
                .map_err(|e| StorageError::Database(format!("Failed to write row: {}", e)))?;
        }

        // Finish the COPY operation
        let rows_written = writer
            .finish()
            .await
            .map_err(|e| StorageError::Database(format!("Failed to finish COPY: {}", e)))?;

        let elapsed = start.elapsed();
        tracing::info!(
            "Wrote {} traces using COPY in {:?} ({:.0} traces/sec)",
            rows_written,
            elapsed,
            rows_written as f64 / elapsed.as_secs_f64()
        );

        Ok(rows_written)
    }

    /// Write trace spans using COPY protocol.
    pub async fn write_spans(client: &Client, spans: Vec<TraceSpan>) -> StorageResult<u64> {
        if spans.is_empty() {
            return Ok(0);
        }

        let start = std::time::Instant::now();
        let row_count = spans.len() as u64;

        tracing::debug!("Writing {} spans using COPY protocol", row_count);

        let copy_stmt = "COPY trace_spans (
            id, trace_id, span_id, parent_span_id, name, kind,
            service_name, start_time, end_time, duration_us, status,
            status_message, attributes, events, links, created_at
        ) FROM STDIN BINARY";

        let sink = client.copy_in(copy_stmt).await.map_err(|e| {
            StorageError::Database(format!("Failed to start COPY operation: {}", e))
        })?;

        let writer = BinaryCopyInWriter::new(
            sink,
            &[
                Type::UUID,        // id
                Type::UUID,        // trace_id
                Type::TEXT,        // span_id
                Type::TEXT,        // parent_span_id (nullable)
                Type::TEXT,        // name
                Type::TEXT,        // kind
                Type::TEXT,        // service_name
                Type::TIMESTAMPTZ, // start_time
                Type::TIMESTAMPTZ, // end_time (nullable)
                Type::INT8,        // duration_us (nullable)
                Type::TEXT,        // status
                Type::TEXT,        // status_message (nullable)
                Type::JSONB,       // attributes
                Type::JSONB,       // events (nullable)
                Type::JSONB,       // links (nullable)
                Type::TIMESTAMPTZ, // created_at
            ],
        );

        tokio::pin!(writer);

        for span in &spans {
            let row: Vec<&(dyn ToSql + Sync)> = vec![
                &span.id,
                &span.trace_id,
                &span.span_id,
                &span.parent_span_id,
                &span.name,
                &span.kind,
                &span.service_name,
                &span.start_time,
                &span.end_time,
                &span.duration_us,
                &span.status,
                &span.status_message,
                &span.attributes,
                &span.events,
                &span.links,
                &span.created_at,
            ];

            writer
                .as_mut()
                .write(&row)
                .await
                .map_err(|e| StorageError::Database(format!("Failed to write row: {}", e)))?;
        }

        let rows_written = writer
            .finish()
            .await
            .map_err(|e| StorageError::Database(format!("Failed to finish COPY: {}", e)))?;

        let elapsed = start.elapsed();
        tracing::info!(
            "Wrote {} spans using COPY in {:?} ({:.0} spans/sec)",
            rows_written,
            elapsed,
            rows_written as f64 / elapsed.as_secs_f64()
        );

        Ok(rows_written)
    }

    /// Write trace events using COPY protocol.
    pub async fn write_events(client: &Client, events: Vec<TraceEvent>) -> StorageResult<u64> {
        if events.is_empty() {
            return Ok(0);
        }

        let start = std::time::Instant::now();
        let row_count = events.len() as u64;

        tracing::debug!("Writing {} events using COPY protocol", row_count);

        let copy_stmt = "COPY trace_events (
            id, span_id, name, timestamp, attributes, created_at
        ) FROM STDIN BINARY";

        let sink = client.copy_in(copy_stmt).await.map_err(|e| {
            StorageError::Database(format!("Failed to start COPY operation: {}", e))
        })?;

        let writer = BinaryCopyInWriter::new(
            sink,
            &[
                Type::UUID,        // id
                Type::UUID,        // span_id
                Type::TEXT,        // name
                Type::TIMESTAMPTZ, // timestamp
                Type::JSONB,       // attributes
                Type::TIMESTAMPTZ, // created_at
            ],
        );

        tokio::pin!(writer);

        for event in &events {
            let row: Vec<&(dyn ToSql + Sync)> = vec![
                &event.id,
                &event.span_id,
                &event.name,
                &event.timestamp,
                &event.attributes,
                &event.created_at,
            ];

            writer
                .as_mut()
                .write(&row)
                .await
                .map_err(|e| StorageError::Database(format!("Failed to write row: {}", e)))?;
        }

        let rows_written = writer
            .finish()
            .await
            .map_err(|e| StorageError::Database(format!("Failed to finish COPY: {}", e)))?;

        let elapsed = start.elapsed();
        tracing::info!(
            "Wrote {} events using COPY in {:?} ({:.0} events/sec)",
            rows_written,
            elapsed,
            rows_written as f64 / elapsed.as_secs_f64()
        );

        Ok(rows_written)
    }

    /// Write metrics using COPY protocol.
    pub async fn write_metrics(client: &Client, metrics: Vec<Metric>) -> StorageResult<u64> {
        if metrics.is_empty() {
            return Ok(0);
        }

        let start = std::time::Instant::now();
        let row_count = metrics.len() as u64;

        tracing::debug!("Writing {} metrics using COPY protocol", row_count);

        let copy_stmt = "COPY metrics (
            id, name, description, unit, metric_type, service_name,
            attributes, resource_attributes, created_at, updated_at
        ) FROM STDIN BINARY";

        let sink = client.copy_in(copy_stmt).await.map_err(|e| {
            StorageError::Database(format!("Failed to start COPY operation: {}", e))
        })?;

        let writer = BinaryCopyInWriter::new(
            sink,
            &[
                Type::UUID,        // id
                Type::TEXT,        // name
                Type::TEXT,        // description (nullable)
                Type::TEXT,        // unit (nullable)
                Type::TEXT,        // metric_type
                Type::TEXT,        // service_name
                Type::JSONB,       // attributes
                Type::JSONB,       // resource_attributes
                Type::TIMESTAMPTZ, // created_at
                Type::TIMESTAMPTZ, // updated_at
            ],
        );

        tokio::pin!(writer);

        for metric in &metrics {
            let row: Vec<&(dyn ToSql + Sync)> = vec![
                &metric.id,
                &metric.name,
                &metric.description,
                &metric.unit,
                &metric.metric_type,
                &metric.service_name,
                &metric.attributes,
                &metric.resource_attributes,
                &metric.created_at,
                &metric.updated_at,
            ];

            writer
                .as_mut()
                .write(&row)
                .await
                .map_err(|e| StorageError::Database(format!("Failed to write row: {}", e)))?;
        }

        let rows_written = writer
            .finish()
            .await
            .map_err(|e| StorageError::Database(format!("Failed to finish COPY: {}", e)))?;

        let elapsed = start.elapsed();
        tracing::info!(
            "Wrote {} metrics using COPY in {:?} ({:.0} metrics/sec)",
            rows_written,
            elapsed,
            rows_written as f64 / elapsed.as_secs_f64()
        );

        Ok(rows_written)
    }

    /// Write metric data points using COPY protocol.
    pub async fn write_data_points(
        client: &Client,
        data_points: Vec<MetricDataPoint>,
    ) -> StorageResult<u64> {
        if data_points.is_empty() {
            return Ok(0);
        }

        let start = std::time::Instant::now();
        let row_count = data_points.len() as u64;

        tracing::debug!("Writing {} data points using COPY protocol", row_count);

        let copy_stmt = "COPY metric_data_points (
            id, metric_id, timestamp, value, count, sum, min, max,
            buckets, quantiles, exemplars, attributes, created_at
        ) FROM STDIN BINARY";

        let sink = client.copy_in(copy_stmt).await.map_err(|e| {
            StorageError::Database(format!("Failed to start COPY operation: {}", e))
        })?;

        let writer = BinaryCopyInWriter::new(
            sink,
            &[
                Type::UUID,        // id
                Type::UUID,        // metric_id
                Type::TIMESTAMPTZ, // timestamp
                Type::FLOAT8,      // value (nullable)
                Type::INT8,        // count (nullable)
                Type::FLOAT8,      // sum (nullable)
                Type::FLOAT8,      // min (nullable)
                Type::FLOAT8,      // max (nullable)
                Type::JSONB,       // buckets (nullable)
                Type::JSONB,       // quantiles (nullable)
                Type::JSONB,       // exemplars (nullable)
                Type::JSONB,       // attributes
                Type::TIMESTAMPTZ, // created_at
            ],
        );

        tokio::pin!(writer);

        for dp in &data_points {
            let row: Vec<&(dyn ToSql + Sync)> = vec![
                &dp.id,
                &dp.metric_id,
                &dp.timestamp,
                &dp.value,
                &dp.count,
                &dp.sum,
                &dp.min,
                &dp.max,
                &dp.buckets,
                &dp.quantiles,
                &dp.exemplars,
                &dp.attributes,
                &dp.created_at,
            ];

            writer
                .as_mut()
                .write(&row)
                .await
                .map_err(|e| StorageError::Database(format!("Failed to write row: {}", e)))?;
        }

        let rows_written = writer
            .finish()
            .await
            .map_err(|e| StorageError::Database(format!("Failed to finish COPY: {}", e)))?;

        let elapsed = start.elapsed();
        tracing::info!(
            "Wrote {} data points using COPY in {:?} ({:.0} points/sec)",
            rows_written,
            elapsed,
            rows_written as f64 / elapsed.as_secs_f64()
        );

        Ok(rows_written)
    }

    /// Write log records using COPY protocol.
    pub async fn write_logs(client: &Client, logs: Vec<LogRecord>) -> StorageResult<u64> {
        if logs.is_empty() {
            return Ok(0);
        }

        let start = std::time::Instant::now();
        let row_count = logs.len() as u64;

        tracing::debug!("Writing {} logs using COPY protocol", row_count);

        let copy_stmt = "COPY logs (
            id, timestamp, observed_timestamp, severity_number, severity_text,
            body, service_name, trace_id, span_id, trace_flags, attributes,
            resource_attributes, scope_name, scope_version, scope_attributes, created_at
        ) FROM STDIN BINARY";

        let sink = client.copy_in(copy_stmt).await.map_err(|e| {
            StorageError::Database(format!("Failed to start COPY operation: {}", e))
        })?;

        let writer = BinaryCopyInWriter::new(
            sink,
            &[
                Type::UUID,        // id
                Type::TIMESTAMPTZ, // timestamp
                Type::TIMESTAMPTZ, // observed_timestamp
                Type::INT4,        // severity_number
                Type::TEXT,        // severity_text
                Type::TEXT,        // body
                Type::TEXT,        // service_name
                Type::TEXT,        // trace_id (nullable)
                Type::TEXT,        // span_id (nullable)
                Type::INT4,        // trace_flags (nullable)
                Type::JSONB,       // attributes
                Type::JSONB,       // resource_attributes
                Type::TEXT,        // scope_name (nullable)
                Type::TEXT,        // scope_version (nullable)
                Type::JSONB,       // scope_attributes (nullable)
                Type::TIMESTAMPTZ, // created_at
            ],
        );

        tokio::pin!(writer);

        for log in &logs {
            let row: Vec<&(dyn ToSql + Sync)> = vec![
                &log.id,
                &log.timestamp,
                &log.observed_timestamp,
                &log.severity_number,
                &log.severity_text,
                &log.body,
                &log.service_name,
                &log.trace_id,
                &log.span_id,
                &log.trace_flags,
                &log.attributes,
                &log.resource_attributes,
                &log.scope_name,
                &log.scope_version,
                &log.scope_attributes,
                &log.created_at,
            ];

            writer
                .as_mut()
                .write(&row)
                .await
                .map_err(|e| StorageError::Database(format!("Failed to write row: {}", e)))?;
        }

        let rows_written = writer
            .finish()
            .await
            .map_err(|e| StorageError::Database(format!("Failed to finish COPY: {}", e)))?;

        let elapsed = start.elapsed();
        tracing::info!(
            "Wrote {} logs using COPY in {:?} ({:.0} logs/sec)",
            rows_written,
            elapsed,
            rows_written as f64 / elapsed.as_secs_f64()
        );

        Ok(rows_written)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These tests require a running PostgreSQL instance
    // Run with: cargo test --features postgres -- --ignored

    #[tokio::test]
    #[ignore]
    async fn test_copy_traces() {
        // This would require a test database connection
        // Implementation left for integration tests
    }
}

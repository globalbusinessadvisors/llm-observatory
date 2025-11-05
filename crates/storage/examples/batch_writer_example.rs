//! Example demonstrating the use of batch writers for high-performance data ingestion.
//!
//! This example shows how to:
//! - Configure and create batch writers
//! - Write trace data efficiently
//! - Monitor buffer and write statistics
//! - Handle auto-flushing

use chrono::Utc;
use llm_observatory_storage::{
    config::StorageConfig,
    models::{LogRecord, Metric, MetricDataPoint, Trace, TraceSpan},
    pool::StoragePool,
    writers::{LogWriter, MetricWriter, TraceWriter},
};
use uuid::Uuid;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    // Create storage configuration
    let config = StorageConfig::from_env()?;

    // Create storage pool
    let pool = StoragePool::new(config).await?;

    // Run the examples
    trace_writer_example(&pool).await?;
    metric_writer_example(&pool).await?;
    log_writer_example(&pool).await?;

    // Close the pool
    pool.close().await;

    Ok(())
}

/// Example of using TraceWriter for batch trace ingestion
async fn trace_writer_example(pool: &StoragePool) -> Result<(), Box<dyn std::error::Error>> {
    println!("\n=== TraceWriter Example ===\n");

    // Create a trace writer with custom configuration
    let config = llm_observatory_storage::writers::trace::WriterConfig {
        batch_size: 100,
        flush_interval_secs: 5,
        max_concurrency: 4,
    };

    let writer = TraceWriter::with_config(pool.clone(), config);

    // Create sample traces
    let mut traces = Vec::new();
    for i in 0..250 {
        let trace = Trace::new(
            format!("trace-{:08}", i),
            "example-service".to_string(),
            Utc::now(),
        );
        traces.push(trace);
    }

    // Write traces in batches
    println!("Writing {} traces...", traces.len());
    let start = std::time::Instant::now();

    for trace in traces {
        writer.write_trace(trace).await?;
    }

    // Flush any remaining buffered data
    writer.flush().await?;

    let elapsed = start.elapsed();
    println!("Wrote 250 traces in {:?}", elapsed);

    // Get statistics
    let buffer_stats = writer.buffer_stats().await;
    let write_stats = writer.write_stats().await;

    println!("\nBuffer Stats:");
    println!("  Traces buffered: {}", buffer_stats.traces_buffered);
    println!("  Spans buffered: {}", buffer_stats.spans_buffered);

    println!("\nWrite Stats:");
    println!("  Traces written: {}", write_stats.traces_written);
    println!("  Spans written: {}", write_stats.spans_written);
    println!("  Write failures: {}", write_stats.write_failures);
    println!("  Retries: {}", write_stats.retries);

    // Example with spans
    println!("\nWriting spans...");
    let trace_id = Uuid::new_v4();

    for i in 0..50 {
        let span = TraceSpan::new(
            trace_id,
            format!("span-{:08}", i),
            format!("operation-{}", i % 5),
            "example-service".to_string(),
            Utc::now(),
        );
        writer.write_span(span).await?;
    }

    writer.flush().await?;
    println!("Wrote 50 spans");

    Ok(())
}

/// Example of using MetricWriter for batch metric ingestion
async fn metric_writer_example(pool: &StoragePool) -> Result<(), Box<dyn std::error::Error>> {
    println!("\n=== MetricWriter Example ===\n");

    // Create a metric writer (higher batch size for metrics)
    let config = llm_observatory_storage::writers::metric::WriterConfig {
        batch_size: 500,
        flush_interval_secs: 5,
        max_concurrency: 4,
    };

    let writer = MetricWriter::with_config(pool.clone(), config);

    // Create sample metrics
    println!("Writing metric definitions...");
    let mut metric_ids = Vec::new();

    for i in 0..10 {
        let metric = Metric {
            id: Uuid::new_v4(),
            name: format!("llm.requests.count.{}", i),
            description: Some(format!("Request count for model {}", i)),
            unit: Some("requests".to_string()),
            metric_type: "counter".to_string(),
            service_name: "example-service".to_string(),
            attributes: serde_json::json!({
                "model": format!("gpt-{}", i),
            }),
            resource_attributes: serde_json::json!({}),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        metric_ids.push(metric.id);
        writer.write_metric(metric).await?;
    }

    writer.flush().await?;
    println!("Wrote 10 metric definitions");

    // Write data points
    println!("\nWriting metric data points...");
    let start = std::time::Instant::now();

    for metric_id in &metric_ids {
        for _ in 0..100 {
            let data_point = MetricDataPoint {
                id: Uuid::new_v4(),
                metric_id: *metric_id,
                timestamp: Utc::now(),
                value: Some(rand::random::<f64>() * 100.0),
                count: None,
                sum: None,
                min: None,
                max: None,
                buckets: None,
                quantiles: None,
                exemplars: None,
                attributes: serde_json::json!({}),
                created_at: Utc::now(),
            };

            writer.write_data_point(data_point).await?;
        }
    }

    writer.flush().await?;

    let elapsed = start.elapsed();
    println!("Wrote 1000 data points in {:?}", elapsed);

    // Get statistics
    let stats = writer.buffer_stats().await;
    println!("\nBuffer Stats:");
    println!("  Metrics buffered: {}", stats.metrics_buffered);
    println!("  Data points buffered: {}", stats.data_points_buffered);

    Ok(())
}

/// Example of using LogWriter with auto-flush
async fn log_writer_example(pool: &StoragePool) -> Result<(), Box<dyn std::error::Error>> {
    println!("\n=== LogWriter Example ===\n");

    // Create a log writer (highest batch size)
    let config = llm_observatory_storage::writers::log::WriterConfig {
        batch_size: 1000,
        flush_interval_secs: 2,
        max_concurrency: 4,
    };

    let writer = LogWriter::with_config(pool.clone(), config);

    // Start auto-flush task
    let _flush_handle = writer.start_auto_flush();
    println!("Started auto-flush task (flushes every 2 seconds)");

    // Write log records
    println!("\nWriting log records...");
    let start = std::time::Instant::now();

    for i in 0..5000 {
        let severity_number = match i % 5 {
            0 => 9,  // INFO
            1 => 13, // WARN
            2 => 17, // ERROR
            _ => 5,  // DEBUG
        };

        let log = LogRecord {
            id: Uuid::new_v4(),
            timestamp: Utc::now(),
            observed_timestamp: Utc::now(),
            severity_number,
            severity_text: match severity_number {
                9 => "INFO",
                13 => "WARN",
                17 => "ERROR",
                _ => "DEBUG",
            }
            .to_string(),
            body: format!("Log message {}", i),
            service_name: "example-service".to_string(),
            trace_id: if i % 10 == 0 {
                Some(format!("trace-{:08}", i / 10))
            } else {
                None
            },
            span_id: None,
            trace_flags: None,
            attributes: serde_json::json!({
                "log.index": i,
            }),
            resource_attributes: serde_json::json!({}),
            scope_name: Some("example".to_string()),
            scope_version: Some("1.0.0".to_string()),
            scope_attributes: None,
            created_at: Utc::now(),
        };

        writer.write_log(log).await?;
    }

    // Final flush
    writer.flush().await?;

    let elapsed = start.elapsed();
    println!(
        "Wrote 5000 logs in {:?} ({:.0} logs/sec)",
        elapsed,
        5000.0 / elapsed.as_secs_f64()
    );

    // Get statistics
    let stats = writer.buffer_stats().await;
    println!("\nBuffer Stats:");
    println!("  Logs buffered: {}", stats.logs_buffered);

    Ok(())
}

/// Performance benchmark example
#[allow(dead_code)]
async fn benchmark_example(pool: &StoragePool) -> Result<(), Box<dyn std::error::Error>> {
    println!("\n=== Performance Benchmark ===\n");

    let writer = TraceWriter::new(pool.clone());

    // Benchmark: 10,000 traces
    let count = 10_000;
    println!("Benchmarking {} trace writes...", count);

    let start = std::time::Instant::now();

    for i in 0..count {
        let trace = Trace::new(
            format!("bench-trace-{:08}", i),
            "benchmark-service".to_string(),
            Utc::now(),
        );
        writer.write_trace(trace).await?;
    }

    writer.flush().await?;

    let elapsed = start.elapsed();
    let throughput = count as f64 / elapsed.as_secs_f64();

    println!("\nBenchmark Results:");
    println!("  Total traces: {}", count);
    println!("  Time elapsed: {:?}", elapsed);
    println!("  Throughput: {:.0} traces/sec", throughput);
    println!(
        "  Average latency: {:.2} ms",
        elapsed.as_millis() as f64 / count as f64
    );

    let stats = writer.write_stats().await;
    println!("\nWrite Stats:");
    println!("  Successful writes: {}", stats.traces_written);
    println!("  Failures: {}", stats.write_failures);
    println!("  Retries: {}", stats.retries);

    Ok(())
}

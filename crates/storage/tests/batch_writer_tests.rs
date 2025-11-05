//! Integration tests for batch writers
//!
//! These tests require a running PostgreSQL instance.
//! Set DATABASE_URL environment variable to run these tests.

#![cfg(feature = "postgres")]

use chrono::Utc;
use llm_observatory_storage::{
    config::StorageConfig,
    models::{LogRecord, Trace, TraceSpan},
    pool::StoragePool,
    writers::{LogWriter, TraceWriter},
};
use uuid::Uuid;

/// Helper to create a test storage pool
async fn create_test_pool() -> Result<StoragePool, Box<dyn std::error::Error>> {
    // Try to load from environment, or use default test database
    let config = StorageConfig::from_env().unwrap_or_else(|_| {
        let mut config = StorageConfig::default();
        config.postgres.host = "localhost".to_string();
        config.postgres.port = 5432;
        config.postgres.database = "llm_observatory_test".to_string();
        config.postgres.username = "postgres".to_string();
        config.postgres.password = "postgres".to_string();
        config
    });

    Ok(StoragePool::new(config).await?)
}

#[tokio::test]
#[ignore] // Requires database
async fn test_trace_writer_basic() -> Result<(), Box<dyn std::error::Error>> {
    let pool = create_test_pool().await?;
    let writer = TraceWriter::new(pool.clone());

    // Create a test trace
    let trace = Trace::new(
        format!("test-trace-{}", Uuid::new_v4()),
        "test-service".to_string(),
        Utc::now(),
    );

    // Write and flush
    writer.write_trace(trace).await?;
    writer.flush().await?;

    // Verify stats
    let stats = writer.write_stats().await;
    assert_eq!(stats.traces_written, 1);
    assert_eq!(stats.write_failures, 0);

    pool.close().await;
    Ok(())
}

#[tokio::test]
#[ignore] // Requires database
async fn test_trace_writer_batch() -> Result<(), Box<dyn std::error::Error>> {
    let pool = create_test_pool().await?;

    let config = llm_observatory_storage::writers::trace::WriterConfig {
        batch_size: 50,
        flush_interval_secs: 5,
        max_concurrency: 4,
    };

    let writer = TraceWriter::with_config(pool.clone(), config);

    // Write 100 traces (should auto-flush at 50)
    for i in 0..100 {
        let trace = Trace::new(
            format!("batch-trace-{}", i),
            "test-service".to_string(),
            Utc::now(),
        );
        writer.write_trace(trace).await?;
    }

    // Flush remaining
    writer.flush().await?;

    // Verify all were written
    let stats = writer.write_stats().await;
    assert_eq!(stats.traces_written, 100);

    pool.close().await;
    Ok(())
}

#[tokio::test]
#[ignore] // Requires database
async fn test_span_writer() -> Result<(), Box<dyn std::error::Error>> {
    let pool = create_test_pool().await?;
    let writer = TraceWriter::new(pool.clone());

    let trace_id = Uuid::new_v4();

    // Write multiple spans for the same trace
    for i in 0..10 {
        let mut span = TraceSpan::new(
            trace_id,
            format!("span-{}", i),
            format!("operation-{}", i),
            "test-service".to_string(),
            Utc::now(),
        );

        // Mark some as completed
        if i % 2 == 0 {
            span.end_time = Some(Utc::now());
            span.status = "ok".to_string();
            span.update_duration();
        }

        writer.write_span(span).await?;
    }

    writer.flush().await?;

    let stats = writer.write_stats().await;
    assert_eq!(stats.spans_written, 10);

    pool.close().await;
    Ok(())
}

#[tokio::test]
#[ignore] // Requires database
async fn test_log_writer_auto_flush() -> Result<(), Box<dyn std::error::Error>> {
    let pool = create_test_pool().await?;

    let config = llm_observatory_storage::writers::log::WriterConfig {
        batch_size: 100,
        flush_interval_secs: 1, // Fast flush for testing
        max_concurrency: 4,
    };

    let writer = LogWriter::with_config(pool.clone(), config);

    // Start auto-flush
    let _flush_handle = writer.start_auto_flush();

    // Write logs
    for i in 0..50 {
        let log = LogRecord {
            id: Uuid::new_v4(),
            timestamp: Utc::now(),
            observed_timestamp: Utc::now(),
            severity_number: 9,
            severity_text: "INFO".to_string(),
            body: format!("Test log {}", i),
            service_name: "test-service".to_string(),
            trace_id: None,
            span_id: None,
            trace_flags: None,
            attributes: serde_json::json!({}),
            resource_attributes: serde_json::json!({}),
            scope_name: None,
            scope_version: None,
            scope_attributes: None,
            created_at: Utc::now(),
        };

        writer.write_log(log).await?;
    }

    // Wait for auto-flush
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Verify buffer is empty (auto-flushed)
    let buffer_stats = writer.buffer_stats().await;
    assert_eq!(buffer_stats.logs_buffered, 0);

    pool.close().await;
    Ok(())
}

#[tokio::test]
#[ignore] // Requires database
async fn test_concurrent_writes() -> Result<(), Box<dyn std::error::Error>> {
    let pool = create_test_pool().await?;
    let writer = TraceWriter::new(pool.clone());

    // Spawn multiple concurrent writers
    let mut handles = vec![];

    for task_id in 0..10 {
        let writer_clone = writer.clone();

        let handle = tokio::spawn(async move {
            for i in 0..10 {
                let trace = Trace::new(
                    format!("concurrent-trace-{}-{}", task_id, i),
                    format!("task-{}", task_id),
                    Utc::now(),
                );
                writer_clone.write_trace(trace).await.unwrap();
            }
        });

        handles.push(handle);
    }

    // Wait for all tasks
    for handle in handles {
        handle.await?;
    }

    // Flush all
    writer.flush().await?;

    // Verify all 100 traces were written
    let stats = writer.write_stats().await;
    assert_eq!(stats.traces_written, 100);

    pool.close().await;
    Ok(())
}

#[tokio::test]
#[ignore] // Requires database
async fn test_upsert_behavior() -> Result<(), Box<dyn std::error::Error>> {
    let pool = create_test_pool().await?;
    let writer = TraceWriter::new(pool.clone());

    let trace_id = "upsert-test-trace".to_string();

    // Write initial trace
    let mut trace1 = Trace::new(trace_id.clone(), "test-service".to_string(), Utc::now());
    trace1.status = "unset".to_string();
    writer.write_trace(trace1).await?;
    writer.flush().await?;

    // Write updated trace with same ID
    let mut trace2 = Trace::new(trace_id.clone(), "test-service".to_string(), Utc::now());
    trace2.status = "ok".to_string();
    trace2.end_time = Some(Utc::now());
    writer.write_trace(trace2).await?;
    writer.flush().await?;

    // Should have written 2 times but only 1 record exists (upsert)
    let stats = writer.write_stats().await;
    assert_eq!(stats.traces_written, 2);

    pool.close().await;
    Ok(())
}

#[tokio::test]
#[ignore] // Requires database
async fn test_performance_benchmark() -> Result<(), Box<dyn std::error::Error>> {
    let pool = create_test_pool().await?;

    let config = llm_observatory_storage::writers::trace::WriterConfig {
        batch_size: 500,
        flush_interval_secs: 10,
        max_concurrency: 8,
    };

    let writer = TraceWriter::with_config(pool.clone(), config);

    let count = 10_000;
    let start = std::time::Instant::now();

    // Write 10,000 traces
    for i in 0..count {
        let trace = Trace::new(
            format!("perf-trace-{}", i),
            "perf-test".to_string(),
            Utc::now(),
        );
        writer.write_trace(trace).await?;
    }

    writer.flush().await?;

    let elapsed = start.elapsed();
    let throughput = count as f64 / elapsed.as_secs_f64();

    println!("Performance Benchmark:");
    println!("  Traces: {}", count);
    println!("  Time: {:?}", elapsed);
    println!("  Throughput: {:.0} traces/sec", throughput);

    // Assert we meet minimum performance requirement
    assert!(
        throughput > 5000.0,
        "Throughput {} is below 5000 traces/sec",
        throughput
    );

    pool.close().await;
    Ok(())
}

#[tokio::test]
#[ignore] // Requires database
async fn test_buffer_stats() -> Result<(), Box<dyn std::error::Error>> {
    let pool = create_test_pool().await?;

    let config = llm_observatory_storage::writers::trace::WriterConfig {
        batch_size: 1000, // Large batch to prevent auto-flush
        flush_interval_secs: 60,
        max_concurrency: 4,
    };

    let writer = TraceWriter::with_config(pool.clone(), config);

    // Write some traces without flushing
    for i in 0..50 {
        let trace = Trace::new(
            format!("buffer-trace-{}", i),
            "test-service".to_string(),
            Utc::now(),
        );
        writer.write_trace(trace).await?;
    }

    // Check buffer stats
    let stats = writer.buffer_stats().await;
    assert_eq!(stats.traces_buffered, 50);

    // Flush and check again
    writer.flush().await?;

    let stats = writer.buffer_stats().await;
    assert_eq!(stats.traces_buffered, 0);

    pool.close().await;
    Ok(())
}

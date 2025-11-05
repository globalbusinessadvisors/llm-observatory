# Batch Writer Quick Start Guide

Get started with high-performance batch writing in 5 minutes.

## Installation

Add to your `Cargo.toml`:

```toml
[dependencies]
llm-observatory-storage = { path = "crates/storage" }
tokio = { version = "1.40", features = ["full"] }
chrono = "0.4"
uuid = { version = "1.10", features = ["v4"] }
```

## Basic Setup

```rust
use llm_observatory_storage::{
    config::StorageConfig,
    pool::StoragePool,
    writers::TraceWriter,
    models::Trace,
};
use chrono::Utc;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Configure storage (from environment or defaults)
    let config = StorageConfig::from_env()?;

    // 2. Create connection pool
    let pool = StoragePool::new(config).await?;

    // 3. Create writer
    let writer = TraceWriter::new(pool.clone());

    // 4. Write data
    let trace = Trace::new(
        "trace-123".to_string(),
        "my-service".to_string(),
        Utc::now(),
    );

    writer.write_trace(trace).await?;

    // 5. Flush before shutdown
    writer.flush().await?;

    pool.close().await;
    Ok(())
}
```

## Environment Variables

Set these before running:

```bash
# Required
export DATABASE_URL="postgresql://user:password@localhost:5432/llm_observatory"

# Optional (with defaults)
export POSTGRES_HOST="localhost"
export POSTGRES_PORT="5432"
export POSTGRES_DATABASE="llm_observatory"
export POSTGRES_USERNAME="postgres"
export POSTGRES_PASSWORD=""
export POSTGRES_MAX_CONNECTIONS="20"
export POSTGRES_MIN_CONNECTIONS="5"
```

## Write Traces

```rust
use llm_observatory_storage::models::Trace;

// Create trace
let trace = Trace::new(
    "trace-456".to_string(),
    "my-service".to_string(),
    Utc::now(),
);

// Write (buffers automatically)
writer.write_trace(trace).await?;

// Auto-flushes when batch size reached (default: 100)
// Or manually flush:
writer.flush().await?;
```

## Write Spans

```rust
use llm_observatory_storage::models::TraceSpan;
use uuid::Uuid;

let trace_id = Uuid::new_v4();

let mut span = TraceSpan::new(
    trace_id,
    "span-789".to_string(),
    "database-query".to_string(),
    "my-service".to_string(),
    Utc::now(),
);

// Mark as completed
span.end_time = Some(Utc::now());
span.status = "ok".to_string();
span.update_duration();

writer.write_span(span).await?;
```

## Write Metrics

```rust
use llm_observatory_storage::{
    writers::MetricWriter,
    models::{Metric, MetricDataPoint},
};

let metric_writer = MetricWriter::new(pool.clone());

// Define metric
let metric = Metric {
    id: Uuid::new_v4(),
    name: "llm.requests.count".to_string(),
    description: Some("Total LLM requests".to_string()),
    unit: Some("requests".to_string()),
    metric_type: "counter".to_string(),
    service_name: "my-service".to_string(),
    attributes: serde_json::json!({}),
    resource_attributes: serde_json::json!({}),
    created_at: Utc::now(),
    updated_at: Utc::now(),
};

metric_writer.write_metric(metric).await?;

// Write data point
let data_point = MetricDataPoint {
    id: Uuid::new_v4(),
    metric_id: metric.id,
    timestamp: Utc::now(),
    value: Some(1.0),
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

metric_writer.write_data_point(data_point).await?;
```

## Write Logs

```rust
use llm_observatory_storage::{
    writers::LogWriter,
    models::LogRecord,
};

let log_writer = LogWriter::new(pool.clone());

// Start auto-flush (every 5 seconds by default)
let _flush_handle = log_writer.start_auto_flush();

let log = LogRecord {
    id: Uuid::new_v4(),
    timestamp: Utc::now(),
    observed_timestamp: Utc::now(),
    severity_number: 9,  // INFO
    severity_text: "INFO".to_string(),
    body: "User logged in".to_string(),
    service_name: "my-service".to_string(),
    trace_id: Some("trace-123".to_string()),
    span_id: None,
    trace_flags: None,
    attributes: serde_json::json!({
        "user_id": "user-456"
    }),
    resource_attributes: serde_json::json!({}),
    scope_name: Some("auth".to_string()),
    scope_version: None,
    scope_attributes: None,
    created_at: Utc::now(),
};

log_writer.write_log(log).await?;
```

## Custom Configuration

```rust
use llm_observatory_storage::writers::trace::WriterConfig;

let config = WriterConfig {
    batch_size: 500,           // Flush after 500 records
    flush_interval_secs: 10,   // Max 10s between flushes
    max_concurrency: 8,        // Max concurrent operations
};

let writer = TraceWriter::with_config(pool, config);
```

## Monitoring

```rust
// Check buffer status
let buffer_stats = writer.buffer_stats().await;
println!("Traces buffered: {}", buffer_stats.traces_buffered);

// Check write statistics
let write_stats = writer.write_stats().await;
println!("Total writes: {}", write_stats.traces_written);
println!("Failures: {}", write_stats.write_failures);
println!("Retries: {}", write_stats.retries);
```

## Convert LlmSpan

Enable the feature in `Cargo.toml`:

```toml
llm-observatory-storage = { path = "crates/storage", features = ["llm-span-conversion"] }
```

Then use:

```rust
use llm_observatory_core::span::LlmSpan;
use llm_observatory_storage::models::TraceSpan;

let llm_span = LlmSpan::builder()
    .span_id("span-123")
    .trace_id("trace-456")
    .name("llm.completion")
    .provider(Provider::OpenAI)
    .model("gpt-4")
    // ... build span
    .build()?;

// Convert to storage model
let trace_span: TraceSpan = llm_span.into();

// Write to database
writer.write_span(trace_span).await?;
```

## Error Handling

```rust
match writer.flush().await {
    Ok(_) => println!("Flush successful"),
    Err(e) if e.is_retryable() => {
        eprintln!("Flush failed after retries: {}", e);
    }
    Err(e) => {
        eprintln!("Flush failed: {}", e);
    }
}
```

## Best Practices

1. **Always flush before shutdown**
   ```rust
   writer.flush().await?;
   pool.close().await;
   ```

2. **Use auto-flush for critical data**
   ```rust
   let _flush_handle = log_writer.start_auto_flush();
   ```

3. **Monitor statistics**
   ```rust
   let stats = writer.write_stats().await;
   if stats.write_failures > 0 {
       eprintln!("Warning: {} write failures", stats.write_failures);
   }
   ```

4. **Choose appropriate batch sizes**
   - Traces: 100-500
   - Metrics: 500-1000
   - Logs: 1000-5000

5. **Configure connection pool**
   ```rust
   use llm_observatory_storage::config::PoolConfig;

   let mut config = StorageConfig::default();
   config.pool.max_connections = 20;
   config.pool.min_connections = 5;
   ```

## Run Example

```bash
# Set database URL
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/llm_observatory"

# Run example
cargo run --example batch_writer_example

# Run tests (requires database)
cargo test --features postgres -- --ignored
```

## Performance Tips

1. **Increase batch size for higher throughput**
   ```rust
   let config = WriterConfig {
       batch_size: 1000,  // Higher batch = higher throughput
       ..Default::default()
   };
   ```

2. **Use multiple writers for parallelism**
   ```rust
   let writer1 = TraceWriter::new(pool.clone());
   let writer2 = TraceWriter::new(pool.clone());
   // Write to both in parallel
   ```

3. **Tune PostgreSQL**
   ```sql
   -- Increase checkpoint interval
   ALTER SYSTEM SET checkpoint_timeout = '15min';

   -- Increase shared buffers
   ALTER SYSTEM SET shared_buffers = '4GB';

   -- Reload configuration
   SELECT pg_reload_conf();
   ```

## Troubleshooting

### Connection Errors

```rust
// Check if database is reachable
pool.health_check().await?;
```

### High Memory Usage

```rust
// Reduce batch size
let config = WriterConfig {
    batch_size: 50,  // Smaller batches
    ..Default::default()
};
```

### Slow Writes

```rust
// Check pool statistics
let stats = pool.stats();
println!("Pool size: {}", stats.postgres_size);
println!("Idle connections: {}", stats.postgres_idle);
```

## Next Steps

- Read [BATCH_WRITER.md](docs/BATCH_WRITER.md) for detailed documentation
- Check [batch_writer_example.rs](examples/batch_writer_example.rs) for more examples
- Run [batch_writer_tests.rs](tests/batch_writer_tests.rs) for integration tests
- See [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for implementation details

## Support

For issues or questions:
- Check documentation in `docs/`
- Review examples in `examples/`
- Run tests to validate setup
- Check PostgreSQL logs for database issues

# Batch Writer Implementation

This document describes the batch writer implementation for high-performance data ingestion into PostgreSQL.

## Overview

The batch writer system provides efficient bulk insertion of traces, metrics, and logs using PostgreSQL's batch insert capabilities. This implementation achieves high throughput while maintaining data integrity and providing retry logic for transient failures.

## Architecture

### Components

1. **TraceWriter** - Handles traces, spans, and trace events
2. **MetricWriter** - Handles metric definitions and data points
3. **LogWriter** - Handles log records with auto-flush support

### Key Features

- **Buffered Writes**: Data is buffered in memory and flushed in batches
- **Auto-flush**: Automatic flushing when batch size is reached
- **Retry Logic**: Exponential backoff retry for transient errors
- **Statistics Tracking**: Real-time monitoring of write operations
- **Thread Safety**: Uses `Arc<RwLock<>>` for safe concurrent access
- **Performance Metrics**: Built-in throughput and latency tracking

## Performance Characteristics

### Target Performance

- **TraceWriter**: 10,000+ traces/second
- **MetricWriter**: 50,000+ data points/second
- **LogWriter**: 100,000+ logs/second

### Optimization Techniques

1. **Batch Inserts**: Uses SQLx `QueryBuilder` for efficient multi-row inserts
2. **Minimal Locking**: Releases locks before I/O operations
3. **Connection Pooling**: Leverages SQLx connection pool
4. **Upsert Support**: Uses `ON CONFLICT` for idempotent writes

## Usage

### Basic Usage

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
    // Create storage pool
    let config = StorageConfig::from_env()?;
    let pool = StoragePool::new(config).await?;

    // Create trace writer
    let writer = TraceWriter::new(pool);

    // Write a trace
    let trace = Trace::new(
        "trace-123".to_string(),
        "my-service".to_string(),
        Utc::now(),
    );

    writer.write_trace(trace).await?;

    // Flush buffered data
    writer.flush().await?;

    Ok(())
}
```

### Custom Configuration

```rust
use llm_observatory_storage::writers::trace::WriterConfig;

let config = WriterConfig {
    batch_size: 500,           // Flush after 500 records
    flush_interval_secs: 10,   // Max 10 seconds between flushes
    max_concurrency: 8,        // Max concurrent operations
};

let writer = TraceWriter::with_config(pool, config);
```

### Monitoring

```rust
// Get buffer statistics
let buffer_stats = writer.buffer_stats().await;
println!("Traces buffered: {}", buffer_stats.traces_buffered);

// Get write statistics
let write_stats = writer.write_stats().await;
println!("Total writes: {}", write_stats.traces_written);
println!("Failures: {}", write_stats.write_failures);
println!("Retries: {}", write_stats.retries);
```

### Auto-flush for Logs

```rust
use llm_observatory_storage::writers::LogWriter;

let writer = LogWriter::new(pool);

// Start background auto-flush task
let flush_handle = writer.start_auto_flush();

// Write logs...
for log in logs {
    writer.write_log(log).await?;
}

// Auto-flush will run every flush_interval_secs
// Manual flush is still available
writer.flush().await?;
```

## Implementation Details

### Batch Insert Strategy

The writers use SQLx's `QueryBuilder` to construct efficient multi-row INSERT statements:

```sql
INSERT INTO traces (id, trace_id, service_name, ...)
VALUES
  ($1, $2, $3, ...),
  ($4, $5, $6, ...),
  ($7, $8, $9, ...)
ON CONFLICT (trace_id) DO UPDATE SET
  end_time = EXCLUDED.end_time,
  status = EXCLUDED.status,
  ...
```

This approach provides:
- **10-100x faster** than individual INSERTs
- Automatic handling of conflicts via upsert
- Transaction safety (all or nothing)

### Retry Logic

The retry mechanism handles transient failures:

```rust
async fn with_retry<F, Fut, T>(&self, op: F) -> StorageResult<T>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = StorageResult<T>>,
{
    let max_retries = 3;
    let mut attempt = 0;

    loop {
        match op().await {
            Ok(result) => return Ok(result),
            Err(e) if e.is_retryable() && attempt < max_retries => {
                attempt += 1;
                let delay = Duration::from_millis(100 * (1 << attempt));
                tokio::time::sleep(delay).await;
            }
            Err(e) => return Err(e),
        }
    }
}
```

Features:
- Exponential backoff: 200ms, 400ms, 800ms
- Only retries transient errors (connection, timeout, pool errors)
- Tracks retry count in statistics

### Thread Safety

Writers use `Arc<RwLock<>>` for safe concurrent access:

```rust
pub struct TraceWriter {
    pool: StoragePool,
    buffer: Arc<RwLock<TraceBuffer>>,
    stats: Arc<RwLock<WriteStats>>,
}
```

Best practices:
- Acquire lock, clone data, release lock before I/O
- Short critical sections
- No I/O operations while holding locks

## LlmSpan Conversion

The storage crate provides conversion from `LlmSpan` (core crate) to `TraceSpan` (storage model):

```rust
use llm_observatory_core::span::LlmSpan;
use llm_observatory_storage::models::TraceSpan;

// Enable the feature
// Cargo.toml: features = ["llm-span-conversion"]

let llm_span = LlmSpan::builder()
    .span_id("span-123")
    .trace_id("trace-456")
    // ... build span
    .build()?;

// Convert to storage model
let trace_span: TraceSpan = llm_span.into();

// Write to database
writer.write_span(trace_span).await?;
```

The conversion:
- Maps all LLM-specific fields to attributes
- Converts enums (Provider, SpanStatus)
- Preserves token usage, cost, and latency data
- Handles metadata and custom attributes

## Database Schema

### Traces Table

```sql
CREATE TABLE traces (
    id UUID PRIMARY KEY,
    trace_id TEXT UNIQUE NOT NULL,
    service_name TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_us BIGINT,
    status TEXT NOT NULL,
    status_message TEXT,
    root_span_name TEXT,
    attributes JSONB NOT NULL DEFAULT '{}',
    resource_attributes JSONB NOT NULL DEFAULT '{}',
    span_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_traces_trace_id ON traces(trace_id);
CREATE INDEX idx_traces_service_name ON traces(service_name);
CREATE INDEX idx_traces_start_time ON traces(start_time DESC);
```

### Trace Spans Table

```sql
CREATE TABLE trace_spans (
    id UUID PRIMARY KEY,
    trace_id UUID NOT NULL REFERENCES traces(id),
    span_id TEXT UNIQUE NOT NULL,
    parent_span_id TEXT,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    service_name TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_us BIGINT,
    status TEXT NOT NULL,
    status_message TEXT,
    attributes JSONB NOT NULL DEFAULT '{}',
    events JSONB,
    links JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_spans_trace_id ON trace_spans(trace_id);
CREATE INDEX idx_spans_span_id ON trace_spans(span_id);
CREATE INDEX idx_spans_start_time ON trace_spans(start_time DESC);
```

## Performance Tuning

### Batch Size Selection

| Writer Type | Default Batch Size | Recommended Range | Notes |
|-------------|-------------------|-------------------|-------|
| TraceWriter | 100 | 50-500 | Balance between latency and throughput |
| MetricWriter | 500 | 200-1000 | Metrics are smaller, can batch more |
| LogWriter | 1000 | 500-5000 | Highest volume, largest batches |

### Connection Pool Settings

```rust
use llm_observatory_storage::config::PoolConfig;

let pool_config = PoolConfig {
    max_connections: 20,        // Match expected concurrency
    min_connections: 5,         // Keep connections warm
    connect_timeout_secs: 10,
    idle_timeout_secs: 300,     // 5 minutes
    max_lifetime_secs: 1800,    // 30 minutes
};
```

### PostgreSQL Optimization

1. **Use UNLOGGED tables** for ultra-high throughput (no WAL)
   ```sql
   CREATE UNLOGGED TABLE traces (...);
   ```
   Warning: Data loss risk on crash

2. **Increase checkpoint interval**
   ```
   checkpoint_timeout = 15min
   max_wal_size = 2GB
   ```

3. **Tune shared buffers**
   ```
   shared_buffers = 4GB
   effective_cache_size = 12GB
   ```

4. **Disable synchronous commits** for async replication
   ```
   synchronous_commit = off
   ```

## Error Handling

### Retryable Errors

The following errors trigger retry logic:
- Connection errors
- Pool timeout errors
- Transient network issues

### Non-retryable Errors

These errors fail immediately:
- Validation errors
- Constraint violations
- Data serialization errors
- Schema mismatches

### Error Recovery

```rust
match writer.flush().await {
    Ok(_) => println!("Flush successful"),
    Err(e) if e.is_retryable() => {
        // Already retried max times
        eprintln!("Flush failed after retries: {}", e);
    }
    Err(e) => {
        // Non-retryable error
        eprintln!("Flush failed: {}", e);
    }
}
```

## Best Practices

1. **Choose appropriate batch sizes** based on record size and latency requirements
2. **Monitor buffer stats** to detect backpressure
3. **Use auto-flush** for time-sensitive data (logs)
4. **Manual flush** before shutdown to prevent data loss
5. **Track write stats** for observability
6. **Configure retry limits** based on SLA requirements
7. **Use connection pooling** to avoid connection overhead
8. **Enable upsert** for idempotent writes

## Future Enhancements

### PostgreSQL COPY Protocol

For extremely high throughput (100,000+ records/sec), use PostgreSQL COPY:

```rust
// Future implementation
async fn insert_traces_copy(&self, traces: Vec<Trace>) -> StorageResult<()> {
    let mut writer = self.pool.postgres()
        .copy_in_raw("COPY traces (...) FROM STDIN WITH (FORMAT BINARY)")
        .await?;

    for trace in traces {
        // Encode trace as binary row
        writer.write_all(&encode_trace_binary(&trace)).await?;
    }

    writer.finish().await?;
    Ok(())
}
```

Benefits:
- 10x faster than batch INSERT
- Minimal overhead
- Binary format support

### Buffer Pooling

Reuse buffer allocations to reduce GC pressure:

```rust
use object_pool::Pool;

let buffer_pool = Pool::new(100, || Vec::with_capacity(1000));

// Acquire buffer from pool
let mut buffer = buffer_pool.pull();
buffer.extend(new_records);

// Return to pool when done
drop(buffer);
```

### Compression

Compress large JSONB fields before insertion:

```rust
use flate2::write::GzEncoder;

let compressed = compress_json(&attributes)?;
```

## Troubleshooting

### High Memory Usage

- Reduce batch size
- Increase flush frequency
- Check for slow queries blocking flushes

### Slow Writes

- Check connection pool utilization
- Monitor PostgreSQL slow query log
- Verify index usage with EXPLAIN ANALYZE
- Check network latency

### Data Loss

- Ensure flush() is called before shutdown
- Use auto-flush for critical data
- Monitor write_failures metric
- Enable WAL for durability

### Connection Pool Exhaustion

- Increase max_connections
- Reduce batch size to free connections faster
- Check for connection leaks
- Monitor pool stats

## Testing

Run the example:
```bash
cargo run --example batch_writer_example --features llm-span-conversion
```

Run benchmarks:
```bash
cargo bench --package llm-observatory-storage
```

## References

- [PostgreSQL Batch Insert Performance](https://www.postgresql.org/docs/current/populate.html)
- [SQLx QueryBuilder](https://docs.rs/sqlx/latest/sqlx/query_builder/index.html)
- [Tokio RwLock](https://docs.rs/tokio/latest/tokio/sync/struct.RwLock.html)

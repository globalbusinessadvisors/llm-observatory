# Performance Tuning Guide

Guide to optimizing storage layer performance based on benchmark results.

## Quick Wins

### 1. Use COPY Protocol for Bulk Writes

**Impact:** 10-100x throughput improvement

```rust
// ❌ Slow: Individual inserts
for span in spans {
    writer.write_span(span).await?;
}
writer.flush().await?;

// ✅ Fast: Batch with COPY
let (client, _) = pool.get_tokio_postgres_client().await?;
CopyWriter::write_spans(&client, spans).await?;
```

**When to use:**
- Batch sizes >100 records
- Bulk data ingestion
- Historical data loading
- High-throughput scenarios

### 2. Optimize Batch Sizes

**Recommended batch sizes:**

| Data Type | Optimal Batch | Memory | Latency |
|-----------|--------------|---------|---------|
| Traces | 500-2000 | ~5MB | <50ms |
| Spans | 1000-5000 | ~10MB | <100ms |
| Logs | 2000-10000 | ~20MB | <150ms |
| Metrics | 500-2000 | ~2MB | <30ms |
| Data Points | 5000-10000 | ~5MB | <80ms |

```rust
// Configure writer batch size
let config = WriterConfig {
    batch_size: 2000,  // Adjust based on data type
    flush_interval_secs: 5,
    max_concurrency: 4,
};
```

### 3. Tune Connection Pool

**Recommended settings:**

```rust
StorageConfig {
    postgres: PostgresConfig {
        max_connections: 20,        // 2-3x CPU cores
        min_connections: 5,         // Keep warm connections
        acquire_timeout_secs: 30,   // Allow time under load
        idle_timeout_secs: 600,     // 10 minutes
        max_lifetime_secs: 1800,    // 30 minutes
    },
}
```

**Rules of thumb:**
- max_connections = 2-3x number of CPU cores
- min_connections = 25% of max_connections
- Don't exceed PostgreSQL max_connections (default 100)

### 4. Optimize Concurrent Writers

**Finding optimal concurrency:**

```bash
# Benchmark different concurrency levels
cargo bench --bench concurrent_writes -- concurrent_scaling
```

**General guidelines:**
- Start with 2-4 concurrent writers
- Scale up to 2x CPU cores
- Beyond that, diminishing returns
- Monitor for contention (increasing latency)

```rust
// Good: Balanced concurrency
tokio::spawn(async move {
    let writer = TraceWriter::new(pool);
    writer.write_traces(traces).await?;
    writer.flush().await?;
});

// ❌ Bad: Excessive concurrency
for _ in 0..100 {  // Too many!
    tokio::spawn(/* ... */);
}
```

## PostgreSQL Configuration

### For Development

```sql
-- postgresql.conf or ALTER SYSTEM

-- Basic performance
shared_buffers = '256MB'
work_mem = '16MB'
maintenance_work_mem = '128MB'

-- Checkpoints
checkpoint_timeout = '10min'
max_wal_size = '2GB'

-- Query planner
random_page_cost = 1.1  -- For SSD
effective_cache_size = '1GB'
```

### For Production

```sql
-- Assuming 8GB RAM, SSD, 4 CPU cores

-- Memory
shared_buffers = '2GB'              -- 25% of RAM
effective_cache_size = '6GB'        -- 75% of RAM
work_mem = '64MB'                   -- For sorting/hashing
maintenance_work_mem = '512MB'      -- For VACUUM, indexes

-- Write performance
wal_buffers = '16MB'
checkpoint_timeout = '15min'
max_wal_size = '4GB'
min_wal_size = '1GB'

-- Planner
random_page_cost = 1.1              -- SSD
effective_io_concurrency = 200      -- SSD

-- Parallelism
max_worker_processes = 4
max_parallel_workers_per_gather = 2
max_parallel_workers = 4

-- Connection
max_connections = 100
```

### Benchmark-Specific Tuning

**For maximum throughput benchmarks:**

```sql
-- ⚠️ WARNING: Do NOT use in production!

-- Disable synchronous commits (data loss risk)
synchronous_commit = off

-- Reduce fsync overhead
wal_writer_delay = '200ms'
commit_delay = 100000  -- 100ms

-- Increase checkpoint distance
checkpoint_timeout = '30min'
max_wal_size = '8GB'
```

**Restore safety after benchmarking:**

```sql
synchronous_commit = on
wal_writer_delay = '200ms'
commit_delay = 0
checkpoint_timeout = '5min'
max_wal_size = '1GB'
```

## Indexing Strategy

### Critical Indexes

These should already exist from migrations:

```sql
-- Traces
CREATE INDEX idx_traces_trace_id ON traces(trace_id);
CREATE INDEX idx_traces_service_time ON traces(service_name, start_time DESC);
CREATE INDEX idx_traces_status ON traces(status);

-- Spans
CREATE INDEX idx_spans_trace_id ON trace_spans(trace_id);
CREATE INDEX idx_spans_service_time ON trace_spans(service_name, start_time DESC);

-- Logs
CREATE INDEX idx_logs_timestamp ON logs(timestamp DESC);
CREATE INDEX idx_logs_service_severity ON logs(service_name, severity_number);
CREATE INDEX idx_logs_trace_id ON logs(trace_id) WHERE trace_id IS NOT NULL;

-- Metrics
CREATE INDEX idx_metrics_name_service ON metrics(name, service_name);
CREATE INDEX idx_data_points_metric_time ON metric_data_points(metric_id, timestamp DESC);
```

### Verify Index Usage

```sql
-- Check if indexes are being used
EXPLAIN ANALYZE
SELECT * FROM traces
WHERE service_name = 'my-service'
  AND start_time >= NOW() - INTERVAL '1 hour'
ORDER BY start_time DESC
LIMIT 100;

-- Look for "Index Scan" in output
-- If you see "Seq Scan", index isn't being used
```

### Monitor Index Bloat

```sql
-- Check index size and bloat
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;

-- Rebuild bloated indexes
REINDEX INDEX CONCURRENTLY idx_traces_service_time;
```

## Query Optimization

### Use Prepared Statements

```rust
// ❌ Slow: Dynamic query building
let query = format!("SELECT * FROM traces WHERE service_name = '{}'", service);

// ✅ Fast: Prepared statement (sqlx does this automatically)
sqlx::query_as::<_, Trace>("SELECT * FROM traces WHERE service_name = $1")
    .bind(service)
    .fetch_all(pool)
    .await?;
```

### Limit Result Sets

```rust
// ❌ Slow: Unbounded query
let traces = repository.list(TraceFilters {
    service_name: Some("my-service"),
    limit: None,  // Could return millions!
    ..Default::default()
}).await?;

// ✅ Fast: Limited results
let traces = repository.list(TraceFilters {
    service_name: Some("my-service"),
    limit: Some(100),  // Reasonable limit
    ..Default::default()
}).await?;
```

### Use Time-Based Partitioning

For large datasets, partition by time:

```sql
-- Create partitioned table (example for traces)
CREATE TABLE traces_partitioned (
    LIKE traces INCLUDING ALL
) PARTITION BY RANGE (start_time);

-- Create monthly partitions
CREATE TABLE traces_2024_01 PARTITION OF traces_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE traces_2024_02 PARTITION OF traces_partitioned
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Queries automatically use correct partition
SELECT * FROM traces_partitioned
WHERE start_time >= '2024-01-15'
  AND start_time < '2024-01-20';
```

## Memory Management

### Batch Processing Memory

**Rule of thumb:** Keep batch size × record size < 100MB

```rust
// Calculate approximate memory usage
let span_size = std::mem::size_of::<TraceSpan>(); // ~500 bytes
let batch_size = 10000;
let memory_usage = span_size * batch_size; // ~5MB ✓

// ❌ Too much memory
let batch_size = 1_000_000; // ~500MB!
```

### Connection Pool Memory

Each connection uses memory:
- Base overhead: ~10MB per connection
- Work memory: configured work_mem per operation
- Result sets: size of data being processed

```
Total = (connections × 10MB) + (active_queries × work_mem)

Example:
20 connections × 10MB = 200MB
+ 5 active queries × 64MB = 320MB
= 520MB total
```

### Writer Buffer Memory

```rust
// Monitor buffer size
let stats = writer.buffer_stats().await;
println!("Buffered: {} traces, {} spans",
    stats.traces_buffered,
    stats.spans_buffered
);

// Flush if too large
if stats.spans_buffered > 10000 {
    writer.flush().await?;
}
```

## Monitoring and Profiling

### Key Metrics to Track

```rust
use std::time::Instant;

// 1. Write throughput
let start = Instant::now();
writer.write_spans(spans).await?;
writer.flush().await?;
let duration = start.elapsed();
let throughput = spans.len() as f64 / duration.as_secs_f64();
println!("Throughput: {:.0} spans/sec", throughput);

// 2. Query latency
let start = Instant::now();
let traces = repository.list(filters).await?;
let latency = start.elapsed();
println!("Query latency: {:?}", latency);

// 3. Connection pool stats
let pool_size = pool.postgres().size();
let idle = pool.postgres().num_idle();
println!("Pool: {}/{} active", pool_size - idle, pool_size);
```

### PostgreSQL Statistics

```sql
-- Active queries
SELECT
    pid,
    usename,
    state,
    query,
    NOW() - query_start AS duration
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- Table statistics
SELECT
    schemaname,
    tablename,
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows
FROM pg_stat_user_tables
ORDER BY n_tup_ins DESC;

-- Index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

### Slow Query Logging

```sql
-- Enable slow query log
ALTER SYSTEM SET log_min_duration_statement = '100ms';
SELECT pg_reload_conf();

-- Check slow queries
SELECT
    query,
    calls,
    total_exec_time / 1000 AS total_sec,
    mean_exec_time / 1000 AS mean_sec,
    max_exec_time / 1000 AS max_sec
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

## Troubleshooting Performance Issues

### Issue: Write throughput below target

**Symptoms:**
- <10,000 spans/sec with COPY protocol
- High CPU usage
- Slow disk I/O

**Solutions:**

1. **Check batch size:**
   ```bash
   cargo bench --bench writer_throughput
   # Compare different batch sizes
   ```

2. **Verify COPY protocol is used:**
   ```rust
   // Should use CopyWriter, not buffered writer
   CopyWriter::write_spans(&client, spans).await?;
   ```

3. **Check PostgreSQL I/O:**
   ```sql
   SELECT * FROM pg_stat_bgwriter;
   -- High buffers_backend = disk I/O bottleneck
   -- Increase shared_buffers
   ```

4. **Reduce contention:**
   ```rust
   // Use fewer concurrent writers
   let config = WriterConfig {
       max_concurrency: 4,  // Down from 8
       // ...
   };
   ```

### Issue: Query latency too high

**Symptoms:**
- P95 latency >100ms
- Slow list operations
- Full table scans

**Solutions:**

1. **Check index usage:**
   ```sql
   EXPLAIN ANALYZE SELECT * FROM traces WHERE service_name = 'test';
   -- Should show "Index Scan", not "Seq Scan"
   ```

2. **Add missing indexes:**
   ```sql
   CREATE INDEX CONCURRENTLY idx_missing
       ON traces(service_name, start_time DESC);
   ```

3. **Reduce result set size:**
   ```rust
   // Always use LIMIT
   let filters = TraceFilters {
       limit: Some(100),
       ..Default::default()
   };
   ```

4. **Optimize filter order:**
   ```sql
   -- ❌ Slow: Filter on unindexed column first
   SELECT * FROM traces
   WHERE status = 'ok'
     AND service_name = 'test';

   -- ✅ Fast: Filter on indexed column first
   SELECT * FROM traces
   WHERE service_name = 'test'
     AND status = 'ok';
   ```

### Issue: Connection pool exhaustion

**Symptoms:**
- "connection pool exhausted" errors
- High connection acquisition time
- Timeouts

**Solutions:**

1. **Increase pool size:**
   ```rust
   postgres: PostgresConfig {
       max_connections: 30,  // Up from 20
       // ...
   }
   ```

2. **Reduce concurrent operations:**
   ```rust
   // Limit parallelism
   use futures::stream::{self, StreamExt};

   stream::iter(batches)
       .for_each_concurrent(4, |batch| async move {
           // Process batch
       })
       .await;
   ```

3. **Check for connection leaks:**
   ```rust
   // Always drop or use connections within scope
   {
       let (client, _handle) = pool.get_tokio_postgres_client().await?;
       // Use client
   } // Automatically released here
   ```

4. **Increase timeouts:**
   ```rust
   postgres: PostgresConfig {
       acquire_timeout_secs: 60,  // Up from 30
       // ...
   }
   ```

### Issue: High memory usage

**Symptoms:**
- OOM errors
- Swap usage
- Process killed

**Solutions:**

1. **Reduce batch sizes:**
   ```rust
   let config = WriterConfig {
       batch_size: 1000,  // Down from 5000
       // ...
   };
   ```

2. **Limit concurrent operations:**
   ```rust
   // Process in smaller chunks
   for chunk in spans.chunks(1000) {
       writer.write_spans(chunk.to_vec()).await?;
   }
   ```

3. **Stream large result sets:**
   ```rust
   // ❌ Load all at once
   let all_traces = repository.list(filters).await?;

   // ✅ Stream with pagination
   let mut offset = 0;
   loop {
       let filters = TraceFilters {
           limit: Some(100),
           offset: Some(offset),
           ..Default::default()
       };
       let traces = repository.list(filters).await?;
       if traces.is_empty() { break; }
       // Process traces
       offset += 100;
   }
   ```

## Best Practices Summary

### Do's ✅

- Use COPY protocol for batches >100 records
- Batch writes (500-5000 records depending on type)
- Limit query results
- Use prepared statements (automatic with sqlx)
- Monitor and optimize slow queries
- Keep connection pool size reasonable (2-3x cores)
- Use indexes for all WHERE clauses
- Partition large tables by time
- Flush writers regularly

### Don'ts ❌

- Don't use individual inserts in loops
- Don't create unbounded result sets
- Don't exceed connection pool limits
- Don't forget to flush buffered writers
- Don't use dynamic SQL strings
- Don't share single writer across many threads
- Don't ignore slow query logs
- Don't run benchmarks in production mode (synchronous_commit=on)

## Further Reading

- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [PostgreSQL COPY Performance](https://www.postgresql.org/docs/current/populate.html)
- [Connection Pooling Best Practices](https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing)
- [Criterion.rs Documentation](https://bheisler.github.io/criterion.rs/book/)
- [Tokio Performance Guide](https://tokio.rs/tokio/tutorial/overview)

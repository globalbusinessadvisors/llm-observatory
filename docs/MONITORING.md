# Storage Layer Monitoring

This document describes the comprehensive monitoring and metrics system for the LLM Observatory storage layer.

## Overview

The storage layer provides production-ready Prometheus metrics for monitoring:

- **Write Performance**: Throughput, latency, batch sizes, and error rates
- **Query Performance**: Latency by repository and method, result counts
- **Connection Pool Health**: Active/idle/max connections, utilization
- **Database Health**: PostgreSQL and Redis connectivity and latency
- **COPY vs INSERT Comparison**: Performance metrics for different write methods
- **Error Tracking**: Errors categorized by type and operation

## Architecture

### Components

1. **StorageMetrics** (`crates/storage/src/metrics.rs`)
   - Core metrics collection and recording
   - Prometheus histogram, counter, and gauge metrics
   - Timing guards for automatic duration recording

2. **HealthServer** (`crates/storage/src/health.rs`)
   - HTTP endpoints for health checks and metrics
   - Runs on a separate port (default: 9090)
   - Provides liveness and readiness probes

3. **Instrumented Writers** (`crates/storage/src/writers/instrumented.rs`)
   - Wrappers around standard writers with automatic metrics
   - Records write durations, throughput, batch sizes, and errors
   - Supports TraceWriter, MetricWriter, LogWriter, and CopyWriter

4. **Instrumented Repositories** (`crates/storage/src/repositories/instrumented.rs`)
   - Wrappers around standard repositories with automatic metrics
   - Records query durations and result counts
   - Supports all repository types

## Available Metrics

### Write Operations

#### `storage_write_duration_seconds` (histogram)
Duration of storage write operations in seconds.

Labels:
- `writer_type`: trace, metric, log, copy
- `operation`: write_trace, write_span, flush, copy, etc.

Example queries:
```promql
# 95th percentile write latency for trace writes
histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket{writer_type="trace"}[5m]))

# Average write duration
rate(storage_write_duration_seconds_sum[5m]) / rate(storage_write_duration_seconds_count[5m])
```

#### `storage_writes_total` (counter)
Total number of storage write operations.

Labels:
- `writer_type`: trace, metric, log, copy
- `operation`: write_trace, write_span, flush, copy, etc.
- `status`: success, error

Example queries:
```promql
# Write throughput (ops/sec)
rate(storage_writes_total{status="success"}[1m])

# Error rate
rate(storage_writes_total{status="error"}[1m])

# Success rate percentage
(rate(storage_writes_total{status="success"}[5m]) / rate(storage_writes_total[5m])) * 100
```

#### `storage_batch_size` (histogram)
Size of batch operations (number of items).

Labels:
- `writer_type`: trace, metric, log
- `operation`: insert, copy, flush

Example queries:
```promql
# Median batch size
histogram_quantile(0.50, rate(storage_batch_size_bucket[5m]))

# 95th percentile batch size
histogram_quantile(0.95, rate(storage_batch_size_bucket[5m]))
```

#### `storage_items_written_total` (counter)
Total number of items written to storage.

Labels:
- `writer_type`: trace, metric, log, copy
- `item_type`: traces, spans, events, metrics, data_points, logs

Example queries:
```promql
# Items written per second
rate(storage_items_written_total[1m])

# Total items by type
sum by (item_type) (storage_items_written_total)
```

#### `storage_buffer_size` (gauge)
Current size of write buffers by writer type.

Labels:
- `writer_type`: trace, metric, log
- `buffer_type`: traces, spans, events, metrics, data_points, logs

Example queries:
```promql
# Current buffer sizes
storage_buffer_size

# Buffer utilization trends
rate(storage_buffer_size[5m])
```

#### `storage_flushes_total` (counter)
Total number of buffer flush operations.

Labels:
- `writer_type`: trace, metric, log
- `status`: success, error

Example queries:
```promql
# Flush rate
rate(storage_flushes_total[1m])

# Failed flushes
rate(storage_flushes_total{status="error"}[5m])
```

### Query Operations

#### `storage_query_duration_seconds` (histogram)
Duration of storage query operations in seconds.

Labels:
- `repository`: trace_repository, metric_repository, log_repository
- `method`: get_by_id, list, search, get_traces, etc.

Example queries:
```promql
# 95th percentile query latency
histogram_quantile(0.95, rate(storage_query_duration_seconds_bucket[5m]))

# Average query duration by method
avg by (method) (rate(storage_query_duration_seconds_sum[5m]) / rate(storage_query_duration_seconds_count[5m]))

# Slowest queries
topk(10, histogram_quantile(0.99, rate(storage_query_duration_seconds_bucket[5m])))
```

#### `storage_query_result_count` (histogram)
Number of results returned by query operations.

Labels:
- `repository`: trace_repository, metric_repository, log_repository
- `method`: get_by_id, list, search, etc.

Example queries:
```promql
# Average result count per query
avg(rate(storage_query_result_count_sum[5m]) / rate(storage_query_result_count_count[5m])) by (repository, method)

# Queries returning large result sets
histogram_quantile(0.95, rate(storage_query_result_count_bucket[5m]))
```

### Connection Pool

#### `storage_pool_connections` (gauge)
Number of database connections in various states.

Labels:
- `state`: active, idle, max

Example queries:
```promql
# Pool utilization percentage
(storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) * 100

# Available connections
storage_pool_connections{state="idle"}

# Pool exhaustion alert
storage_pool_connections{state="active"} / storage_pool_connections{state="max"} > 0.8
```

#### `storage_connection_acquire_duration_seconds` (histogram)
Time taken to acquire a connection from the pool.

Example queries:
```promql
# 95th percentile connection acquisition time
histogram_quantile(0.95, rate(storage_connection_acquire_duration_seconds_bucket[5m]))

# Slow connection acquisitions (>100ms)
storage_connection_acquire_duration_seconds_bucket{le="0.1"}
```

### Errors

#### `storage_errors_total` (counter)
Total number of storage errors by type.

Labels:
- `error_type`: connection, query, timeout, write, flush, copy
- `operation`: optional operation context

Example queries:
```promql
# Error rate by type
rate(storage_errors_total[1m])

# Total errors in last hour
sum(increase(storage_errors_total[1h]))

# Most common error types
topk(5, sum by (error_type) (increase(storage_errors_total[5m])))
```

### Retries

#### `storage_retries_total` (counter)
Total number of retry attempts.

Labels:
- `operation`: operation being retried

Example queries:
```promql
# Retry rate
rate(storage_retries_total[1m])

# Operations requiring most retries
topk(5, sum by (operation) (increase(storage_retries_total[5m])))
```

## Health Endpoints

### `/health`
Comprehensive health check including:
- PostgreSQL connectivity and latency
- Redis connectivity and latency (if configured)
- Connection pool statistics
- Overall health status

Response example:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-05T10:30:00Z",
  "database": {
    "postgres": {
      "status": "healthy",
      "latency_ms": 2.3
    },
    "redis": {
      "status": "healthy",
      "latency_ms": 1.1
    }
  },
  "pool_stats": {
    "size": 10,
    "active": 3,
    "idle": 7,
    "max_connections": 20,
    "min_connections": 2,
    "utilization_percent": 15.0,
    "near_capacity": false
  },
  "check_duration_ms": 5
}
```

HTTP Status Codes:
- `200 OK`: All systems healthy
- `503 Service Unavailable`: One or more systems unhealthy

### `/health/live`
Liveness probe for Kubernetes/container orchestration.

- Always returns `200 OK` if the service is running
- Does not check external dependencies
- Use for liveness probes

### `/health/ready`
Readiness probe for Kubernetes/container orchestration.

- Returns `200 OK` if the service can accept traffic
- Checks PostgreSQL connectivity
- Use for readiness probes

### `/metrics`
Prometheus metrics scraping endpoint.

- Returns all metrics in Prometheus text format
- Should be scraped every 10-30 seconds
- Configure as a scrape target in Prometheus

## Usage

### Starting the Health Server

```rust
use llm_observatory_storage::{StorageConfig, StoragePool, HealthServer};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize storage
    let config = StorageConfig::from_env()?;
    let pool = StoragePool::new(config).await?;

    // Start health and metrics server
    let health_server = HealthServer::new(pool.clone());

    tokio::spawn(async move {
        health_server.serve("0.0.0.0:9090").await.unwrap();
    });

    // Your application code...

    Ok(())
}
```

### Using Instrumented Writers

```rust
use llm_observatory_storage::{
    StoragePool, StorageMetrics,
    writers::InstrumentedTraceWriter,
};
use std::sync::Arc;

let pool = StoragePool::new(config).await?;
let metrics = Arc::new(StorageMetrics::new());

// Create instrumented writer
let writer = InstrumentedTraceWriter::new(pool.clone(), metrics.clone());

// All operations are automatically instrumented
writer.write_trace(trace).await?;
writer.flush().await?;
```

### Using Instrumented Repositories

```rust
use llm_observatory_storage::{
    StoragePool, StorageMetrics,
    repositories::InstrumentedTraceRepository,
};
use std::sync::Arc;

let pool = StoragePool::new(config).await?;
let metrics = Arc::new(StorageMetrics::new());

// Create instrumented repository
let repo = InstrumentedTraceRepository::new(pool.clone(), metrics.clone());

// All queries are automatically instrumented
let trace = repo.get_by_id(trace_id).await?;
let traces = repo.list(filters).await?;
```

### Updating Pool Metrics

Pool metrics should be updated periodically:

```rust
use tokio::time::{interval, Duration};

let pool = pool.clone();
tokio::spawn(async move {
    let mut ticker = interval(Duration::from_secs(10));
    loop {
        ticker.tick().await;
        pool.update_metrics();
    }
});
```

## Grafana Dashboards

Pre-built Grafana dashboards are available in `/docs/grafana/`:

### Storage Overview Dashboard
`storage-overview.json`

Features:
- Write throughput and latency
- Items written per second
- Batch sizes
- Connection pool utilization
- Query latency
- Error rates
- Buffer sizes
- Flush operations
- Retry rates

### Database Health Dashboard
`database-health.json`

Features:
- Connection pool health gauge
- Write success rate gauge
- Query success rate gauge
- Active connections over time
- Error types distribution (pie chart)
- Write operations by type
- Query operations by repository
- Write latency heatmap
- Query latency heatmap
- COPY vs INSERT performance comparison

### Importing Dashboards

1. Open Grafana
2. Navigate to Dashboards → Import
3. Upload the JSON file
4. Select your Prometheus data source
5. Click Import

## Alerting Recommendations

### Critical Alerts

#### High Error Rate
```yaml
alert: HighStorageErrorRate
expr: rate(storage_errors_total[5m]) > 1
for: 5m
severity: critical
summary: Storage error rate is high
description: Error rate is {{ $value }} errors/sec
```

#### Pool Near Capacity
```yaml
alert: ConnectionPoolNearCapacity
expr: (storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) > 0.85
for: 5m
severity: warning
summary: Connection pool is near capacity
description: Pool utilization is {{ $value }}%
```

#### Low Write Success Rate
```yaml
alert: LowWriteSuccessRate
expr: (rate(storage_writes_total{status="success"}[5m]) / rate(storage_writes_total[5m])) < 0.95
for: 5m
severity: critical
summary: Write success rate is low
description: Success rate is {{ $value }}%
```

### Warning Alerts

#### High Query Latency
```yaml
alert: HighQueryLatency
expr: histogram_quantile(0.95, rate(storage_query_duration_seconds_bucket[5m])) > 1
for: 10m
severity: warning
summary: Query latency is high
description: P95 latency is {{ $value }}s
```

#### High Retry Rate
```yaml
alert: HighRetryRate
expr: rate(storage_retries_total[5m]) > 5
for: 10m
severity: warning
summary: High retry rate detected
description: Retry rate is {{ $value }} retries/sec
```

#### Large Buffer Sizes
```yaml
alert: LargeBufferSizes
expr: storage_buffer_size > 1000
for: 10m
severity: warning
summary: Buffer sizes are large
description: Buffer size for {{ $labels.writer_type }}/{{ $labels.buffer_type }} is {{ $value }}
```

## Prometheus Configuration

Example `prometheus.yml` configuration:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'llm-observatory-storage'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 10s
    scrape_timeout: 5s
```

## Best Practices

### 1. Monitor All Layers

- Use instrumented writers for all write operations
- Use instrumented repositories for all queries
- Update pool metrics every 10 seconds
- Run health server on a separate port

### 2. Set Up Alerts

- Configure critical alerts for error rates and pool exhaustion
- Set warning alerts for high latency and retry rates
- Use different channels for different severities

### 3. Dashboard Organization

- Use the storage overview dashboard for at-a-glance monitoring
- Use the database health dashboard for detailed investigation
- Create custom dashboards for specific use cases

### 4. Metric Retention

- Keep high-resolution metrics (10s) for 24 hours
- Downsampled metrics (1m) for 30 days
- Aggregated metrics (5m) for 1 year

### 5. Performance Impact

- Metrics have minimal overhead (<1% CPU, <10MB memory)
- Histograms use exponential buckets for efficiency
- Gauges are updated only when pool stats change

## Troubleshooting

### High Error Rate

1. Check `/health` endpoint for database connectivity
2. Review error types in `storage_errors_total` metric
3. Check database logs for connection issues
4. Verify network connectivity

### High Latency

1. Check connection acquisition time
2. Review query patterns (large result sets?)
3. Check database load and resources
4. Consider adding indexes for common queries

### Pool Exhaustion

1. Increase `max_connections` in configuration
2. Review connection acquisition patterns
3. Check for connection leaks (long-running queries)
4. Implement connection pooling at application level

### High Retry Rate

1. Check database availability and stability
2. Review timeout configurations
3. Check network latency and reliability
4. Consider exponential backoff tuning

## Performance Benchmarks

Expected performance metrics:

### Write Operations
- INSERT throughput: 5,000-10,000 rows/sec
- COPY throughput: 50,000-100,000 rows/sec
- Batch write latency (p95): <100ms
- Single write latency (p95): <10ms

### Query Operations
- Simple queries (p95): <5ms
- Complex queries (p95): <50ms
- List operations (100 results, p95): <20ms
- Statistics queries (p95): <100ms

### Connection Pool
- Acquisition time (p95): <10ms
- Typical utilization: 20-40%
- Max safe utilization: 85%

### Error Rates
- Target error rate: <0.01%
- Alert threshold: >1%
- Critical threshold: >5%

## Further Reading

- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
- [PostgreSQL Monitoring](https://www.postgresql.org/docs/current/monitoring.html)
- [Connection Pooling Best Practices](https://www.postgresql.org/docs/current/runtime-config-connection.html)

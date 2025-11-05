# Metrics Quick Reference

A quick reference for the most important LLM Observatory storage metrics.

## Key Performance Indicators (KPIs)

### Write Performance

| Metric | Query | Good | Warning | Critical |
|--------|-------|------|---------|----------|
| Write Throughput | `rate(storage_writes_total{status="success"}[1m])` | >100/s | <50/s | <10/s |
| Write P95 Latency | `histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket[5m]))` | <100ms | >500ms | >1s |
| Write Success Rate | `(rate(storage_writes_total{status="success"}[5m]) / rate(storage_writes_total[5m])) * 100` | >99% | <99% | <95% |
| Batch Size (median) | `histogram_quantile(0.50, rate(storage_batch_size_bucket[5m]))` | >100 | <50 | <10 |

### Query Performance

| Metric | Query | Good | Warning | Critical |
|--------|-------|------|---------|----------|
| Query P95 Latency | `histogram_quantile(0.95, rate(storage_query_duration_seconds_bucket[5m]))` | <50ms | >200ms | >1s |
| Query Throughput | `rate(storage_query_duration_seconds_count[1m])` | >10/s | <5/s | <1/s |

### Database Health

| Metric | Query | Good | Warning | Critical |
|--------|-------|------|---------|----------|
| Pool Utilization | `(storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) * 100` | <70% | >80% | >90% |
| Error Rate | `rate(storage_errors_total[1m])` | <0.01/s | >0.1/s | >1/s |
| Connection Acquire Time | `histogram_quantile(0.95, rate(storage_connection_acquire_duration_seconds_bucket[5m]))` | <10ms | >50ms | >100ms |

## Essential Queries

### Write Operations

```promql
# Total items written per second
rate(storage_items_written_total[1m])

# Items written by type
sum by (item_type) (rate(storage_items_written_total[1m]))

# Write latency percentiles
histogram_quantile(0.50, rate(storage_write_duration_seconds_bucket[5m]))  # p50
histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket[5m]))  # p95
histogram_quantile(0.99, rate(storage_write_duration_seconds_bucket[5m]))  # p99

# COPY vs INSERT performance comparison
histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket{operation="copy"}[5m]))
/
histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket{operation=~"insert|write_.*"}[5m]))
```

### Query Operations

```promql
# Query latency by repository
avg by (repository) (rate(storage_query_duration_seconds_sum[5m]) / rate(storage_query_duration_seconds_count[5m]))

# Slowest query methods
topk(10, histogram_quantile(0.99, rate(storage_query_duration_seconds_bucket[5m])))

# Average result count per query
avg(rate(storage_query_result_count_sum[5m]) / rate(storage_query_result_count_count[5m])) by (repository, method)
```

### Connection Pool

```promql
# Current pool state
storage_pool_connections{state="active"}
storage_pool_connections{state="idle"}
storage_pool_connections{state="max"}

# Pool utilization percentage
(storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) * 100

# Available connections
storage_pool_connections{state="idle"}

# Pool exhaustion predictor (5min trend)
predict_linear(storage_pool_connections{state="active"}[5m], 300)
```

### Errors and Reliability

```promql
# Error rate by type
rate(storage_errors_total[1m])

# Most common errors
topk(5, sum by (error_type) (increase(storage_errors_total[5m])))

# Error ratio (errors per operation)
rate(storage_errors_total[5m]) / rate(storage_writes_total[5m])

# Retry rate
rate(storage_retries_total[1m])

# Operations requiring most retries
topk(5, sum by (operation) (increase(storage_retries_total[5m])))
```

### Buffer Management

```promql
# Current buffer sizes
storage_buffer_size

# Buffer size by writer and type
storage_buffer_size{writer_type="trace", buffer_type="traces"}

# Flush rate
rate(storage_flushes_total[1m])

# Failed flush rate
rate(storage_flushes_total{status="error"}[5m])
```

## Alert Expressions

### Critical Alerts

```promql
# High error rate (>1 error/sec for 5 minutes)
rate(storage_errors_total[5m]) > 1

# Connection pool near capacity (>85% for 5 minutes)
(storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) > 0.85

# Low write success rate (<95% for 5 minutes)
(rate(storage_writes_total{status="success"}[5m]) / rate(storage_writes_total[5m])) < 0.95

# Database unreachable
up{job="llm-observatory-storage"} == 0
```

### Warning Alerts

```promql
# High write latency (p95 >1s for 10 minutes)
histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket[5m])) > 1

# High query latency (p95 >500ms for 10 minutes)
histogram_quantile(0.95, rate(storage_query_duration_seconds_bucket[5m])) > 0.5

# High retry rate (>5 retries/sec for 10 minutes)
rate(storage_retries_total[5m]) > 5

# Large buffer sizes (>1000 items for 10 minutes)
storage_buffer_size > 1000

# Connection acquisition slow (p95 >100ms for 10 minutes)
histogram_quantile(0.95, rate(storage_connection_acquire_duration_seconds_bucket[5m])) > 0.1
```

## Dashboard Panels

### Write Performance Panel

```promql
# Panel: Write Throughput
rate(storage_writes_total{status="success"}[1m])

# Panel: Write Latency
histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket[5m]))

# Panel: Items Written
rate(storage_items_written_total[1m])

# Panel: Batch Sizes
histogram_quantile(0.50, rate(storage_batch_size_bucket[5m]))  # Median
histogram_quantile(0.95, rate(storage_batch_size_bucket[5m]))  # P95
```

### Database Health Panel

```promql
# Panel: Pool Utilization Gauge
(storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) * 100

# Panel: Success Rate Gauge
(rate(storage_writes_total{status="success"}[5m]) / rate(storage_writes_total[5m])) * 100

# Panel: Error Types (Pie Chart)
sum by (error_type) (increase(storage_errors_total[5m]))
```

### Performance Comparison Panel

```promql
# Panel: COPY vs INSERT Performance
histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket{operation="copy"}[5m]))
histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket{operation=~"insert|write_.*"}[5m]))

# Panel: Throughput by Method
rate(storage_items_written_total{writer_type="copy"}[1m])
rate(storage_items_written_total{writer_type!="copy"}[1m])
```

## Recording Rules

Useful recording rules for expensive queries:

```yaml
groups:
  - name: storage_recording_rules
    interval: 30s
    rules:
      # Pre-compute write latency percentiles
      - record: storage:write_duration_seconds:p95
        expr: histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket[5m]))

      - record: storage:write_duration_seconds:p99
        expr: histogram_quantile(0.99, rate(storage_write_duration_seconds_bucket[5m]))

      # Pre-compute query latency percentiles
      - record: storage:query_duration_seconds:p95
        expr: histogram_quantile(0.95, rate(storage_query_duration_seconds_bucket[5m]))

      # Pre-compute success rates
      - record: storage:write_success_rate
        expr: rate(storage_writes_total{status="success"}[5m]) / rate(storage_writes_total[5m])

      # Pre-compute pool utilization
      - record: storage:pool_utilization
        expr: storage_pool_connections{state="active"} / storage_pool_connections{state="max"}

      # Pre-compute error rate
      - record: storage:error_rate
        expr: rate(storage_errors_total[5m])
```

## Metric Label Reference

### Common Labels

| Label | Values | Description |
|-------|--------|-------------|
| `writer_type` | trace, metric, log, copy | Type of writer component |
| `operation` | write_trace, write_span, flush, copy, etc. | Specific operation being performed |
| `status` | success, error | Operation result status |
| `repository` | trace_repository, metric_repository, log_repository | Repository component |
| `method` | get_by_id, list, search, etc. | Repository method name |
| `error_type` | connection, query, timeout, write, flush, copy | Category of error |
| `state` | active, idle, max | Connection pool state |
| `item_type` | traces, spans, events, metrics, data_points, logs | Type of data item |
| `buffer_type` | traces, spans, events, metrics, data_points, logs | Type of buffer |

## Grafana Variables

Useful template variables for dashboards:

```
# Writer type
writer_type = label_values(storage_writes_total, writer_type)

# Repository
repository = label_values(storage_query_duration_seconds, repository)

# Error type
error_type = label_values(storage_errors_total, error_type)

# Time range
$__range = 5m, 15m, 1h, 6h, 24h, 7d

# Percentile
percentile = 0.50, 0.75, 0.95, 0.99
```

## Common Aggregations

```promql
# Total throughput across all writers
sum(rate(storage_writes_total{status="success"}[1m]))

# Average latency by operation
avg by (operation) (rate(storage_write_duration_seconds_sum[5m]) / rate(storage_write_duration_seconds_count[5m]))

# Error rate by writer
sum by (writer_type) (rate(storage_errors_total[5m]))

# Total items by type
sum by (item_type) (storage_items_written_total)
```

## Useful PromQL Functions

```promql
# Rate of increase (per-second)
rate(metric[time_range])

# Absolute increase
increase(metric[time_range])

# Percentile calculation
histogram_quantile(quantile, metric)

# Average over time
avg_over_time(metric[time_range])

# Maximum over time
max_over_time(metric[time_range])

# Predict future value
predict_linear(metric[time_range], future_seconds)

# Top N values
topk(N, metric)

# Bottom N values
bottomk(N, metric)
```

## Quick Troubleshooting

| Symptom | Check This Metric | Likely Cause |
|---------|-------------------|--------------|
| Slow writes | `storage:write_duration_seconds:p95` | Database load, network latency, or large batch sizes |
| Slow queries | `storage:query_duration_seconds:p95` | Missing indexes, complex queries, or database load |
| High error rate | `storage_errors_total` by `error_type` | Connection issues, timeouts, or constraint violations |
| Pool exhaustion | `storage:pool_utilization` | Insufficient connections or leaked connections |
| High retries | `storage_retries_total` by `operation` | Transient failures or database instability |
| Growing buffers | `storage_buffer_size` | Slow flush or high write rate |

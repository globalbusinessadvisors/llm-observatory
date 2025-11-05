# Storage Layer Performance Benchmarks

Comprehensive benchmark suite for the LLM Observatory storage layer, measuring throughput, latency, and scalability across different workload patterns.

## Overview

This benchmark suite provides:

- **Writer Throughput**: Measures write performance for traces, spans, metrics, and logs at different batch sizes
- **Query Performance**: Measures read latency for common repository operations
- **Pool Performance**: Tests connection pool behavior under load
- **Concurrent Writes**: Evaluates write performance with multiple concurrent writers
- **Mixed Workload**: Simulates realistic production scenarios with concurrent reads and writes
- **COPY vs INSERT**: Compares PostgreSQL COPY protocol against standard batch INSERT

## Target Metrics

Based on the LLM Observatory performance requirements:

| Metric | Target | Benchmark |
|--------|--------|-----------|
| Write throughput | >10,000 spans/sec | `writer_throughput`, `copy_vs_insert` |
| Query latency P95 | <100ms | `query_performance` |
| COPY protocol | 50,000-100,000 rows/sec | `copy_vs_insert`, `writer_throughput` |
| Connection acquisition | <1ms P95 | `pool_performance` |
| Concurrent scaling | Linear up to CPU cores | `concurrent_writes` |

## Quick Start

### Using Testcontainers (Recommended)

Automatically spins up an isolated PostgreSQL container for benchmarking:

```bash
# Run all benchmarks
cargo bench

# Run specific benchmark suite
cargo bench --bench writer_throughput
cargo bench --bench query_performance
cargo bench --bench pool_performance
cargo bench --bench concurrent_writes
cargo bench --bench mixed_workload
cargo bench --bench copy_vs_insert

# Run specific benchmark within a suite
cargo bench --bench writer_throughput -- trace_writer_copy
cargo bench --bench query_performance -- trace_get_by_id
```

### Using Existing Database

For faster iteration during development:

```bash
# Set up test database
export DATABASE_URL="postgres://postgres:password@localhost/llm_observatory_bench"

# Run migrations (optional, benchmarks run migrations automatically)
sqlx migrate run

# Run benchmarks
cargo bench --bench writer_throughput
```

## Benchmark Suites

### 1. Writer Throughput (`writer_throughput`)

Measures write throughput for different data types and batch sizes.

**What it measures:**
- COPY protocol throughput for traces, spans, and logs
- Buffered writer throughput (INSERT-based)
- Metric and metric data point write performance
- Batch size impact on throughput

**Batch sizes tested:** 100, 500, 1000, 5000, 10000

**Example output:**
```
trace_writer_copy/1000  time:   [15.234 ms 15.567 ms 15.901 ms]
                        thrpt:  [62890 elem/s 64230 elem/s 65632 elem/s]

span_writer_copy/5000   time:   [45.123 ms 46.234 ms 47.345 ms]
                        thrpt:  [105623 elem/s 108134 elem/s 110789 elem/s]
```

**Key benchmarks:**
- `trace_writer_copy`: COPY protocol for traces
- `span_writer_copy`: COPY protocol for spans
- `log_writer_copy`: COPY protocol for logs
- `trace_writer_buffered`: INSERT-based buffered writes
- `metric_data_point_writer`: Metric data point throughput

### 2. Query Performance (`query_performance`)

Measures read latency for repository operations.

**What it measures:**
- Single record lookup by ID
- List queries with various filters
- Span queries for traces
- Time-range queries
- Service name and severity filters

**Test data:** 10,000 traces, 50,000 spans, 10,000 logs, 1,000 metrics

**Example output:**
```
trace_get_by_id         time:   [1.234 ms 1.456 ms 1.678 ms]
trace_list/limit_100    time:   [5.234 ms 5.567 ms 5.901 ms]
log_queries/filter_severity_limit_100
                        time:   [12.34 ms 13.45 ms 14.56 ms]
```

**Key benchmarks:**
- `trace_get_by_id`: Single trace lookup
- `trace_list`: List traces with filters
- `log_queries`: Log queries with severity and service filters
- `metric_queries`: Metric listing and filtering
- `metric_data_point_queries`: Data point time-range queries

### 3. Pool Performance (`pool_performance`)

Tests connection pool behavior under various conditions.

**What it measures:**
- Connection acquisition latency
- Concurrent connection handling
- Pool saturation and recovery
- Connection reuse efficiency
- Mixed read/write workload

**Concurrency levels tested:** 2, 5, 10, 20

**Example output:**
```
connection_acquisition/single_connection
                        time:   [234.5 µs 256.7 µs 278.9 µs]

concurrent_connections/10
                        time:   [5.234 ms 5.567 ms 5.901 ms]
                        thrpt:  [1796 elem/s 1797 elem/s 1910 elem/s]

pool_saturation_recovery
                        time:   [45.23 ms 47.34 ms 49.45 ms]
```

**Key benchmarks:**
- `connection_acquisition`: Basic connection get/release
- `concurrent_connections`: Parallel connection requests
- `concurrent_writes`: Concurrent write operations
- `pool_saturation_recovery`: Behavior when exceeding pool size
- `mixed_workload`: 70% read, 30% write pattern

### 4. Concurrent Writes (`concurrent_writes`)

Measures write performance with multiple concurrent writers.

**What it measures:**
- Scaling behavior across different worker counts
- COPY protocol under concurrent load
- Buffered writer contention
- Mixed data type writes
- Write amplification

**Configurations tested:**
- 2, 4, 8, 16 concurrent writers
- Various batch sizes per writer
- Shared vs independent writers

**Example output:**
```
concurrent_trace_writes_copy/writers/4_x_500
                        time:   [67.89 ms 71.23 ms 74.56 ms]
                        thrpt:  [26834 elem/s 28123 elem/s 29456 elem/s]

concurrent_span_writes_copy/writers/8_x_500
                        time:   [89.12 ms 92.34 ms 95.56 ms]
                        thrpt:  [41876 elem/s 43234 elem/s 44876 elem/s]
```

**Key benchmarks:**
- `concurrent_trace_writes_copy`: Concurrent trace writes
- `concurrent_span_writes_copy`: Concurrent span writes
- `concurrent_mixed_writes`: Traces + spans + logs together
- `shared_writer_contention`: Shared vs independent writers
- `concurrent_scaling`: Scaling efficiency measurement

### 5. Mixed Workload (`mixed_workload`)

Simulates realistic production scenarios with concurrent reads and writes.

**What it measures:**
- Read-heavy workload (80% read, 20% write)
- Write-heavy workload (20% read, 80% write)
- Balanced workload (50% read, 50% write)
- Complex queries under write load
- Sustained mixed operations

**Test scenarios:**
- Realistic application patterns
- Query performance degradation under write load
- 100 concurrent operations
- Long-running sustained workload

**Example output:**
```
read_heavy_workload/80_read_20_write
                        time:   [23.45 ms 24.67 ms 25.89 ms]

balanced_workload/50_read_50_write
                        time:   [34.56 ms 36.78 ms 38.90 ms]

realistic_application_workload/realistic_mix
                        time:   [45.67 ms 48.90 ms 52.13 ms]
```

**Key benchmarks:**
- `read_heavy_workload`: 80/20 read/write split
- `write_heavy_workload`: 20/80 read/write split
- `balanced_workload`: 50/50 read/write split
- `realistic_application_workload`: Production-like mix
- `sustained_mixed_workload`: 100 concurrent operations

### 6. COPY vs INSERT (`copy_vs_insert`)

Compares PostgreSQL COPY protocol against standard batch INSERT operations.

**What it measures:**
- COPY protocol throughput
- Batch INSERT throughput
- Speedup ratio
- Different data types (traces, spans, logs)

**Batch sizes tested:** 100, 1000, 5000, 10000

**Expected results:**
- INSERT: 5,000-10,000 rows/sec
- COPY: 50,000-100,000 rows/sec
- Speedup: 10-100x depending on data complexity

## Interpreting Results

### Understanding Criterion Output

Criterion provides detailed statistical analysis for each benchmark:

```
trace_writer_copy/1000  time:   [15.234 ms 15.567 ms 15.901 ms]
                        thrpt:  [62890 elem/s 64230 elem/s 65632 elem/s]
```

- **time**: [lower bound, estimate, upper bound] - 95% confidence interval
- **thrpt**: Throughput in elements per second
- **Change**: Comparison with previous run (after first run)

### Performance Analysis

**Good performance indicators:**
- Write throughput >10,000 spans/sec for batch sizes ≥1000
- Query latency P95 <100ms for filtered queries
- COPY protocol 5-20x faster than INSERT
- Linear scaling up to 4-8 concurrent writers
- Connection acquisition <1ms

**Warning signs:**
- Throughput decreases with larger batch sizes
- Query latency >100ms for simple lookups
- Poor concurrent scaling (sublinear or negative)
- Connection acquisition >5ms
- High variability in measurements (wide confidence intervals)

### Comparing Runs

```bash
# Baseline measurement
cargo bench --bench writer_throughput -- --save-baseline main

# After optimization
cargo bench --bench writer_throughput -- --baseline main
```

## HTML Reports

Criterion generates detailed HTML reports at:
```
target/criterion/
├── report/
│   └── index.html          # Overall summary
├── trace_writer_copy/
│   └── report/index.html   # Individual benchmark
└── ...
```

View reports:
```bash
# Open in browser
open target/criterion/report/index.html

# Or use a simple HTTP server
python3 -m http.server 8000 --directory target/criterion
# Visit http://localhost:8000/report/
```

Reports include:
- Violin plots showing distribution
- Iteration times and outliers
- Slope graphs for trend analysis
- Comparison with previous runs

## Performance Tuning Recommendations

### Database Configuration

**PostgreSQL settings for optimal performance:**

```sql
-- Increase shared buffers (25% of RAM)
shared_buffers = 4GB

-- Increase work memory for sorting/hashing
work_mem = 64MB

-- Disable synchronous commits for benchmarks (not production!)
synchronous_commit = off

-- Increase checkpoint distance
checkpoint_timeout = 15min
max_wal_size = 4GB

-- Optimize for bulk loads
maintenance_work_mem = 512MB
```

### Connection Pool Settings

```rust
StorageConfig {
    postgres: PostgresConfig {
        max_connections: 20,        // 2-3x number of CPU cores
        min_connections: 5,         // Keep warm connections
        acquire_timeout_secs: 30,   // Allow time during load
        idle_timeout_secs: 600,     // 10 minutes
        max_lifetime_secs: 1800,    // 30 minutes
    },
    // ...
}
```

### Batch Size Tuning

**General guidelines:**
- **Traces**: 500-2000 per batch
- **Spans**: 1000-5000 per batch
- **Logs**: 2000-10000 per batch
- **Metric data points**: 5000-10000 per batch

**Trade-offs:**
- Larger batches: Higher throughput, more memory usage, longer latency spikes
- Smaller batches: Lower latency, less memory, slightly lower throughput

### Writer Configuration

```rust
// For high-throughput scenarios
WriterConfig {
    batch_size: 5000,           // Larger batches for throughput
    flush_interval_secs: 1,     // Frequent flushes
    max_concurrency: 8,         // Match CPU cores
}

// For low-latency scenarios
WriterConfig {
    batch_size: 100,            // Smaller batches for latency
    flush_interval_secs: 5,     // Less frequent flushes
    max_concurrency: 2,         // Reduce contention
}
```

### Concurrent Write Optimization

**Best practices:**
- Use COPY protocol for bulk writes (10-100x faster)
- Use independent writers for different data types
- Limit concurrent writers to 2-3x CPU cores
- Batch data before sending to writers
- Use connection pooling effectively

**Anti-patterns:**
- Sharing a single buffered writer across many threads
- Writing individual records without batching
- Exceeding connection pool size with concurrent operations
- Using INSERT for large batch writes

## Troubleshooting

### Benchmark Failures

**Container startup issues:**
```bash
# Check Docker is running
docker ps

# Clean up old containers
docker container prune

# Set explicit database URL
export DATABASE_URL="postgres://postgres:password@localhost/llm_observatory_bench"
```

**Migration failures:**
```bash
# Verify migrations directory
ls migrations/

# Run migrations manually
sqlx migrate run --database-url "postgres://..."
```

### Performance Issues

**Slow benchmarks:**
- Check available system resources (CPU, memory, disk I/O)
- Reduce sample size for faster iteration: `cargo bench -- --sample-size 10`
- Use existing database instead of containers
- Run individual benchmarks instead of full suite

**High variance:**
- Close other applications
- Disable CPU frequency scaling
- Run multiple times and compare: `cargo bench -- --rerun`
- Increase warm-up time in benchmark code

**Connection errors:**
- Increase pool size and timeouts
- Check PostgreSQL max_connections setting
- Verify network connectivity

## CI/CD Integration

### Running in CI

```yaml
# GitHub Actions example
- name: Run benchmarks
  run: |
    # Install Docker for testcontainers
    # ...

    # Run benchmarks with shorter sample size
    cargo bench --bench writer_throughput -- --sample-size 10

    # Upload Criterion reports as artifacts
    - uses: actions/upload-artifact@v3
      with:
        name: benchmark-results
        path: target/criterion/
```

### Continuous Performance Monitoring

```bash
# Track performance over time
cargo bench --bench writer_throughput -- --save-baseline main

# After changes
cargo bench --bench writer_throughput -- --baseline main

# Generate comparison report
# Check for regressions >5%
```

## Contributing

When adding new benchmarks:

1. Add benchmark file to `benches/`
2. Update `Cargo.toml` with `[[bench]]` entry
3. Use common test data generators from `benches/common/mod.rs`
4. Include realistic workload patterns
5. Document expected performance ranges
6. Add to this README

### Benchmark Guidelines

- **Realistic**: Use production-like data and access patterns
- **Repeatable**: Use fixed seeds for randomness
- **Isolated**: Each benchmark should be independent
- **Documented**: Explain what is being measured and why
- **Meaningful**: Measure actual bottlenecks and use cases

## Additional Resources

- [Criterion.rs Documentation](https://bheisler.github.io/criterion.rs/book/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Async Rust Performance](https://rust-lang.github.io/async-book/)
- [LLM Observatory Storage Implementation](../IMPLEMENTATION_SUMMARY.md)

## License

See repository root for license information.

# Storage Layer Benchmark Suite - Implementation Summary

## Overview

Comprehensive benchmark suite for the LLM Observatory storage layer, providing statistical analysis of throughput, latency, and scalability metrics.

## Benchmark Files Created

### 1. `writer_throughput.rs` (240 lines)
**Purpose:** Measure write throughput across different data types and batch sizes

**Benchmarks:**
- `trace_writer_copy` - COPY protocol for traces (100-10K batch sizes)
- `span_writer_copy` - COPY protocol for spans (100-10K batch sizes)
- `log_writer_copy` - COPY protocol for logs (100-10K batch sizes)
- `trace_writer_buffered` - INSERT-based buffered writes (100-2K batch sizes)
- `span_writer_buffered` - INSERT-based buffered writes (100-2K batch sizes)
- `metric_writer` - Metric definition writes (100-5K batch sizes)
- `metric_data_point_writer` - Metric data point writes (100-10K batch sizes)
- `log_writer_buffered` - INSERT-based log writes (100-10K batch sizes)

**Key features:**
- Tests both COPY and INSERT protocols
- Multiple batch sizes for scaling analysis
- Realistic test data generation
- Throughput measurement in elements/sec

### 2. `query_performance.rs` (360 lines)
**Purpose:** Measure read latency for repository operations

**Setup:**
- 10,000 traces
- 50,000 spans
- 10,000 logs
- 1,000 metrics with 10,000 data points

**Benchmarks:**
- `trace_get_by_id` - Single trace lookup by UUID
- `trace_get_by_trace_id` - Trace lookup by string ID
- `trace_list` - List queries with filters (limit, service, time range)
- `span_queries` - Get spans for trace
- `log_queries` - List logs with filters (limit, severity, service)
- `metric_queries` - List metrics with filters
- `metric_data_point_queries` - Data point time-range queries

**Key features:**
- Realistic query patterns
- Multiple filter combinations
- P50/P95/P99 latency measurement
- Random access patterns to avoid caching bias

### 3. `pool_performance.rs` (210 lines)
**Purpose:** Test connection pool behavior under load

**Benchmarks:**
- `connection_acquisition` - Single connection get/release latency
- `concurrent_connections` - 2-20 concurrent connection requests
- `concurrent_writes` - Concurrent write operations
- `pool_saturation_recovery` - Behavior when exceeding pool size
- `mixed_workload` - 70% read, 30% write pattern
- `connection_reuse` - Sequential operations efficiency
- `pool_initialization` - Pool creation time

**Key features:**
- Tests pool limits and saturation
- Concurrent access patterns
- Recovery behavior measurement
- Connection reuse efficiency

### 4. `concurrent_writes.rs` (330 lines)
**Purpose:** Measure write performance with multiple concurrent writers

**Configurations:**
- 2, 4, 8, 16 concurrent writers
- Variable batch sizes per writer
- Fixed total workload for scaling tests

**Benchmarks:**
- `concurrent_trace_writes_copy` - Concurrent COPY writes (traces)
- `concurrent_span_writes_copy` - Concurrent COPY writes (spans)
- `concurrent_log_writes_copy` - Concurrent COPY writes (logs)
- `concurrent_buffered_writes` - Concurrent INSERT-based writes
- `concurrent_mixed_writes` - Mixed data type writes
- `shared_writer_contention` - Shared vs independent writers
- `concurrent_scaling` - Scaling efficiency (1-16 workers)

**Key features:**
- Linear scaling measurement
- Contention analysis
- Write amplification detection
- Optimal concurrency determination

### 5. `mixed_workload.rs` (310 lines)
**Purpose:** Simulate realistic production scenarios

**Setup:**
- 5,000 traces
- 20,000 spans
- 10,000 logs

**Benchmarks:**
- `read_heavy_workload` - 80% reads, 20% writes
- `write_heavy_workload` - 20% reads, 80% writes
- `balanced_workload` - 50% reads, 50% writes
- `complex_queries_under_write_load` - Query performance during writes
- `realistic_application_workload` - Production-like mix
- `sustained_mixed_workload` - 100 concurrent operations

**Key features:**
- Real-world access patterns
- Read/write interference measurement
- Sustained load testing
- Performance degradation analysis

### 6. `copy_vs_insert.rs` (Updated, 304 lines)
**Purpose:** Compare COPY protocol vs batch INSERT performance

**Benchmarks:**
- `bench_copy_traces` - COPY protocol traces
- `bench_copy_spans` - COPY protocol spans
- `bench_copy_logs` - COPY protocol logs
- `bench_insert_traces` - Batch INSERT traces

**Expected results:**
- INSERT: 5,000-10,000 rows/sec
- COPY: 50,000-100,000 rows/sec
- Speedup: 10-100x

### 7. `common/mod.rs` (280 lines)
**Purpose:** Shared utilities and test data generators

**Features:**
- `BenchmarkContext` - Database setup with testcontainers
- `generate_traces()` - Realistic trace data
- `generate_spans()` - Realistic span data
- `generate_logs()` - Realistic log data
- `generate_metrics()` - Realistic metric data
- `generate_metric_data_points()` - Time-series data
- `setup_test_container()` - Container management

**Key features:**
- Automatic PostgreSQL container management
- Environment variable support for existing DB
- Realistic data distribution
- Sinusoidal patterns for metrics
- Error simulation (10% traces, 5% spans)

## Documentation

### `README.md` (580 lines)
Comprehensive guide covering:
- Quick start with testcontainers
- Manual database setup
- Detailed benchmark descriptions
- Target metrics and expectations
- Interpreting Criterion output
- Performance tuning recommendations
- Database configuration
- Batch size tuning
- Writer configuration
- Troubleshooting
- CI/CD integration

### `QUICKSTART.md` (190 lines)
Fast-track guide with:
- Prerequisites
- Two setup options (automatic/manual)
- Common commands
- Quick performance check
- Troubleshooting
- Expected durations
- Performance targets

### `BENCHMARK_SUMMARY.md` (This file)
Implementation overview and architecture

## Configuration Updates

### `Cargo.toml`
Added 6 benchmark entries:
```toml
[[bench]]
name = "writer_throughput"
harness = false

[[bench]]
name = "query_performance"
harness = false

[[bench]]
name = "pool_performance"
harness = false

[[bench]]
name = "concurrent_writes"
harness = false

[[bench]]
name = "mixed_workload"
harness = false

[[bench]]
name = "copy_vs_insert"  # Already existed
harness = false
```

Added dependency:
```toml
testcontainers-modules = { version = "0.11", features = ["postgres"] }
```

## Architecture

```
benches/
├── README.md                    # Comprehensive documentation
├── QUICKSTART.md               # Fast-track setup guide
├── BENCHMARK_SUMMARY.md        # This file
├── common/
│   └── mod.rs                  # Shared utilities
├── writer_throughput.rs        # Write performance tests
├── query_performance.rs        # Read latency tests
├── pool_performance.rs         # Connection pool tests
├── concurrent_writes.rs        # Concurrent write tests
├── mixed_workload.rs          # Production scenario tests
└── copy_vs_insert.rs          # Protocol comparison
```

## Test Data Characteristics

### Traces
- Unique trace IDs with hex format
- Variable duration (100-300ms)
- 10% error rate
- Service name, attributes, resource attributes
- Realistic span counts (1-10)

### Spans
- Hex-formatted span IDs
- Parent-child relationships (2/3 have parents)
- Multiple span kinds (client, server, producer, consumer, internal)
- Variable duration (10-110ms)
- 5% error rate
- Events for 10% of spans

### Logs
- Multiple severity levels (TRACE to FATAL)
- 20% correlation with traces
- Realistic log messages
- Service and component attributes
- User ID attributes

### Metrics
- Multiple types (counter, gauge, histogram, summary)
- Descriptive names and descriptions
- Appropriate units
- Service and environment attributes

### Metric Data Points
- Sinusoidal value patterns
- Timestamp sequences
- Aggregation data (count, sum, min, max)
- Realistic distribution

## Statistical Analysis

Using Criterion.rs features:
- **Sample sizes:** 10-100 iterations per benchmark
- **Confidence intervals:** 95% (default)
- **Outlier detection:** Automatic
- **Warm-up:** Automatic per benchmark
- **HTML reports:** Violin plots, slopes, comparisons
- **Baseline comparison:** Support for regression detection

## Performance Targets

### Write Throughput (Elements/Second)
- Traces (COPY): >50,000
- Spans (COPY): >80,000
- Logs (COPY): >100,000
- Traces (INSERT): >5,000
- Spans (INSERT): >8,000
- Metrics: >10,000
- Data points: >50,000

### Query Latency (Milliseconds)
- Single lookup: <5ms (P95)
- List 100 records: <50ms (P95)
- Filtered queries: <100ms (P95)
- Time-range queries: <80ms (P95)

### Pool Performance
- Connection acquisition: <1ms (P95)
- Concurrent 10 connections: <10ms
- Pool saturation: graceful degradation
- Recovery time: <100ms

### Concurrent Performance
- 2 workers: ~1.8x baseline
- 4 workers: ~3.2x baseline
- 8 workers: ~5.5x baseline
- 16 workers: ~8x baseline (CPU-dependent)

## Usage Examples

### Run All Benchmarks
```bash
cargo bench
```

### Run Specific Suite
```bash
cargo bench --bench writer_throughput
cargo bench --bench query_performance
```

### Run Specific Test
```bash
cargo bench --bench writer_throughput -- trace_writer_copy
cargo bench --bench query_performance -- trace_get_by_id
```

### Quick Iteration (Fewer Samples)
```bash
cargo bench --bench writer_throughput -- --sample-size 10
```

### Baseline Comparison
```bash
# Save baseline
cargo bench --bench writer_throughput -- --save-baseline main

# Compare after changes
cargo bench --bench writer_throughput -- --baseline main
```

### Using Existing Database
```bash
export DATABASE_URL="postgres://postgres:password@localhost/llm_observatory_bench"
cargo bench
```

## Output Interpretation

### Example Output
```
trace_writer_copy/1000  time:   [15.234 ms 15.567 ms 15.901 ms]
                        thrpt:  [62890 elem/s 64230 elem/s 65632 elem/s]
                        change: [-5.2% -3.1% -1.0%] (p = 0.00 < 0.05)
                        Performance has improved.
```

**Reading this:**
- Time: 15.567ms average (95% CI: 15.234-15.901ms)
- Throughput: 64,230 elements/sec
- Change: 3.1% faster than baseline (statistically significant)
- Verdict: Performance improved

## CI/CD Integration

Benchmarks designed for:
- Automated performance regression detection
- Baseline tracking over time
- PR performance validation
- Release performance verification

**Recommended CI approach:**
```yaml
- Run with --sample-size 10 for faster execution
- Save baselines per branch/release
- Flag regressions >5% as failures
- Upload HTML reports as artifacts
```

## Future Enhancements

Potential additions:
1. **Batch size optimization:** Automatic optimal batch size determination
2. **Memory profiling:** Memory usage per operation
3. **Network latency:** Simulate remote database
4. **Compression:** Test impact of data compression
5. **Index impact:** Benchmark with/without indexes
6. **Partitioning:** Test partitioned table performance
7. **Redis caching:** Add caching layer benchmarks
8. **Metrics export:** Prometheus metrics benchmarking

## Maintenance

**Updating benchmarks:**
1. Keep test data realistic and representative
2. Adjust sample sizes based on CI time budgets
3. Update baselines with each major release
4. Review and update target metrics annually
5. Add benchmarks for new features

**Monitoring:**
- Track benchmark durations (detect slowdowns)
- Monitor variance (detect instability)
- Review outliers (identify anomalies)
- Compare across hardware (ensure portability)

## Dependencies

**Core:**
- `criterion` 0.5 - Statistical benchmarking framework
- `tokio` - Async runtime
- `sqlx` - Database operations
- `llm-observatory-storage` - Storage layer being benchmarked

**Test infrastructure:**
- `testcontainers` 0.23 - Container orchestration
- `testcontainers-modules` 0.11 - PostgreSQL container
- `once_cell` - Global state management
- `rand` - Random data generation

## Total Implementation

**Lines of code:**
- Benchmarks: ~1,740 lines
- Common utilities: ~280 lines
- Documentation: ~1,300 lines
- **Total: ~3,320 lines**

**Files created:**
- 7 benchmark files
- 3 documentation files
- 1 shared utilities module

## Summary

This comprehensive benchmark suite provides:
- ✅ Complete coverage of storage operations
- ✅ Realistic workload simulations
- ✅ Statistical rigor with Criterion.rs
- ✅ Automated infrastructure with testcontainers
- ✅ Production-ready performance targets
- ✅ Detailed documentation and guides
- ✅ CI/CD friendly design
- ✅ Baseline tracking and regression detection

The suite enables data-driven optimization, performance regression detection, and capacity planning for the LLM Observatory storage layer.

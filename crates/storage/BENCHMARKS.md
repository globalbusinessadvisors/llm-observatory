# Storage Layer Benchmarks

Comprehensive performance benchmark suite for the LLM Observatory storage layer.

## Overview

The storage layer includes a complete benchmark suite that measures:

- **Write Throughput**: Traces, spans, metrics, and logs at various batch sizes
- **Query Performance**: Repository operations and filtering
- **Connection Pool**: Behavior under concurrent load
- **Concurrent Writes**: Scaling and contention analysis
- **Mixed Workload**: Realistic production scenarios
- **COPY vs INSERT**: Protocol performance comparison

## Quick Start

```bash
# Navigate to storage crate
cd crates/storage

# Run all benchmarks (uses testcontainers automatically)
cargo bench

# Run specific benchmark suite
cargo bench --bench writer_throughput
cargo bench --bench query_performance

# Quick performance check (~2 minutes)
cargo bench --bench writer_throughput -- --sample-size 10 trace_writer_copy/1000
```

## Documentation

Detailed documentation in the `benches/` directory:

### 📖 [QUICKSTART.md](benches/QUICKSTART.md)
5-minute guide to running benchmarks
- Prerequisites and setup
- Common commands
- Troubleshooting
- Expected performance

### 📚 [README.md](benches/README.md)
Comprehensive benchmark documentation
- Detailed benchmark descriptions
- Interpreting results
- Performance targets
- CI/CD integration
- 580 lines of detailed documentation

### ⚡ [PERFORMANCE_TUNING.md](benches/PERFORMANCE_TUNING.md)
Performance optimization guide
- Quick wins (COPY protocol, batch sizes, etc.)
- PostgreSQL configuration
- Query optimization
- Memory management
- Troubleshooting

### 📊 [BENCHMARK_SUMMARY.md](benches/BENCHMARK_SUMMARY.md)
Implementation details and architecture
- File-by-file breakdown
- Test data characteristics
- Statistical analysis
- Usage examples

## Performance Targets

Based on LLM Observatory requirements:

| Metric | Target | How to Verify |
|--------|--------|---------------|
| Write throughput | >10,000 spans/sec | `cargo bench --bench writer_throughput` |
| Query latency P95 | <100ms | `cargo bench --bench query_performance` |
| COPY protocol | 50,000-100,000 rows/sec | `cargo bench --bench copy_vs_insert` |
| Connection acquisition | <1ms P95 | `cargo bench --bench pool_performance` |
| Concurrent scaling | Linear to CPU cores | `cargo bench --bench concurrent_writes` |

## Benchmark Suites

### 1. Writer Throughput (`writer_throughput.rs`)

Measures write performance across data types and batch sizes.

```bash
cargo bench --bench writer_throughput
```

**Tests:**
- COPY protocol: traces, spans, logs (100-10K batch sizes)
- Buffered writers: INSERT-based (100-2K batch sizes)
- Metric writes: definitions and data points

**Expected results:**
- COPY traces: 50,000-100,000/sec
- COPY spans: 80,000-120,000/sec
- COPY logs: 100,000-150,000/sec
- INSERT traces: 5,000-10,000/sec

### 2. Query Performance (`query_performance.rs`)

Measures read latency for repository operations.

```bash
cargo bench --bench query_performance
```

**Tests:**
- Single record lookups (by ID, by trace_id)
- List queries with filters
- Time-range queries
- Service and severity filters

**Expected results:**
- Single lookup: <5ms (P95)
- List 100 records: <50ms (P95)
- Filtered queries: <100ms (P95)

### 3. Pool Performance (`pool_performance.rs`)

Tests connection pool under various loads.

```bash
cargo bench --bench pool_performance
```

**Tests:**
- Connection acquisition latency
- Concurrent connections (2-20)
- Pool saturation and recovery
- Mixed read/write workload

**Expected results:**
- Single acquisition: <1ms
- 10 concurrent: <10ms
- Graceful degradation under saturation

### 4. Concurrent Writes (`concurrent_writes.rs`)

Evaluates write performance with multiple concurrent writers.

```bash
cargo bench --bench concurrent_writes
```

**Tests:**
- 2-16 concurrent writers
- Scaling efficiency
- Shared vs independent writers
- Mixed data type writes

**Expected results:**
- 2 workers: ~1.8x baseline
- 4 workers: ~3.2x baseline
- 8 workers: ~5.5x baseline

### 5. Mixed Workload (`mixed_workload.rs`)

Simulates realistic production scenarios.

```bash
cargo bench --bench mixed_workload
```

**Tests:**
- Read-heavy (80/20), write-heavy (20/80), balanced (50/50)
- Complex queries under write load
- Sustained 100 concurrent operations

**Expected results:**
- Minimal read latency degradation under write load
- >5,000 total ops/sec

### 6. COPY vs INSERT (`copy_vs_insert.rs`)

Compares protocol performance.

```bash
cargo bench --bench copy_vs_insert
```

**Expected results:**
- INSERT: 5,000-10,000 rows/sec
- COPY: 50,000-100,000 rows/sec
- Speedup: 10-100x

## Viewing Results

### Command Line

```bash
cargo bench --bench writer_throughput
```

Output:
```
trace_writer_copy/1000  time:   [15.234 ms 15.567 ms 15.901 ms]
                        thrpt:  [62890 elem/s 64230 elem/s 65632 elem/s]
```

### HTML Reports

Criterion generates detailed HTML reports:

```bash
# Run benchmarks
cargo bench

# View reports
open target/criterion/report/index.html

# Or use a web server
cd target/criterion
python3 -m http.server 8000
# Visit http://localhost:8000/report/
```

Reports include:
- Violin plots showing distribution
- Iteration times and outliers
- Slope graphs for trend analysis
- Comparison with previous runs

### Baseline Tracking

```bash
# Save baseline
cargo bench --bench writer_throughput -- --save-baseline main

# Make changes...

# Compare with baseline
cargo bench --bench writer_throughput -- --baseline main
```

Output shows regression/improvement:
```
trace_writer_copy/1000  change: [-5.2% -3.1% -1.0%] (p = 0.00 < 0.05)
                        Performance has improved.
```

## Common Use Cases

### Quick Performance Check

```bash
# ~2 minute quick check
cargo bench --bench writer_throughput -- --sample-size 10 trace_writer_copy/1000

# Expected: ~60,000 traces/second ✓
```

### Before/After Optimization

```bash
# Before
cargo bench --bench writer_throughput -- --save-baseline before

# Apply optimization...

# After
cargo bench --bench writer_throughput -- --baseline before

# Review improvement percentage
```

### CI/CD Performance Gate

```bash
# In CI pipeline
cargo bench --bench writer_throughput -- --sample-size 10 --baseline main

# Fail if regression >5%
```

### Find Optimal Batch Size

```bash
# Run writer throughput benchmarks
cargo bench --bench writer_throughput -- trace_writer_copy

# Review HTML report
open target/criterion/trace_writer_copy/report/index.html

# Compare throughput across batch sizes
```

### Diagnose Pool Issues

```bash
# Run pool benchmarks
cargo bench --bench pool_performance

# Check saturation behavior
open target/criterion/pool_saturation_recovery/report/index.html
```

## Environment Setup

### Automatic (Testcontainers)

No setup needed! Benchmarks automatically:
1. Download PostgreSQL container (first time only)
2. Start container
3. Run migrations
4. Execute benchmarks

```bash
cargo bench
```

### Manual (Existing Database)

For faster iteration:

```bash
# Start PostgreSQL
docker run -d \
  --name llm-bench-postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=llm_observatory_bench \
  -p 5432:5432 \
  postgres:16-alpine

# Set database URL
export DATABASE_URL="postgres://postgres:password@localhost:5432/llm_observatory_bench"

# Run benchmarks
cargo bench
```

## Performance Tuning

### Quick Wins

1. **Use COPY protocol for bulk writes** (10-100x faster)
   ```rust
   CopyWriter::write_spans(&client, spans).await?;
   ```

2. **Optimize batch sizes**
   - Traces: 500-2000
   - Spans: 1000-5000
   - Logs: 2000-10000

3. **Tune connection pool**
   - max_connections: 2-3x CPU cores
   - min_connections: 25% of max

4. **Limit concurrent writers**
   - Start with 2-4
   - Scale up to 2x CPU cores

### PostgreSQL Configuration

```sql
-- For production (8GB RAM, SSD, 4 cores)
shared_buffers = '2GB'
effective_cache_size = '6GB'
work_mem = '64MB'
maintenance_work_mem = '512MB'
checkpoint_timeout = '15min'
max_wal_size = '4GB'
random_page_cost = 1.1
```

See [PERFORMANCE_TUNING.md](benches/PERFORMANCE_TUNING.md) for detailed guide.

## Troubleshooting

### "Docker not found"

Install Docker Desktop or Docker Engine, then start the daemon.

### "Connection refused"

```bash
# Check Docker is running
docker ps

# Or use existing database
export DATABASE_URL="postgres://postgres:password@localhost/llm_observatory_bench"
```

### Benchmarks too slow

```bash
# Reduce sample size
cargo bench -- --sample-size 10

# Use existing database (faster startup)
export DATABASE_URL="postgres://..."

# Run specific benchmarks only
cargo bench --bench writer_throughput
```

### High variance in results

- Close other applications
- Run multiple times: `cargo bench -- --rerun`
- Check system resources (CPU, memory, disk)

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
- name: Run benchmarks
  run: |
    # Run with smaller sample size for CI
    cargo bench -- --sample-size 10 --save-baseline ci-${{ github.sha }}

    # Check for regressions
    cargo bench -- --sample-size 10 --baseline main

- name: Upload results
  uses: actions/upload-artifact@v3
  with:
    name: benchmark-results
    path: target/criterion/
```

## Architecture

```
benches/
├── README.md                    # Comprehensive documentation (580 lines)
├── QUICKSTART.md               # 5-minute setup guide (190 lines)
├── PERFORMANCE_TUNING.md       # Optimization guide (480 lines)
├── BENCHMARK_SUMMARY.md        # Implementation details (350 lines)
├── common/
│   └── mod.rs                  # Shared utilities (280 lines)
├── writer_throughput.rs        # Write performance (240 lines)
├── query_performance.rs        # Read latency (360 lines)
├── pool_performance.rs         # Connection pool (210 lines)
├── concurrent_writes.rs        # Concurrent writes (330 lines)
├── mixed_workload.rs          # Production scenarios (310 lines)
└── copy_vs_insert.rs          # Protocol comparison (304 lines)
```

**Total:** ~3,320 lines of benchmarks and documentation

## Key Features

- ✅ **Comprehensive**: Covers all storage operations
- ✅ **Realistic**: Production-like workload patterns
- ✅ **Statistical**: Rigorous analysis with Criterion.rs
- ✅ **Automated**: Testcontainers for isolation
- ✅ **Documented**: 1,300+ lines of guides
- ✅ **CI-friendly**: Fast sample sizes, baseline tracking
- ✅ **Actionable**: Clear performance targets and tuning

## Contributing

When adding benchmarks:

1. Add to appropriate file or create new one
2. Update `Cargo.toml` with `[[bench]]` entry
3. Use common test data generators
4. Document expected performance
5. Add to this README

## Resources

- [Criterion.rs Book](https://bheisler.github.io/criterion.rs/book/)
- [PostgreSQL Performance](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Benchmarks Documentation](benches/README.md)
- [Quick Start Guide](benches/QUICKSTART.md)
- [Performance Tuning](benches/PERFORMANCE_TUNING.md)

## License

See repository root for license information.

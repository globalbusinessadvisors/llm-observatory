# Benchmark Quick Start Guide

Get up and running with storage benchmarks in 5 minutes.

## Prerequisites

- Rust toolchain (1.75+)
- Docker (for testcontainers)
- ~2GB free disk space
- ~4GB free memory

## Option 1: Automatic (Testcontainers)

The easiest way - automatically manages PostgreSQL container:

```bash
# Navigate to storage crate
cd crates/storage

# Run all benchmarks (takes ~10-15 minutes)
cargo bench

# Run specific benchmark (takes ~2-3 minutes)
cargo bench --bench writer_throughput
```

That's it! Criterion will:
1. Download PostgreSQL container (first time only)
2. Start container
3. Run migrations
4. Execute benchmarks
5. Generate HTML reports

## Option 2: Manual Setup (Faster)

Use an existing PostgreSQL instance for faster iteration:

```bash
# 1. Start PostgreSQL (if not already running)
docker run -d \
  --name llm-bench-postgres \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=llm_observatory_bench \
  -p 5432:5432 \
  postgres:16-alpine

# 2. Set database URL
export DATABASE_URL="postgres://postgres:password@localhost:5432/llm_observatory_bench"

# 3. Run migrations (first time only)
sqlx migrate run

# 4. Run benchmarks
cargo bench --bench writer_throughput
```

## Viewing Results

After running benchmarks:

```bash
# View HTML report
open target/criterion/report/index.html

# Or on Linux
xdg-open target/criterion/report/index.html

# Or use a web server
cd target/criterion
python3 -m http.server 8000
# Visit http://localhost:8000/report/
```

## Common Commands

```bash
# Run single benchmark suite
cargo bench --bench writer_throughput
cargo bench --bench query_performance
cargo bench --bench pool_performance
cargo bench --bench concurrent_writes
cargo bench --bench mixed_workload
cargo bench --bench copy_vs_insert

# Run specific test within suite
cargo bench --bench writer_throughput -- trace_writer_copy
cargo bench --bench query_performance -- trace_get_by_id

# Faster iteration (fewer samples)
cargo bench --bench writer_throughput -- --sample-size 10

# Save baseline for comparison
cargo bench --bench writer_throughput -- --save-baseline main

# Compare with baseline
cargo bench --bench writer_throughput -- --baseline main
```

## Quick Performance Check

Want to quickly verify performance? Run this:

```bash
# ~2 minute quick check
cargo bench --bench writer_throughput -- --sample-size 10 trace_writer_copy/1000

# Expected output (on modern hardware):
# trace_writer_copy/1000  time:   [~15 ms ... ~17 ms]
#                         thrpt:  [~58000 elem/s ... ~66000 elem/s]
#
# This means: ~60,000 traces/second write throughput ✓
```

## Troubleshooting

### "Docker not found"
```bash
# Install Docker Desktop or Docker Engine
# macOS: brew install --cask docker
# Ubuntu: sudo apt-get install docker.io
# Then start Docker daemon
```

### "Connection refused"
```bash
# Check Docker is running
docker ps

# Or use manual setup with existing database
export DATABASE_URL="postgres://postgres:password@localhost:5432/llm_observatory_bench"
```

### "Migration failed"
```bash
# Ensure migrations directory exists
ls migrations/

# Try manual migration
sqlx migrate run --database-url $DATABASE_URL
```

### Benchmarks too slow
```bash
# Use existing database (skip container startup)
export DATABASE_URL="postgres://..."

# Reduce sample size
cargo bench -- --sample-size 10

# Run individual benchmarks instead of full suite
cargo bench --bench writer_throughput
```

## What to Expect

Typical benchmark durations:

| Benchmark | Sample Size 100 | Sample Size 10 |
|-----------|----------------|----------------|
| writer_throughput | ~10 min | ~2 min |
| query_performance | ~8 min | ~2 min |
| pool_performance | ~6 min | ~1.5 min |
| concurrent_writes | ~12 min | ~3 min |
| mixed_workload | ~10 min | ~2.5 min |
| copy_vs_insert | ~8 min | ~2 min |

**Full suite:** ~50-60 minutes (sample size 100), ~15-20 minutes (sample size 10)

## Performance Targets

You should see approximately:

- **Write throughput:** 50,000-100,000 spans/sec (COPY protocol)
- **Query latency:** 1-5ms for simple lookups
- **List queries:** 10-50ms for 100 records
- **Connection acquisition:** <1ms
- **Concurrent scaling:** ~2-4x speedup with 4 workers

Results vary based on hardware, but modern machines should achieve these targets.

## Next Steps

1. **Run full suite:** `cargo bench`
2. **View reports:** Check `target/criterion/report/index.html`
3. **Read detailed docs:** See [README.md](./README.md)
4. **Optimize:** Review [Performance Tuning](./README.md#performance-tuning-recommendations)

## Need Help?

- Check [README.md](./README.md) for detailed documentation
- Review [Troubleshooting](./README.md#troubleshooting) section
- Check existing GitHub issues
- File a new issue with benchmark output

Happy benchmarking! 🚀

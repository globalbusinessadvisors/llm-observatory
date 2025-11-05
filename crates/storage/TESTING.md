# Storage Layer Testing Guide

Quick reference for running and understanding storage layer tests.

## Quick Start

```bash
# Ensure Docker is running
docker ps

# Run all integration tests
cd crates/storage
cargo test --test integration_*

# Run with output
cargo test --test integration_* -- --nocapture
```

## Test Suites

### 1. Configuration Tests (28 tests)

Tests all aspects of configuration loading and validation.

```bash
cargo test --test integration_config_test
```

**Key Tests:**
- Configuration construction
- Environment variable parsing
- YAML file loading
- Validation rules
- SSL mode validation
- Retry policy calculations

### 2. Connection Pool Tests (16 tests)

Tests database connection pooling and lifecycle.

```bash
cargo test --test integration_pool_test
```

**Key Tests:**
- Pool creation and initialization
- Health checks (Postgres + Redis)
- Connection statistics
- Concurrent connections
- Transaction support
- Connection reuse

### 3. Writer Tests (24 tests)

Tests batch writing for traces, metrics, and logs.

```bash
cargo test --test integration_writer_test
```

**Key Tests:**
- Trace/Span/Event insertion
- Metric and data point insertion
- Log insertion with various severities
- Batch auto-flush
- Buffer statistics
- Concurrent writes
- Performance validation

## Test Architecture

### Directory Structure

```
tests/
├── common/              # Shared test utilities
│   ├── mod.rs          # Exports and setup helpers
│   ├── database.rs     # Testcontainers integration
│   └── fixtures.rs     # Test data generators
├── integration_config_test.rs   # 28 config tests
├── integration_pool_test.rs     # 16 pool tests
└── integration_writer_test.rs   # 24 writer tests
```

### Key Components

**TestDatabase** - Manages PostgreSQL containers using testcontainers
- Automatic startup and cleanup
- Isolated database per test suite
- No manual database setup required

**Fixtures** - Generate realistic test data
- Traces, spans, events
- Metrics and data points
- Logs with various severities

**Setup Helpers** - Common test setup
- `setup_test_pool()` - Get configured pool
- `cleanup_test_data()` - Clean between tests
- `run_test_migrations()` - Initialize schema

## Running Specific Tests

```bash
# Single test
cargo test --test integration_pool_test test_pool_creation

# Tests matching pattern
cargo test --test integration_writer_test trace_writer

# All trace writer tests
cargo test --test integration_writer_test test_trace_writer

# With detailed output
cargo test --test integration_config_test -- --nocapture

# Show test list without running
cargo test --test integration_* -- --list
```

## Test Isolation

Each test:
1. Gets a fresh PostgreSQL container (via testcontainers)
2. Runs migrations to create schema
3. Cleans up data before/after execution
4. Uses independent database connections

## Dependencies

### Required
- Docker (for testcontainers)
- Rust 1.75.0+

### Test Dependencies (already in Cargo.toml)
- `testcontainers = "0.23"` - Container management
- `tokio-test = "0.4"` - Async test utilities
- `tempfile = "3.12"` - Temporary file handling
- `once_cell = "1.19"` - Global test state

## Troubleshooting

### Docker Not Running
```
Error: Cannot connect to Docker daemon
```
**Fix:** Start Docker Desktop or docker daemon

### Port Conflicts
```
Error: Address already in use
```
**Fix:** Testcontainers handles port mapping automatically. If issues persist, check for other PostgreSQL instances.

### Timeout Errors
```
Error: Connection timeout
```
**Fix:**
- Increase `connect_timeout_secs` in test configs
- Check Docker resource limits
- Ensure sufficient system resources

### Slow Execution
**Fix:**
- Run with specific test threads: `cargo test -- --test-threads=4`
- Use cargo-nextest: `cargo install cargo-nextest && cargo nextest run`
- Run only changed tests during development

## Writing New Tests

### Example: Adding a Pool Test

```rust
#[tokio::test]
async fn test_my_pool_feature() {
    // Setup
    let (pool, _guard) = setup_test_pool().await;
    cleanup_test_data(&pool).await;

    // Execute
    let result = pool.some_operation().await;

    // Verify
    assert!(result.is_ok());
}
```

### Example: Adding a Writer Test

```rust
#[tokio::test]
async fn test_my_writer_feature() {
    let (pool, _guard) = setup_test_pool().await;
    cleanup_test_data(&pool).await;

    let writer = TraceWriter::new(pool.clone());
    let trace = create_test_trace("test-id", "test-service");

    writer.write_trace(trace).await.unwrap();
    writer.flush().await.unwrap();

    // Verify in database
    let count: (i64,) = sqlx::query_as(
        "SELECT COUNT(*) FROM traces WHERE trace_id = $1"
    )
    .bind("test-id")
    .fetch_one(pool.postgres())
    .await
    .unwrap();

    assert_eq!(count.0, 1);
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable

      - name: Run Integration Tests
        run: |
          cd crates/storage
          cargo test --test integration_*
```

### GitLab CI Example

```yaml
test:storage:
  image: rust:1.75
  services:
    - docker:dind
  script:
    - cd crates/storage
    - cargo test --test integration_*
```

## Performance Expectations

- **Configuration Tests**: <1 second (no database)
- **Pool Tests**: 2-5 seconds (container startup)
- **Writer Tests**: 5-10 seconds (includes data insertion)
- **Full Suite**: 10-20 seconds

## Test Coverage

Current coverage: **68 integration tests**

- Configuration: 28 tests (100% coverage of config module)
- Pool: 16 tests (100% coverage of pool operations)
- Writers: 24 tests (85% coverage of writer functionality)

## Best Practices

1. **Always clean up**: Use `cleanup_test_data()` before tests
2. **Use fixtures**: Don't hardcode test data, use generators
3. **Test isolation**: Each test should be independent
4. **Descriptive names**: Use clear test function names
5. **Fast tests**: Keep tests under 5 seconds when possible
6. **Error messages**: Include helpful assertion messages

## Advanced Usage

### Running Tests in Parallel

```bash
# Default (parallel)
cargo test --test integration_*

# Limit parallelism
cargo test --test integration_* -- --test-threads=2

# Sequential
cargo test --test integration_* -- --test-threads=1
```

### Filtering Tests

```bash
# Run only "health" tests
cargo test --test integration_* health

# Run tests with "validation" in name
cargo test --test integration_* validation

# Exclude certain tests
cargo test --test integration_* -- --skip concurrent
```

### Debug Output

```bash
# Show all output
cargo test --test integration_* -- --nocapture

# Show only failing test output
cargo test --test integration_*

# Verbose cargo output
cargo test --test integration_* --verbose
```

## Resources

- [Full Test Documentation](tests/README.md)
- [Storage Module Docs](src/lib.rs)
- [Testcontainers Docs](https://docs.rs/testcontainers)
- [Tokio Testing Guide](https://tokio.rs/tokio/topics/testing)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review test logs with `--nocapture`
3. Ensure Docker is running and healthy
4. Check Docker resource allocation
5. Open an issue if problem persists

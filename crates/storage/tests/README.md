# Storage Layer Integration Tests

This directory contains comprehensive integration tests for the LLM Observatory storage layer. The tests validate database connectivity, connection pooling, configuration management, and batch writing functionality for traces, metrics, and logs.

## Test Structure

```
tests/
├── common/
│   ├── mod.rs           # Common utilities and re-exports
│   ├── database.rs      # Test database setup using testcontainers
│   └── fixtures.rs      # Test data generators and factories
├── integration_config_test.rs    # Configuration tests (28 tests)
├── integration_pool_test.rs      # Connection pool tests (16 tests)
└── integration_writer_test.rs    # Writer tests (24 tests)
```

## Total Test Count: 68 Integration Tests

- **Configuration Tests**: 28 tests
- **Connection Pool Tests**: 16 tests
- **Writer Tests**: 24 tests

## Test Infrastructure

### Test Database Setup

Tests use **testcontainers** to provide isolated PostgreSQL databases:

- Each test suite gets a fresh PostgreSQL 16 container
- Automatic schema creation with all required tables
- Proper cleanup after test completion
- No external database dependencies required

### Common Utilities

#### Database Module (`common/database.rs`)

- `TestDatabase`: Manages PostgreSQL containers
- `TestDatabaseGuard`: Ensures container lifecycle
- Automatic port mapping and connection URL generation

#### Fixtures Module (`common/fixtures.rs`)

Provides factory functions for creating test data:

- `create_test_trace()` - Create individual traces
- `create_test_traces()` - Create multiple traces
- `create_test_span()` - Create trace spans
- `create_test_metric()` - Create metrics
- `create_test_metric_data_point()` - Create metric data points
- `create_histogram_data_point()` - Create histogram data
- `create_test_log()` - Create log records
- `create_test_logs()` - Create multiple logs
- `TraceBuilder` - Builder pattern for complex trace scenarios

#### Shared Utilities (`common/mod.rs`)

- `setup_test_pool()` - Create and initialize a test pool
- `run_test_migrations()` - Run database migrations
- `cleanup_test_data()` - Clean up test data between tests
- `config_from_url()` - Parse database URLs into configs

## Running Tests

### Prerequisites

- Docker installed and running (for testcontainers)
- Rust 1.75.0 or later

### Run All Integration Tests

```bash
cd crates/storage
cargo test --test integration_*
```

### Run Specific Test Suites

```bash
# Configuration tests only
cargo test --test integration_config_test

# Pool tests only
cargo test --test integration_pool_test

# Writer tests only
cargo test --test integration_writer_test
```

### Run Individual Tests

```bash
# Run a specific test
cargo test --test integration_pool_test test_pool_creation

# Run tests matching a pattern
cargo test --test integration_writer_test trace_writer
```

### Run with Output

```bash
# Show test output
cargo test --test integration_* -- --nocapture

# Show test names
cargo test --test integration_* -- --list
```

## Test Coverage

### Configuration Tests (28 tests)

Tests for `StorageConfig`, `PostgresConfig`, `RedisConfig`, `PoolConfig`, and `RetryConfig`:

- ✅ Configuration construction and defaults
- ✅ PostgreSQL URL generation
- ✅ Redis configuration
- ✅ Pool configuration validation
- ✅ Retry policy validation
- ✅ SSL mode validation
- ✅ Configuration validation (all fields)
- ✅ YAML file loading
- ✅ Duration conversions
- ✅ Retry delay calculations
- ✅ Error handling for invalid configurations

### Connection Pool Tests (16 tests)

Tests for `StoragePool` and connection management:

- ✅ Pool creation and initialization
- ✅ PostgreSQL health checks
- ✅ Full health check (Postgres + Redis)
- ✅ Pool statistics and metrics
- ✅ Connection utilization tracking
- ✅ Concurrent connection handling
- ✅ Query execution
- ✅ Connection reuse verification
- ✅ Transaction support
- ✅ Transaction rollback
- ✅ Prepared statement usage
- ✅ Pool isolation between tests

### Writer Tests (24 tests)

Tests for `TraceWriter`, `MetricWriter`, and `LogWriter`:

#### Trace Writer (9 tests)
- ✅ Single trace insertion
- ✅ Multiple trace insertion
- ✅ Batch auto-flush
- ✅ Span insertion
- ✅ Multiple spans insertion
- ✅ Event insertion
- ✅ Write statistics tracking
- ✅ Duplicate trace handling (upsert)
- ✅ Buffer statistics

#### Metric Writer (7 tests)
- ✅ Single metric insertion
- ✅ Multiple metrics insertion
- ✅ Data point insertion
- ✅ Multiple data points insertion
- ✅ Histogram data point insertion
- ✅ Buffer statistics
- ✅ Metric upsert functionality

#### Log Writer (6 tests)
- ✅ Single log insertion
- ✅ Multiple logs insertion
- ✅ Different severity levels
- ✅ Logs with trace context
- ✅ Buffer statistics
- ✅ Batch auto-flush
- ✅ Custom attributes

#### Performance Tests (2 tests)
- ✅ Concurrent writes
- ✅ Large batch performance

## Test Design Principles

### Isolation

- Each test runs with a fresh database state
- Tests use `cleanup_test_data()` to ensure no data pollution
- Testcontainers provide process-level isolation

### Repeatability

- Tests use deterministic data generators
- No reliance on external state or timing
- Idempotent test operations

### Error Messages

- Clear assertion messages
- Descriptive test names
- Detailed failure output

### Performance

- Tests complete in reasonable time (<5 seconds for large batches)
- Parallel test execution supported
- Minimal container startup overhead (reused when possible)

## Common Test Patterns

### Basic Test Pattern

```rust
#[tokio::test]
async fn test_something() {
    // Setup: Get a test pool and database
    let (pool, _guard) = setup_test_pool().await;
    cleanup_test_data(&pool).await;

    // Test: Perform operations
    let result = operation(&pool).await;

    // Verify: Check results
    assert!(result.is_ok());
}
```

### Writer Test Pattern

```rust
#[tokio::test]
async fn test_writer_operation() {
    let (pool, _guard) = setup_test_pool().await;
    cleanup_test_data(&pool).await;

    let writer = TraceWriter::new(pool.clone());
    let trace = create_test_trace("trace-id", "service");

    writer.write_trace(trace).await.unwrap();
    writer.flush().await.unwrap();

    // Verify data was written
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM traces")
        .fetch_one(pool.postgres())
        .await
        .unwrap();

    assert_eq!(count.0, 1);
}
```

## Troubleshooting

### Tests Fail to Start

**Problem**: Docker not running or testcontainers can't start
```
Error: Failed to create test database
```

**Solution**: Ensure Docker is running:
```bash
docker ps
```

### Port Conflicts

**Problem**: Port already in use
```
Error: Address already in use
```

**Solution**: Testcontainers automatically finds available ports. If issues persist, stop other PostgreSQL instances.

### Slow Test Execution

**Problem**: Tests take a long time

**Solution**:
- Run tests in parallel: `cargo test --test integration_* -- --test-threads=4`
- Use cargo nextest for faster test execution: `cargo nextest run`

### Connection Timeouts

**Problem**: Tests timeout connecting to database

**Solution**:
- Increase timeout in `PoolConfig::connect_timeout_secs`
- Check Docker resource allocation
- Verify network connectivity

## Contributing

When adding new tests:

1. Place them in the appropriate test file based on the component being tested
2. Use the common fixtures and utilities from the `common` module
3. Ensure tests clean up after themselves
4. Add descriptive test names that explain what is being tested
5. Update this README with new test categories if needed

## CI/CD Integration

These tests are designed to run in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run Integration Tests
  run: |
    cargo test --package llm-observatory-storage --test integration_*
```

## Performance Benchmarks

The test suite includes performance validation:

- Single trace write: <10ms
- Batch of 100 traces: <5 seconds
- Concurrent writes (10 tasks): <2 seconds

## Future Enhancements

Planned improvements:

- [ ] Redis integration tests
- [ ] Migration testing
- [ ] Backup/restore testing
- [ ] Performance regression tests
- [ ] Query optimization tests
- [ ] Failure recovery tests
- [ ] Distributed transaction tests

## License

Apache 2.0 - See LICENSE file for details

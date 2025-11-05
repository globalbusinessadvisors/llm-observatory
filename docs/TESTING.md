# Testing Guide

Complete guide to testing LLM Observatory using the Docker-based testing infrastructure.

## Table of Contents

- [Quick Start](#quick-start)
- [Test Types](#test-types)
- [Running Tests](#running-tests)
- [Coverage](#coverage)
- [CI/CD](#cicd)
- [Test Data](#test-data)
- [Configuration](#configuration)
- [Best Practices](#best-practices)

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Rust 1.75.0 or later
- cargo-nextest (optional, for local testing)

### Run All Tests (Docker)

```bash
# One-command test execution
make test-docker

# Or using docker compose directly
docker compose -f docker/compose/docker-compose.test.yml run --rm test-runner
```

### Run Tests Locally

```bash
# Install test tools
cargo install cargo-nextest cargo-tarpaulin

# Start test databases
make start-test-db

# Run all tests
make test-all

# Or run specific types
make test-unit          # Unit tests only
make test-integration   # Integration tests
make test-coverage      # With coverage
```

## Test Types

### Unit Tests

Fast tests with no external dependencies.

**Characteristics:**
- No database or Redis required
- Test pure functions and business logic
- Run in milliseconds
- Part of every commit

**Run:**
```bash
# Using Make
make test-unit

# Using cargo-nextest
cargo nextest run --workspace --lib --all-features

# Using Docker
docker compose -f docker/compose/docker-compose.test.yml --profile unit-test up
```

### Integration Tests

Tests requiring real services (database, Redis).

**Characteristics:**
- Full database and Redis instances
- Test API endpoints, storage layer
- Realistic data scenarios
- Run in seconds to minutes

**Run:**
```bash
# Using Make
make test-integration

# Using helper script
./docker/test/run-specific-tests.sh --test-type integration

# Using Docker
docker compose -f docker/compose/docker-compose.test.yml --profile integration-test up
```

### End-to-End Tests

Full system tests simulating real workflows.

**Characteristics:**
- All services running
- Real network calls
- Complete trace workflows
- Run in minutes

**Run:**
```bash
# Using Docker compose
docker compose -f docker/compose/docker-compose.test.yml --profile test up
```

### Benchmark Tests

Performance benchmarks for critical paths.

**Characteristics:**
- Measure performance metrics
- Identify regressions
- Generate detailed reports
- Run on-demand

**Run:**
```bash
# Using Docker
docker compose -f docker/compose/docker-compose.test.yml --profile benchmark up

# Using cargo
cargo bench --workspace
```

## Running Tests

### Using Make (Recommended)

```bash
# Show all available commands
make help

# Common test commands
make test-all           # Comprehensive test suite
make test-unit          # Unit tests only
make test-integration   # Integration tests
make test-coverage      # Generate coverage
make test-docker        # Run in Docker
make test-parallel      # Parallel execution

# Database operations
make start-test-db      # Start test databases
make stop-test-db       # Stop test databases
make seed-test-data     # Populate with fixtures

# CI simulation
make ci-test            # Run CI test pipeline
make ci-coverage        # Run CI coverage pipeline

# Cleanup
make clean-test         # Remove test artifacts
```

### Using Helper Scripts

```bash
# Run all tests with full reporting
./docker/test/run-all-tests.sh

# Run specific tests
./docker/test/run-specific-tests.sh --help

# Examples:
./docker/test/run-specific-tests.sh --package llm-observatory-core
./docker/test/run-specific-tests.sh --filter database
./docker/test/run-specific-tests.sh --exact test_connection
./docker/test/run-specific-tests.sh --list

# Generate coverage
./docker/test/run-coverage.sh

# With custom configuration
COVERAGE_FORMAT="html,lcov,json" MIN_COVERAGE=80 ./docker/test/run-coverage.sh

# Seed test data
./docker/test/seed-test-data.sh

# Different sizes
SEED_DATA_SIZE=minimal ./docker/test/seed-test-data.sh
SEED_DATA_SIZE=medium ./docker/test/seed-test-data.sh
SEED_DATA_SIZE=large ./docker/test/seed-test-data.sh
```

### Using Docker Compose Directly

```bash
# Start test environment
docker compose -f docker/compose/docker-compose.test.yml up -d timescaledb-test redis-test

# Run specific test profiles
docker compose -f docker/compose/docker-compose.test.yml --profile unit-test up
docker compose -f docker/compose/docker-compose.test.yml --profile integration-test up
docker compose -f docker/compose/docker-compose.test.yml --profile coverage up

# Run and remove
docker compose -f docker/compose/docker-compose.test.yml run --rm test-runner

# Cleanup
docker compose -f docker/compose/docker-compose.test.yml down -v
```

### Using cargo-nextest

```bash
# Install
cargo install cargo-nextest

# Run all tests
cargo nextest run --workspace --all-features

# Run with specific profile
cargo nextest run --profile ci
cargo nextest run --profile fast

# Run specific package
cargo nextest run --package llm-observatory-core

# Run tests matching pattern
cargo nextest run --filter database

# List all tests
cargo nextest list --workspace

# Parallel execution with sharding
cargo nextest run --partition hash:0/4  # Shard 1 of 4
cargo nextest run --partition hash:1/4  # Shard 2 of 4
```

## Coverage

### Generate Coverage Reports

```bash
# Using Make (recommended)
make test-coverage

# Using script
./docker/test/run-coverage.sh

# Using Docker
docker compose -f docker/compose/docker-compose.test.yml --profile coverage up

# Using tarpaulin directly
cargo tarpaulin \
  --workspace \
  --all-features \
  --engine llvm \
  --out Html \
  --out Lcov \
  --output-dir coverage
```

### Coverage Formats

Multiple output formats are supported:

- **HTML**: Interactive web report (`coverage/index.html`)
- **LCOV**: For CI integration (`coverage/lcov.info`)
- **JSON**: Machine-readable (`coverage/coverage.json`)
- **XML**: Cobertura format (`coverage/cobertura.xml`)

```bash
# Specify formats
COVERAGE_FORMAT="html,lcov,json,xml" ./docker/test/run-coverage.sh
```

### Coverage Thresholds

Set minimum coverage requirements:

```bash
# Fail if coverage < 80%
MIN_COVERAGE=80 ./docker/test/run-coverage.sh
```

### View Coverage Reports

```bash
# Open HTML report
open coverage/index.html

# Or on Linux
xdg-open coverage/index.html

# View summary
cat coverage/summary.json
```

## CI/CD

### GitHub Actions

See `.github/workflows/test.yml` for the complete workflow.

**Features:**
- Matrix testing (multiple OS/Rust versions)
- Parallel test shards
- Coverage with Codecov integration
- Security audits
- Test result aggregation

**Trigger manually:**
```bash
gh workflow run test.yml -f coverage=true
```

### GitLab CI

See `.ci/.gitlab-ci.yml` for the complete pipeline.

**Stages:**
1. Prepare - Build images, cache dependencies
2. Validate - Format, clippy, docs, security
3. Test - Unit, integration, parallel tests
4. Coverage - Generate coverage reports
5. Report - Aggregate and publish results

**Run locally:**
```bash
# Simulate CI locally
make ci-test
make ci-coverage
```

### Environment Variables

```bash
# Test configuration
export DATABASE_URL="postgres://test_user:test_password@localhost:5433/llm_observatory_test"
export REDIS_URL="redis://:test_redis@localhost:6380"
export RUST_BACKTRACE=1
export RUST_LOG=info
export TEST_THREADS=4
export NEXTEST_PROFILE=ci

# Coverage
export COVERAGE_OUTPUT_DIR=./coverage
export COVERAGE_FORMAT=html,lcov
export MIN_COVERAGE=70

# CI flags
export CI=true
export GITHUB_ACTIONS=true
```

## Test Data

### Fixtures

Located in `docker/test/fixtures/`:

- **users.json** - Test users with different roles
- **projects.json** - Projects with various configurations
- **api_keys.json** - API keys with different permissions
- **llm_models.json** - LLM model configurations
- **sample_traces.json** - Sample trace data

### Database Schema

Initialized from `docker/test/init/01-test-schema.sql`:

- Complete schema with TimescaleDB
- Hypertables for time-series data
- Continuous aggregates
- Test-specific users and permissions

### Seeding Data

```bash
# Default (small dataset)
make seed-test-data

# Different sizes
SEED_DATA_SIZE=minimal make seed-test-data  # 10 traces
SEED_DATA_SIZE=small make seed-test-data    # 100 traces
SEED_DATA_SIZE=medium make seed-test-data   # 1000 traces
SEED_DATA_SIZE=large make seed-test-data    # 10000 traces
```

### Test Data Characteristics

- **Realistic distribution**: Multiple models and providers
- **Time-based**: Data spread across last 7 days
- **Error scenarios**: ~5% error rate
- **Proper relationships**: Traces → Spans → Events
- **Token usage**: Realistic token counts
- **Cost data**: Based on actual pricing

## Configuration

### Nextest Configuration

See `docker/test/.config/nextest.toml`.

**Profiles:**
- `default` - Standard local testing
- `ci` - CI-optimized (no retries, verbose)
- `fast` - Quick tests only
- `integration` - Longer timeouts for integration
- `debug` - No timeouts, verbose output

**Usage:**
```bash
cargo nextest run --profile ci
cargo nextest run --profile fast
```

### Docker Configuration

**Test Database (TimescaleDB):**
- Port: 5433
- User: test_user
- Password: test_password
- Database: llm_observatory_test
- Storage: tmpfs (in-memory for speed)
- Optimizations: fsync=off, no WAL

**Test Redis:**
- Port: 6380
- Password: test_redis
- Storage: tmpfs (no persistence)
- Max memory: 128MB

### Environment Files

Create `.env.test` for local overrides:

```bash
# .env.test
TEST_DB_PORT=5433
TEST_REDIS_PORT=6380
RUST_LOG=debug
TEST_THREADS=8
```

## Best Practices

### Writing Tests

1. **Name tests descriptively:**
   ```rust
   #[test]
   fn test_user_authentication_with_valid_credentials() {
       // Clear what's being tested
   }
   ```

2. **Follow AAA pattern:**
   ```rust
   #[test]
   fn test_example() {
       // Arrange
       let input = setup_test_data();

       // Act
       let result = function_under_test(input);

       // Assert
       assert_eq!(result, expected);
   }
   ```

3. **Test one behavior per test:**
   ```rust
   // Good
   #[test]
   fn test_valid_email_accepted() { }

   #[test]
   fn test_invalid_email_rejected() { }

   // Bad
   #[test]
   fn test_email_validation() {
       // Tests both valid and invalid cases
   }
   ```

4. **Use fixtures and helpers:**
   ```rust
   #[fixture]
   fn sample_user() -> User {
       User::new("test@example.com")
   }

   #[test]
   fn test_with_fixture(sample_user: User) {
       assert!(sample_user.is_valid());
   }
   ```

5. **Clean up resources:**
   ```rust
   #[tokio::test]
   async fn test_database_operations() {
       let db = setup_test_db().await;

       // Test code

       cleanup_test_db(db).await; // Always cleanup
   }
   ```

### Test Organization

```rust
#[cfg(test)]
mod tests {
    use super::*;

    mod unit {
        use super::*;

        #[test]
        fn test_fast_logic() { }
    }

    #[cfg(feature = "integration-tests")]
    mod integration {
        use super::*;

        #[tokio::test]
        async fn test_with_database() { }
    }
}
```

### Performance

1. **Use in-memory databases** (tmpfs)
2. **Disable durability** in tests (fsync=off)
3. **Run tests in parallel** (cargo-nextest)
4. **Cache dependencies** (Docker layers, cargo cache)
5. **Filter tests** during development

### Debugging

```bash
# Run with backtrace
RUST_BACKTRACE=full cargo test

# Run single test
cargo test test_name -- --exact

# Show test output
cargo test -- --nocapture

# Debug profile
cargo nextest run --profile debug

# Verbose output
cargo nextest run --verbose
```

## Troubleshooting

### Common Issues

**Tests hanging:**
```bash
# Check database connection
docker compose -f docker/compose/docker-compose.test.yml exec timescaledb-test pg_isready

# Increase timeouts
TARPAULIN_TIMEOUT=1200 ./docker/test/run-coverage.sh
```

**Port conflicts:**
```bash
# Change test ports
TEST_DB_PORT=15433 TEST_REDIS_PORT=16380 make start-test-db
```

**Out of disk space:**
```bash
# Use tmpfs for test data
# Already configured in docker/compose/docker-compose.test.yml

# Clean up
make clean-test
docker system prune -af
```

**Flaky tests:**
```bash
# Retry failed tests
cargo nextest run --profile ci --retries 3

# Run specific test multiple times
cargo nextest run --test-threads 1 test_name
```

### Getting Help

1. Check logs: `docker compose -f docker/compose/docker-compose.test.yml logs`
2. Review test output in `test-results/`
3. Check coverage reports in `coverage/`
4. See detailed docs in `docker/test/README.md`

## Additional Resources

- [cargo-nextest docs](https://nexte.st/)
- [Tarpaulin docs](https://github.com/xd009642/tarpaulin)
- [TimescaleDB docs](https://docs.timescale.com/)
- [Docker Testing Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## License

Apache-2.0 - See LICENSE for details

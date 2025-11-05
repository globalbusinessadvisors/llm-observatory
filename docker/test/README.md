# LLM Observatory - Docker Testing Infrastructure

Comprehensive testing infrastructure for LLM Observatory using Docker, optimized for local development, CI/CD, and automated testing.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Test Types](#test-types)
- [Usage](#usage)
- [CI/CD Integration](#cicd-integration)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## Overview

This testing infrastructure provides:

- **Isolated Test Environment**: In-memory databases with tmpfs for speed
- **Parallel Test Execution**: Run tests in parallel shards for faster feedback
- **Code Coverage**: Multiple coverage tools (tarpaulin, llvm-cov)
- **Multiple Test Types**: Unit, integration, e2e, benchmarks
- **CI/CD Ready**: GitHub Actions and GitLab CI configurations
- **Test Data Management**: Fixtures and seeders for realistic test data

## Quick Start

### Run All Tests

```bash
# Start test environment and run all tests
docker compose -f docker/compose/docker-compose.test.yml up --build test-runner

# View test results
docker compose -f docker/compose/docker-compose.test.yml cp test-runner:/workspace/test-results ./test-results
```

### Run Specific Test Types

```bash
# Unit tests only (fast, no dependencies)
docker compose -f docker/compose/docker-compose.test.yml --profile unit-test up --build

# Integration tests (with database and Redis)
docker compose -f docker/compose/docker-compose.test.yml --profile integration-test up --build

# Coverage report
docker compose -f docker/compose/docker-compose.test.yml --profile coverage up --build
```

### Run Tests Locally

```bash
# Install test dependencies
cargo install cargo-nextest cargo-tarpaulin

# Start test databases
docker compose -f docker/compose/docker-compose.test.yml up -d timescaledb-test redis-test

# Run tests
export DATABASE_URL="postgres://test_user:test_password@localhost:5433/llm_observatory_test"
export REDIS_URL="redis://:test_redis@localhost:6380"
cargo nextest run --workspace --all-features

# Generate coverage
cargo tarpaulin --workspace --all-features --out Html --out Lcov
```

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     Test Infrastructure                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  TimescaleDB │  │    Redis     │  │ Test Runner  │         │
│  │   (tmpfs)    │  │   (tmpfs)    │  │   Container  │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│         │                 │                   │                 │
│         └─────────────────┴───────────────────┘                 │
│                          │                                      │
│                 ┌────────┴────────┐                             │
│                 │                 │                             │
│         ┌───────▼──────┐  ┌──────▼────────┐                    │
│         │  Unit Tests  │  │  Integration  │                    │
│         │   (Nextest)  │  │     Tests     │                    │
│         └──────────────┘  └───────────────┘                    │
│                 │                 │                             │
│                 └────────┬────────┘                             │
│                          │                                      │
│                 ┌────────▼────────┐                             │
│                 │  Coverage Tool  │                             │
│                 │   (Tarpaulin)   │                             │
│                 └─────────────────┘                             │
│                          │                                      │
│                 ┌────────▼────────┐                             │
│                 │  Test Reports   │                             │
│                 │  HTML/LCOV/JSON │                             │
│                 └─────────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

### Docker Services

- **timescaledb-test**: PostgreSQL with TimescaleDB, optimized for tests (tmpfs, no fsync)
- **redis-test**: Redis with no persistence, in-memory only
- **test-runner**: Main test execution container with all tools
- **coverage-runner**: Specialized container for coverage generation
- **parallel-test-runner**: Sharded test execution for parallelization
- **test-seeder**: Database seeding with test fixtures

## Test Types

### Unit Tests

Fast tests with no external dependencies.

```bash
# Using Docker
docker compose -f docker/compose/docker-compose.test.yml --profile unit-test up

# Using cargo-nextest
cargo nextest run --workspace --lib --all-features

# Using helper script
./docker/test/run-specific-tests.sh --test-type unit
```

### Integration Tests

Tests requiring database and Redis.

```bash
# Using Docker
docker compose -f docker/compose/docker-compose.test.yml --profile integration-test up

# Using cargo-nextest
export DATABASE_URL="postgres://test_user:test_password@localhost:5433/llm_observatory_test"
export REDIS_URL="redis://:test_redis@localhost:6380"
cargo nextest run --workspace --test '*' --all-features

# Using helper script
./docker/test/run-specific-tests.sh --test-type integration
```

### Parallel Tests

Run tests in parallel shards for faster execution.

```bash
# Run 4 parallel shards
for i in {0..3}; do
  SHARD_INDEX=$i SHARD_TOTAL=4 \
  docker compose -f docker/compose/docker-compose.test.yml --profile parallel-test up -d
done

# Or use matrix in CI/CD (see .github/workflows/test.yml)
```

### Coverage Tests

Generate code coverage reports.

```bash
# Using Docker
docker compose -f docker/compose/docker-compose.test.yml --profile coverage up

# Using tarpaulin
cargo tarpaulin \
  --workspace \
  --all-features \
  --engine llvm \
  --out Html \
  --out Lcov \
  --output-dir coverage

# Using helper script
./docker/test/run-coverage.sh
```

### Benchmarks

Performance benchmarks (requires nightly Rust).

```bash
# Using Docker
docker compose -f docker/compose/docker-compose.test.yml --profile benchmark up

# Using cargo bench
cargo bench --workspace
```

## Usage

### Helper Scripts

#### run-all-tests.sh

Comprehensive test suite with all checks.

```bash
./docker/test/run-all-tests.sh

# With custom configuration
NEXTEST_PROFILE=ci TEST_THREADS=8 ./docker/test/run-all-tests.sh
```

Features:
- Clippy linting
- Format checking
- Unit tests
- Integration tests
- Documentation tests
- Security audit
- Test summary report

#### run-specific-tests.sh

Run specific tests or test suites.

```bash
# Run tests in specific package
./docker/test/run-specific-tests.sh --package llm-observatory-core

# Run tests matching pattern
./docker/test/run-specific-tests.sh --filter database

# Run specific test
./docker/test/run-specific-tests.sh --exact test_connection

# List all tests
./docker/test/run-specific-tests.sh --list

# Show help
./docker/test/run-specific-tests.sh --help
```

#### run-coverage.sh

Generate coverage reports with configurable formats.

```bash
# Default (HTML and LCOV)
./docker/test/run-coverage.sh

# Custom formats
COVERAGE_FORMAT="html,lcov,json,xml" ./docker/test/run-coverage.sh

# Set minimum coverage threshold
MIN_COVERAGE=80 ./docker/test/run-coverage.sh
```

#### seed-test-data.sh

Populate database with test fixtures.

```bash
# Default (small dataset)
./docker/test/seed-test-data.sh

# Specific size
SEED_DATA_SIZE=medium ./docker/test/seed-test-data.sh

# Available sizes: minimal, small, medium, large
```

### Environment Variables

#### Test Configuration

```bash
# Database
DATABASE_URL="postgres://test_user:test_password@localhost:5433/llm_observatory_test"
TEST_DATABASE_URL="postgres://test_user:test_password@localhost:5433/llm_observatory_test"

# Redis
REDIS_URL="redis://:test_redis@localhost:6380"
TEST_REDIS_URL="redis://:test_redis@localhost:6380"

# Test execution
RUST_BACKTRACE=1              # Enable backtraces
RUST_LOG=info                 # Log level
TEST_THREADS=4                # Number of test threads
NEXTEST_PROFILE=ci            # Nextest profile (default, ci, fast, debug)

# Coverage
COVERAGE_OUTPUT_DIR=./coverage
COVERAGE_FORMAT=html,lcov
TARPAULIN_TIMEOUT=600
MIN_COVERAGE=70

# Seeding
SEED_DATA_SIZE=small          # minimal, small, medium, large
```

#### CI/CD Variables

```bash
CI=true                       # Running in CI
GITHUB_ACTIONS=true           # GitHub Actions
GITLAB_CI=true                # GitLab CI
CARGO_TERM_COLOR=always       # Force color output
```

## CI/CD Integration

### GitHub Actions

See `.github/workflows/test.yml` for the complete workflow.

Features:
- Fast checks (format, clippy, docs)
- Matrix testing (multiple OS and Rust versions)
- Integration tests with services
- Parallel test shards
- Coverage with Codecov
- Docker-based tests
- Security audits
- Test result aggregation

Usage:
```bash
# Runs automatically on push/PR to main/develop
# Manual trigger with coverage:
gh workflow run test.yml -f coverage=true
```

### GitLab CI

See `.gitlab-ci.yml` for the complete pipeline.

Features:
- Multi-stage pipeline (prepare, validate, test, coverage, report)
- Docker registry caching
- Parallel test execution
- Coverage reports
- Test result artifacts
- GitLab Pages for documentation

Stages:
1. **Prepare**: Build images, cache dependencies
2. **Validate**: Format, clippy, docs, security
3. **Test**: Unit, integration, parallel, docker tests
4. **Coverage**: Generate coverage reports
5. **Report**: Aggregate results, generate badges
6. **Deploy**: Documentation to GitLab Pages

### Local CI Simulation

Test CI configuration locally:

```bash
# GitHub Actions (using act)
act -j test

# GitLab CI (using gitlab-runner)
gitlab-runner exec docker test-runner
```

## Configuration

### Nextest Configuration

See `docker/test/.config/nextest.toml` for nextest configuration.

Profiles:
- **default**: Standard local testing
- **ci**: CI-optimized (no retries, verbose output)
- **fast**: Quick tests only (strict timeouts)
- **integration**: Integration tests (longer timeouts)
- **debug**: Debugging (no timeouts, verbose)

### Docker Build Args

Customize test image build:

```bash
docker build \
  --file docker/Dockerfile.test \
  --build-arg RUST_VERSION=1.75.0 \
  --build-arg CARGO_BUILD_JOBS=8 \
  --target test-runner \
  -t llm-observatory-test:custom \
  .
```

## Test Data

### Fixtures

Located in `docker/test/fixtures/`:

- `users.json` - Test users with various roles
- `projects.json` - Test projects with configurations
- `api_keys.json` - API keys with different permissions
- `llm_models.json` - LLM model configurations and pricing
- `sample_traces.json` - Sample trace data with spans and events

### Database Schema

Located in `docker/test/init/01-test-schema.sql`:

- Complete schema with TimescaleDB hypertables
- Indexes for performance
- Continuous aggregates
- Utility functions
- Test-specific users and permissions

## Troubleshooting

### Tests Failing Locally

```bash
# Check service health
docker compose -f docker/compose/docker-compose.test.yml ps

# View service logs
docker compose -f docker/compose/docker-compose.test.yml logs timescaledb-test
docker compose -f docker/compose/docker-compose.test.yml logs redis-test

# Restart services
docker compose -f docker/compose/docker-compose.test.yml restart

# Clean restart
docker compose -f docker/compose/docker-compose.test.yml down -v
docker compose -f docker/compose/docker-compose.test.yml up -d
```

### Database Connection Issues

```bash
# Test database connection
docker compose -f docker/compose/docker-compose.test.yml exec timescaledb-test \
  pg_isready -U test_user -d llm_observatory_test

# Connect to database
docker compose -f docker/compose/docker-compose.test.yml exec timescaledb-test \
  psql -U test_user -d llm_observatory_test

# Check database logs
docker compose -f docker/compose/docker-compose.test.yml logs timescaledb-test
```

### Slow Tests

```bash
# Run only fast tests
cargo nextest run --profile fast

# Run tests in parallel
cargo nextest run --test-threads 8

# Skip slow tests
cargo nextest run --skip slow_
```

### Coverage Issues

```bash
# Use alternative coverage tool
cargo install cargo-llvm-cov
cargo llvm-cov --workspace --html

# Debug tarpaulin
cargo tarpaulin --verbose --debug

# Increase timeout
TARPAULIN_TIMEOUT=1200 ./docker/test/run-coverage.sh
```

### Cleanup

```bash
# Remove test volumes
docker compose -f docker/compose/docker-compose.test.yml down -v

# Clean Rust build cache
cargo clean

# Remove Docker build cache
docker builder prune -af

# Full cleanup
docker compose -f docker/compose/docker-compose.test.yml down -v
docker system prune -af
rm -rf target/ .cargo/
```

## Best Practices

### Writing Tests

1. **Use descriptive test names**: `test_user_authentication_with_valid_credentials`
2. **Follow AAA pattern**: Arrange, Act, Assert
3. **Test one thing**: Each test should verify a single behavior
4. **Use fixtures**: Leverage test fixtures for consistent data
5. **Clean up resources**: Ensure tests clean up after themselves
6. **Mark slow tests**: Use `#[ignore]` or custom attributes for slow tests

### Test Organization

```rust
#[cfg(test)]
mod tests {
    use super::*;

    // Unit tests - fast, no I/O
    mod unit {
        #[test]
        fn test_fast_logic() {
            // Test pure functions
        }
    }

    // Integration tests - require services
    #[cfg(feature = "integration-tests")]
    mod integration {
        #[tokio::test]
        async fn test_database_operations() {
            // Test with real database
        }
    }

    // Slow tests - mark for filtering
    #[test]
    #[ignore]
    fn test_slow_operation() {
        // Long-running test
    }
}
```

### Performance

1. **Use tmpfs**: Test databases run in memory for speed
2. **Disable durability**: fsync=off for tests
3. **Parallel execution**: Use cargo-nextest with --test-threads
4. **Cache dependencies**: Use Docker layer caching and Cargo cache
5. **Filter tests**: Run only relevant tests during development

## Additional Resources

- [cargo-nextest Documentation](https://nexte.st/)
- [Tarpaulin Documentation](https://github.com/xd009642/tarpaulin)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitLab CI Documentation](https://docs.gitlab.com/ee/ci/)

## License

Apache-2.0 - See LICENSE file for details

# LLM Observatory Storage

The storage crate provides the persistence layer for LLM Observatory, handling all database operations for traces, metrics, and logs.

## Architecture

```
storage/
├── src/
│   ├── lib.rs              # Main entry point and exports
│   ├── config.rs           # Database configuration
│   ├── pool.rs             # Connection pool management
│   ├── error.rs            # Storage-specific errors
│   ├── models/             # Data models
│   │   ├── trace.rs        # Trace, span, and event models
│   │   ├── metric.rs       # Metric and data point models
│   │   └── log.rs          # Log record models
│   ├── repositories/       # Query interfaces (read operations)
│   │   ├── trace.rs        # Trace queries
│   │   ├── metric.rs       # Metric queries
│   │   └── log.rs          # Log queries
│   └── writers/            # Batch writers (write operations)
│       ├── trace.rs        # Trace batch insertion
│       ├── metric.rs       # Metric batch insertion
│       └── log.rs          # Log batch insertion
├── migrations/             # SQLx database migrations
└── Cargo.toml
```

## Features

- **PostgreSQL**: Primary storage backend with full ACID compliance
- **High-Performance COPY Protocol**: 10-100x faster batch inserts using PostgreSQL COPY (50,000-100,000 rows/sec)
- **Dual Write Methods**: Standard INSERT (default) and COPY protocol (high-throughput)
- **Redis**: Optional caching and real-time data streaming
- **Batch Writers**: Efficient bulk insert operations with configurable batching
- **Connection Pooling**: Managed database connections with automatic retry
- **Migrations**: Automated schema management using SQLx
- **Type Safety**: Strong typing with SQLx compile-time query verification
- **UUID Resolution**: Automatic trace UUID resolution for LlmSpan conversion (see [UUID Resolution](docs/UUID_RESOLUTION.md))

## Usage

### Basic Setup

```rust
use llm_observatory_storage::{StorageConfig, StoragePool};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Load configuration
    let config = StorageConfig::from_env()?;

    // Create connection pool
    let pool = StoragePool::new(config).await?;

    // Run migrations
    pool.run_migrations().await?;

    Ok(())
}
```

### Writing LLM Spans (Recommended)

For LLM spans with proper trace UUID resolution:

```rust
use llm_observatory_storage::writers::TraceWriter;
use llm_observatory_core::span::LlmSpan;

// Create writer
let writer = TraceWriter::new(pool.clone());

// Write LLM span with automatic trace UUID resolution
let trace_span = writer.write_span_from_llm(llm_span).await?;

// Flush buffered data
writer.flush().await?;
```

See [UUID Resolution Guide](docs/UUID_RESOLUTION.md) for details.

### Writing Data Directly

```rust
use llm_observatory_storage::writers::TraceWriter;

// Create writer
let writer = TraceWriter::new(pool.clone());

// Write traces
writer.write_trace(trace).await?;

// Flush buffered data
writer.flush().await?;
```

### High-Performance COPY Protocol

For maximum throughput (10-100x faster than INSERT):

```rust
use llm_observatory_storage::writers::CopyWriter;

// Get a tokio-postgres client for COPY operations
let (client, _handle) = pool.get_tokio_postgres_client().await?;

// Write large batches using COPY protocol
let traces = generate_traces(10000);
let rows = CopyWriter::write_traces(&client, traces).await?;
// Throughput: ~50,000-100,000 rows/sec vs ~5,000-10,000 with INSERT
```

See [COPY Protocol Guide](./COPY_PROTOCOL.md) for detailed information.

### Reading Data

```rust
use llm_observatory_storage::repositories::TraceRepository;

// Create repository
let repo = TraceRepository::new(pool.clone());

// Query traces
let traces = repo.list(filters).await?;
```

## Configuration

The storage crate can be configured via environment variables or configuration files:

### Environment Variables

- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string (optional)
- `DB_MAX_CONNECTIONS` - Maximum pool size (default: 50)
- `DB_MIN_CONNECTIONS` - Minimum pool size (default: 5)

### Configuration File

```yaml
postgres:
  host: localhost
  port: 5432
  database: llm_observatory
  username: postgres
  password: secret
  ssl_mode: prefer

redis:
  url: redis://localhost:6379/0

pool:
  max_connections: 50
  min_connections: 5
  connect_timeout_secs: 10
```

## Database Schema

### Traces

- `traces` - Main trace records
- `trace_spans` - Individual spans within traces
- `trace_events` - Events attached to spans

### Metrics

- `metrics` - Metric definitions
- `metric_data_points` - Time series data points

### Logs

- `logs` - Log records with full-text search support

## Development

### Running Migrations

```bash
sqlx migrate run --source crates/storage/migrations
```

### Running Tests

```bash
# Unit tests
cargo test -p llm-observatory-storage

# Integration tests (requires PostgreSQL)
cargo test -p llm-observatory-storage --features test-integration
```

## Recently Completed

- [x] Implement configuration loading from environment with `from_env()` method
- [x] Implement configuration loading from files (YAML, TOML, JSON)
- [x] Add comprehensive validation for all configuration values
- [x] Implement connection pool with automatic retry logic
- [x] Add health check methods for PostgreSQL and Redis
- [x] Implement pool statistics and monitoring
- [x] Create test connection binary for easy verification
- [x] Add .env.example with all configuration options
- [x] Support for both DATABASE_URL and individual PostgreSQL settings
- [x] Exponential backoff retry logic with configurable parameters

## Environment Variable Reference

See [.env.example](./.env.example) for a complete list of all configuration options.

### Testing Your Configuration

Run the test connection binary to verify your setup:

```bash
# Set minimal required config
export DB_PASSWORD=postgres

# Run the test
cargo run --bin test_connection

# With debug logging
RUST_LOG=debug cargo run --bin test_connection
```

The test binary will:
1. Load and validate configuration
2. Create connection pool with retry
3. Test PostgreSQL connectivity
4. Test Redis connectivity (if configured)
5. Run health checks
6. Display pool statistics
7. Execute a sample query

## Performance

### Benchmarks

Run benchmarks to compare INSERT vs COPY performance:

```bash
export DATABASE_URL="postgres://postgres:password@localhost/llm_observatory"
cargo bench --bench copy_vs_insert
```

Expected results:
- INSERT: ~5,000-10,000 rows/sec
- COPY: ~50,000-100,000 rows/sec
- Speedup: 10-100x depending on batch size and data complexity

### Performance Documentation

- [COPY Protocol Guide](./COPY_PROTOCOL.md) - Comprehensive guide to high-performance COPY
- [Benchmark Code](./benches/copy_vs_insert.rs) - Performance comparison benchmarks
- [Example Usage](./examples/copy_protocol.rs) - Working example with measurements

## TODO

- [x] Implement batch insert operations in writers
- [x] Add PostgreSQL COPY protocol support
- [x] Create comprehensive benchmarks
- [ ] Implement query methods in repositories
- [ ] Create database migration files
- [ ] Add integration tests
- [ ] Implement Redis caching layer
- [ ] Add data retention policies
- [ ] Optimize query performance with indexes
- [ ] Add compression for large JSON fields
- [ ] Implement time-series partitioning

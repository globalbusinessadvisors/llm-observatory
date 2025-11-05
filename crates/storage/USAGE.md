# Storage Layer Usage Guide

Complete guide for using the LLM Observatory storage layer.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration](#configuration)
3. [Connection Management](#connection-management)
4. [Health Monitoring](#health-monitoring)
5. [Error Handling](#error-handling)
6. [Best Practices](#best-practices)
7. [Examples](#examples)
8. [Troubleshooting](#troubleshooting)

## Quick Start

### Minimal Setup

```rust
use llm_observatory_storage::{StorageConfig, StoragePool};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Requires DB_PASSWORD environment variable
    let config = StorageConfig::from_env()?;
    let pool = StoragePool::new(config).await?;

    // Verify connectivity
    pool.health_check().await?;

    println!("Storage is ready!");
    Ok(())
}
```

### Testing Your Setup

Before integrating into your application, test your configuration:

```bash
# 1. Copy the example env file
cp crates/storage/.env.example .env

# 2. Edit .env and set your database password
# DB_PASSWORD=your_password_here

# 3. Run the test binary
cargo run --bin test_connection -p llm-observatory-storage
```

## Configuration

### Method 1: Environment Variables (Recommended)

**Minimal Configuration:**
```bash
export DB_PASSWORD=postgres
```

This uses sensible defaults:
- Host: localhost
- Port: 5432
- Database: llm_observatory
- User: postgres
- SSL Mode: prefer

**Full Configuration:**
```bash
# PostgreSQL
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=llm_observatory
export DB_USER=postgres
export DB_PASSWORD=your_password
export DB_SSL_MODE=prefer
export DB_APP_NAME=my-app

# Redis (optional)
export REDIS_URL=redis://localhost:6379/0

# Pool settings
export DB_POOL_MAX_CONNECTIONS=50
export DB_POOL_MIN_CONNECTIONS=5

# Retry settings
export DB_RETRY_MAX_ATTEMPTS=3
```

### Method 2: DATABASE_URL (Production)

```bash
export DATABASE_URL=postgresql://user:pass@localhost:5432/llm_observatory?sslmode=require&application_name=my-app
```

### Method 3: .env File

Create a `.env` file in your project root:

```bash
DB_PASSWORD=postgres
REDIS_URL=redis://localhost:6379/0
```

The library automatically loads `.env` files when calling `from_env()`.

### Method 4: Config File

Create `storage.yaml`:

```yaml
postgres:
  host: localhost
  port: 5432
  database: llm_observatory
  username: postgres
  password: postgres
  ssl_mode: prefer

redis:
  url: redis://localhost:6379/0
  pool_size: 10

pool:
  max_connections: 50
  min_connections: 5
```

Load it:

```rust
let config = StorageConfig::from_file("storage.yaml")?;
```

## Connection Management

### Creating a Connection Pool

```rust
use llm_observatory_storage::{StorageConfig, StoragePool};

// Load config
let config = StorageConfig::from_env()?;

// Create pool (automatically retries on failure)
let pool = StoragePool::new(config).await?;
```

### Accessing Connections

```rust
// PostgreSQL
let pg_pool = pool.postgres();

// Execute query
let result = sqlx::query("SELECT 1")
    .fetch_one(pg_pool)
    .await?;

// Redis (if configured)
if let Some(redis) = pool.redis() {
    let mut conn = redis.clone();
    redis::cmd("PING")
        .query_async::<_, String>(&mut conn)
        .await?;
}
```

### Pool Statistics

```rust
let stats = pool.stats();

println!("Active connections: {}/{}",
    stats.postgres_active,
    stats.postgres_max_connections
);

println!("Idle connections: {}", stats.postgres_idle);
println!("Utilization: {:.1}%", stats.utilization_percent());

// Check if pool is near capacity (>80%)
if stats.is_near_capacity() {
    eprintln!("Warning: Connection pool near capacity!");
}
```

### Graceful Shutdown

```rust
// In shutdown handler
pool.close().await;
```

## Health Monitoring

### Basic Health Check

```rust
// Check both PostgreSQL and Redis
let health = pool.health_check().await?;

if health.is_healthy() {
    println!("All systems operational");
} else {
    println!("Some services are degraded");
}
```

### Individual Health Checks

```rust
// Check only PostgreSQL
match pool.health_check_postgres().await {
    Ok(_) => println!("PostgreSQL is healthy"),
    Err(e) => eprintln!("PostgreSQL error: {}", e),
}

// Check only Redis
match pool.health_check_redis().await {
    Ok(_) => println!("Redis is healthy"),
    Err(e) => eprintln!("Redis error: {}", e),
}
```

### Periodic Health Checks

```rust
use tokio::time::{interval, Duration};

// Spawn health check task
tokio::spawn(async move {
    let mut ticker = interval(Duration::from_secs(30));
    loop {
        ticker.tick().await;

        match pool.health_check().await {
            Ok(health) => {
                tracing::info!(
                    "Health: postgres={}, redis={:?}",
                    health.postgres_healthy,
                    health.redis_healthy
                );
            }
            Err(e) => {
                tracing::error!("Health check failed: {}", e);
            }
        }
    }
});
```

## Error Handling

### Error Types

```rust
use llm_observatory_storage::StorageError;

match some_operation() {
    Ok(result) => { /* success */ }
    Err(StorageError::ConnectionError(msg)) => {
        // Connection failed - might be transient
        eprintln!("Connection error: {}", msg);
    }
    Err(StorageError::QueryError(msg)) => {
        // Query failed - check SQL syntax
        eprintln!("Query error: {}", msg);
    }
    Err(StorageError::ConfigError(msg)) => {
        // Configuration invalid - fix config
        eprintln!("Config error: {}", msg);
    }
    Err(StorageError::NotFound(msg)) => {
        // Record not found - expected in some cases
        eprintln!("Not found: {}", msg);
    }
    Err(e) => {
        eprintln!("Other error: {}", e);
    }
}
```

### Retryable Errors

```rust
use llm_observatory_storage::StorageError;

fn is_retryable(error: &StorageError) -> bool {
    error.is_retryable()
}

// Retryable errors:
// - ConnectionError
// - PoolError
// - Timeout
```

### Custom Retry Logic

```rust
use tokio::time::{sleep, Duration};

async fn query_with_retry<T>(
    pool: &StoragePool,
    max_retries: u32,
) -> Result<T, StorageError> {
    let mut attempt = 0;

    loop {
        match execute_query(pool).await {
            Ok(result) => return Ok(result),
            Err(e) if e.is_retryable() && attempt < max_retries => {
                attempt += 1;
                let delay = Duration::from_millis(100 * 2_u64.pow(attempt));
                sleep(delay).await;
            }
            Err(e) => return Err(e),
        }
    }
}
```

## Best Practices

### 1. Connection Pool Sizing

**Web Application:**
```bash
# Rule of thumb: (2 × CPU cores) to (4 × CPU cores)
# For 8 cores:
DB_POOL_MAX_CONNECTIONS=32
DB_POOL_MIN_CONNECTIONS=8
```

**Background Worker:**
```bash
# Fewer connections needed
DB_POOL_MAX_CONNECTIONS=10
DB_POOL_MIN_CONNECTIONS=2
```

**High Throughput:**
```bash
# More connections but monitor server capacity
DB_POOL_MAX_CONNECTIONS=100
DB_POOL_MIN_CONNECTIONS=20
```

### 2. Timeouts

**User-Facing API:**
```bash
# Fail fast for better UX
DB_POOL_CONNECT_TIMEOUT=5
```

**Background Jobs:**
```bash
# More patient
DB_POOL_CONNECT_TIMEOUT=30
```

### 3. Configuration Management

**Development:**
```rust
// Use .env file
let config = StorageConfig::from_env()?;
```

**Production:**
```rust
// Use environment variables from deployment system
// Don't commit .env to version control
let config = StorageConfig::from_env()?;
```

**Testing:**
```rust
// Use a separate test database
#[cfg(test)]
let config = StorageConfig {
    postgres: PostgresConfig {
        database: "llm_observatory_test".to_string(),
        // ... other settings
    },
    // ...
};
```

### 4. Logging

```rust
// Configure tracing in main
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

tracing_subscriber::registry()
    .with(
        tracing_subscriber::EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| "info,sqlx=warn".into()),
    )
    .with(tracing_subscriber::fmt::layer())
    .init();
```

Control log levels:
```bash
# Production
RUST_LOG=info,llm_observatory_storage=info,sqlx=warn

# Development
RUST_LOG=debug,llm_observatory_storage=debug,sqlx=debug

# Debugging issues
RUST_LOG=trace
```

## Examples

### Example 1: Writing LLM Spans with UUID Resolution

The recommended way to write LLM spans with proper trace UUID resolution:

```rust
use llm_observatory_storage::{StorageConfig, StoragePool};
use llm_observatory_storage::writers::TraceWriter;
use llm_observatory_core::span::{LlmSpan, LlmInput, SpanStatus};
use llm_observatory_core::types::{Provider, Latency};

async fn write_llm_span(pool: &StoragePool) -> Result<(), Box<dyn std::error::Error>> {
    // Create trace writer
    let writer = TraceWriter::new(pool.clone());

    // Build an LLM span (from your instrumentation)
    let now = chrono::Utc::now();
    let llm_span = LlmSpan::builder()
        .span_id("span_abc123")
        .trace_id("trace_xyz789")  // String trace ID
        .name("llm.completion")
        .provider(Provider::OpenAI)
        .model("gpt-4")
        .input(LlmInput::Text {
            prompt: "Hello, world!".to_string(),
        })
        .latency(Latency::new(now, now))
        .status(SpanStatus::Ok)
        .build()?;

    // Write span with automatic trace UUID resolution
    // This will:
    // 1. Look up or create trace with trace_id="trace_xyz789"
    // 2. Convert LlmSpan to TraceSpan with proper UUID
    // 3. Buffer the span for batch writing
    let trace_span = writer.write_span_from_llm(llm_span).await?;

    println!("Span written with trace UUID: {}", trace_span.trace_id);

    // Flush buffered writes
    writer.flush().await?;

    Ok(())
}
```

For more details, see [UUID Resolution Documentation](docs/UUID_RESOLUTION.md).

### Example 2: Simple Query

```rust
use llm_observatory_storage::{StorageConfig, StoragePool};

async fn count_traces(pool: &StoragePool) -> Result<i64, Box<dyn std::error::Error>> {
    let row = sqlx::query("SELECT COUNT(*) as count FROM llm_traces")
        .fetch_one(pool.postgres())
        .await?;

    let count: i64 = row.get("count");
    Ok(count)
}
```

### Example 2: With Redis Cache

```rust
async fn get_user_with_cache(
    pool: &StoragePool,
    user_id: &str,
) -> Result<User, Box<dyn std::error::Error>> {
    // Try cache first
    if let Some(redis) = pool.redis() {
        let mut conn = redis.clone();
        let cache_key = format!("user:{}", user_id);

        if let Ok(cached) = redis::cmd("GET")
            .arg(&cache_key)
            .query_async::<_, String>(&mut conn)
            .await
        {
            return Ok(serde_json::from_str(&cached)?);
        }
    }

    // Cache miss, query database
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_one(pool.postgres())
        .await?;

    // Update cache
    if let Some(redis) = pool.redis() {
        let mut conn = redis.clone();
        let cache_key = format!("user:{}", user_id);
        let _ = redis::cmd("SETEX")
            .arg(&cache_key)
            .arg(300) // 5 minute TTL
            .arg(serde_json::to_string(&user)?)
            .query_async::<_, ()>(&mut conn)
            .await;
    }

    Ok(user)
}
```

### Example 3: Transaction

```rust
use sqlx::Transaction;

async fn transfer_cost(
    pool: &StoragePool,
    from_user: &str,
    to_user: &str,
    amount: f64,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut tx = pool.postgres().begin().await?;

    // Deduct from sender
    sqlx::query("UPDATE user_balances SET balance = balance - $1 WHERE user_id = $2")
        .bind(amount)
        .bind(from_user)
        .execute(&mut *tx)
        .await?;

    // Add to receiver
    sqlx::query("UPDATE user_balances SET balance = balance + $1 WHERE user_id = $2")
        .bind(amount)
        .bind(to_user)
        .execute(&mut *tx)
        .await?;

    tx.commit().await?;
    Ok(())
}
```

## Troubleshooting

### Problem: "DB_PASSWORD environment variable is required"

**Solution:** Set the DB_PASSWORD environment variable:
```bash
export DB_PASSWORD=your_password
# Or create .env file with: DB_PASSWORD=your_password
```

### Problem: "PostgreSQL connection failed after 3 attempts"

**Solutions:**
1. Check PostgreSQL is running: `pg_isready`
2. Verify connection details in your config
3. Check firewall/network connectivity
4. Verify credentials

### Problem: "Connection pool timeout"

**Solutions:**
1. Increase pool size: `DB_POOL_MAX_CONNECTIONS=100`
2. Increase timeout: `DB_POOL_CONNECT_TIMEOUT=30`
3. Check for connection leaks (not closing connections)
4. Monitor active connections with `pool.stats()`

### Problem: "Redis not configured" warnings

**Solution:** This is informational, not an error. Redis is optional:
- To use Redis: Set `REDIS_URL=redis://localhost:6379/0`
- To ignore: Redis features will be disabled but app will work

### Problem: High connection utilization

**Check utilization:**
```rust
let stats = pool.stats();
println!("Utilization: {:.1}%", stats.utilization_percent());
```

**Solutions:**
1. Increase max connections
2. Optimize query performance
3. Use connection pooling in application code
4. Check for connection leaks

### Problem: SSL/TLS connection errors

**Solution:** Adjust SSL mode:
```bash
# Disable SSL (development only)
DB_SSL_MODE=disable

# Require SSL (production)
DB_SSL_MODE=require
```

## Need Help?

- Check logs with `RUST_LOG=debug`
- Run `cargo run --bin test_connection` to diagnose issues
- Review [.env.example](./.env.example) for configuration options
- See [README.md](./README.md) for architecture details

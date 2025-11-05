# Storage Crate Implementation Guide

This guide provides step-by-step instructions for implementing the remaining functionality in the storage crate.

## Phase 1: Database Migrations (Priority: High)

### Step 1.1: Create Traces Migration

```bash
sqlx migrate add create_traces_tables
```

File: `migrations/{timestamp}_create_traces_tables.sql`

```sql
-- Create traces table
CREATE TABLE IF NOT EXISTS traces (
    id UUID PRIMARY KEY,
    trace_id VARCHAR(32) NOT NULL,
    service_name VARCHAR(255) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_us BIGINT,
    status VARCHAR(50) NOT NULL,
    status_message TEXT,
    root_span_name VARCHAR(255),
    attributes JSONB NOT NULL DEFAULT '{}',
    resource_attributes JSONB NOT NULL DEFAULT '{}',
    span_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for traces
CREATE INDEX idx_traces_trace_id ON traces(trace_id);
CREATE INDEX idx_traces_service_name ON traces(service_name);
CREATE INDEX idx_traces_start_time ON traces(start_time DESC);
CREATE INDEX idx_traces_status ON traces(status);
CREATE INDEX idx_traces_duration ON traces(duration_us);

-- Create trace_spans table
CREATE TABLE IF NOT EXISTS trace_spans (
    id UUID PRIMARY KEY,
    trace_id UUID NOT NULL REFERENCES traces(id) ON DELETE CASCADE,
    span_id VARCHAR(16) NOT NULL,
    parent_span_id VARCHAR(16),
    name VARCHAR(255) NOT NULL,
    kind VARCHAR(50) NOT NULL,
    service_name VARCHAR(255) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_us BIGINT,
    status VARCHAR(50) NOT NULL,
    status_message TEXT,
    attributes JSONB NOT NULL DEFAULT '{}',
    events JSONB,
    links JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for spans
CREATE INDEX idx_spans_trace_id ON trace_spans(trace_id);
CREATE INDEX idx_spans_span_id ON trace_spans(span_id);
CREATE INDEX idx_spans_start_time ON trace_spans(start_time DESC);
CREATE INDEX idx_spans_name ON trace_spans(name);

-- Create trace_events table
CREATE TABLE IF NOT EXISTS trace_events (
    id UUID PRIMARY KEY,
    span_id UUID NOT NULL REFERENCES trace_spans(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    attributes JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_events_span_id ON trace_events(span_id);
```

### Step 1.2: Create Metrics Migration

```bash
sqlx migrate add create_metrics_tables
```

### Step 1.3: Create Logs Migration

```bash
sqlx migrate add create_logs_table
```

### Step 1.4: Update Migration Runner in pool.rs

```rust
pub async fn run_migrations(&self) -> StorageResult<()> {
    tracing::info!("Running database migrations...");

    sqlx::migrate!("./crates/storage/migrations")
        .run(&self.postgres)
        .await
        .map_err(|e| StorageError::MigrationError(e.to_string()))?;

    tracing::info!("Database migrations completed");
    Ok(())
}
```

## Phase 2: Configuration Implementation (Priority: High)

### Step 2.1: Implement from_env() in config.rs

```rust
use std::env;

impl StorageConfig {
    pub fn from_env() -> Result<Self, StorageError> {
        let postgres = PostgresConfig {
            host: env::var("DB_HOST").unwrap_or_else(|_| "localhost".to_string()),
            port: env::var("DB_PORT")
                .unwrap_or_else(|_| "5432".to_string())
                .parse()
                .map_err(|e| StorageError::ConfigError(format!("Invalid port: {}", e)))?,
            database: env::var("DB_NAME").unwrap_or_else(|_| "llm_observatory".to_string()),
            username: env::var("DB_USER").unwrap_or_else(|_| "postgres".to_string()),
            password: env::var("DB_PASSWORD").unwrap_or_else(|_| "".to_string()),
            ssl_mode: env::var("DB_SSL_MODE").unwrap_or_else(|_| "prefer".to_string()),
            application_name: env::var("DB_APP_NAME")
                .unwrap_or_else(|_| "llm-observatory".to_string()),
        };

        let redis = if let Ok(redis_url) = env::var("REDIS_URL") {
            Some(RedisConfig {
                url: redis_url,
                pool_size: env::var("REDIS_POOL_SIZE")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(10),
                timeout_secs: env::var("REDIS_TIMEOUT")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(5),
            })
        } else {
            None
        };

        Ok(Self {
            postgres,
            redis,
            pool: PoolConfig::default(),
            retry: RetryConfig::default(),
        })
    }
}
```

## Phase 3: Writer Implementation (Priority: High)

### Step 3.1: Implement Batch Insert for Traces

In `writers/trace.rs`, replace the `insert_traces` implementation:

```rust
async fn insert_traces(&self, traces: Vec<Trace>) -> StorageResult<()> {
    use sqlx::QueryBuilder;

    tracing::debug!("Inserting {} traces", traces.len());

    // Use QueryBuilder for batch insert
    let mut query_builder = QueryBuilder::new(
        "INSERT INTO traces (
            id, trace_id, service_name, start_time, end_time, duration_us,
            status, status_message, root_span_name, attributes,
            resource_attributes, span_count
        ) "
    );

    query_builder.push_values(traces.iter(), |mut b, trace| {
        b.push_bind(trace.id)
            .push_bind(&trace.trace_id)
            .push_bind(&trace.service_name)
            .push_bind(trace.start_time)
            .push_bind(trace.end_time)
            .push_bind(trace.duration_us)
            .push_bind(&trace.status)
            .push_bind(&trace.status_message)
            .push_bind(&trace.root_span_name)
            .push_bind(&trace.attributes)
            .push_bind(&trace.resource_attributes)
            .push_bind(trace.span_count);
    });

    // Add ON CONFLICT clause for idempotency
    query_builder.push(
        " ON CONFLICT (id) DO UPDATE SET
            end_time = EXCLUDED.end_time,
            duration_us = EXCLUDED.duration_us,
            status = EXCLUDED.status,
            status_message = EXCLUDED.status_message,
            span_count = EXCLUDED.span_count,
            updated_at = NOW()
        "
    );

    query_builder
        .build()
        .execute(self.pool.postgres())
        .await
        .map_err(StorageError::from)?;

    tracing::info!("Inserted {} traces", traces.len());
    Ok(())
}
```

### Step 3.2: Implement Similar for Spans and Events

Follow the same pattern for `insert_spans` and `insert_events`.

## Phase 4: Repository Implementation (Priority: High)

### Step 4.1: Implement TraceRepository Queries

In `repositories/trace.rs`:

```rust
pub async fn get_by_id(&self, id: Uuid) -> StorageResult<Trace> {
    sqlx::query_as::<_, Trace>(
        "SELECT * FROM traces WHERE id = $1"
    )
    .bind(id)
    .fetch_one(self.pool.postgres())
    .await
    .map_err(StorageError::from)
}

pub async fn list(&self, filters: TraceFilters) -> StorageResult<Vec<Trace>> {
    let mut query = QueryBuilder::new("SELECT * FROM traces WHERE 1=1");

    if let Some(service) = &filters.service_name {
        query.push(" AND service_name = ");
        query.push_bind(service);
    }

    if let Some(status) = &filters.status {
        query.push(" AND status = ");
        query.push_bind(status);
    }

    if let Some(start) = filters.start_time {
        query.push(" AND start_time >= ");
        query.push_bind(start);
    }

    if let Some(end) = filters.end_time {
        query.push(" AND start_time <= ");
        query.push_bind(end);
    }

    query.push(" ORDER BY start_time DESC");

    if let Some(limit) = filters.limit {
        query.push(" LIMIT ");
        query.push_bind(limit);
    }

    if let Some(offset) = filters.offset {
        query.push(" OFFSET ");
        query.push_bind(offset);
    }

    query
        .build_query_as::<Trace>()
        .fetch_all(self.pool.postgres())
        .await
        .map_err(StorageError::from)
}
```

## Phase 5: Model Constructors (Priority: Medium)

### Step 5.1: Implement Trace::new()

In `models/trace.rs`:

```rust
impl Trace {
    pub fn new(
        trace_id: String,
        service_name: String,
        start_time: DateTime<Utc>,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            trace_id,
            service_name,
            start_time,
            end_time: None,
            duration_us: None,
            status: "unset".to_string(),
            status_message: None,
            root_span_name: None,
            attributes: serde_json::json!({}),
            resource_attributes: serde_json::json!({}),
            span_count: 0,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }
}
```

## Phase 6: Integration Tests (Priority: Medium)

### Step 6.1: Create Test Helper

Create `tests/common/mod.rs`:

```rust
use llm_observatory_storage::{StorageConfig, StoragePool};
use sqlx::PgPool;

pub async fn setup_test_db() -> StoragePool {
    let config = StorageConfig::from_env()
        .expect("Failed to load test config");

    let pool = StoragePool::new(config)
        .await
        .expect("Failed to create pool");

    pool.run_migrations()
        .await
        .expect("Failed to run migrations");

    pool
}

pub async fn cleanup_test_db(pool: &StoragePool) {
    sqlx::query("TRUNCATE traces, trace_spans, trace_events CASCADE")
        .execute(pool.postgres())
        .await
        .expect("Failed to cleanup");
}
```

### Step 6.2: Create Integration Tests

Create `tests/trace_writer_test.rs`:

```rust
use common::*;

mod common;

#[tokio::test]
async fn test_write_and_read_trace() {
    let pool = setup_test_db().await;

    // Test implementation

    cleanup_test_db(&pool).await;
}
```

## Phase 7: Performance Optimization (Priority: Low)

### Step 7.1: Add Connection Pooling Metrics

### Step 7.2: Implement Query Caching

### Step 7.3: Add Time-Series Partitioning

## Testing Checklist

- [ ] Unit tests for all models
- [ ] Unit tests for error conversions
- [ ] Integration tests for writers
- [ ] Integration tests for repositories
- [ ] Benchmark tests for batch operations
- [ ] Load tests for concurrent writes
- [ ] Migration rollback tests

## Environment Variables Reference

Required:
- `DB_HOST` - Database host (default: localhost)
- `DB_PORT` - Database port (default: 5432)
- `DB_NAME` - Database name (default: llm_observatory)
- `DB_USER` - Database user (default: postgres)
- `DB_PASSWORD` - Database password

Optional:
- `REDIS_URL` - Redis connection URL
- `DB_SSL_MODE` - SSL mode (disable, allow, prefer, require)
- `DB_MAX_CONNECTIONS` - Max pool size (default: 50)
- `DB_MIN_CONNECTIONS` - Min pool size (default: 5)

## Common Issues and Solutions

### Issue: SQLx compile-time verification fails

**Solution**: Generate query metadata:
```bash
cargo sqlx prepare -- --lib -p llm-observatory-storage
```

### Issue: Migration conflicts

**Solution**: Use database URL:
```bash
export DATABASE_URL=postgres://user:pass@localhost/dbname
sqlx migrate run
```

### Issue: Connection pool exhaustion

**Solution**: Increase pool size or reduce connection timeout:
```rust
config.pool.max_connections = 100;
config.pool.connect_timeout_secs = 5;
```

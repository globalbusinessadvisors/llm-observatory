# Development Environment Setup

This guide provides comprehensive instructions for setting up and using the LLM Observatory development environment with hot reload capabilities.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Development Environment](#development-environment)
4. [Hot Reload](#hot-reload)
5. [Database Operations](#database-operations)
6. [Development Workflow](#development-workflow)
7. [Testing](#testing)
8. [Performance Optimization](#performance-optimization)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

- Docker 24.0+ and Docker Compose 2.20+
- Make (optional, for convenience commands)
- 8GB+ RAM available for Docker
- 10GB+ free disk space

## Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/llm-observatory/llm-observatory.git
cd llm-observatory

# Create environment file
make env
# OR
cp .env.example .env

# Edit .env file with your settings (optional for development)
```

### 2. Start Development Environment

```bash
# Using Make (recommended)
make dev-start

# OR using docker-compose directly
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# OR using the helper script
./scripts/dev.sh start
```

### 3. Verify Services

Wait for all services to start (approximately 30-60 seconds), then verify:

```bash
# Check service status
make status

# Check health endpoints
make health
```

### 4. Seed Database (Optional)

```bash
# Add sample data for testing
make dev-seed
```

### 5. Start Developing!

Edit any Rust file in `crates/` and watch it automatically rebuild and restart within 2-3 seconds!

## Development Environment

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Development Environment                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Collector   │  │     API      │  │   Storage    │     │
│  │  (Hot Reload)│  │ (Hot Reload) │  │ (Hot Reload) │     │
│  │  Port: 4317/8│  │  Port: 8080  │  │  Port: 8081  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            │                                │
│  ┌─────────────────────────┴──────────────────────────┐    │
│  │             Infrastructure Services                 │    │
│  │  ┌──────────────┐  ┌──────────┐  ┌──────────────┐│    │
│  │  │ TimescaleDB  │  │  Redis   │  │   Grafana    ││    │
│  │  │  Port: 5432  │  │Port: 6379│  │  Port: 3000  ││    │
│  │  └──────────────┘  └──────────┘  └──────────────┘│    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Services

| Service | Description | Ports | Hot Reload |
|---------|-------------|-------|------------|
| **Collector** | OTLP collector with LLM processors | 4317 (gRPC), 4318 (HTTP), 9091 (metrics) | ✓ |
| **API** | REST API for queries and management | 8080 (HTTP), 9092 (metrics) | ✓ |
| **Storage** | Data storage and aggregation | 8081 (HTTP), 9093 (metrics) | ✓ |
| **TimescaleDB** | PostgreSQL with time-series extensions | 5432 | - |
| **Redis** | Caching and session storage | 6379 | - |
| **Grafana** | Visualization and dashboards | 3000 | - |
| **PgAdmin** | Database admin UI (optional) | 5050 | - |

### Volume Configuration

The development environment uses Docker volumes for optimal performance:

#### Shared Volumes (Build Cache)
- `cargo_registry` - Shared cargo package registry
- `cargo_git` - Shared cargo git dependencies
- Prevents re-downloading dependencies on rebuild

#### Per-Service Volumes (Incremental Builds)
- `collector_target` - Collector build artifacts
- `api_target` - API build artifacts
- `storage_target` - Storage build artifacts
- Enables fast incremental compilation

#### Mounted Volumes (Source Code)
- `./crates` → `/app/crates` - Source code (read-only)
- `./Cargo.toml` → `/app/Cargo.toml` - Workspace config
- `./Cargo.lock` → `/app/Cargo.lock` - Dependency lock

## Hot Reload

### How It Works

1. **cargo-watch** monitors file changes in mounted source directories
2. When a change is detected, it triggers `cargo run`
3. Cargo performs **incremental compilation** (only rebuilds changed code)
4. The service automatically restarts with the new binary
5. Total time: **2-3 seconds** for typical changes

### cargo-watch Configuration

```bash
cargo watch \
    --watch crates \              # Watch all crates
    --watch Cargo.toml \          # Watch workspace config
    --watch Cargo.lock \          # Watch dependencies
    --clear \                     # Clear screen on rebuild
    --why \                       # Show what triggered rebuild
    --delay 0.5 \                 # Batch changes within 0.5s
    --no-gitignore \              # Watch all files
    --exec "run --bin <service>"  # Run the service binary
```

### Watching Reload Process

To see the hot reload in action:

```bash
# Terminal 1: Watch service logs
make dev-logs-api

# Terminal 2: Make a change
echo "// test change" >> crates/api/src/main.rs

# Terminal 1: You'll see:
# [Running 'cargo run --bin llm-observatory-api']
# Compiling llm-observatory-api v0.1.0
# Finished dev [unoptimized + debuginfo] target(s) in 2.34s
# Running `target/debug/llm-observatory-api`
```

### Optimizing Reload Speed

**Already configured optimizations:**

1. **Incremental Compilation** - `CARGO_INCREMENTAL=1`
2. **Separate Target Directories** - Per-service volumes
3. **Shared Cargo Cache** - Registry and git cache volumes
4. **Development Profile** - Fast compilation, no optimizations
5. **PostgreSQL Tuning** - Async writes, reduced durability for dev

**Manual optimizations (if needed):**

```bash
# 1. Use sccache for distributed compilation cache
docker-compose exec api cargo install sccache

# 2. Add to docker-compose.dev.yml environment:
RUSTC_WRAPPER: sccache
SCCACHE_DIR: /cache/sccache

# 3. Add volume for sccache:
volumes:
  - sccache:/cache/sccache
```

## Database Operations

### Seeding Sample Data

```bash
# Using Make
make dev-seed

# Using script
./scripts/dev.sh seed

# Using docker-compose
docker-compose -f docker-compose.yml -f docker-compose.dev.yml run --rm dev-utils sh -c "psql < /seed-data/seed.sql"
```

Sample data includes:
- 5 LLM traces (OpenAI, Anthropic, Azure OpenAI)
- 4 LLM attribute records with token counts and costs
- 13 time-series metrics
- Continuous aggregates for hourly rollups

### Resetting Database

```bash
# Using Make (with confirmation prompt)
make dev-reset

# Using script
./scripts/dev.sh reset

# Manual reset
docker-compose -f docker-compose.yml -f docker-compose.dev.yml run --rm dev-utils sh -c "psql < /seed-data/reset.sql"
```

### Database Shell Access

```bash
# Using Make
make db-shell

# Using docker-compose
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec timescaledb psql -U postgres -d llm_observatory
```

### Sample Queries

```sql
-- View all traces
SELECT * FROM traces ORDER BY start_time DESC LIMIT 10;

-- View LLM usage by provider
SELECT
    provider,
    COUNT(*) as requests,
    SUM(total_tokens) as total_tokens,
    SUM(cost_usd) as total_cost
FROM llm_attributes
GROUP BY provider;

-- View average request duration by model
SELECT
    l.model,
    AVG(t.duration_ms) as avg_duration_ms,
    COUNT(*) as request_count
FROM traces t
JOIN llm_attributes l ON t.trace_id = l.trace_id
GROUP BY l.model
ORDER BY avg_duration_ms DESC;

-- View recent metrics
SELECT
    time,
    metric_name,
    tags->>'provider' as provider,
    value
FROM metrics
ORDER BY time DESC
LIMIT 20;
```

### Migrations (Future)

Once the migration system is implemented:

```bash
# Run migrations
make dev-shell-api
cargo run --bin llm-observatory-api -- migrate up

# Rollback migrations
cargo run --bin llm-observatory-api -- migrate down

# Create new migration
cargo run --bin llm-observatory-api -- migrate create add_user_table
```

## Development Workflow

### Typical Development Session

```bash
# 1. Start environment
make dev-start

# 2. In another terminal, watch logs
make dev-logs-api

# 3. Make code changes in your editor
# File: crates/api/src/main.rs

# 4. Save - watch automatic rebuild in logs terminal
# Rebuild completes in 2-3 seconds

# 5. Test changes
curl http://localhost:8080/health

# 6. View detailed logs for debugging
make dev-logs-api

# 7. Repeat steps 3-6

# 8. When done, stop services
make dev-stop
```

### Making Changes

#### Adding a New Endpoint

```rust
// File: crates/api/src/routes/mod.rs

// Add new route
pub async fn new_endpoint() -> Json<serde_json::Value> {
    Json(json!({
        "message": "Hello from new endpoint"
    }))
}

// Register route in router
pub fn router() -> Router {
    Router::new()
        .route("/health", get(health_check))
        .route("/new", get(new_endpoint)) // Add this line
}
```

Save the file and watch it rebuild automatically!

#### Adding a New Dependency

```toml
# File: crates/api/Cargo.toml

[dependencies]
# ... existing dependencies
new-crate = "1.0"
```

Save and cargo-watch will automatically fetch and compile the new dependency.

#### Modifying Database Schema

```sql
-- File: docker/seed/custom-migration.sql

ALTER TABLE traces ADD COLUMN user_id UUID;
CREATE INDEX idx_traces_user_id ON traces(user_id);
```

Apply the changes:
```bash
make dev-shell-api
psql -h timescaledb -U postgres -d llm_observatory < /app/docker/seed/custom-migration.sql
```

### Working with Multiple Services

Start specific services:
```bash
# Only start infrastructure and API
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up timescaledb redis api

# Or use profiles
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --scale collector=0 --scale storage=0
```

## Testing

### Running Tests

```bash
# All services
make dev-test

# Specific service
make dev-test-api
make dev-test-collector
make dev-test-storage

# With verbose output
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api cargo test -- --nocapture
```

### Integration Testing

```bash
# Run integration tests
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api cargo test --test integration_tests

# With database fixture
docker-compose -f docker-compose.yml -f docker-compose.dev.yml run --rm dev-utils sh -c "psql < /seed-data/reset.sql && psql < /seed-data/seed.sql"
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api cargo test --test integration_tests
```

### Manual API Testing

```bash
# Health check
curl http://localhost:8080/health

# Send sample trace to collector
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-app"}
        }]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": "1544712660000000000",
          "endTimeUnixNano": "1544712661000000000"
        }]
      }]
    }]
  }'

# Query API
curl http://localhost:8080/api/v1/traces?limit=10

# Check metrics
curl http://localhost:9092/metrics
```

## Performance Optimization

### Current Optimizations

The development environment is pre-optimized for fast iteration:

#### Docker Layer Caching
- Dependencies built in separate layer
- Only rebuilt when Cargo.toml changes
- Source code in separate layer

#### Cargo Incremental Compilation
- `CARGO_INCREMENTAL=1` enabled
- Only recompiles changed modules
- 2-3 second rebuild times

#### Shared Build Caches
- Cargo registry shared across services
- Git dependencies shared
- No re-downloading on rebuild

#### PostgreSQL Development Mode
- `fsync=off` - No disk sync waits
- `synchronous_commit=off` - Async commits
- `full_page_writes=off` - Reduced WAL
- Faster writes, safe for development

#### Redis Development Mode
- No persistence (`appendonly=no`)
- No snapshots (`save=""`)
- Faster restarts

### Measuring Performance

```bash
# Time a rebuild
time docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api cargo build

# Watch rebuild times in logs
make dev-logs-api | grep "Finished dev"

# Check Docker stats
docker stats llm-observatory-api-dev
```

### If Rebuilds Are Slow

1. **Check Docker resources:**
   ```bash
   # Verify Docker has enough resources
   docker info | grep -i memory
   docker info | grep -i cpus
   ```

2. **Clear build cache if corrupted:**
   ```bash
   # Remove target volumes
   docker volume rm llm-observatory-api-target
   docker volume rm llm-observatory-collector-target
   docker volume rm llm-observatory-storage-target

   # Restart services
   make dev-stop
   make dev-start
   ```

3. **Check disk I/O:**
   ```bash
   # Monitor disk I/O
   iostat -x 1

   # If slow, consider using tmpfs for target directory (Linux only)
   # Add to docker-compose.dev.yml:
   tmpfs:
     - /app/target:size=2G
   ```

4. **Enable sccache:**
   ```bash
   # Install in container
   docker-compose exec api cargo install sccache

   # Add environment variables (see Hot Reload section)
   ```

## Troubleshooting

### Services Won't Start

**Check Docker is running:**
```bash
docker info
```

**Check .env file exists:**
```bash
ls -la .env
```

**Check port conflicts:**
```bash
# Check if ports are in use
lsof -i :8080
lsof -i :5432
lsof -i :6379
```

**View service logs:**
```bash
make dev-logs
```

### Hot Reload Not Working

**Verify cargo-watch is running:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs api | grep "cargo watch"
```

**Check file mounts:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api ls -la /app/crates
```

**Verify changes are saved:**
```bash
# Check file timestamp
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api stat /app/crates/api/src/main.rs
```

### Slow Rebuilds

**Check Docker resources:**
```bash
docker stats
```

**Check available disk space:**
```bash
df -h
```

**Clear cargo cache:**
```bash
docker volume rm llm-observatory-cargo-registry
docker volume rm llm-observatory-cargo-git
make dev-rebuild
```

### Database Connection Issues

**Check database is running:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml ps timescaledb
```

**Check database health:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec timescaledb pg_isready -U postgres
```

**View database logs:**
```bash
make dev-logs-db
```

**Reset database:**
```bash
make dev-reset
```

### Container Memory Issues

**Increase Docker memory limit** (Docker Desktop → Settings → Resources)

**Monitor memory usage:**
```bash
docker stats
```

**Reduce concurrent services:**
```bash
# Start only essential services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up timescaledb redis api
```

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [cargo-watch Documentation](https://github.com/watchexec/cargo-watch)
- [Rust Book - Development Process](https://doc.rust-lang.org/book/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Project README](../README.md)
- [Contributing Guide](../CONTRIBUTING.md)

## Getting Help

If you encounter issues not covered here:

1. Check the [GitHub Issues](https://github.com/llm-observatory/llm-observatory/issues)
2. Search existing issues or create a new one
3. Join our community Discord (link in README)
4. Review the [Troubleshooting](#troubleshooting) section

## Next Steps

- Explore the codebase in `crates/`
- Review architecture documentation in `docs/`
- Check out example integrations in `examples/`
- Read the [Contributing Guide](../CONTRIBUTING.md)
- Set up your IDE for Rust development

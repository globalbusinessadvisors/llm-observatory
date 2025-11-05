# Docker Workflows for LLM Observatory

Comprehensive guide to development, testing, debugging, and operational workflows using Docker for LLM Observatory.

## Table of Contents

- [Development Workflow](#development-workflow)
- [Testing Workflow](#testing-workflow)
- [Debugging Workflow](#debugging-workflow)
- [Database Management](#database-management)
- [Monitoring and Observability](#monitoring-and-observability)
- [Common Tasks](#common-tasks)
- [Best Practices](#best-practices)

---

## Development Workflow

### Hot Reload Development Setup

For Rust development with automatic rebuilding when code changes:

#### Option 1: Using cargo-watch (Recommended)

```bash
# Install cargo-watch
cargo install cargo-watch

# Start infrastructure
docker compose up -d

# Run with hot reload in one terminal
cargo watch -x 'run --bin llm-observatory-api'

# Run tests on changes in another terminal
cargo watch -x 'test'
```

#### Option 2: Using Docker Compose with Volume Mounts

Create `docker/compose/docker-compose.dev.yml`:

```yaml
version: '3.8'

services:
  # Extend the base services
  api:
    build:
      context: .
      dockerfile: crates/api/Dockerfile.dev
    volumes:
      # Mount source code for hot reload
      - ./crates:/app/crates:ro
      - ./Cargo.toml:/app/Cargo.toml:ro
      - ./Cargo.lock:/app/Cargo.lock:ro
      # Cargo cache
      - cargo-cache:/usr/local/cargo/registry
      - cargo-target:/app/target
    environment:
      - RUST_LOG=debug
      - DATABASE_URL=postgresql://llm_observatory_app:password@timescaledb:5432/llm_observatory
      - REDIS_URL=redis://:redis_password@redis:6379/0
    ports:
      - "8080:8080"
    depends_on:
      timescaledb:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - llm-observatory-network
    command: cargo watch -x 'run --bin llm-observatory-api'

  collector:
    build:
      context: .
      dockerfile: crates/collector/Dockerfile.dev
    volumes:
      - ./crates:/app/crates:ro
      - ./Cargo.toml:/app/Cargo.toml:ro
      - cargo-cache:/usr/local/cargo/registry
      - cargo-target:/app/target
    environment:
      - RUST_LOG=debug
      - DATABASE_URL=postgresql://llm_observatory_app:password@timescaledb:5432/llm_observatory
      - REDIS_URL=redis://:redis_password@redis:6379/0
    ports:
      - "4317:4317"  # OTLP gRPC
      - "4318:4318"  # OTLP HTTP
    depends_on:
      timescaledb:
        condition: service_healthy
    networks:
      - llm-observatory-network
    command: cargo watch -x 'run --bin llm-observatory-collector'

volumes:
  cargo-cache:
    name: llm-observatory-cargo-cache
  cargo-target:
    name: llm-observatory-cargo-target

networks:
  llm-observatory-network:
    external: true
```

Start development environment:

```bash
# Start infrastructure
docker compose up -d

# Start development services
docker compose -f docker/compose/docker-compose.dev.yml up -d

# View logs
docker compose -f docker/compose/docker-compose.dev.yml logs -f api
```

### Local Development (Without Docker for App)

Run infrastructure in Docker, application locally:

```bash
# Start infrastructure only
docker compose up -d

# Set environment variables
export DATABASE_URL="postgresql://llm_observatory_app:password@localhost:5432/llm_observatory"
export REDIS_URL="redis://:redis_password@localhost:6379/0"
export RUST_LOG=debug

# Run application locally with hot reload
cargo watch -x 'run --bin llm-observatory-api'

# In another terminal, run collector
cargo watch -x 'run --bin llm-observatory-collector'

# Run tests
cargo test
```

### Iterative Database Schema Development

When developing database schema:

```bash
# 1. Make changes to SQL migration files
vim crates/storage/migrations/001_initial_schema.sql

# 2. Apply migrations
docker compose exec timescaledb psql -U postgres -d llm_observatory < crates/storage/migrations/001_initial_schema.sql

# 3. Test the changes
cargo test --test integration_tests

# 4. If changes needed, rollback
docker compose exec timescaledb psql -U postgres -d llm_observatory < crates/storage/migrations/rollback/001_rollback.sql

# 5. Iterate until satisfied

# 6. Reset database for clean state
docker compose down -v
docker compose up -d
# Wait for healthy status
docker compose exec timescaledb psql -U postgres -d llm_observatory < crates/storage/migrations/001_initial_schema.sql
```

### Code-Database Sync Workflow

```bash
# 1. Generate Rust types from database schema (using sqlx)
cargo sqlx prepare --database-url postgresql://postgres:postgres@localhost:5432/llm_observatory

# 2. This creates .sqlx/ directory with offline query data

# 3. Commit the .sqlx/ directory to version control
git add .sqlx/
git commit -m "Update database schema types"

# 4. Other developers can now build without database access
cargo build --features sqlx/offline
```

---

## Testing Workflow

### Unit Testing

```bash
# Run all unit tests
cargo test --lib

# Run tests for specific crate
cargo test -p llm-observatory-core

# Run tests with output
cargo test -- --nocapture

# Run tests matching pattern
cargo test test_span_creation
```

### Integration Testing with Docker

```bash
# Start test infrastructure
docker compose up -d

# Wait for services to be healthy
docker compose ps

# Run integration tests
cargo test --test '*' -- --test-threads=1

# Run specific integration test
cargo test --test database_integration
```

### End-to-End Testing

Create a test script `scripts/e2e-test.sh`:

```bash
#!/bin/bash
set -e

echo "Starting E2E test..."

# 1. Start infrastructure
echo "Starting infrastructure..."
docker compose up -d
sleep 30  # Wait for services

# 2. Run database migrations
echo "Running migrations..."
docker compose exec -T timescaledb psql -U postgres -d llm_observatory < crates/storage/migrations/001_initial_schema.sql

# 3. Start application
echo "Starting application..."
cargo build --release
./target/release/llm-observatory-api &
API_PID=$!
./target/release/llm-observatory-collector &
COLLECTOR_PID=$!

sleep 5  # Wait for startup

# 4. Send test spans
echo "Sending test spans..."
curl -X POST http://localhost:8080/api/v1/spans \
  -H "Content-Type: application/json" \
  -d @tests/fixtures/test_span.json

# 5. Verify data in database
echo "Verifying data..."
RESULT=$(docker compose exec -T timescaledb psql -U postgres -d llm_observatory -t -c "SELECT COUNT(*) FROM spans;")
if [ "$RESULT" -gt 0 ]; then
    echo "✓ E2E test passed"
    EXIT_CODE=0
else
    echo "✗ E2E test failed"
    EXIT_CODE=1
fi

# 6. Cleanup
kill $API_PID $COLLECTOR_PID
docker compose down

exit $EXIT_CODE
```

Run E2E tests:

```bash
chmod +x scripts/e2e-test.sh
./scripts/e2e-test.sh
```

### Performance Testing

```bash
# Start infrastructure
docker compose up -d

# Start application
cargo run --release --bin llm-observatory-api &

# Run load test with Apache Bench
ab -n 10000 -c 100 -p tests/fixtures/test_span.json \
   -T application/json http://localhost:8080/api/v1/spans

# Or use wrk for more advanced scenarios
wrk -t12 -c400 -d30s --latency \
    -s tests/load/post_span.lua \
    http://localhost:8080/api/v1/spans

# Monitor database performance during test
docker compose exec timescaledb psql -U postgres -d llm_observatory -c \
  "SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

### Test Data Management

```bash
# Load test fixtures
docker compose exec -T timescaledb psql -U postgres -d llm_observatory < tests/fixtures/sample_data.sql

# Export test data
docker compose exec timescaledb pg_dump -U postgres llm_observatory \
  --data-only --table=spans > tests/fixtures/sample_data.sql

# Reset test database
docker compose exec timescaledb psql -U postgres -c "DROP DATABASE IF EXISTS llm_observatory_test;"
docker compose exec timescaledb psql -U postgres -c "CREATE DATABASE llm_observatory_test;"
```

---

## Debugging Workflow

### Interactive Debugging with Container

```bash
# Exec into running container
docker compose exec timescaledb bash

# Or start a shell in the API container (if running)
docker compose -f docker/compose/docker-compose.dev.yml exec api bash

# Inside container, use psql
psql -U postgres -d llm_observatory

# Or use Redis CLI
redis-cli -h redis -p 6379 -a redis_password
```

### Debugging Database Queries

```bash
# Enable query logging
docker compose exec timescaledb psql -U postgres -c \
  "ALTER DATABASE llm_observatory SET log_statement = 'all';"

# Restart to apply
docker compose restart timescaledb

# View logs in real-time
docker compose logs -f timescaledb | grep "LOG:"

# Disable after debugging
docker compose exec timescaledb psql -U postgres -c \
  "ALTER DATABASE llm_observatory SET log_statement = 'mod';"
```

### Analyzing Slow Queries

```bash
# View slowest queries
docker compose exec timescaledb psql -U postgres -d llm_observatory <<EOF
SELECT
    substring(query, 1, 100) AS query_snippet,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS mean_ms,
    ROUND(total_exec_time::numeric, 2) AS total_ms
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
EOF

# Analyze specific query
docker compose exec timescaledb psql -U postgres -d llm_observatory <<EOF
EXPLAIN ANALYZE
SELECT * FROM spans
WHERE ts > NOW() - INTERVAL '1 hour'
ORDER BY ts DESC
LIMIT 100;
EOF
```

### Debugging Redis Cache

```bash
# Monitor Redis commands in real-time
docker compose exec redis redis-cli -a redis_password MONITOR

# View cache hit rate
docker compose exec redis redis-cli -a redis_password INFO stats | grep hit

# Inspect specific keys
docker compose exec redis redis-cli -a redis_password KEYS 'cache:*'

# Get key value
docker compose exec redis redis-cli -a redis_password GET 'cache:query:123'

# Clear cache (WARNING: Deletes all cached data)
docker compose exec redis redis-cli -a redis_password FLUSHDB
```

### Application Log Debugging

```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f api

# Search logs for errors
docker compose logs api | grep -i error

# Save logs to file
docker compose logs --no-color > debug.log

# View logs with timestamps
docker compose logs -t api

# View last 100 lines
docker compose logs --tail 100 api
```

### Network Debugging

```bash
# Test connectivity between containers
docker compose exec api nc -zv timescaledb 5432
docker compose exec api nc -zv redis 6379

# Check DNS resolution
docker compose exec api nslookup timescaledb
docker compose exec api ping -c 3 timescaledb

# Inspect network
docker network inspect llm-observatory-network

# View network traffic (requires tcpdump in container)
docker compose exec timescaledb tcpdump -i any -n port 5432
```

### Debugging with GDB (Advanced)

For debugging Rust application with GDB:

```dockerfile
# Dockerfile.debug
FROM rust:1.75 AS builder
RUN apt-get update && apt-get install -y gdb
WORKDIR /app
COPY . .
RUN cargo build --bin llm-observatory-api
CMD ["gdb", "-ex", "run", "./target/debug/llm-observatory-api"]
```

```bash
# Build and run with debugger
docker build -f Dockerfile.debug -t llm-obs-debug .
docker run -it --rm \
  --network llm-observatory-network \
  -e DATABASE_URL=postgresql://llm_observatory_app:password@timescaledb:5432/llm_observatory \
  llm-obs-debug
```

---

## Database Management

### Schema Migrations

#### Using sqlx-cli

```bash
# Install sqlx-cli
cargo install sqlx-cli --no-default-features --features postgres

# Create new migration
sqlx migrate add create_spans_table

# Apply migrations
sqlx migrate run --database-url postgresql://postgres:postgres@localhost:5432/llm_observatory

# Revert last migration
sqlx migrate revert --database-url postgresql://postgres:postgres@localhost:5432/llm_observatory

# Check migration status
sqlx migrate info --database-url postgresql://postgres:postgres@localhost:5432/llm_observatory
```

#### Manual Migration Management

Create migration scripts in `crates/storage/migrations/`:

```bash
# migrations/001_initial_schema.sql
CREATE TABLE IF NOT EXISTS spans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trace_id TEXT NOT NULL,
    span_id TEXT NOT NULL,
    parent_span_id TEXT,
    name TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_ms INTEGER,
    attributes JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create hypertable for time-series optimization
SELECT create_hypertable('spans', 'start_time', if_not_exists => TRUE);

-- Create indexes
CREATE INDEX idx_spans_trace_id ON spans(trace_id);
CREATE INDEX idx_spans_start_time ON spans(start_time DESC);
CREATE INDEX idx_spans_attributes ON spans USING GIN(attributes);
```

Apply migrations:

```bash
# Apply all migrations
for file in crates/storage/migrations/*.sql; do
    echo "Applying $file..."
    docker compose exec -T timescaledb psql -U postgres -d llm_observatory < "$file"
done
```

### Backup and Restore

#### Quick Backup

```bash
# Full database backup
docker compose exec timescaledb pg_dump -U postgres llm_observatory \
  | gzip > "backups/llm_obs_$(date +%Y%m%d_%H%M%S).sql.gz"

# Backup specific tables
docker compose exec timescaledb pg_dump -U postgres -t spans llm_observatory \
  > "backups/spans_$(date +%Y%m%d_%H%M%S).sql"

# Backup schema only
docker compose exec timescaledb pg_dump -U postgres --schema-only llm_observatory \
  > "backups/schema_$(date +%Y%m%d_%H%M%S).sql"
```

#### Restore Database

```bash
# Stop application to prevent writes
docker compose stop api collector

# Restore from backup
gunzip -c backups/llm_obs_20240115_120000.sql.gz | \
  docker compose exec -T timescaledb psql -U postgres llm_observatory

# Restart application
docker compose start api collector
```

#### Automated Backups with Cron

```bash
# Add to crontab (crontab -e)
# Daily backup at 2 AM
0 2 * * * cd /path/to/llm-observatory && docker compose --profile backup run backup

# Weekly full backup with upload to S3
0 3 * * 0 cd /path/to/llm-observatory && ./scripts/backup_to_s3.sh
```

### Data Retention and Cleanup

```bash
# Drop old data (example: older than 90 days)
docker compose exec timescaledb psql -U postgres -d llm_observatory <<EOF
DELETE FROM spans WHERE start_time < NOW() - INTERVAL '90 days';
VACUUM ANALYZE spans;
EOF

# Use TimescaleDB retention policies (preferred)
docker compose exec timescaledb psql -U postgres -d llm_observatory <<EOF
-- Add retention policy (drop chunks older than 90 days)
SELECT add_retention_policy('spans', INTERVAL '90 days', if_not_exists => TRUE);

-- View retention policies
SELECT * FROM timescaledb_information.jobs WHERE proc_name = 'policy_retention';
EOF
```

### Database Optimization

```bash
# Analyze query performance
docker compose exec timescaledb psql -U postgres -d llm_observatory <<EOF
-- Reset statistics
SELECT pg_stat_statements_reset();

-- Run your application for a while...

-- View top queries by total time
SELECT
    substring(query, 1, 100) AS query,
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_ms,
    ROUND(mean_exec_time::numeric, 2) AS mean_ms,
    ROUND((100 * total_exec_time / SUM(total_exec_time) OVER ())::numeric, 2) AS percentage
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
EOF

# Vacuum and analyze
docker compose exec timescaledb psql -U postgres -d llm_observatory -c "VACUUM ANALYZE;"

# Reindex
docker compose exec timescaledb psql -U postgres -d llm_observatory -c "REINDEX DATABASE llm_observatory;"

# Update table statistics
docker compose exec timescaledb psql -U postgres -d llm_observatory -c "ANALYZE spans;"
```

---

## Monitoring and Observability

### Health Checks

```bash
# Check all services health
docker compose ps

# Custom health check script
cat > scripts/health-check.sh <<'EOF'
#!/bin/bash

services=("timescaledb:5432" "redis:6379" "grafana:3000")
failed=0

for service in "${services[@]}"; do
    IFS=':' read -r name port <<< "$service"
    if docker compose exec -T "$name" nc -z localhost "$port" 2>/dev/null; then
        echo "✓ $name is healthy"
    else
        echo "✗ $name is unhealthy"
        failed=1
    fi
done

exit $failed
EOF

chmod +x scripts/health-check.sh
./scripts/health-check.sh
```

### Resource Monitoring

```bash
# Real-time resource usage
docker stats

# Formatted output
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Save metrics to file
docker stats --no-stream --format "{{.Container}},{{.CPUPerc}},{{.MemUsage}}" > metrics.csv
```

### Log Aggregation

```bash
# Aggregate logs from all services
docker compose logs --no-color > logs/aggregate_$(date +%Y%m%d).log

# Parse and analyze errors
docker compose logs --no-color | grep -i error | sort | uniq -c | sort -rn

# Extract specific log fields (JSON logs)
docker compose logs api --no-color | jq -r '.level + " " + .message'
```

### Alerting Setup

Create alert rules in `docker/prometheus/alerts/`:

```yaml
# alerts/database_alerts.yml
groups:
  - name: database
    interval: 30s
    rules:
      - alert: HighDatabaseConnections
        expr: pg_stat_database_numbackends > 180
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High number of database connections"
          description: "Database has {{ $value }} connections (threshold: 180)"

      - alert: SlowQueries
        expr: rate(pg_stat_statements_mean_exec_time[5m]) > 5000
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Slow database queries detected"
          description: "Average query time is {{ $value }}ms"
```

---

## Common Tasks

### Adding a New Service

1. **Update docker-compose.yml**:

```yaml
  new-service:
    image: your-image:tag
    container_name: llm-observatory-new-service
    restart: unless-stopped
    environment:
      - CONFIG_VAR=${ENV_VAR}
    ports:
      - "${SERVICE_PORT}:8080"
    volumes:
      - new-service-data:/data
    networks:
      - llm-observatory-network
    depends_on:
      timescaledb:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 3

volumes:
  new-service-data:
    name: llm-observatory-new-service-data
```

2. **Update .env**:

```bash
SERVICE_PORT=8081
ENV_VAR=value
```

3. **Start new service**:

```bash
docker compose up -d new-service
```

### Updating Services

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Update specific service
docker compose pull timescaledb
docker compose up -d timescaledb
```

### Scaling Services

```bash
# Scale API service to 3 instances
docker compose up -d --scale api=3

# For load balancing, add nginx or traefik
# See docker-compose.lb.yml example
```

### Environment Management

```bash
# Development environment
cp .env.example .env.dev
docker compose --env-file .env.dev up -d

# Staging environment
cp .env.example .env.staging
docker compose --env-file .env.staging up -d

# Production environment (separate host)
cp .env.example .env.prod
# Edit .env.prod with production values
docker compose --env-file .env.prod up -d
```

---

## Best Practices

### Security

1. **Never commit .env files**:
```bash
echo ".env*" >> .gitignore
echo "!.env.example" >> .gitignore
```

2. **Use secrets for sensitive data** (Docker Swarm/Kubernetes):
```bash
# Create secrets
echo "my_db_password" | docker secret create db_password -

# Use in docker-compose.yml
secrets:
  db_password:
    external: true
```

3. **Regularly update images**:
```bash
# Check for updates
docker compose pull

# Update and restart
docker compose up -d
```

4. **Enable SSL/TLS for production**:
```yaml
# In docker-compose.prod.yml
environment:
  - DB_SSL_MODE=require
  - REDIS_TLS_ENABLED=true
```

### Performance

1. **Use volumes for data persistence** (not bind mounts):
```yaml
volumes:
  - timescaledb_data:/var/lib/postgresql/data  # ✓ Good
  # - ./data:/var/lib/postgresql/data  # ✗ Slow on macOS/Windows
```

2. **Limit log file sizes**:
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

3. **Set resource limits**:
```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 4G
    reservations:
      cpus: '1.0'
      memory: 2G
```

### Reliability

1. **Always use health checks**:
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

2. **Set restart policies**:
```yaml
restart: unless-stopped  # ✓ Good for most services
# restart: always         # ✗ May restart on intentional stops
# restart: on-failure     # ✓ Good for batch jobs
```

3. **Use depends_on with conditions**:
```yaml
depends_on:
  timescaledb:
    condition: service_healthy  # ✓ Wait for health check
  # timescaledb: {}              # ✗ Only waits for container start
```

### Maintainability

1. **Version pin images**:
```yaml
image: timescale/timescaledb:2.14.2-pg16  # ✓ Specific version
# image: timescale/timescaledb:latest     # ✗ Unpredictable
```

2. **Document environment variables**:
```yaml
# Always add comments
DB_PASSWORD=${DB_PASSWORD:-postgres}  # Database password (required)
```

3. **Use docker compose profiles**:
```yaml
profiles:
  - dev      # For development-only services
  - admin    # For admin tools
  - backup   # For backup services
```

### Development

1. **Use docker compose watch** (Docker Compose 2.22+):
```yaml
develop:
  watch:
    - action: sync
      path: ./crates
      target: /app/crates
    - action: rebuild
      path: Cargo.toml
```

2. **Separate dev and prod configs**:
```bash
docker-compose.yml           # Base config
docker/compose/docker-compose.dev.yml       # Development overrides
docker-compose.prod.yml      # Production config
```

3. **Use .dockerignore**:
```
target/
.git/
.env
*.log
```

---

## Troubleshooting Workflows

See [Troubleshooting Docker Guide](/workspaces/llm-observatory/docs/TROUBLESHOOTING_DOCKER.md) for detailed solutions.

**Quick checks**:

```bash
# 1. Service health
docker compose ps

# 2. Recent errors
docker compose logs --tail 50 | grep -i error

# 3. Disk space
df -h
docker system df

# 4. Network connectivity
docker compose exec api nc -zv timescaledb 5432

# 5. Resource usage
docker stats --no-stream
```

---

## Additional Resources

- [Docker README](/workspaces/llm-observatory/docker/README.md) - Infrastructure overview
- [Quick Start Guide](/workspaces/llm-observatory/docs/QUICK_START.md) - Get started in 5 minutes
- [Architecture Guide](/workspaces/llm-observatory/docs/ARCHITECTURE_DOCKER.md) - System design
- [Operations Manual](/workspaces/llm-observatory/docs/OPERATIONS_MANUAL.md) - Production operations

---

**Built with ❤️ for the LLM community**

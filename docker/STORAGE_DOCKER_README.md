# Storage Service Docker Configuration

This directory contains Docker configuration files for the LLM Observatory Storage Service, which provides a high-performance database layer optimized for COPY protocol bulk operations.

## Overview

The Storage Service is a Rust-based database management layer that:

- **Manages Database Connections**: Connection pooling with configurable limits
- **COPY Protocol Optimization**: High-throughput batch writing for observability data
- **Auto-Migration**: Automatically runs database migrations on startup
- **Health & Metrics**: Exposes health check and Prometheus metrics endpoints
- **Graceful Shutdown**: Properly closes connections and flushes pending writes

## Files

### Dockerfiles

- **`Dockerfile.storage`** - Production multi-stage build
  - Optimized for minimal image size (~50MB final image)
  - Includes sqlx-cli for migrations
  - Non-root user for security
  - Health checks built-in

- **`Dockerfile.storage.dev`** - Development with hot reload
  - Includes cargo-watch for automatic rebuilds
  - Development tools (cargo-nextest, psql, redis-cli)
  - Debug builds for faster compilation
  - Source code mounted as volume

### Entrypoint Scripts

- **`entrypoint-storage.sh`** - Production startup script
  - Waits for database availability
  - Runs migrations automatically
  - Validates configuration
  - Starts storage service

- **`entrypoint-storage-dev.sh`** - Development startup script
  - Enhanced logging with colors
  - Dependency cache management
  - Development tool information
  - Flexible migration handling

### Configuration

- **`.sqlx-config.toml`** - SQLx migration configuration
  - Migration directory paths
  - Database connection settings
  - Compile-time query verification options

## Quick Start

### Production

```bash
# Build and start the storage service
docker-compose up storage

# View logs
docker-compose logs -f storage

# Check health
curl http://localhost:8082/health

# View metrics
curl http://localhost:9092/metrics
```

### Development

```bash
# Start with hot reload
docker-compose --profile dev up storage-dev

# Run tests with hot reload
docker-compose --profile dev run storage-dev cargo watch -x test

# Run benchmarks
docker-compose --profile dev run storage-dev cargo bench

# Access shell
docker-compose --profile dev run storage-dev bash

# Run migrations manually
docker-compose --profile dev run storage-dev sqlx migrate run
```

## Configuration

### Environment Variables

#### Database Configuration

```bash
# Connection URL
DATABASE_URL=postgresql://user:pass@timescaledb:5432/llm_observatory

# Connection Pool
DB_POOL_MIN_SIZE=5          # Minimum connections (default: 5)
DB_POOL_MAX_SIZE=20         # Maximum connections (default: 20)
DB_POOL_TIMEOUT=30          # Connection timeout in seconds (default: 30)
DB_POOL_IDLE_TIMEOUT=300    # Idle timeout in seconds (default: 300)
DB_POOL_MAX_LIFETIME=1800   # Max connection lifetime in seconds (default: 1800)
```

#### COPY Protocol Settings

```bash
# Batch writing optimization
COPY_BATCH_SIZE=10000       # Records per batch (default: 10000)
COPY_FLUSH_INTERVAL=1000    # Flush interval in ms (default: 1000)
COPY_BUFFER_SIZE=8192       # Buffer size in bytes (default: 8192)
COPY_MAX_RETRIES=3          # Max retry attempts (default: 3)
COPY_RETRY_DELAY_MS=100     # Retry delay in ms (default: 100)
```

#### Server Configuration

```bash
# Listening addresses
APP_HOST=0.0.0.0            # API host (default: 0.0.0.0)
APP_PORT=8080               # Internal API port (default: 8080)
METRICS_PORT=9090           # Metrics port (default: 9090)

# Features
HEALTH_CHECK_ENABLED=true   # Enable health endpoint (default: true)
METRICS_ENABLED=true        # Enable metrics endpoint (default: true)
```

#### Logging

```bash
RUST_LOG=info,llm_observatory_storage=debug,sqlx=warn
LOG_FORMAT=json             # json or text (default: json)
RUST_BACKTRACE=1            # Enable backtraces
```

#### Data Retention

```bash
RETENTION_TRACES_DAYS=30    # Trace retention (default: 30)
RETENTION_METRICS_DAYS=90   # Metrics retention (default: 90)
RETENTION_LOGS_DAYS=7       # Log retention (default: 7)
```

#### Migration Control

```bash
SKIP_MIGRATIONS=false       # Skip migrations on startup (default: false)
```

### Ports

| Port | Purpose | External |
|------|---------|----------|
| 8080 | Internal API (health/admin) | 8082 |
| 9090 | Prometheus metrics | 9092 |

External ports can be customized via environment variables:
- `STORAGE_API_PORT=8082` (maps to internal 8080)
- `STORAGE_METRICS_PORT=9092` (maps to internal 9090)

## Performance Tuning

### Connection Pool Sizing

For production workloads:

```bash
# High throughput (lots of concurrent writes)
DB_POOL_MIN_SIZE=10
DB_POOL_MAX_SIZE=50
DB_POOL_TIMEOUT=60

# Balanced (moderate traffic)
DB_POOL_MIN_SIZE=5
DB_POOL_MAX_SIZE=20
DB_POOL_TIMEOUT=30

# Low resource (development/testing)
DB_POOL_MIN_SIZE=2
DB_POOL_MAX_SIZE=10
DB_POOL_TIMEOUT=30
```

### COPY Protocol Tuning

For maximum throughput:

```bash
# High throughput (large batches, less frequent flushes)
COPY_BATCH_SIZE=50000
COPY_FLUSH_INTERVAL=5000
COPY_BUFFER_SIZE=16384

# Balanced (default settings)
COPY_BATCH_SIZE=10000
COPY_FLUSH_INTERVAL=1000
COPY_BUFFER_SIZE=8192

# Low latency (small batches, frequent flushes)
COPY_BATCH_SIZE=1000
COPY_FLUSH_INTERVAL=100
COPY_BUFFER_SIZE=4096
```

### Resource Limits

Adjust Docker resource limits in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'        # CPU limit
      memory: 2G         # Memory limit
    reservations:
      cpus: '0.5'        # CPU reservation
      memory: 512M       # Memory reservation
```

## Monitoring

### Health Checks

The storage service exposes a health endpoint:

```bash
# Check overall health
curl http://localhost:8082/health

# Response format
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "version": "0.1.0",
  "database": {
    "connected": true,
    "latency_ms": 1.23
  },
  "pool": {
    "active": 5,
    "idle": 15,
    "max_size": 20
  }
}
```

### Metrics

Prometheus metrics are available at:

```bash
curl http://localhost:9092/metrics
```

Key metrics include:

- `storage_connection_pool_active` - Active database connections
- `storage_connection_pool_idle` - Idle database connections
- `storage_copy_write_duration_seconds` - COPY operation latency
- `storage_copy_batch_size` - Batch size distribution
- `storage_copy_errors_total` - Write error count
- `storage_query_duration_seconds` - Query latency distribution

### Logs

View structured logs:

```bash
# All logs
docker-compose logs -f storage

# Filter by level
docker-compose logs -f storage | grep ERROR

# JSON logs (production)
docker-compose logs -f storage | jq
```

## Migrations

### Automatic Migrations

By default, migrations run automatically on startup. To disable:

```bash
SKIP_MIGRATIONS=true docker-compose up storage
```

### Manual Migrations

Run migrations manually in a separate container:

```bash
# Run all pending migrations
docker-compose run --rm storage sqlx migrate run

# Check migration status
docker-compose run --rm storage sqlx migrate info

# Dry run (preview migrations without applying)
docker-compose run --rm storage sqlx migrate dry-run
```

### Migration Files

Migration files are located in:
```
crates/storage/migrations/
├── 001_initial_schema.sql
├── 002_add_hypertables.sql
├── 003_create_indexes.sql
├── 004_continuous_aggregates.sql
├── 005_retention_policies.sql
└── 006_supporting_tables.sql
```

## Troubleshooting

### Service Won't Start

1. **Check database connectivity**:
   ```bash
   docker-compose run --rm storage psql $DATABASE_URL -c "SELECT 1"
   ```

2. **Verify migrations**:
   ```bash
   docker-compose run --rm storage sqlx migrate info
   ```

3. **Check logs for errors**:
   ```bash
   docker-compose logs storage | grep ERROR
   ```

### Connection Pool Exhausted

If you see "connection pool exhausted" errors:

1. Increase pool size:
   ```bash
   DB_POOL_MAX_SIZE=50 docker-compose up storage
   ```

2. Check for connection leaks in application code

3. Monitor active connections:
   ```bash
   curl http://localhost:8082/health | jq '.pool'
   ```

### Slow Write Performance

1. **Increase batch size**:
   ```bash
   COPY_BATCH_SIZE=50000 docker-compose up storage
   ```

2. **Reduce flush interval** (write more frequently):
   ```bash
   COPY_FLUSH_INTERVAL=500 docker-compose up storage
   ```

3. **Check database performance**:
   ```bash
   # View slow queries in PostgreSQL logs
   docker-compose logs timescaledb | grep "duration:"
   ```

### Migration Failures

1. **Check migration syntax**:
   ```bash
   docker-compose run --rm storage sqlx migrate dry-run
   ```

2. **Manually fix database state**:
   ```bash
   docker-compose run --rm storage psql $DATABASE_URL
   ```

3. **Reset migrations** (⚠️ destructive):
   ```bash
   # Drop and recreate database
   docker-compose run --rm storage sqlx database drop
   docker-compose run --rm storage sqlx database create
   docker-compose run --rm storage sqlx migrate run
   ```

## Development

### Building Locally

```bash
# Build production image
docker build -f docker/Dockerfile.storage -t llm-observatory-storage:latest .

# Build development image
docker build -f docker/Dockerfile.storage.dev -t llm-observatory-storage:dev .
```

### Testing

```bash
# Run all tests
docker-compose --profile dev run storage-dev cargo nextest run

# Run specific test
docker-compose --profile dev run storage-dev cargo test test_name

# Run benchmarks
docker-compose --profile dev run storage-dev cargo bench
```

### Debugging

```bash
# Access shell in running container
docker-compose exec storage bash

# Run storage service with debug logging
RUST_LOG=debug docker-compose up storage

# Enable SQL query logging
DB_QUERY_LOGGING=true docker-compose up storage
```

## Security

### Production Checklist

- [ ] Change default database passwords
- [ ] Use strong JWT secrets
- [ ] Enable TLS for database connections
- [ ] Restrict network access with firewalls
- [ ] Run as non-root user (default in our images)
- [ ] Enable read-only root filesystem where possible
- [ ] Regular security updates for base images
- [ ] Monitor for suspicious activity

### Secrets Management

Never commit secrets to version control. Use:

1. Environment variables from `.env` (not committed)
2. Docker secrets (for Swarm mode)
3. Kubernetes secrets (for K8s deployments)
4. External secret managers (Vault, AWS Secrets Manager, etc.)

## Advanced Topics

### Multi-Stage Deployment

For zero-downtime deployments:

1. Deploy new version alongside old
2. Run health checks
3. Switch traffic gradually
4. Retire old version

### Scaling

The storage service is stateless and can be horizontally scaled:

```bash
# Scale to 3 instances
docker-compose up --scale storage=3
```

Use a load balancer to distribute traffic across instances.

### Backup and Recovery

Regular database backups are essential:

```bash
# Manual backup
docker-compose --profile backup run backup

# Automated backups (cron)
0 2 * * * docker-compose --profile backup run backup
```

## Additional Resources

- [Storage Service Documentation](../crates/storage/README.md)
- [Migration Guide](../crates/storage/migrations/README.md)
- [COPY Protocol Performance](../crates/storage/COPY_PROTOCOL.md)
- [Performance Benchmarks](../crates/storage/BENCHMARKS.md)

## Support

For issues and questions:

- GitHub Issues: https://github.com/llm-observatory/llm-observatory/issues
- Documentation: https://docs.llm-observatory.io
- Community: https://discord.gg/llm-observatory

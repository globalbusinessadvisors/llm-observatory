# Development Environment Guide

This guide explains how to set up and use the hot-reload development environment for LLM Observatory.

## Quick Start

1. **Start the development environment:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
   ```

2. **Access the services:**
   - API: http://localhost:8080
   - Collector (OTLP HTTP): http://localhost:4318
   - Collector (OTLP gRPC): http://localhost:4317
   - Storage: http://localhost:8081
   - Grafana: http://localhost:3000
   - PgAdmin: http://localhost:5050 (with `--profile admin`)

3. **Make code changes** - The services will automatically reload within 2-3 seconds!

## Architecture

### Services

The development environment includes:

- **TimescaleDB** - PostgreSQL with time-series extensions
- **Redis** - Caching and session storage
- **Grafana** - Visualization and dashboards
- **Collector** - OpenTelemetry collector with LLM processors (hot reload)
- **API** - REST API for querying and managing data (hot reload)
- **Storage** - Data storage and aggregation service (hot reload)
- **dev-utils** - Database utilities for seeding and maintenance

### Hot Reload with cargo-watch

Each Rust service uses `cargo-watch` to monitor file changes and automatically rebuild:

- **Watch scope**: All Rust source files and Cargo.toml files
- **Rebuild time**: 2-3 seconds for incremental builds
- **Behavior**: Clears terminal and shows rebuild reason
- **Delay**: 0.5s to batch multiple file changes

### Volume Mounts

Development volumes are configured for optimal performance:

```yaml
# Source code (read-only, mounted from host)
- ./crates:/app/crates:ro
- ./Cargo.toml:/app/Cargo.toml:ro
- ./Cargo.lock:/app/Cargo.lock:ro

# Cargo caches (shared across services)
- cargo_registry:/usr/local/cargo/registry
- cargo_git:/usr/local/cargo/git

# Build artifacts (per-service for isolation)
- collector_target:/app/target
- api_target:/app/target
- storage_target:/app/target
```

### Build Caching

The development environment uses Docker layer caching and volume mounts:

1. **Dependency layer**: Built once, cached until dependencies change
2. **Source layer**: Rebuilt on code changes (incremental compilation)
3. **Cargo cache**: Shared registry and git caches across rebuilds
4. **Target directory**: Per-service volumes for isolated incremental builds

## Usage

### Starting Services

**All services:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

**Specific services:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up api collector
```

**Background mode:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

**With admin tools (PgAdmin):**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml --profile admin up
```

### Viewing Logs

**All services:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f
```

**Specific service:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f api
```

**With timestamps:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f --timestamps api
```

### Stopping Services

**Stop all:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down
```

**Stop and remove volumes:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v
```

### Database Operations

**Seed development data:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml run --rm dev-utils sh -c "psql < /seed-data/seed.sql"
```

**Reset database:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml run --rm dev-utils sh -c "psql < /seed-data/reset.sql"
```

**Access PostgreSQL shell:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec timescaledb psql -U postgres -d llm_observatory
```

**Run migrations (once migration system is implemented):**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api /app/target/debug/llm-observatory-api migrate
```

### Rebuilding Services

**Rebuild after dependency changes:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache
```

**Rebuild specific service:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache api
```

**Rebuild and restart:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

### Cleaning Up

**Remove stopped containers:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml rm
```

**Clean build cache volumes:**
```bash
docker volume rm llm-observatory-collector-target
docker volume rm llm-observatory-api-target
docker volume rm llm-observatory-storage-target
```

**Complete cleanup (WARNING: removes all data):**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v
docker volume prune -f
```

## Configuration

### Environment Variables

Development environment variables are set in `.env` file. Key settings:

```bash
# Development mode
ENVIRONMENT=development
DEBUG=true
AUTO_RELOAD=true

# Logging (verbose for development)
RUST_LOG=debug
RUST_BACKTRACE=1
LOG_LEVEL=debug
DB_QUERY_LOGGING=true

# Database (relaxed for development)
DB_POOL_MAX_SIZE=20
DB_POOL_MIN_SIZE=5

# CORS (permissive for development)
CORS_ORIGINS=*

# Rate limiting (relaxed for development)
RATE_LIMIT_REQUESTS=1000
RATE_LIMIT_WINDOW=60
```

### Service Ports

| Service | Host Port | Container Port | Description |
|---------|-----------|----------------|-------------|
| API | 8080 | 8080 | REST API |
| API Metrics | 9092 | 9090 | Prometheus metrics |
| Collector HTTP | 4318 | 4318 | OTLP HTTP endpoint |
| Collector gRPC | 4317 | 4317 | OTLP gRPC endpoint |
| Collector Metrics | 9091 | 9090 | Prometheus metrics |
| Storage | 8081 | 8081 | Storage service |
| Storage Metrics | 9093 | 9090 | Prometheus metrics |
| TimescaleDB | 5432 | 5432 | PostgreSQL |
| Redis | 6379 | 6379 | Redis cache |
| Grafana | 3000 | 3000 | Dashboards |
| PgAdmin | 5050 | 80 | DB admin UI |

### Performance Tuning

For faster rebuilds, adjust these settings:

**PostgreSQL (development optimizations in docker-compose.dev.yml):**
- `fsync=off` - Faster writes, safe for development
- `synchronous_commit=off` - Async commits
- `full_page_writes=off` - Reduce WAL size
- `checkpoint_timeout=1h` - Less frequent checkpoints

**Redis (development optimizations):**
- `appendonly=no` - No persistence
- `save=""` - No RDB snapshots
- Lower memory limit for faster restarts

**Cargo incremental compilation:**
- `CARGO_INCREMENTAL=1` - Enable incremental builds
- Per-service target directories avoid conflicts
- Shared cargo registry and git caches

## Troubleshooting

### Slow Rebuilds

1. **Check cargo cache volumes:**
   ```bash
   docker volume ls | grep cargo
   ```

2. **Verify incremental compilation:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api sh -c 'echo $CARGO_INCREMENTAL'
   ```

3. **Clear target directory if corrupted:**
   ```bash
   docker volume rm llm-observatory-api-target
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build api
   ```

### Service Won't Start

1. **Check logs:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs api
   ```

2. **Verify database connection:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec timescaledb pg_isready -U postgres
   ```

3. **Check port conflicts:**
   ```bash
   lsof -i :8080  # Check if port is already in use
   ```

### Hot Reload Not Working

1. **Verify cargo-watch is running:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs api | grep "cargo watch"
   ```

2. **Check file permissions:**
   ```bash
   ls -la crates/api/src/
   ```

3. **Ensure volumes are mounted:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api ls -la /app/crates
   ```

### Database Issues

1. **Reset database:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
   ```

2. **Check database health:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec timescaledb pg_isready
   ```

3. **View database logs:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs timescaledb
   ```

## Development Workflow

### Typical Development Session

1. **Start the environment:**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
   ```

2. **Make code changes** in your editor

3. **Watch automatic rebuild** in the terminal (2-3 seconds)

4. **Test the changes:**
   ```bash
   curl http://localhost:8080/health
   ```

5. **View logs** for debugging:
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f api
   ```

6. **Iterate** - repeat steps 2-5

### Adding New Dependencies

1. **Update Cargo.toml** in the appropriate crate

2. **Rebuild the service** (cargo-watch will handle this automatically, but first build may be slower)

3. **Wait for rebuild** - you'll see cargo fetching new dependencies

### Testing Changes

**Manual testing:**
```bash
# Health check
curl http://localhost:8080/health

# Send test trace
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d @test-data/sample-trace.json
```

**Run unit tests in container:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api cargo test
```

**Run integration tests:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api cargo test --test integration_tests
```

## Best Practices

1. **Use `.env` file** for all configuration (copy from `.env.example`)
2. **Monitor logs** with `-f` flag to see real-time updates
3. **Seed database** after major schema changes
4. **Clean volumes** periodically to free up space
5. **Keep services running** - starting/stopping is slower than hot reload
6. **Use PgAdmin** for complex database queries (start with `--profile admin`)
7. **Check metrics endpoints** for service health (ports 9090-9093)

## Next Steps

- Set up your IDE for Rust development
- Configure Git hooks for code quality
- Add custom seed data for your use case
- Create custom Grafana dashboards
- Set up debugging with breakpoints (requires separate setup)

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [cargo-watch Documentation](https://github.com/watchexec/cargo-watch)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Rust Development in Docker](https://www.lpalmieri.com/posts/fast-rust-docker-builds/)

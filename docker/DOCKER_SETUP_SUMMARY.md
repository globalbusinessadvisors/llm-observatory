# LLM Observatory - Docker Setup Summary

## Files Created

### Dockerfiles

1. **`docker/Dockerfile.collector`** (Production)
   - Multi-stage build optimized for size (~50MB)
   - Rust 1.75 slim base
   - Protobuf compiler for OTLP
   - Non-root user for security
   - Health checks included
   - Release optimizations (strip, LTO)

2. **`docker/Dockerfile.collector.dev`** (Development)
   - Based on rust:1.75-slim
   - Includes cargo-watch for hot reload
   - Debug symbols enabled
   - Development tools (cargo-expand, cargo-audit)
   - Fast incremental builds

### Docker Compose Files

3. **`docker/compose/docker-compose.app.yml`** (Application Services)
   - Storage service configuration
   - Collector service (production)
   - Collector-dev service (development with hot reload)
   - Complete environment variables
   - Health checks and dependencies
   - Volume configurations

4. **`docker/compose/docker-compose.dev.yml`** (Development Overrides) - EXISTS
   - Optimized for local development
   - Smaller resource limits
   - Debug logging enabled
   - Hot reload for all services
   - Faster startup times

### Configuration Files

5. **`docker/config/collector.yaml`**
   - Comprehensive collector configuration
   - OTLP receivers (gRPC + HTTP)
   - LLM-specific processors
   - Multiple exporters (storage, database, prometheus)
   - Pipeline definitions
   - Performance tuning settings
   - Feature flags

### Environment Configuration

6. **`.env.example`** (Updated)
   - Added Storage Service variables
   - Added Collector Service variables
   - Port configurations
   - Batch processing settings
   - LLM processing features
   - Logging configurations
   - OTLP protocol settings

### Documentation

7. **`docker/COLLECTOR_README.md`**
   - Complete collector documentation
   - Architecture overview
   - Feature descriptions
   - Usage instructions
   - Configuration reference
   - Troubleshooting guide
   - Integration examples
   - Performance tuning

8. **`docker/QUICKSTART.collector.md`**
   - 5-minute quick start guide
   - Step-by-step setup
   - First trace examples
   - Common commands
   - Troubleshooting tips

9. **`docker/Makefile.collector`**
   - Convenient make commands
   - Build targets
   - Run/stop commands
   - Testing utilities
   - Monitoring helpers
   - CI/CD targets

## Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Docker Network                             │
│  (llm-observatory-network)                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │  Collector   │───▶│   Storage    │───▶│ TimescaleDB  │     │
│  │  Service     │    │   Service    │    │              │     │
│  │              │    │              │    │              │     │
│  │ OTLP: 4327/8 │    │ API: 8081    │    │ Port: 5432   │     │
│  │ Metrics: 9091│    │ Metrics: 9092│    │              │     │
│  │ Health: 8082 │    │              │    │              │     │
│  └──────────────┘    └──────────────┘    └──────────────┘     │
│         │                    │                                 │
│         │                    │                                 │
│         └────────────────────┴──────────────┐                  │
│                                              │                  │
│                                     ┌────────▼────────┐         │
│                                     │     Redis       │         │
│                                     │   Port: 6379    │         │
│                                     └─────────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Port Mappings

### Collector Service (Production)
- **4327**: OTLP gRPC receiver
- **4328**: OTLP HTTP receiver
- **9091**: Prometheus metrics
- **8082**: Health check

### Collector Service (Development)
- **4337**: OTLP gRPC receiver
- **4338**: OTLP HTTP receiver
- **9191**: Prometheus metrics
- **8182**: Health check

### Storage Service
- **8081**: HTTP API and Health
- **9092**: Prometheus metrics

### Infrastructure
- **5432**: TimescaleDB (PostgreSQL)
- **6379**: Redis
- **9090**: Prometheus
- **3000**: Grafana
- **4317/4318**: Jaeger OTLP (separate from collector)

## Quick Start

### 1. Setup Environment

```bash
# Copy environment file
cp .env.example .env

# Edit as needed
nano .env
```

### 2. Start Infrastructure

```bash
# Start database and cache
docker compose up -d timescaledb redis
```

### 3. Start Application Services

```bash
# Production mode
docker compose -f docker-compose.yml -f docker/compose/docker-compose.app.yml up -d

# Development mode
docker compose -f docker-compose.yml -f docker/compose/docker-compose.dev.yml -f docker/compose/docker-compose.app.yml up -d
```

### 4. Verify Services

```bash
# Check all services
docker compose ps

# Check collector health
curl http://localhost:8082/health

# Check collector metrics
curl http://localhost:9091/metrics
```

## Environment Variables

### Critical Variables

```bash
# Database (Required)
DATABASE_URL=postgresql://llm_observatory_app:password@timescaledb:5432/llm_observatory
DB_APP_USER=llm_observatory_app
DB_APP_PASSWORD=change_me_in_production

# Redis (Required)
REDIS_URL=redis://:redis_password@redis:6379/0
REDIS_PASSWORD=redis_password

# Collector Ports (Optional - defaults shown)
COLLECTOR_OTLP_GRPC_PORT=4327
COLLECTOR_OTLP_HTTP_PORT=4328
COLLECTOR_METRICS_PORT=9091
COLLECTOR_HEALTH_PORT=8082

# LLM Processing (Optional)
COLLECTOR_LLM_ENRICHMENT_ENABLED=true
COLLECTOR_TOKEN_COUNTING_ENABLED=true
COLLECTOR_COST_CALCULATION_ENABLED=true
COLLECTOR_PII_REDACTION_ENABLED=false

# Batch Processing (Optional)
COLLECTOR_BATCH_SIZE=500
COLLECTOR_BATCH_TIMEOUT=10
COLLECTOR_MAX_QUEUE_SIZE=10000
COLLECTOR_NUM_WORKERS=4
```

## Docker Commands Cheat Sheet

### Build

```bash
# Build production collector
docker build -f docker/Dockerfile.collector -t llm-observatory/collector:latest .

# Build development collector
docker build -f docker/Dockerfile.collector.dev -t llm-observatory/collector:dev .

# Build without cache
docker build --no-cache -f docker/Dockerfile.collector -t llm-observatory/collector:latest .
```

### Run

```bash
# Start all services
docker compose -f docker-compose.yml -f docker/compose/docker-compose.app.yml up -d

# Start only collector
docker compose -f docker/compose/docker-compose.app.yml up -d collector

# Start with development overrides
docker compose -f docker-compose.yml -f docker/compose/docker-compose.dev.yml -f docker/compose/docker-compose.app.yml up -d

# Start dev collector with hot reload
docker compose -f docker/compose/docker-compose.app.yml --profile dev up -d collector-dev
```

### Monitor

```bash
# View logs
docker compose -f docker/compose/docker-compose.app.yml logs -f collector

# View specific service
docker compose -f docker/compose/docker-compose.app.yml logs -f storage

# Check status
docker compose -f docker/compose/docker-compose.app.yml ps

# Check health
docker compose -f docker/compose/docker-compose.app.yml exec collector /usr/local/bin/collector health-check
```

### Debug

```bash
# Shell into collector
docker compose -f docker/compose/docker-compose.app.yml exec collector sh

# Check environment
docker compose -f docker/compose/docker-compose.app.yml exec collector env

# Check configuration
docker compose -f docker/compose/docker-compose.app.yml exec collector cat /app/config/collector.yaml

# Check connectivity
docker compose -f docker/compose/docker-compose.app.yml exec collector ping storage
docker compose -f docker/compose/docker-compose.app.yml exec collector ping timescaledb
```

### Cleanup

```bash
# Stop services
docker compose -f docker/compose/docker-compose.app.yml down

# Stop and remove volumes
docker compose -f docker/compose/docker-compose.app.yml down -v

# Remove images
docker rmi llm-observatory/collector:latest llm-observatory/collector:dev

# Full cleanup
docker compose -f docker-compose.yml -f docker/compose/docker-compose.app.yml down -v --rmi all
```

## Using Make (Recommended)

```bash
# Build
make -f docker/Makefile.collector build
make -f docker/Makefile.collector build-dev

# Run
make -f docker/Makefile.collector up
make -f docker/Makefile.collector up-dev

# Monitor
make -f docker/Makefile.collector logs
make -f docker/Makefile.collector health
make -f docker/Makefile.collector metrics

# Test
make -f docker/Makefile.collector test-http
make -f docker/Makefile.collector test-grpc
make -f docker/Makefile.collector benchmark

# Cleanup
make -f docker/Makefile.collector down
make -f docker/Makefile.collector clean
```

## Development Workflow

### Hot Reload Development

```bash
# 1. Start dev services
docker compose -f docker-compose.yml -f docker/compose/docker-compose.dev.yml -f docker/compose/docker-compose.app.yml --profile dev up -d

# 2. Edit source code in crates/collector/

# 3. Watch logs for automatic rebuild
docker compose logs -f collector-dev

# 4. Test changes immediately
curl -X POST http://localhost:4338/v1/traces -d @test_trace.json
```

### Testing Changes

```bash
# Run unit tests
docker compose -f docker/compose/docker-compose.app.yml exec collector-dev cargo test

# Run integration tests
docker compose -f docker/compose/docker-compose.app.yml exec collector-dev cargo test --features integration

# Run benchmarks
docker compose -f docker/compose/docker-compose.app.yml exec collector-dev cargo bench
```

## Production Deployment

### Security Checklist

- [ ] Use strong passwords for DB_APP_PASSWORD, REDIS_PASSWORD
- [ ] Enable TLS for OTLP receivers
- [ ] Configure PII redaction (COLLECTOR_PII_REDACTION_ENABLED=true)
- [ ] Use secrets management (Docker secrets, Kubernetes secrets)
- [ ] Restrict CORS origins in collector.yaml
- [ ] Enable authentication/authorization
- [ ] Set resource limits (memory, CPU)
- [ ] Use non-default ports
- [ ] Regular security updates

### Performance Tuning

```bash
# High throughput
COLLECTOR_NUM_WORKERS=16
COLLECTOR_BATCH_SIZE=2000
COLLECTOR_MAX_QUEUE_SIZE=50000
DB_POOL_MAX_SIZE=100

# Low latency
COLLECTOR_BATCH_TIMEOUT=1
COLLECTOR_NUM_WORKERS=8
OTLP_COMPRESSION=none

# Memory constrained
COLLECTOR_BATCH_SIZE=100
COLLECTOR_MAX_QUEUE_SIZE=1000
COLLECTOR_NUM_WORKERS=2
```

## Troubleshooting

### Collector won't start

```bash
# Check dependencies
docker compose ps timescaledb redis storage

# Check logs
docker compose -f docker/compose/docker-compose.app.yml logs collector

# Verify database connection
docker compose -f docker/compose/docker-compose.app.yml exec collector psql $DATABASE_URL -c "SELECT 1"
```

### Port conflicts

```bash
# Check what's using the port
sudo lsof -i :4327

# Use different ports
export COLLECTOR_OTLP_GRPC_PORT=4427
docker compose -f docker/compose/docker-compose.app.yml up -d collector
```

### High memory usage

```bash
# Check current usage
docker stats collector

# Adjust limits in collector.yaml
# memory_limiter:
#   limit_mib: 256
#   spike_limit_mib: 64

# Reduce batch size
COLLECTOR_BATCH_SIZE=100
COLLECTOR_MAX_QUEUE_SIZE=1000
```

### No data being received

```bash
# 1. Check collector health
curl http://localhost:8082/health

# 2. Check logs for errors
docker compose -f docker/compose/docker-compose.app.yml logs collector | grep -i error

# 3. Send test trace
curl -X POST http://localhost:4328/v1/traces -d @test_trace.json

# 4. Check metrics
curl http://localhost:9091/metrics | grep spans_received
```

## Next Steps

1. Read [COLLECTOR_README.md](COLLECTOR_README.md) for detailed documentation
2. Follow [QUICKSTART.collector.md](QUICKSTART.collector.md) for hands-on guide
3. Configure monitoring dashboards
4. Set up alerting
5. Integrate with your application

## Support

- Documentation: https://docs.llm-observatory.io
- GitHub Issues: https://github.com/llm-observatory/llm-observatory/issues
- Discord: https://discord.gg/llm-observatory

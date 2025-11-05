# LLM Observatory - Development Quick Start

Fast setup guide for the hot-reload development environment. For detailed documentation, see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Prerequisites

- Docker 24.0+ with Docker Compose 2.20+
- 8GB+ RAM, 10GB+ disk space

## Setup (One Time)

```bash
# 1. Clone repository
git clone https://github.com/llm-observatory/llm-observatory.git
cd llm-observatory

# 2. Create environment file
make env
# Edit .env if needed (defaults work for development)

# 3. Start development environment
make dev-start

# 4. Seed database with sample data (optional)
make dev-seed
```

## Daily Development

### Start/Stop

```bash
make dev-start      # Start all services
make dev-stop       # Stop all services
make dev-restart    # Restart all services
```

### Logs

```bash
make dev-logs              # All services
make dev-logs-api          # API only
make dev-logs-collector    # Collector only
make dev-logs-storage      # Storage only
```

### Testing

```bash
make dev-test       # Run all tests
make dev-test-api   # Test API only
```

### Database

```bash
make dev-seed       # Add sample data
make dev-reset      # Reset database
make db-shell       # PostgreSQL shell
```

## Hot Reload

Just edit files in `crates/` - services rebuild automatically in 2-3 seconds!

```bash
# Watch logs to see rebuild
make dev-logs-api

# Make a change
vim crates/api/src/main.rs

# Save and watch automatic rebuild!
```

## Service URLs

- **API**: http://localhost:8080
- **Collector (HTTP)**: http://localhost:4318
- **Collector (gRPC)**: http://localhost:4317
- **Storage**: http://localhost:8081
- **Grafana**: http://localhost:3000 (admin/admin)
- **Metrics**:
  - API: http://localhost:9092/metrics
  - Collector: http://localhost:9091/metrics
  - Storage: http://localhost:9093/metrics

## Quick Tests

```bash
# Health check
curl http://localhost:8080/health

# Send test trace
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test"}
        }]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "test",
          "startTimeUnixNano": "1544712660000000000",
          "endTimeUnixNano": "1544712661000000000"
        }]
      }]
    }]
  }'

# Check metrics
curl http://localhost:9092/metrics
```

## Common Commands

| Task | Command |
|------|---------|
| Start environment | `make dev-start` |
| Stop environment | `make dev-stop` |
| View logs | `make dev-logs` |
| Run tests | `make dev-test` |
| Seed database | `make dev-seed` |
| Reset database | `make dev-reset` |
| Shell in container | `make dev-shell-api` |
| Rebuild services | `make dev-rebuild` |
| Clean everything | `make dev-clean` |
| Show all commands | `make help` |

## Troubleshooting

### Services won't start
```bash
# Check Docker is running
docker info

# Check for port conflicts
lsof -i :8080

# View logs
make dev-logs
```

### Hot reload not working
```bash
# Verify cargo-watch is running
make dev-logs-api | grep "cargo watch"

# Check mounts
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec api ls /app/crates
```

### Slow rebuilds
```bash
# Check Docker resources
docker stats

# Clear build cache
docker volume rm llm-observatory-api-target
make dev-restart
```

### Database issues
```bash
# Reset database
make dev-reset

# Check database health
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec timescaledb pg_isready
```

## Development Workflow

```bash
# 1. Start services
make dev-start

# 2. Watch logs in another terminal
make dev-logs-api

# 3. Edit code
vim crates/api/src/main.rs

# 4. Save - watch automatic rebuild (2-3 seconds)

# 5. Test changes
curl http://localhost:8080/health

# 6. Repeat 3-5

# 7. Stop when done
make dev-stop
```

## Alternative Commands

If `make` is not available:

```bash
# Start
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Stop
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

# Logs
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Or use the shell script
./scripts/dev.sh start
./scripts/dev.sh stop
./scripts/dev.sh logs
```

## Performance Tips

1. **Keep services running** - Starting/stopping is slower than hot reload
2. **Use focused logs** - `make dev-logs-api` instead of all services
3. **Seed once** - Database seeding only needed once per session
4. **Monitor resources** - Use `docker stats` to check memory/CPU
5. **Clear cache if slow** - Remove target volumes and rebuild

## Next Steps

- Read detailed documentation: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- Explore the codebase: `crates/`
- Review architecture: `docs/`
- Check examples: `examples/`
- Contributing guide: [CONTRIBUTING.md](CONTRIBUTING.md)

## Getting Help

- GitHub Issues: https://github.com/llm-observatory/llm-observatory/issues
- Documentation: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- README: [README.md](README.md)

---

**Happy coding! Your changes will hot-reload in 2-3 seconds! 🚀**

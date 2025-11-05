# Analytics API Service

Enterprise-grade REST API for querying traces and metrics from the LLM Observatory platform.

## Features

- ✅ **JWT Authentication**: Secure token-based authentication
- ✅ **Role-Based Access Control**: Admin, Developer, Viewer, Billing roles
- ✅ **Advanced Rate Limiting**: Token bucket algorithm with Redis backend
- ✅ **Trace Querying**: 25+ filter parameters with cursor-based pagination
- ✅ **Performance**: Redis caching with smart TTLs
- ✅ **Security**: SQL injection prevention, input validation, audit logging

## Quick Start

```bash
# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Start with Docker Compose
docker-compose up -d

# Check health
curl http://localhost:8080/health
```

## API Endpoints

### Authentication Required

- `GET /api/v1/traces` - List traces with filtering
- `GET /api/v1/traces/:trace_id` - Get single trace

### Public (for now)

- `GET /api/v1/analytics/costs` - Cost analytics
- `GET /api/v1/analytics/performance` - Performance metrics
- `GET /api/v1/analytics/quality` - Quality metrics
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

## Documentation

- **Phase 1 Implementation**: See [PHASE1_IMPLEMENTATION.md](PHASE1_IMPLEMENTATION.md)
- **Client Examples**: See [examples/client_examples.md](examples/client_examples.md)
- **Phase 1 Summary**: See [PHASE1_SUMMARY.md](PHASE1_SUMMARY.md)

## Environment Variables

```bash
# Required
DATABASE_READONLY_URL=postgres://readonly:password@localhost:5432/llm_observatory
REDIS_URL=redis://localhost:6379
JWT_SECRET=your_secret_key_min_32_chars

# Optional
API_PORT=8080
CACHE_DEFAULT_TTL=3600
CORS_ORIGINS=http://localhost:3000
RUST_LOG=analytics_api=info
```

## Development

```bash
# Build
cargo build

# Run tests
cargo test

# Run locally
cargo run

# Format code
cargo fmt

# Lint
cargo clippy
```

## Production Deployment

See [PHASE1_IMPLEMENTATION.md](PHASE1_IMPLEMENTATION.md) for deployment guide.

## License

Apache 2.0

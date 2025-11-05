# LLM Observatory API Service - Docker Configuration

This directory contains the Docker configuration for the LLM Observatory API service, supporting both REST and GraphQL endpoints with comprehensive security, authentication, and monitoring features.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration Files](#configuration-files)
- [Deployment Modes](#deployment-modes)
- [Security Features](#security-features)
- [API Endpoints](#api-endpoints)
- [Monitoring & Metrics](#monitoring--metrics)
- [Development Guide](#development-guide)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

## Overview

The API service provides:

- **REST API**: RESTful endpoints for querying traces, metrics, and logs
- **GraphQL API**: Flexible query interface with schema introspection
- **JWT Authentication**: Secure token-based authentication
- **Rate Limiting**: Configurable per-endpoint and per-role limits
- **CORS Support**: Cross-origin resource sharing configuration
- **Caching**: Redis-based response caching
- **Metrics**: Prometheus metrics on port 9090
- **Health Checks**: Ready/alive/health endpoints
- **Security Hardening**: Non-root user, minimal attack surface

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      API Service                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  REST API   │  │  GraphQL    │  │   Metrics   │         │
│  │  :8080      │  │  :8080      │  │   :9090     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│  Middleware Layer:                                           │
│  - Authentication (JWT, API Keys)                           │
│  - Authorization (RBAC)                                      │
│  - Rate Limiting (Redis)                                     │
│  - CORS                                                      │
│  - Request Logging                                           │
│  - Error Handling                                            │
└─────────────────────────────────────────────────────────────┘
           │                    │
           ▼                    ▼
    ┌────────────┐      ┌────────────┐
    │ TimescaleDB│      │   Redis    │
    │ (Read-Only)│      │  (Cache)   │
    └────────────┘      └────────────┘
```

## Quick Start

### Production Mode

Start the API service in production mode:

```bash
# Build and start the API service
docker compose up -d api

# View logs
docker compose logs -f api

# Check health
curl http://localhost:8080/health
```

The API will be available at:
- REST API: http://localhost:8080/api/v1
- GraphQL: http://localhost:8080/graphql
- Metrics: http://localhost:9091/metrics

### Development Mode

Start with hot reload for development:

```bash
# Start development API service
docker compose --profile dev up -d api-dev

# View logs with auto-reload output
docker compose logs -f api-dev
```

Development features:
- Hot reload on code changes
- GraphQL Playground: http://localhost:5555/graphql/playground
- Debug logging enabled
- Introspection enabled
- Rate limiting disabled

## Configuration Files

### Dockerfile.api (Production)

Multi-stage build with:
- **Stage 1-2**: Dependency caching with cargo-chef
- **Stage 3**: Dependency compilation
- **Stage 4**: Application build
- **Stage 5**: Minimal runtime (Debian slim)

Key features:
- Optimized binary size (~15MB stripped)
- Non-root user (uid:1000)
- Security hardening
- Health check support

### Dockerfile.api.dev (Development)

Development image with:
- cargo-watch for hot reload
- Full Rust toolchain
- Development tools (gdb, strace)
- Debug symbols enabled
- Source code mounted

### api-config.yml

Comprehensive configuration covering:
- Server settings
- Authentication/Authorization
- Rate limiting per endpoint/role
- CORS configuration
- Caching strategies
- Logging and tracing
- Security headers
- Feature flags

## Deployment Modes

### 1. Standalone Production

```bash
docker compose up -d timescaledb redis api
```

### 2. Full Stack with Monitoring

```bash
docker compose up -d
```

Includes:
- TimescaleDB (database)
- Redis (cache)
- API (service)
- Prometheus (metrics)
- Grafana (dashboards)
- Jaeger (tracing)

### 3. Development Stack

```bash
docker compose --profile dev up -d
```

Uses development variants with hot reload.

### 4. Minimal Testing

```bash
docker build -f docker/Dockerfile.api -t llm-observatory-api .
docker run -p 8080:8080 -p 9090:9090 \
  -e DATABASE_URL=postgresql://user:pass@db:5432/llm_observatory \
  -e REDIS_URL=redis://:password@redis:6379/0 \
  -e JWT_SECRET=your_secret_here \
  llm-observatory-api
```

## Security Features

### 1. Authentication

**JWT (JSON Web Tokens)**
- HS256 algorithm by default (configurable)
- 1-hour token expiration
- 7-day refresh token
- Secure secret management via environment variables

```bash
# Generate a secure JWT secret
openssl rand -hex 32
```

**API Key Authentication**
- Header-based: `X-API-Key: your_key_here`
- Redis caching for fast lookups
- Role-based permissions

### 2. Authorization (RBAC)

Roles:
- **Admin**: Full access (10,000 req/min)
- **Developer**: High access (1,000 req/min)
- **Viewer**: Read-only (100 req/min)

### 3. Rate Limiting

Configured per:
- Endpoint (e.g., /api/v1/traces: 1000/min)
- User role
- IP address (optional)

Storage: Redis with automatic cleanup

### 4. CORS

Production default:
```yaml
allowed_origins:
  - http://localhost:3000
  - https://your-domain.com
```

Development: Permissive (`*`)

### 5. Security Headers

Automatically applied:
- `Strict-Transport-Security`
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection`
- `Content-Security-Policy`
- `Referrer-Policy`

### 6. Container Security

- Non-root user (uid:1000)
- No new privileges
- Capabilities dropped (ALL)
- Only NET_BIND_SERVICE added
- Read-only root filesystem option
- Tmpfs for temporary files

## API Endpoints

### REST API

Base path: `/api/v1`

**Traces**
```bash
GET    /api/v1/traces              # List traces
GET    /api/v1/traces/:id          # Get trace details
POST   /api/v1/traces/search       # Search traces
```

**Metrics**
```bash
GET    /api/v1/metrics             # List metrics
GET    /api/v1/metrics/:id         # Get metric details
POST   /api/v1/metrics/query       # Query metrics
```

**Models**
```bash
GET    /api/v1/models              # List LLM models
GET    /api/v1/models/:id          # Get model details
GET    /api/v1/models/:id/usage    # Get usage stats
```

### GraphQL API

Endpoint: `/graphql`

**Example Query**
```graphql
query GetTraces($filter: TraceFilter) {
  traces(filter: $filter, limit: 10) {
    id
    timestamp
    model
    duration
    tokenCount
    cost
    metadata
  }
}
```

**Playground**: Available in development at `/graphql/playground`

### Health Endpoints

```bash
GET /health      # Overall health
GET /ready       # Readiness check
GET /alive       # Liveness check
```

### Metrics Endpoint

```bash
GET /metrics     # Prometheus metrics (port 9090)
```

## Monitoring & Metrics

### Prometheus Metrics

The API exposes metrics on port 9090:

**Request Metrics**
- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request latency
- `http_requests_in_flight` - Current requests

**API Metrics**
- `api_graphql_queries_total` - GraphQL query count
- `api_rest_requests_total` - REST request count
- `api_auth_failures_total` - Authentication failures

**Rate Limiting**
- `rate_limit_exceeded_total` - Rate limit hits
- `rate_limit_requests_allowed` - Allowed requests

**Cache Metrics**
- `cache_hits_total` - Cache hits
- `cache_misses_total` - Cache misses
- `cache_size_bytes` - Cache memory usage

**Database Metrics**
- `db_pool_connections` - Active connections
- `db_query_duration_seconds` - Query latency

### Grafana Dashboards

Pre-configured dashboards available for:
- API performance overview
- Request rate and latency
- Error rates and types
- Rate limiting statistics
- Cache effectiveness
- Database query performance

### Alerting

Example alerts (configured in Prometheus):
- High error rate (>5%)
- Slow response time (>1s p95)
- Rate limit exceeded frequently
- Database connection pool exhausted

## Development Guide

### Local Development Setup

1. **Start dependencies**
```bash
docker compose up -d timescaledb redis
```

2. **Run API in development mode**
```bash
docker compose --profile dev up api-dev
```

3. **Make code changes**
Files are hot-reloaded automatically from `./crates/api/src`

4. **Access GraphQL Playground**
```bash
open http://localhost:5555/graphql/playground
```

### Development Tools

**Debugging**
```bash
# Attach to running container
docker compose exec api-dev bash

# Run with debugger
docker compose exec api-dev gdb /app/target/debug/llm-observatory-api
```

**Testing**
```bash
# Run tests in container
docker compose exec api-dev cargo test

# Run with coverage
docker compose exec api-dev cargo tarpaulin
```

**Linting**
```bash
# Format code
docker compose exec api-dev cargo fmt

# Clippy lints
docker compose exec api-dev cargo clippy
```

### Environment Variables

Development overrides:
```bash
export RUST_LOG=debug
export GRAPHQL_PLAYGROUND=true
export RATE_LIMIT_ENABLED=false
export CORS_ORIGINS=*
```

## Production Deployment

### Pre-deployment Checklist

- [ ] Set secure `JWT_SECRET` (32+ bytes)
- [ ] Set secure `SECRET_KEY` (32+ bytes)
- [ ] Configure `CORS_ORIGINS` with actual domains
- [ ] Disable `GRAPHQL_PLAYGROUND`
- [ ] Disable `GRAPHQL_INTROSPECTION`
- [ ] Enable `RATE_LIMIT_ENABLED`
- [ ] Set appropriate rate limits
- [ ] Configure `SENTRY_DSN` for error tracking
- [ ] Review database connection pool settings
- [ ] Set up SSL/TLS certificates
- [ ] Configure monitoring alerts

### Environment Configuration

Production `.env`:
```bash
ENVIRONMENT=production
API_PORT=8080
API_METRICS_PORT=9091

# Security
JWT_SECRET=<generated-secret>
SECRET_KEY=<generated-secret>
CORS_ORIGINS=https://app.example.com,https://dashboard.example.com

# GraphQL
GRAPHQL_ENABLED=true
GRAPHQL_PLAYGROUND=false
GRAPHQL_INTROSPECTION=false

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=60

# Database (read-only user)
DB_READONLY_USER=llm_observatory_readonly
DB_READONLY_PASSWORD=<secure-password>

# Redis
REDIS_PASSWORD=<secure-password>

# Monitoring
SENTRY_DSN=https://your-sentry-dsn
```

### Build and Deploy

```bash
# Build production image
docker compose build api

# Deploy with health checks
docker compose up -d api

# Verify health
curl http://localhost:8080/health

# Check metrics
curl http://localhost:9091/metrics
```

### Scaling

Horizontal scaling with load balancer:
```bash
docker compose up -d --scale api=3
```

**Note**: Ensure Redis is shared across instances for rate limiting.

### Resource Limits

Recommended limits:
```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
    reservations:
      cpus: '0.5'
      memory: 512M
```

## Troubleshooting

### Common Issues

**1. API won't start**
```bash
# Check logs
docker compose logs api

# Common causes:
# - Database not ready
# - Redis connection failed
# - Invalid JWT_SECRET
```

**2. Authentication failures**
```bash
# Verify JWT secret is set
docker compose exec api env | grep JWT_SECRET

# Check token expiration
# Tokens expire after 1 hour by default
```

**3. Rate limiting issues**
```bash
# Check Redis connection
docker compose exec api redis-cli -h redis -a redis_password ping

# Clear rate limit data
docker compose exec redis redis-cli FLUSHDB
```

**4. Database connection errors**
```bash
# Verify database is ready
docker compose exec timescaledb pg_isready

# Check connection string
docker compose exec api env | grep DATABASE_URL

# Verify read-only user exists
docker compose exec timescaledb psql -U postgres -c "\du"
```

**5. CORS errors**
```bash
# Check allowed origins
docker compose exec api env | grep CORS_ORIGINS

# For development, allow all:
CORS_ORIGINS=* docker compose up api-dev
```

### Debug Mode

Enable verbose logging:
```bash
RUST_LOG=debug,llm_observatory_api=trace docker compose up api
```

### Health Check Failures

```bash
# Manual health check
curl -v http://localhost:8080/health

# Check all health endpoints
curl http://localhost:8080/alive
curl http://localhost:8080/ready
curl http://localhost:8080/health
```

### Performance Issues

```bash
# Check metrics
curl http://localhost:9091/metrics | grep api_

# Monitor database connections
curl http://localhost:9091/metrics | grep db_pool

# Check cache hit rate
curl http://localhost:9091/metrics | grep cache_
```

## Additional Resources

- [API Documentation](../docs/api.md)
- [GraphQL Schema](../crates/api/schema.graphql)
- [Security Guide](../docs/security.md)
- [Deployment Guide](../docs/deployment.md)
- [Contributing Guide](../CONTRIBUTING.md)

## Support

For issues and questions:
- GitHub Issues: https://github.com/llm-observatory/llm-observatory/issues
- Documentation: https://docs.llm-observatory.io
- Community: https://discord.gg/llm-observatory

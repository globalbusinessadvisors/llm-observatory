# Analytics API

High-performance analytics service for LLM Observatory metrics aggregation and analysis.

## Overview

The Analytics API provides real-time metrics aggregation and analysis for LLM usage data stored in TimescaleDB. It offers:

- **Cost Analytics**: Track and analyze LLM costs by model, provider, user, and time period
- **Performance Metrics**: Monitor latency, throughput, and token usage with percentile calculations
- **Model Comparison**: Compare multiple models across various dimensions
- **Trend Analysis**: Identify patterns and trends in usage over time
- **Redis Caching**: Fast response times through intelligent caching

## Architecture

```
┌─────────────────┐
│   Client Apps   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Analytics API  │
│   (Axum 0.7)    │
└────┬────────┬───┘
     │        │
     ▼        ▼
┌────────┐  ┌────────┐
│ Redis  │  │TimescaleDB
│ Cache  │  │(PostgreSQL)
└────────┘  └────────┘
```

## Features

### 1. Cost Analytics
- Total cost tracking with breakdown by prompt/completion
- Cost breakdown by model, provider, and user
- Time-series cost data
- Cost projection and trend analysis

### 2. Performance Monitoring
- Latency metrics (avg, min, max, p50, p95, p99)
- Throughput (requests per second)
- Token usage statistics
- Time-series performance data

### 3. Model Comparison
- Side-by-side comparison of multiple models
- Automated recommendations
- Performance vs. cost analysis

### 4. Metrics Summary
- Comprehensive overview dashboard
- Top cost drivers
- Usage patterns
- Success rates

## API Endpoints

### Health & Status
- `GET /health` - Service health check
- `GET /ready` - Readiness check (database + Redis)
- `GET /metrics` - Prometheus metrics

### Cost Analytics
- `GET /api/v1/costs` - Get cost analytics
- `GET /api/v1/costs/breakdown` - Get detailed cost breakdown

### Performance Metrics
- `GET /api/v1/performance` - Get performance metrics

### Metrics & Analysis
- `GET /api/v1/metrics/summary` - Get metrics overview
- `GET /api/v1/metrics/conversations` - Get conversation metrics
- `GET /api/v1/metrics/models` - Compare multiple models
- `GET /api/v1/metrics/trends` - Get trend data

## Query Parameters

All analytics endpoints support the following query parameters:

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `start_time` | ISO 8601 | Start of time range | 7 days ago |
| `end_time` | ISO 8601 | End of time range | Now |
| `provider` | string | Filter by provider (e.g., "openai") | All |
| `model` | string | Filter by model (e.g., "gpt-4") | All |
| `environment` | string | Filter by environment | All |
| `user_id` | string | Filter by user | All |
| `granularity` | string | Time bucket (1min, 1hour, 1day) | 1hour |

## Configuration

Configuration is loaded from environment variables. See `.env.example` for all available options.

### Required Variables

```bash
# Database (TimescaleDB)
DATABASE_URL=postgresql://user:password@localhost:5432/llm_observatory

# Redis Cache
REDIS_URL=redis://localhost:6379/0
```

### Optional Variables

```bash
# Application
APP_HOST=0.0.0.0
API_PORT=8080
CORS_ORIGINS=*

# Database Pool
DATABASE_MAX_CONNECTIONS=20
DATABASE_MIN_CONNECTIONS=5

# Cache
CACHE_DEFAULT_TTL=3600
CACHE_ENABLED=true
```

## Running Locally

### Prerequisites
- Rust 1.75+
- PostgreSQL with TimescaleDB extension
- Redis

### Build and Run

```bash
# Build the service
cargo build --release

# Run with environment variables
export DATABASE_URL="postgresql://localhost/llm_observatory"
export REDIS_URL="redis://localhost:6379/0"

# Start the service
cargo run --release
```

## Docker Deployment

```bash
# Build Docker image
docker build -t analytics-api .

# Run with docker-compose
docker-compose up analytics-api
```

## Example Requests

### Get Cost Analytics

```bash
curl -X GET "http://localhost:8080/api/v1/costs?start_time=2024-01-01T00:00:00Z&granularity=1day"
```

### Get Performance Metrics

```bash
curl -X GET "http://localhost:8080/api/v1/performance?model=gpt-4&granularity=1hour"
```

### Compare Models

```bash
curl -X GET "http://localhost:8080/api/v1/metrics/models?models=gpt-4,gpt-3.5-turbo,claude-3-opus"
```

## Testing

```bash
# Run unit tests
cargo test

# Run integration tests (requires test database)
cargo test --test integration_test

# Run with coverage
cargo tarpaulin --out Html
```

## License

Apache-2.0

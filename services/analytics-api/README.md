# Analytics API Service

Production-ready REST API service for LLM Observatory analytics, built with Axum and Rust.

## Features

- **Cost Analytics**: Track and analyze LLM usage costs across models, providers, and users
- **Performance Metrics**: Monitor latency (P50, P95, P99), throughput, and token processing
- **Quality Metrics**: Track success rates, error patterns, and reliability
- **Model Comparison**: A/B testing and comparison across multiple models
- **Optimization Recommendations**: Automated suggestions for cost, performance, and quality improvements
- **TimescaleDB Integration**: Efficient time-series queries with continuous aggregates
- **Redis Caching**: Fast response times with intelligent caching
- **Production Ready**: Comprehensive error handling, logging, metrics, and health checks

## Architecture

```
src/
├── main.rs                 # Application entry point and server setup
├── lib.rs                  # Library exports
├── models.rs               # Data models and types
├── routes/                 # HTTP route handlers
│   ├── costs.rs           # Cost analytics endpoints
│   ├── performance.rs     # Performance metrics endpoints
│   ├── quality.rs         # Quality metrics endpoints
│   └── models.rs          # Model comparison endpoints
└── services/
    └── timescaledb.rs     # Database query service
```

## API Endpoints

### Cost Analytics

#### `GET /api/v1/analytics/costs`
Get cost analytics with time series data.

**Query Parameters:**
- `start_time` (optional): Start of time range (ISO 8601)
- `end_time` (optional): End of time range (ISO 8601)
- `provider` (optional): Filter by provider (e.g., "openai", "anthropic")
- `model` (optional): Filter by model (e.g., "gpt-4", "claude-3-opus")
- `environment` (optional): Filter by environment (e.g., "production", "staging")
- `granularity` (optional): Time bucket (1min, 1hour, 1day) - default: 1hour

**Response:**
```json
{
  "total_cost": 1234.56,
  "prompt_cost": 789.01,
  "completion_cost": 445.55,
  "request_count": 10000,
  "avg_cost_per_request": 0.123456,
  "time_series": [
    {
      "timestamp": "2025-01-01T00:00:00Z",
      "total_cost": 123.45,
      "prompt_cost": 78.90,
      "completion_cost": 44.55,
      "request_count": 1000
    }
  ]
}
```

#### `GET /api/v1/analytics/costs/breakdown`
Get detailed cost breakdown by model, provider, user, and time.

**Response:**
```json
{
  "by_model": [
    {
      "dimension": "gpt-4",
      "total_cost": 456.78,
      "request_count": 5000,
      "percentage": 45.6
    }
  ],
  "by_provider": [...],
  "by_user": [...],
  "by_time": [...]
}
```

### Performance Metrics

#### `GET /api/v1/analytics/performance`
Get performance metrics including latency percentiles and throughput.

**Query Parameters:** (same as cost analytics)

**Response:**
```json
{
  "request_count": 10000,
  "avg_latency_ms": 1234.56,
  "min_latency_ms": 100,
  "max_latency_ms": 5000,
  "p50_latency_ms": 1000.0,
  "p95_latency_ms": 2500.0,
  "p99_latency_ms": 4000.0,
  "throughput_rps": 10.5,
  "total_tokens": 1000000,
  "tokens_per_second": 100.5,
  "time_series": [...]
}
```

**Note:** Percentile calculations (P50, P95, P99) are only available for `granularity=1min` or `granularity=raw`.

### Quality Metrics

#### `GET /api/v1/analytics/quality`
Get quality metrics including success/error rates and error breakdown.

**Response:**
```json
{
  "total_requests": 10000,
  "successful_requests": 9500,
  "failed_requests": 500,
  "success_rate": 0.95,
  "error_rate": 0.05,
  "error_breakdown": [
    {
      "error_type": "rate_limit_exceeded",
      "count": 250,
      "percentage": 50.0,
      "sample_message": "Rate limit exceeded"
    }
  ],
  "time_series": [...]
}
```

### Model Comparison

#### `GET /api/v1/analytics/models/compare`
Compare multiple models for A/B testing.

**Query Parameters:**
- `models` (required): Comma-separated list of models (min 2, max 10)
- `metrics` (optional): Comma-separated metrics to include
- `start_time`, `end_time`, `environment` (optional)

**Response:**
```json
{
  "models": [
    {
      "model": "gpt-4",
      "provider": "openai",
      "metrics": {
        "avg_latency_ms": 1500.0,
        "p95_latency_ms": 3000.0,
        "avg_cost_usd": 0.05,
        "total_cost_usd": 500.0,
        "success_rate": 0.98,
        "request_count": 10000,
        "total_tokens": 1000000,
        "throughput_rps": 10.0
      }
    }
  ],
  "summary": {
    "fastest_model": "gpt-3.5-turbo",
    "cheapest_model": "gpt-3.5-turbo",
    "most_reliable_model": "gpt-4",
    "recommendations": [
      "Consider using gpt-3.5-turbo for latency-sensitive applications..."
    ]
  }
}
```

### Optimization Recommendations

#### `GET /api/v1/analytics/optimization`
Get automated optimization recommendations.

**Response:**
```json
{
  "cost_optimizations": [
    {
      "title": "High per-request cost detected",
      "description": "Average cost per request is $0.0500...",
      "impact": "high",
      "potential_savings": 150.0,
      "effort": "medium",
      "priority": 1
    }
  ],
  "performance_optimizations": [...],
  "quality_optimizations": [...],
  "overall_score": 0.75
}
```

## Configuration

Environment variables:

```bash
# Database (use read-only replica for analytics)
DATABASE_READONLY_URL=postgresql://readonly:password@localhost:5432/llm_observatory
DATABASE_URL=postgresql://user:password@localhost:5432/llm_observatory

# Redis
REDIS_URL=redis://:password@localhost:6379/0
# Or individual settings
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=password
REDIS_DB=0

# Cache settings
CACHE_DEFAULT_TTL=3600  # seconds

# Server
APP_HOST=0.0.0.0
API_PORT=8080
API_METRICS_PORT=9091

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:8080

# Logging
RUST_LOG=info,analytics_api=debug,sqlx=warn
```

## Running

### Development

```bash
# Install dependencies
cargo build

# Run the service
cargo run

# Run with custom config
DATABASE_URL=postgresql://... cargo run

# Run tests
cargo test

# Run integration tests (requires database)
cargo test --test integration_tests -- --ignored
```

### Production

```bash
# Build release binary
cargo build --release

# Run
./target/release/analytics-api
```

### Docker

```bash
# Build image
docker build -t analytics-api:latest .

# Run container
docker run -d \
  -p 8080:8080 \
  -p 9091:9091 \
  -e DATABASE_URL=postgresql://... \
  -e REDIS_URL=redis://... \
  --name analytics-api \
  analytics-api:latest
```

## Monitoring

### Health Check
```bash
curl http://localhost:8080/health
```

### Metrics (Prometheus)
```bash
curl http://localhost:9091/metrics
```

## Performance Considerations

### Caching Strategy
- Cost analytics: 1 hour TTL (configurable via `CACHE_DEFAULT_TTL`)
- Performance metrics: 1 hour TTL
- Quality metrics: 1 hour TTL
- Model comparisons: 1 hour TTL
- Optimization recommendations: 30 minutes TTL (more dynamic)

### Database Queries
- Uses TimescaleDB continuous aggregates for fast queries
- Automatically selects appropriate aggregate table based on granularity
  - `1min` → `llm_metrics_1min`
  - `1hour` → `llm_metrics_1hour` (default)
  - `1day` → `llm_metrics_1day`
- Percentile calculations require raw data queries (use `granularity=1min` or `granularity=raw`)

### Connection Pooling
- Database: 5-20 connections with 30s timeout
- Redis: Connection manager with automatic reconnection

## Security

- Non-root container user
- Minimal runtime dependencies
- Read-only database user recommended for analytics
- CORS configuration required for web access
- No authentication built-in (add reverse proxy with auth)

## License

Apache-2.0 - See LICENSE file for details

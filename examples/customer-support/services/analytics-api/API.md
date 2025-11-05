# Analytics API Documentation

## Overview

The Analytics API provides comprehensive metrics and analytics for LLM Observatory. It aggregates data from TimescaleDB and provides efficient querying through Redis caching.

## Base URL

```
http://localhost:8080
```

## Authentication

Currently, the API does not require authentication. In production, implement authentication middleware.

## Common Response Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad Request - Invalid parameters |
| 404 | Not Found |
| 500 | Internal Server Error |
| 503 | Service Unavailable - Database or cache unavailable |

## Endpoints

### Health & Status

#### GET /health

Check service health.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "service": "analytics-api"
}
```

#### GET /ready

Check service readiness (including dependencies).

**Response:**
```json
{
  "ready": true,
  "database": true,
  "redis": true,
  "timestamp": "2024-01-01T00:00:00Z"
}
```

#### GET /metrics

Prometheus metrics endpoint.

---

### Cost Analytics

#### GET /api/v1/costs

Get cost analytics with time-series data.

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| start_time | ISO 8601 | No | 7 days ago | Start of time range |
| end_time | ISO 8601 | No | Now | End of time range |
| provider | string | No | All | Filter by provider |
| model | string | No | All | Filter by model |
| environment | string | No | All | Filter by environment |
| user_id | string | No | All | Filter by user |
| granularity | string | No | 1hour | Time bucket (1min, 1hour, 1day) |

**Example Request:**
```bash
curl -X GET "http://localhost:8080/api/v1/costs?start_time=2024-01-01T00:00:00Z&end_time=2024-01-31T23:59:59Z&granularity=1day&provider=openai"
```

**Response:**
```json
{
  "total_cost": 125.50,
  "prompt_cost": 60.25,
  "completion_cost": 65.25,
  "request_count": 1250,
  "avg_cost_per_request": 0.1004,
  "time_series": [
    {
      "timestamp": "2024-01-01T00:00:00Z",
      "total_cost": 12.50,
      "prompt_cost": 6.00,
      "completion_cost": 6.50,
      "request_count": 125
    },
    {
      "timestamp": "2024-01-02T00:00:00Z",
      "total_cost": 13.75,
      "prompt_cost": 6.50,
      "completion_cost": 7.25,
      "request_count": 138
    }
  ]
}
```

#### GET /api/v1/costs/breakdown

Get detailed cost breakdown by model, provider, and user.

**Query Parameters:** Same as `/api/v1/costs`

**Example Request:**
```bash
curl -X GET "http://localhost:8080/api/v1/costs/breakdown?start_time=2024-01-01T00:00:00Z&granularity=1day"
```

**Response:**
```json
{
  "by_model": [
    {
      "dimension": "gpt-4",
      "total_cost": 75.50,
      "request_count": 500,
      "percentage": 60.2
    },
    {
      "dimension": "gpt-3.5-turbo",
      "total_cost": 30.00,
      "request_count": 600,
      "percentage": 23.9
    }
  ],
  "by_provider": [
    {
      "dimension": "openai",
      "total_cost": 105.50,
      "request_count": 1100,
      "percentage": 84.1
    },
    {
      "dimension": "anthropic",
      "total_cost": 20.00,
      "request_count": 150,
      "percentage": 15.9
    }
  ],
  "by_user": [
    {
      "dimension": "user_123",
      "total_cost": 45.00,
      "request_count": 400,
      "percentage": 35.9
    }
  ],
  "by_time": [
    {
      "timestamp": "2024-01-01T00:00:00Z",
      "total_cost": 12.50,
      "prompt_cost": 6.00,
      "completion_cost": 6.50,
      "request_count": 125
    }
  ]
}
```

---

### Performance Metrics

#### GET /api/v1/performance

Get performance metrics including latency and throughput.

**Query Parameters:** Same as `/api/v1/costs`

**Example Request:**
```bash
curl -X GET "http://localhost:8080/api/v1/performance?model=gpt-4&granularity=1hour"
```

**Response:**
```json
{
  "request_count": 1000,
  "avg_latency_ms": 1250.5,
  "min_latency_ms": 500,
  "max_latency_ms": 5000,
  "p50_latency_ms": 1200.0,
  "p95_latency_ms": 2500.0,
  "p99_latency_ms": 4000.0,
  "throughput_rps": 2.5,
  "total_tokens": 250000,
  "tokens_per_second": 625.0,
  "time_series": [
    {
      "timestamp": "2024-01-01T00:00:00Z",
      "avg_latency_ms": 1200.0,
      "min_latency_ms": 500,
      "max_latency_ms": 4500,
      "request_count": 100,
      "total_tokens": 25000
    }
  ]
}
```

---

### Metrics Summary

#### GET /api/v1/metrics/summary

Get comprehensive metrics overview.

**Query Parameters:** Same as `/api/v1/costs`

**Example Request:**
```bash
curl -X GET "http://localhost:8080/api/v1/metrics/summary?start_time=2024-01-01T00:00:00Z"
```

**Response:**
```json
{
  "cost": {
    "total_cost": 125.50,
    "cost_by_provider": [
      {
        "provider": "openai",
        "cost": 105.50,
        "percentage": 84.1
      }
    ],
    "top_models_by_cost": [
      {
        "model": "gpt-4",
        "provider": "openai",
        "cost": 75.50
      }
    ]
  },
  "performance": {
    "avg_latency_ms": 1250.5,
    "p95_latency_ms": 2500.0,
    "success_rate": 0.98
  },
  "usage": {
    "total_requests": 1250,
    "total_tokens": 312500,
    "requests_by_model": [
      {
        "model": "gpt-4",
        "provider": "openai",
        "requests": 500,
        "tokens": 150000
      }
    ]
  }
}
```

#### GET /api/v1/metrics/conversations

Get conversation-level metrics.

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| start_time | ISO 8601 | No | 7 days ago | Start of time range |
| end_time | ISO 8601 | No | Now | End of time range |
| conversation_id | string | No | All | Filter by conversation |
| user_id | string | No | All | Filter by user |

**Response:**
```json
{
  "total_conversations": 150,
  "avg_messages_per_conversation": 8.5,
  "avg_tokens_per_conversation": 2500,
  "avg_cost_per_conversation": 0.85,
  "conversations": [
    {
      "conversation_id": "conv_123",
      "user_id": "user_456",
      "start_time": "2024-01-01T10:00:00Z",
      "end_time": "2024-01-01T10:15:00Z",
      "message_count": 10,
      "total_tokens": 3000,
      "total_cost": 1.20
    }
  ]
}
```

#### GET /api/v1/metrics/models

Compare multiple models.

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| models | string | Yes | - | Comma-separated list of models (min 2) |
| start_time | ISO 8601 | No | 7 days ago | Start of time range |
| end_time | ISO 8601 | No | Now | End of time range |
| environment | string | No | All | Filter by environment |

**Example Request:**
```bash
curl -X GET "http://localhost:8080/api/v1/metrics/models?models=gpt-4,gpt-3.5-turbo,claude-3-opus"
```

**Response:**
```json
{
  "models": [
    {
      "model": "gpt-4",
      "provider": "openai",
      "metrics": {
        "avg_latency_ms": 1500.0,
        "p95_latency_ms": 2800.0,
        "avg_cost_usd": 0.15,
        "total_cost_usd": 75.00,
        "success_rate": 0.99,
        "request_count": 500,
        "total_tokens": 150000,
        "throughput_rps": 2.0
      }
    },
    {
      "model": "gpt-3.5-turbo",
      "provider": "openai",
      "metrics": {
        "avg_latency_ms": 800.0,
        "p95_latency_ms": 1500.0,
        "avg_cost_usd": 0.05,
        "total_cost_usd": 30.00,
        "success_rate": 0.98,
        "request_count": 600,
        "total_tokens": 180000,
        "throughput_rps": 2.4
      }
    }
  ],
  "summary": {
    "fastest_model": "gpt-3.5-turbo",
    "cheapest_model": "gpt-3.5-turbo",
    "most_reliable_model": "gpt-4",
    "recommendations": [
      "Use gpt-3.5-turbo for low-latency applications and gpt-3.5-turbo for cost-sensitive workloads",
      "gpt-3.5-turbo offers excellent balance of speed, cost, and reliability"
    ]
  }
}
```

#### GET /api/v1/metrics/trends

Get trend data over time.

**Query Parameters:** Same as `/api/v1/costs`

**Response:**
```json
{
  "cost_trend": [
    {
      "timestamp": "2024-01-01T00:00:00Z",
      "value": 12.50,
      "change_percentage": null
    },
    {
      "timestamp": "2024-01-02T00:00:00Z",
      "value": 13.75,
      "change_percentage": 10.0
    }
  ],
  "performance_trend": [
    {
      "timestamp": "2024-01-01T00:00:00Z",
      "value": 1200.0,
      "change_percentage": null
    },
    {
      "timestamp": "2024-01-02T00:00:00Z",
      "value": 1150.0,
      "change_percentage": -4.17
    }
  ],
  "usage_trend": [
    {
      "timestamp": "2024-01-01T00:00:00Z",
      "value": 125.0,
      "change_percentage": null
    },
    {
      "timestamp": "2024-01-02T00:00:00Z",
      "value": 138.0,
      "change_percentage": 10.4
    }
  ]
}
```

---

## Error Responses

All error responses follow this format:

```json
{
  "error": "error_type",
  "message": "Human-readable error message"
}
```

**Error Types:**

- `validation_error` - Invalid request parameters (400)
- `not_found` - Resource not found (404)
- `database_error` - Database connection or query error (500)
- `cache_error` - Redis connection error (500)
- `config_error` - Configuration error (500)
- `server_error` - General server error (500)
- `external_error` - External service error (502)

**Example Error Response:**

```json
{
  "error": "validation_error",
  "message": "At least 2 models are required for comparison"
}
```

---

## Rate Limiting

Currently not implemented. In production, consider implementing rate limiting based on:
- IP address
- API key
- User ID

---

## Caching

The API uses Redis caching with the following strategy:

- **Cache TTL**: 1 hour (configurable via `CACHE_DEFAULT_TTL`)
- **Cache Keys**: Include all query parameters
- **Cache Bypass**: Not currently supported (add `?nocache=true` in future)

To disable caching:
```bash
export CACHE_ENABLED=false
```

---

## Best Practices

1. **Time Ranges**: Use appropriate granularity for your time range
   - 1min: For detailed analysis (< 24 hours)
   - 1hour: For daily/weekly analysis (< 30 days)
   - 1day: For monthly/yearly analysis (> 30 days)

2. **Filters**: Apply filters to reduce data volume
   - Filter by model for model-specific analysis
   - Filter by provider for provider comparison
   - Filter by user for user-level tracking

3. **Caching**: Repeated queries are cached for 1 hour
   - Use consistent query parameters for cache hits
   - Cache is automatically invalidated after TTL

4. **Performance**: For large time ranges, use higher granularity
   - 1day granularity for year-long analysis
   - Reduces query time and data transfer

---

## Examples

### Monitor Daily Costs

```bash
# Get today's costs
curl -X GET "http://localhost:8080/api/v1/costs?start_time=$(date -u +%Y-%m-%dT00:00:00Z)&granularity=1hour"
```

### Compare GPT-4 vs GPT-3.5

```bash
curl -X GET "http://localhost:8080/api/v1/metrics/models?models=gpt-4,gpt-3.5-turbo"
```

### Track User Costs

```bash
curl -X GET "http://localhost:8080/api/v1/costs?user_id=user_123&start_time=2024-01-01T00:00:00Z"
```

### Get Performance Stats for Production

```bash
curl -X GET "http://localhost:8080/api/v1/performance?environment=production&granularity=1hour"
```

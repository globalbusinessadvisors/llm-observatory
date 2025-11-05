# Analytics API Reference

**Version:** 1.0.0
**Base URL:** `https://api.llm-observatory.io`
**Authentication:** Bearer Token (JWT)

---

## Table of Contents

1. [Authentication](#authentication)
2. [Rate Limiting](#rate-limiting)
3. [Error Handling](#error-handling)
4. [Pagination](#pagination)
5. [Field Selection](#field-selection)
6. [Caching](#caching)
7. [Endpoints](#endpoints)
   - [Health & Status](#health--status)
   - [Traces](#traces)
   - [Metrics](#metrics)
   - [Costs](#costs)
   - [Export](#export)
   - [Models](#models)

---

## Authentication

All API requests require authentication using a JWT Bearer token.

### Getting a Token

```bash
# Request a token (implemented by your auth service)
POST /auth/token
Content-Type: application/json

{
  "client_id": "your_client_id",
  "client_secret": "your_client_secret"
}
```

### Using the Token

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://api.llm-observatory.io/api/v1/traces
```

### Token Expiration

Tokens expire after 24 hours. Refresh tokens before expiration to maintain access.

---

## Rate Limiting

The API implements token bucket rate limiting based on your role:

| Role | Requests/Minute | Burst Capacity |
|------|----------------|----------------|
| Admin | 100,000 | 120,000 |
| Developer | 10,000 | 12,000 |
| Viewer | 1,000 | 1,200 |
| Billing | 1,000 | 1,200 |

### Rate Limit Headers

Every response includes rate limit information:

```http
X-RateLimit-Limit: 10000
X-RateLimit-Remaining: 9950
X-RateLimit-Reset: 1699200000
```

### Rate Limit Exceeded

When rate limited, you'll receive a `429 Too Many Requests` response:

```json
{
  "error": {
    "code": 1500,
    "error_code": "RATE_LIMIT_EXCEEDED",
    "category": "RATE_LIMIT",
    "message": "Rate limit exceeded. Please slow down your requests."
  },
  "meta": {
    "timestamp": "2025-11-05T10:30:00Z",
    "documentation_url": "https://docs.llm-observatory.io/errors/1500"
  }
}
```

**Retry-After Header:** Indicates seconds to wait before retrying.

---

## Error Handling

All errors follow a standardized format:

### Error Response Structure

```json
{
  "error": {
    "code": 1200,
    "error_code": "INVALID_REQUEST",
    "category": "VALIDATION",
    "message": "Invalid value for field 'limit'",
    "details": "Limit must be between 1 and 1000",
    "field": "limit"
  },
  "meta": {
    "timestamp": "2025-11-05T10:30:00Z",
    "request_id": "req_abc123",
    "documentation_url": "https://docs.llm-observatory.io/errors/1200"
  }
}
```

### Error Code Ranges

| Range | Category | HTTP Status |
|-------|----------|-------------|
| 1000-1099 | Authentication | 401 |
| 1100-1199 | Authorization | 403 |
| 1200-1299 | Validation | 400 |
| 1300-1399 | Resource Not Found | 404 |
| 1400-1499 | Conflicts | 409 |
| 1500-1599 | Rate Limiting | 429 |
| 1600-1699 | Database Errors | 503 |
| 1700-1799 | External Service Errors | 502/503 |
| 1800-1899 | Timeouts | 504 |
| 1900-1999 | Internal Errors | 500 |

### Common Error Codes

- `1000` - Missing authorization header
- `1001` - Invalid or malformed token
- `1002` - Token has expired
- `1100` - Insufficient permissions
- `1200` - Invalid request
- `1201` - Missing required field
- `1300` - Resource not found
- `1500` - Rate limit exceeded
- `1900` - Internal server error

---

## Pagination

List endpoints support cursor-based pagination:

### Query Parameters

- `limit` (integer): Number of results per page (1-1000, default: 50)
- `offset` (integer): Number of results to skip (default: 0)

### Example

```bash
GET /api/v1/traces?limit=100&offset=200
```

### Response

```json
{
  "data": [...],
  "pagination": {
    "total": 15420,
    "limit": 100,
    "offset": 200,
    "has_more": true
  }
}
```

---

## Field Selection

Reduce response payload by requesting specific fields:

### Query Parameter

- `fields` (string): Comma-separated list of fields to include

### Example

```bash
GET /api/v1/traces?fields=trace_id,model,cost,duration_ms
```

### Response

```json
{
  "data": [
    {
      "trace_id": "550e8400-e29b-41d4-a716-446655440000",
      "model": "gpt-4",
      "cost": 0.015,
      "duration_ms": 1250
    }
  ]
}
```

### Available Fields by Endpoint

**Traces:**
- `trace_id`, `span_id`, `ts`, `provider`, `model`, `environment`
- `input_text`, `output_text`, `status_code`, `error_message`
- `total_tokens`, `total_cost_usd`, `duration_ms`

**Metrics:**
- `timestamp`, `avg_latency_ms`, `p95_latency_ms`, `p99_latency_ms`
- `request_count`, `total_tokens`, `throughput_rps`

**Costs:**
- `timestamp`, `total_cost`, `prompt_cost`, `completion_cost`
- `request_count`, `provider`, `model`

---

## Caching

The API implements HTTP caching for improved performance:

### Cache Headers

**Request Headers:**
- `If-None-Match`: ETag value from previous response
- `If-Modified-Since`: Timestamp from previous response

**Response Headers:**
- `ETag`: Unique identifier for response content
- `Last-Modified`: When the resource was last modified
- `Cache-Control`: Caching directives (e.g., `private, max-age=60`)

### Example

```bash
# Initial request
GET /api/v1/metrics/performance
Response: 200 OK
ETag: "a1b2c3d4e5f6"
Cache-Control: private, max-age=60

# Subsequent request (within TTL)
GET /api/v1/metrics/performance
If-None-Match: "a1b2c3d4e5f6"
Response: 304 Not Modified
```

### Benefits

- Reduced bandwidth usage
- Faster response times
- Lower server load

---

## Endpoints

### Health & Status

#### GET /health

Check API health status.

**Authentication:** Not required

**Response:**

```json
{
  "status": "healthy",
  "database": "healthy",
  "redis": "healthy",
  "timestamp": "2025-11-05T10:30:00Z"
}
```

**Status Codes:**
- `200` - Healthy
- `503` - Service Unavailable

---

#### GET /metrics

Prometheus metrics endpoint for monitoring.

**Authentication:** Not required

**Response:** Prometheus text format

---

### Traces

#### GET /api/v1/traces

List traces with optional filtering.

**Authentication:** Required
**Permissions:** `traces:read`

**Query Parameters:**

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `start_time` | ISO 8601 | Filter traces after this time | - |
| `end_time` | ISO 8601 | Filter traces before this time | - |
| `provider` | string | Filter by provider (e.g., "openai") | - |
| `model` | string | Filter by model (e.g., "gpt-4") | - |
| `environment` | string | Filter by environment | - |
| `user_id` | string | Filter by user ID | - |
| `status_code` | string | Filter by status code | - |
| `min_duration_ms` | integer | Minimum duration in milliseconds | - |
| `max_duration_ms` | integer | Maximum duration in milliseconds | - |
| `min_cost` | number | Minimum cost in USD | - |
| `max_cost` | number | Maximum cost in USD | - |
| `limit` | integer | Results per page (1-1000) | 50 |
| `offset` | integer | Number of results to skip | 0 |
| `fields` | string | Comma-separated fields to return | all |

**Example:**

```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://api.llm-observatory.io/api/v1/traces?\
provider=openai&\
model=gpt-4&\
start_time=2025-11-01T00:00:00Z&\
end_time=2025-11-05T23:59:59Z&\
limit=100"
```

**Response:**

```json
{
  "data": [
    {
      "trace_id": "550e8400-e29b-41d4-a716-446655440000",
      "span_id": "660f9500-f39c-51e5-b827-557766551111",
      "ts": "2025-11-05T10:30:00Z",
      "project_id": "proj_abc123",
      "provider": "openai",
      "model": "gpt-4",
      "environment": "production",
      "user_id": "user_xyz789",
      "input_text": "What is the capital of France?",
      "output_text": "The capital of France is Paris.",
      "prompt_tokens": 8,
      "completion_tokens": 7,
      "total_tokens": 15,
      "input_cost_usd": 0.00024,
      "output_cost_usd": 0.00042,
      "total_cost_usd": 0.00066,
      "duration_ms": 1250,
      "status_code": "200",
      "error_message": null,
      "metadata": {},
      "tags": ["production", "api"]
    }
  ],
  "pagination": {
    "total": 15420,
    "limit": 100,
    "offset": 0,
    "has_more": true
  }
}
```

**Status Codes:**
- `200` - Success
- `400` - Invalid parameters
- `401` - Unauthorized
- `403` - Forbidden
- `429` - Rate limit exceeded

---

#### GET /api/v1/traces/:trace_id

Get a single trace by ID.

**Authentication:** Required
**Permissions:** `traces:read`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `trace_id` | UUID | Unique trace identifier |

**Example:**

```bash
curl -H "Authorization: Bearer TOKEN" \
  https://api.llm-observatory.io/api/v1/traces/550e8400-e29b-41d4-a716-446655440000
```

**Response:**

```json
{
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "span_id": "660f9500-f39c-51e5-b827-557766551111",
  "ts": "2025-11-05T10:30:00Z",
  "project_id": "proj_abc123",
  "provider": "openai",
  "model": "gpt-4",
  "environment": "production",
  "user_id": "user_xyz789",
  "input_text": "What is the capital of France?",
  "output_text": "The capital of France is Paris.",
  "prompt_tokens": 8,
  "completion_tokens": 7,
  "total_tokens": 15,
  "input_cost_usd": 0.00024,
  "output_cost_usd": 0.00042,
  "total_cost_usd": 0.00066,
  "duration_ms": 1250,
  "latency_ms": 1200,
  "time_to_first_token_ms": 350,
  "tokens_per_second": 12.0,
  "status_code": "200",
  "error_message": null,
  "metadata": {
    "temperature": 0.7,
    "max_tokens": 100
  },
  "tags": ["production", "api"],
  "model_parameters": {
    "temperature": 0.7,
    "top_p": 1.0,
    "frequency_penalty": 0.0,
    "presence_penalty": 0.0
  }
}
```

**Status Codes:**
- `200` - Success
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Trace not found

---

#### POST /api/v1/traces/search

Advanced trace search with complex filtering.

**Authentication:** Required
**Permissions:** `traces:read`

**Request Body:**

```json
{
  "filter": {
    "operator": "AND",
    "filters": [
      {
        "field": "provider",
        "operator": "eq",
        "value": "openai"
      },
      {
        "field": "total_cost_usd",
        "operator": "gte",
        "value": 1.0
      },
      {
        "field": "input_text",
        "operator": "search",
        "value": "authentication error"
      }
    ]
  },
  "sort_by": "total_cost_usd",
  "sort_desc": true,
  "limit": 100,
  "fields": ["trace_id", "model", "total_cost_usd", "input_text"]
}
```

**Filter Operators:**

- `eq` - Equal to
- `ne` - Not equal to
- `gt` - Greater than
- `gte` - Greater than or equal to
- `lt` - Less than
- `lte` - Less than or equal to
- `in` - In array
- `not_in` - Not in array
- `contains` - Contains substring (case-insensitive)
- `not_contains` - Does not contain substring
- `starts_with` - Starts with prefix
- `ends_with` - Ends with suffix
- `regex` - Matches regex pattern
- `search` - Full-text search

**Response:**

```json
{
  "data": [...],
  "pagination": {
    "total": 150,
    "limit": 100,
    "has_more": true
  }
}
```

---

### Metrics

#### GET /api/v1/metrics/performance

Get performance metrics with time-series data.

**Authentication:** Not required (public endpoint)

**Query Parameters:**

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `start_time` | ISO 8601 | Start of time range | 1 hour ago |
| `end_time` | ISO 8601 | End of time range | now |
| `provider` | string | Filter by provider | - |
| `model` | string | Filter by model | - |
| `environment` | string | Filter by environment | - |
| `granularity` | string | Time bucket (1min, 1hour, 1day) | 1hour |

**Example:**

```bash
curl "https://api.llm-observatory.io/api/v1/metrics/performance?\
start_time=2025-11-01T00:00:00Z&\
end_time=2025-11-05T23:59:59Z&\
provider=openai&\
granularity=1hour"
```

**Response:**

```json
{
  "request_count": 15420,
  "avg_latency_ms": 850.5,
  "min_latency_ms": 120,
  "max_latency_ms": 5000,
  "p50_latency_ms": 750.0,
  "p95_latency_ms": 1800.0,
  "p99_latency_ms": 3200.0,
  "throughput_rps": 3.2,
  "total_tokens": 2456890,
  "tokens_per_second": 512.5,
  "time_series": [
    {
      "timestamp": "2025-11-05T10:00:00Z",
      "avg_latency_ms": 820.3,
      "min_latency_ms": 150,
      "max_latency_ms": 2500,
      "request_count": 320,
      "total_tokens": 51200
    }
  ]
}
```

---

#### GET /api/v1/metrics/quality

Get quality metrics including success rates and errors.

**Authentication:** Not required (public endpoint)

**Response:**

```json
{
  "total_requests": 15420,
  "successful_requests": 15250,
  "failed_requests": 170,
  "success_rate": 0.989,
  "error_rate": 0.011,
  "avg_feedback_score": 4.2,
  "resolution_rate": 0.95,
  "error_breakdown": [
    {
      "error_type": "500",
      "count": 85,
      "percentage": 0.50,
      "sample_message": "Internal server error"
    },
    {
      "error_type": "429",
      "count": 50,
      "percentage": 0.29,
      "sample_message": "Rate limit exceeded"
    }
  ],
  "time_series": [
    {
      "timestamp": "2025-11-05T10:00:00Z",
      "success_rate": 0.992,
      "error_rate": 0.008,
      "request_count": 320
    }
  ]
}
```

---

### Costs

#### GET /api/v1/costs/analytics

Get cost analytics with time-series data.

**Authentication:** Required
**Permissions:** `costs:read`

**Query Parameters:**

Similar to performance metrics endpoint.

**Response:**

```json
{
  "total_cost": 1250.75,
  "prompt_cost": 450.25,
  "completion_cost": 800.50,
  "request_count": 15420,
  "avg_cost_per_request": 0.0811,
  "time_series": [
    {
      "timestamp": "2025-11-05T10:00:00Z",
      "total_cost": 25.50,
      "prompt_cost": 9.20,
      "completion_cost": 16.30,
      "request_count": 320
    }
  ]
}
```

---

#### GET /api/v1/costs/breakdown

Get cost breakdown by model, user, and provider.

**Authentication:** Required
**Permissions:** `costs:read`

**Response:**

```json
{
  "by_model": [
    {
      "dimension": "gpt-4",
      "total_cost": 850.25,
      "request_count": 5200,
      "percentage": 67.98
    },
    {
      "dimension": "gpt-3.5-turbo",
      "total_cost": 400.50,
      "request_count": 10220,
      "percentage": 32.02
    }
  ],
  "by_user": [...],
  "by_provider": [...],
  "by_time": [...]
}
```

---

### Export

#### POST /api/v1/export/traces

Create an export job to download traces.

**Authentication:** Required
**Permissions:** `exports:create`

**Request Body:**

```json
{
  "format": "json",
  "compression": "gzip",
  "start_time": "2025-11-01T00:00:00Z",
  "end_time": "2025-11-05T23:59:59Z",
  "provider": "openai",
  "model": "gpt-4",
  "limit": 10000
}
```

**Format Options:**
- `csv` - Comma-separated values
- `json` - JSON array
- `jsonl` - JSON lines (one object per line)

**Compression Options:**
- `none` - No compression
- `gzip` - Gzip compression

**Response:**

```json
{
  "job_id": "job_abc123",
  "status": "pending",
  "created_at": "2025-11-05T10:30:00Z",
  "estimated_completion_at": "2025-11-05T10:35:00Z",
  "status_url": "/api/v1/export/jobs/job_abc123"
}
```

---

#### GET /api/v1/export/jobs

List export jobs.

**Authentication:** Required
**Permissions:** `exports:read`

**Query Parameters:**

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `status` | string | Filter by status | - |
| `limit` | integer | Results per page | 50 |
| `offset` | integer | Number to skip | 0 |

**Response:**

```json
{
  "data": [
    {
      "job_id": "job_abc123",
      "status": "completed",
      "format": "json",
      "compression": "gzip",
      "created_at": "2025-11-05T10:30:00Z",
      "completed_at": "2025-11-05T10:33:00Z",
      "trace_count": 10000,
      "file_size_bytes": 2500000,
      "expires_at": "2025-11-12T10:33:00Z"
    }
  ],
  "pagination": {...}
}
```

---

#### GET /api/v1/export/jobs/:job_id

Get export job status.

**Authentication:** Required
**Permissions:** `exports:read`

**Response:**

```json
{
  "job_id": "job_abc123",
  "status": "completed",
  "format": "json",
  "compression": "gzip",
  "created_at": "2025-11-05T10:30:00Z",
  "started_at": "2025-11-05T10:30:05Z",
  "completed_at": "2025-11-05T10:33:00Z",
  "trace_count": 10000,
  "file_size_bytes": 2500000,
  "progress_percent": 100,
  "download_url": "/api/v1/export/jobs/job_abc123/download",
  "expires_at": "2025-11-12T10:33:00Z"
}
```

**Status Values:**
- `pending` - Waiting to start
- `processing` - Currently exporting
- `completed` - Ready for download
- `failed` - Export failed
- `cancelled` - Manually cancelled
- `expired` - Download expired

---

#### GET /api/v1/export/jobs/:job_id/download

Download exported file.

**Authentication:** Required
**Permissions:** `exports:read`

**Response:** Binary file with appropriate Content-Type

---

#### DELETE /api/v1/export/jobs/:job_id

Cancel an export job (only pending/processing jobs can be cancelled).

**Authentication:** Required
**Permissions:** `exports:delete`

**Response:**

```json
{
  "job_id": "job_abc123",
  "status": "cancelled",
  "message": "Export job cancelled successfully"
}
```

---

### Models

#### POST /api/v1/models/compare

Compare performance metrics across multiple models.

**Authentication:** Not required (public endpoint)

**Request Body:**

```json
{
  "models": ["gpt-4", "gpt-3.5-turbo", "claude-3-opus"],
  "metrics": ["latency", "cost", "quality"],
  "start_time": "2025-11-01T00:00:00Z",
  "end_time": "2025-11-05T23:59:59Z",
  "environment": "production"
}
```

**Response:**

```json
{
  "models": [
    {
      "model": "gpt-4",
      "provider": "openai",
      "metrics": {
        "avg_latency_ms": 1250.5,
        "p95_latency_ms": 2100.0,
        "avg_cost_usd": 0.015,
        "total_cost_usd": 850.25,
        "success_rate": 0.992,
        "request_count": 5200,
        "total_tokens": 850000,
        "throughput_rps": 1.1
      }
    },
    {
      "model": "gpt-3.5-turbo",
      "provider": "openai",
      "metrics": {
        "avg_latency_ms": 650.2,
        "p95_latency_ms": 1100.0,
        "avg_cost_usd": 0.0039,
        "total_cost_usd": 400.50,
        "success_rate": 0.995,
        "request_count": 10220,
        "total_tokens": 1200000,
        "throughput_rps": 2.1
      }
    }
  ],
  "summary": {
    "fastest_model": "gpt-3.5-turbo",
    "cheapest_model": "gpt-3.5-turbo",
    "most_reliable_model": "gpt-3.5-turbo",
    "recommendations": [
      "gpt-3.5-turbo offers the best cost-performance ratio",
      "Consider gpt-4 for complex tasks requiring higher quality",
      "gpt-3.5-turbo has 2x better throughput than gpt-4"
    ]
  }
}
```

---

## WebSocket API

### Connection

```javascript
const ws = new WebSocket('wss://api.llm-observatory.io/ws?token=YOUR_JWT_TOKEN');
```

### Subscribe to Events

```javascript
ws.send(JSON.stringify({
  type: 'subscribe',
  events: ['trace_created', 'cost_threshold', 'export_job_status'],
  filters: {
    provider: 'openai',
    environment: 'production'
  }
}));
```

### Event Types

- `trace_created` - New trace created
- `trace_updated` - Trace updated
- `metric_threshold` - Metric threshold exceeded
- `cost_threshold` - Cost threshold exceeded
- `export_job_status` - Export job status changed
- `system_alert` - System alert triggered

### Receiving Events

```javascript
ws.onmessage = (event) => {
  const message = JSON.parse(event.data);

  if (message.type === 'event') {
    console.log('Event:', message.event_type, message.data);
  }
};
```

---

## Best Practices

### 1. Use Field Selection

Request only the fields you need to reduce bandwidth:

```bash
GET /api/v1/traces?fields=trace_id,model,cost
```

### 2. Implement Caching

Use ETags to avoid re-downloading unchanged data:

```bash
GET /api/v1/metrics/performance
If-None-Match: "a1b2c3d4e5f6"
```

### 3. Handle Rate Limits

Check rate limit headers and implement exponential backoff:

```javascript
if (response.status === 429) {
  const retryAfter = response.headers.get('Retry-After');
  await sleep(retryAfter * 1000);
}
```

### 4. Use Batch Operations

Instead of multiple requests, use search endpoints with filters:

```bash
POST /api/v1/traces/search
# More efficient than multiple GET requests
```

### 5. Monitor Token Expiration

Refresh tokens before they expire to avoid downtime.

---

## SDKs

Official SDKs are available for:

- **Python:** `pip install llm-observatory`
- **JavaScript/TypeScript:** `npm install @llm-observatory/sdk`
- **Go:** `go get github.com/llm-observatory/go-sdk`
- **Rust:** `cargo add llm-observatory-sdk`

See [SDK Documentation](./SDK_INTEGRATION.md) for details.

---

## Support

- **Documentation:** https://docs.llm-observatory.io
- **API Status:** https://status.llm-observatory.io
- **GitHub:** https://github.com/llm-observatory/llm-observatory
- **Email:** support@llm-observatory.io

---

**Last Updated:** 2025-11-05
**API Version:** 1.0.0

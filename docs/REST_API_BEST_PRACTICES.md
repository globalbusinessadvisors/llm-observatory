# REST API Best Practices for LLM Observatory

**Version:** 1.0
**Last Updated:** 2025-11-05
**Purpose:** Guidelines and recommendations for designing and implementing REST APIs for observability and monitoring platforms

---

## Table of Contents

1. [Endpoint Naming Conventions](#1-endpoint-naming-conventions)
2. [Pagination Strategies](#2-pagination-strategies)
3. [Filtering and Query Parameters](#3-filtering-and-query-parameters)
4. [Response Format Standards](#4-response-format-standards)
5. [Rate Limiting and Authentication](#5-rate-limiting-and-authentication)
6. [Performance Optimization](#6-performance-optimization)
7. [Industry Patterns Reference](#7-industry-patterns-reference)
8. [Implementation Roadmap](#8-implementation-roadmap)

---

## 1. Endpoint Naming Conventions

### 1.1 General Principles

**Use Resource-Based URLs**
```
✅ Good: /api/v1/traces
✅ Good: /api/v1/metrics
✅ Good: /api/v1/analytics/costs

❌ Bad: /api/v1/getTraces
❌ Bad: /api/v1/fetch-metrics
```

**Follow RESTful Hierarchy**
```
GET    /api/v1/traces              # List all traces
GET    /api/v1/traces/{id}         # Get specific trace
POST   /api/v1/traces/search       # Complex query (use POST for body)
GET    /api/v1/traces/{id}/spans   # Get nested resources
```

### 1.2 Time-Series Data Endpoints

For observability platforms, follow these patterns:

**Metrics Endpoints**
```
GET    /api/v1/metrics                    # Query metrics (time-series)
GET    /api/v1/metrics/query              # Advanced metric queries
POST   /api/v1/metrics/query              # Complex metric queries with body
GET    /api/v1/metrics/labels             # Get available metric labels
GET    /api/v1/metrics/labels/{name}/values  # Get label values
```

**Analytics Endpoints**
```
GET    /api/v1/analytics/costs            # Cost time-series
GET    /api/v1/analytics/costs/breakdown  # Aggregated breakdown
GET    /api/v1/analytics/performance      # Performance metrics
GET    /api/v1/analytics/quality          # Quality metrics
```

**Trace Endpoints**
```
GET    /api/v1/traces                     # List traces
GET    /api/v1/traces/{id}                # Get trace details
POST   /api/v1/traces/search              # Search traces (complex filters)
GET    /api/v1/traces/{id}/spans          # Get spans for trace
```

### 1.3 Naming Best Practices

1. **Use Plural Nouns**: `/traces` not `/trace`
2. **Use Kebab-Case**: `/cost-breakdown` not `/costBreakdown`
3. **Version Your API**: `/api/v1/` not `/api/`
4. **Keep URLs Short**: Max 3 levels deep when possible
5. **Use Query Parameters for Filtering**: `/traces?status=error` not `/traces/error`

### 1.4 Special Endpoint Types

**Search/Query Endpoints** (use POST for complex queries):
```
POST   /api/v1/traces/search
POST   /api/v1/metrics/query
```

**Aggregation Endpoints**:
```
GET    /api/v1/analytics/costs/breakdown
GET    /api/v1/analytics/costs/summary
```

**Comparison Endpoints**:
```
GET    /api/v1/analytics/models/compare?models=gpt-4,claude-3
```

---

## 2. Pagination Strategies

### 2.1 Cursor-Based Pagination (RECOMMENDED)

**Why Cursor-Based?**
- ✅ Consistent results even when data changes
- ✅ Better performance on large datasets
- ✅ No duplicate or missing records during pagination
- ✅ Scales well with time-series data

**Implementation**:
```http
GET /api/v1/traces?limit=100&cursor=eyJpZCI6MTIzNDU2fQ

Response:
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIzNTU2fQ",
    "has_more": true,
    "limit": 100
  }
}
```

**Cursor Format**:
```rust
// Encode cursor as base64 JSON
{
  "id": 123456,           // Last record ID
  "timestamp": "2025-11-05T10:00:00Z",  // Last timestamp
  "sort_field": "created_at"  // Sort field used
}
```

### 2.2 Offset-Based Pagination (Limited Use)

**Use Cases**: Small datasets, admin interfaces, or when absolute page numbers are required

```http
GET /api/v1/traces?limit=100&offset=200

Response:
{
  "data": [...],
  "pagination": {
    "limit": 100,
    "offset": 200,
    "total": 1500,
    "page": 3,
    "total_pages": 15
  }
}
```

**Limitations**:
- ❌ Performance degrades with large offsets
- ❌ Inconsistent results if data changes
- ❌ Not suitable for real-time data

### 2.3 Time-Based Pagination (Time-Series Data)

**Best for**: Metrics and time-series queries

```http
GET /api/v1/metrics?start=2025-11-05T00:00:00Z&end=2025-11-05T23:59:59Z&step=1h

Response:
{
  "data": {
    "result_type": "matrix",
    "result": [...]
  },
  "metadata": {
    "start": "2025-11-05T00:00:00Z",
    "end": "2025-11-05T23:59:59Z",
    "step": "1h",
    "points": 24
  }
}
```

### 2.4 Pagination Best Practices

1. **Default Limits**: Set reasonable defaults (e.g., 100 items)
2. **Maximum Limits**: Enforce max limits (e.g., 1000 items per page)
3. **Metadata**: Always include pagination metadata
4. **Consistency**: Use the same pagination style across similar endpoints
5. **Empty Pages**: Handle empty results gracefully

```json
// Empty results example
{
  "data": [],
  "pagination": {
    "next_cursor": null,
    "has_more": false,
    "limit": 100
  }
}
```

### 2.5 Recommended Implementation

```rust
// For LLM Observatory
#[derive(Debug, Deserialize)]
pub struct PaginationParams {
    #[serde(default = "default_limit")]
    pub limit: u32,
    pub cursor: Option<String>,
}

fn default_limit() -> u32 { 100 }

#[derive(Debug, Serialize)]
pub struct PaginatedResponse<T> {
    pub data: Vec<T>,
    pub pagination: PaginationMetadata,
}

#[derive(Debug, Serialize)]
pub struct PaginationMetadata {
    pub next_cursor: Option<String>,
    pub has_more: bool,
    pub limit: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub total: Option<u64>,  // Optional for cursor-based
}
```

---

## 3. Filtering and Query Parameters

### 3.1 Filter Parameter Design

**Basic Filters** (single value):
```http
GET /api/v1/traces?status=error
GET /api/v1/traces?service=rag-service
GET /api/v1/traces?model=gpt-4
```

**Multiple Values** (comma-separated):
```http
GET /api/v1/traces?status=error,timeout
GET /api/v1/metrics?models=gpt-4,claude-3-opus
```

**Range Filters** (use prefixes):
```http
GET /api/v1/traces?min_duration_ms=1000
GET /api/v1/traces?max_duration_ms=5000
GET /api/v1/analytics/costs?min_cost_usd=0.01
```

**Comparison Operators**:
```http
GET /api/v1/traces?duration_ms[gte]=1000      # Greater than or equal
GET /api/v1/traces?duration_ms[lt]=5000       # Less than
GET /api/v1/traces?cost_usd[between]=0.01,1.0 # Range
```

### 3.2 Time Range Parameters

**Standard Time Filters**:
```http
GET /api/v1/metrics?start_time=2025-11-05T00:00:00Z&end_time=2025-11-05T23:59:59Z
GET /api/v1/traces?from=2025-11-05T00:00:00Z&to=2025-11-05T23:59:59Z
```

**Relative Time Filters** (inspired by Grafana/Prometheus):
```http
GET /api/v1/metrics?from=now-1h               # Last hour
GET /api/v1/metrics?from=now-24h&to=now       # Last 24 hours
GET /api/v1/metrics?from=now-7d               # Last 7 days
GET /api/v1/metrics?from=now/d&to=now         # Today
```

### 3.3 Aggregation Parameters

**Time Bucketing**:
```http
GET /api/v1/analytics/costs?granularity=1min   # 1-minute buckets
GET /api/v1/analytics/costs?granularity=1hour  # 1-hour buckets
GET /api/v1/analytics/costs?granularity=1day   # Daily aggregation
```

**Group By**:
```http
GET /api/v1/analytics/costs?group_by=model
GET /api/v1/analytics/costs?group_by=provider,environment
```

**Aggregation Functions**:
```http
GET /api/v1/metrics?aggregation=avg
GET /api/v1/metrics?aggregation=sum
GET /api/v1/metrics?aggregation=p95,p99
```

### 3.4 Sorting

```http
GET /api/v1/traces?sort=duration_ms           # Ascending
GET /api/v1/traces?sort=-duration_ms          # Descending (prefix with -)
GET /api/v1/traces?sort=timestamp,duration_ms # Multiple fields
```

### 3.5 Field Selection

```http
GET /api/v1/traces?fields=id,timestamp,duration_ms,model
GET /api/v1/traces?exclude=metadata,tags
```

### 3.6 Search and Text Filtering

```http
GET /api/v1/traces?search=error+message
GET /api/v1/traces?service_name[contains]=api
GET /api/v1/traces?model[starts_with]=gpt
```

### 3.7 Query Parameter Best Practices

1. **Use Clear Names**: `start_time` not `st` or `s`
2. **Consistent Naming**: Use snake_case consistently
3. **Validation**: Validate all parameters, return 400 for invalid values
4. **Documentation**: Document all parameters with examples
5. **Default Values**: Provide sensible defaults
6. **Max Values**: Enforce maximums for safety

```rust
// Example validation
#[derive(Debug, Deserialize)]
pub struct AnalyticsQuery {
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    pub provider: Option<String>,
    pub model: Option<String>,
    pub environment: Option<String>,
    #[serde(default = "default_granularity")]
    pub granularity: String,

    #[serde(default = "default_limit")]
    #[validate(range(min = 1, max = 1000))]
    pub limit: u32,
}

fn default_granularity() -> String { "1hour".to_string() }
fn default_limit() -> u32 { 100 }
```

---

## 4. Response Format Standards

### 4.1 Standard Success Response

**Single Resource**:
```json
{
  "data": {
    "id": "trace_123",
    "timestamp": "2025-11-05T10:30:00Z",
    "duration_ms": 1250,
    "model": "gpt-4",
    "status": "success"
  }
}
```

**Collection Response**:
```json
{
  "data": [
    { "id": "trace_123", ... },
    { "id": "trace_124", ... }
  ],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIzfQ",
    "has_more": true,
    "limit": 100
  }
}
```

**Aggregated Data**:
```json
{
  "data": {
    "total_cost": 125.45,
    "prompt_cost": 75.30,
    "completion_cost": 50.15,
    "request_count": 1250,
    "time_series": [
      {
        "timestamp": "2025-11-05T10:00:00Z",
        "total_cost": 12.50,
        "request_count": 125
      }
    ]
  },
  "metadata": {
    "start_time": "2025-11-05T00:00:00Z",
    "end_time": "2025-11-05T23:59:59Z",
    "granularity": "1hour"
  }
}
```

### 4.2 Error Response Format

**Standard Error Structure** (based on Prometheus pattern):
```json
{
  "status": "error",
  "error_type": "bad_request",
  "error": "Invalid time range: start_time must be before end_time",
  "details": {
    "field": "start_time",
    "provided": "2025-11-06T00:00:00Z",
    "constraint": "must be before end_time"
  },
  "request_id": "req_abc123"
}
```

**Error Types**:
- `bad_request` - Invalid input (400)
- `unauthorized` - Authentication failed (401)
- `forbidden` - Permission denied (403)
- `not_found` - Resource not found (404)
- `rate_limit_exceeded` - Too many requests (429)
- `internal_error` - Server error (500)
- `service_unavailable` - Service down (503)
- `timeout` - Request timeout (504)

### 4.3 HTTP Status Codes

**Success Codes**:
- `200 OK` - Successful GET, PUT, PATCH
- `201 Created` - Successful POST (resource created)
- `202 Accepted` - Async operation accepted
- `204 No Content` - Successful DELETE

**Client Error Codes**:
- `400 Bad Request` - Invalid parameters
- `401 Unauthorized` - Missing or invalid authentication
- `403 Forbidden` - Authenticated but not authorized
- `404 Not Found` - Resource doesn't exist
- `422 Unprocessable Entity` - Valid syntax but semantic errors
- `429 Too Many Requests` - Rate limit exceeded

**Server Error Codes**:
- `500 Internal Server Error` - Unexpected error
- `503 Service Unavailable` - Temporary outage
- `504 Gateway Timeout` - Request timeout

### 4.4 Timestamp Format

**Always use ISO 8601 with UTC**:
```json
{
  "timestamp": "2025-11-05T10:30:00Z",
  "created_at": "2025-11-05T10:30:00.123Z",
  "updated_at": "2025-11-05T10:30:00.123456Z"
}
```

### 4.5 Number Formats

**Costs**: Use fixed-point decimals (2-4 places)
```json
{
  "total_cost_usd": 125.4567,
  "prompt_cost_usd": 75.30,
  "completion_cost_usd": 50.16
}
```

**Durations**: Use milliseconds for consistency
```json
{
  "duration_ms": 1250,
  "avg_latency_ms": 342.5,
  "p95_latency_ms": 1200
}
```

### 4.6 Metadata and Context

**Include Query Context**:
```json
{
  "data": [...],
  "metadata": {
    "query": {
      "start_time": "2025-11-05T00:00:00Z",
      "end_time": "2025-11-05T23:59:59Z",
      "filters": {
        "provider": "openai",
        "environment": "production"
      }
    },
    "execution": {
      "duration_ms": 125,
      "cached": false,
      "cache_ttl": 3600
    }
  }
}
```

### 4.7 Warnings and Partial Results

**Include Warnings Without Failing**:
```json
{
  "status": "success",
  "data": [...],
  "warnings": [
    {
      "code": "partial_data",
      "message": "Some data points missing due to retention policy",
      "details": "Data before 2025-10-01 is not available"
    }
  ]
}
```

---

## 5. Rate Limiting and Authentication

### 5.1 Authentication Methods

**Primary: JWT (JSON Web Tokens)**
```http
GET /api/v1/traces
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Configuration**:
- Algorithm: HS256 (or RS256 for multi-service)
- Expiration: 1 hour (access token)
- Refresh token: 7 days
- Claims: user_id, role, permissions

**Secondary: API Keys**
```http
GET /api/v1/traces
X-API-Key: sk_live_abc123def456...
```

**API Key Best Practices**:
- Prefix keys: `sk_live_` (production), `sk_test_` (development)
- Store as hashed values
- Support key rotation
- Allow multiple keys per account

### 5.2 Rate Limiting Strategies

**Algorithm: Token Bucket** (recommended for observability)
- Allows bursts while maintaining average rate
- Better for legitimate usage patterns
- Smoother for users

**Rate Limit Tiers** (per API key):
```
Viewer:     100 requests/minute,  5,000/hour
Developer:  1,000 requests/minute, 50,000/hour
Admin:      10,000 requests/minute, 500,000/hour
```

**Per-Endpoint Limits**:
```
GET  /api/v1/traces           - 1,000/min
POST /api/v1/traces/search    - 100/min (more expensive)
GET  /api/v1/metrics          - 1,000/min
POST /api/v1/metrics/query    - 100/min
GET  /api/v1/analytics/*      - 500/min (cached, less strict)
```

### 5.3 Rate Limit Headers

**Standard Headers** (following GitHub/Stripe pattern):
```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 987
X-RateLimit-Reset: 1699200000
Retry-After: 60
```

**When Limit Exceeded**:
```http
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1699200000
Retry-After: 45

{
  "status": "error",
  "error_type": "rate_limit_exceeded",
  "error": "Rate limit exceeded. Please wait 45 seconds before retrying.",
  "details": {
    "limit": 1000,
    "window": "1 minute",
    "retry_after": 45
  }
}
```

### 5.4 Authentication Error Responses

**401 Unauthorized** (missing or invalid token):
```json
{
  "status": "error",
  "error_type": "unauthorized",
  "error": "Authentication required. Please provide a valid access token.",
  "details": {
    "documentation": "https://docs.llm-observatory.io/api/authentication"
  }
}
```

**403 Forbidden** (authenticated but insufficient permissions):
```json
{
  "status": "error",
  "error_type": "forbidden",
  "error": "Insufficient permissions to access this resource.",
  "details": {
    "required_permission": "analytics:read",
    "user_role": "viewer"
  }
}
```

### 5.5 CORS Configuration

**Production**:
```yaml
allowed_origins:
  - https://app.llm-observatory.io
  - https://dashboard.llm-observatory.io
allowed_methods:
  - GET
  - POST
  - OPTIONS
allowed_headers:
  - Content-Type
  - Authorization
  - X-API-Key
max_age: 3600
```

**Development**:
```yaml
allowed_origins: "*"  # Permissive for development only
```

### 5.6 Security Headers

**Always Include**:
```http
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
Referrer-Policy: strict-origin-when-cross-origin
```

---

## 6. Performance Optimization

### 6.1 Caching Strategies

**Multi-Layer Caching**:

1. **Redis Cache** (Short-term, 1 second - 1 hour)
2. **CDN Cache** (Static responses, 5-60 minutes)
3. **Client Cache** (HTTP cache headers)

**Cache Key Design**:
```rust
// Good cache key structure
fn cache_key(query: &AnalyticsQuery) -> String {
    format!(
        "cost:analytics:{}:{}:{}:{}:{}",
        query.start_time.map(|t| t.to_rfc3339()).unwrap_or_default(),
        query.end_time.map(|t| t.to_rfc3339()).unwrap_or_default(),
        query.provider.as_deref().unwrap_or("all"),
        query.model.as_deref().unwrap_or("all"),
        query.granularity
    )
}
```

**TTL Guidelines** (based on data volatility):
```
Real-time metrics (1min granularity):     30 seconds
Recent data (1hour granularity):          5 minutes
Historical data (1day granularity):       1 hour
Aggregated analytics:                     15 minutes
Model comparisons:                        30 minutes
Optimization recommendations:             30 minutes (or half normal TTL)
```

**HTTP Cache Headers**:
```http
# For cacheable GET requests
Cache-Control: public, max-age=300, s-maxage=600
ETag: "abc123def456"
Last-Modified: Wed, 05 Nov 2025 10:30:00 GMT

# For real-time data
Cache-Control: no-cache, must-revalidate

# For private user data
Cache-Control: private, max-age=300
```

### 6.2 Query Optimization

**TimescaleDB Continuous Aggregates**:
```sql
-- Pre-aggregate data for common queries
CREATE MATERIALIZED VIEW llm_metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', timestamp) AS bucket,
    provider,
    model,
    COUNT(*) AS request_count,
    AVG(duration_ms) AS avg_duration_ms,
    SUM(cost_usd) AS total_cost_usd
FROM llm_traces
GROUP BY bucket, provider, model;
```

**Query Guidelines**:
1. **Use Indexes**: Ensure indexes on filter columns
2. **Limit Time Ranges**: Default to last 24 hours, max 90 days
3. **Use Continuous Aggregates**: For coarse granularities (1hour, 1day)
4. **Avoid SELECT ***: Only fetch needed fields
5. **Use Connection Pooling**: Min 5, Max 20 connections

**Time Range Validation**:
```rust
pub fn validate_time_range(
    start: Option<DateTime<Utc>>,
    end: Option<DateTime<Utc>>
) -> Result<(DateTime<Utc>, DateTime<Utc>), ApiError> {
    let end = end.unwrap_or_else(Utc::now);
    let start = start.unwrap_or_else(|| end - Duration::hours(24));

    // Validate range
    if start >= end {
        return Err(ApiError::BadRequest(
            "start_time must be before end_time".to_string()
        ));
    }

    // Limit to 90 days
    let max_range = Duration::days(90);
    if end - start > max_range {
        return Err(ApiError::BadRequest(
            format!("Time range cannot exceed {} days", max_range.num_days())
        ));
    }

    Ok((start, end))
}
```

### 6.3 Response Compression

**Enable gzip/brotli**:
```rust
use tower_http::compression::CompressionLayer;

let app = Router::new()
    .layer(CompressionLayer::new())
    .layer(cors);
```

**Headers**:
```http
Accept-Encoding: gzip, deflate, br
Content-Encoding: gzip
```

### 6.4 Pagination Best Practices

1. **Default Limits**: 100 items
2. **Max Limits**: 1000 items
3. **Use Cursor Pagination**: For large datasets
4. **Index Sort Columns**: Ensure efficient sorting

### 6.5 Async Processing

**For Expensive Queries**:
```http
POST /api/v1/analytics/costs/export
Content-Type: application/json

{
  "start_time": "2025-01-01T00:00:00Z",
  "end_time": "2025-11-05T23:59:59Z",
  "format": "csv"
}

Response:
HTTP/1.1 202 Accepted
Location: /api/v1/jobs/job_abc123

{
  "job_id": "job_abc123",
  "status": "processing",
  "estimated_duration": 120,
  "status_url": "/api/v1/jobs/job_abc123"
}
```

**Check Job Status**:
```http
GET /api/v1/jobs/job_abc123

Response:
{
  "job_id": "job_abc123",
  "status": "completed",
  "created_at": "2025-11-05T10:30:00Z",
  "completed_at": "2025-11-05T10:32:00Z",
  "result": {
    "download_url": "/api/v1/jobs/job_abc123/download",
    "expires_at": "2025-11-06T10:32:00Z"
  }
}
```

### 6.6 Monitoring and Observability

**Expose Metrics**:
```http
GET /metrics

# Response (Prometheus format)
http_requests_total{method="GET",endpoint="/api/v1/traces",status="200"} 1250
http_request_duration_seconds_bucket{le="0.1"} 950
http_request_duration_seconds_bucket{le="0.5"} 1200
cache_hits_total{endpoint="/api/v1/analytics/costs"} 850
cache_misses_total{endpoint="/api/v1/analytics/costs"} 150
db_query_duration_seconds_sum 125.5
```

**Key Metrics to Track**:
- Request count by endpoint
- Response times (p50, p95, p99)
- Error rates
- Cache hit/miss rates
- Database query times
- Rate limit violations
- Authentication failures

---

## 7. Industry Patterns Reference

### 7.1 Datadog API Patterns

**Query Metrics**:
```http
GET /api/v1/query
  ?query=avg:system.cpu.user{*}
  &from=1699200000
  &to=1699300000
```

**Key Learnings**:
- Use query languages for complex metrics (consider PromQL-like syntax)
- Batch operations to reduce API calls
- Comprehensive rate limiting with clear limits
- Separate read and write API keys

### 7.2 Grafana API Patterns

**Query Data Sources**:
```http
POST /api/ds/query
{
  "queries": [
    {
      "refId": "A",
      "datasourceId": 1,
      "expr": "rate(http_requests_total[5m])"
    }
  ],
  "from": "now-1h",
  "to": "now"
}
```

**Key Learnings**:
- Support relative time ranges (now-1h, now-24h)
- Allow multiple queries in single request
- Use ref IDs for query identification
- Support for multiple data sources

### 7.3 Prometheus API Patterns

**Query Endpoint**:
```http
GET /api/v1/query
  ?query=up
  &time=2025-11-05T10:30:00.000Z

Response:
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": { "__name__": "up", "job": "api" },
        "value": [1699182600, "1"]
      }
    ]
  }
}
```

**Range Query**:
```http
GET /api/v1/query_range
  ?query=rate(http_requests_total[5m])
  &start=2025-11-05T00:00:00Z
  &end=2025-11-05T23:59:59Z
  &step=1h
```

**Key Learnings**:
- Clear status field in all responses
- Separate instant vs range queries
- Include warnings without failing
- Structured error types

### 7.4 Common Patterns Summary

| Feature | Datadog | Grafana | Prometheus | Recommendation |
|---------|---------|---------|------------|----------------|
| Auth | API + App Keys | API Keys | None (proxy) | JWT + API Keys |
| Pagination | Offset | Page-based | Time-based | Cursor-based |
| Time Format | Unix timestamp | ISO 8601/relative | Unix/ISO 8601 | ISO 8601 + relative |
| Errors | Detailed JSON | Structured | Status + type | Prometheus style |
| Caching | Aggressive | Moderate | Client-side | Multi-layer |
| Rate Limits | 1000/hour | Varies | N/A | Token bucket |

---

## 8. Implementation Roadmap

### Phase 1: Core API Structure (Current)

**Status**: ✅ Implemented

- [x] Basic REST endpoints
- [x] JWT authentication
- [x] Redis caching
- [x] Basic error handling
- [x] Prometheus metrics
- [x] Health checks

**Current Endpoints**:
```
GET  /api/v1/analytics/costs
GET  /api/v1/analytics/costs/breakdown
GET  /api/v1/analytics/performance
GET  /api/v1/analytics/quality
GET  /api/v1/analytics/models/compare
GET  /api/v1/analytics/optimization
```

### Phase 2: Enhanced Pagination

**Priority**: HIGH
**Effort**: Medium
**Timeline**: 2 weeks

- [ ] Implement cursor-based pagination
- [ ] Add pagination metadata to all list endpoints
- [ ] Support both cursor and offset for backward compatibility
- [ ] Add max limit enforcement (1000 items)
- [ ] Update documentation with pagination examples

**Implementation**:
```rust
// Add to models.rs
#[derive(Debug, Serialize)]
pub struct PaginatedResponse<T> {
    pub data: Vec<T>,
    pub pagination: PaginationMetadata,
}

#[derive(Debug, Serialize)]
pub struct PaginationMetadata {
    pub next_cursor: Option<String>,
    pub has_more: bool,
    pub limit: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub total: Option<u64>,
}
```

### Phase 3: Advanced Filtering

**Priority**: HIGH
**Effort**: Medium
**Timeline**: 2 weeks

- [ ] Implement comparison operators (gte, lt, between)
- [ ] Add multi-value filtering (comma-separated)
- [ ] Support text search and pattern matching
- [ ] Add field selection (include/exclude)
- [ ] Validate all filter parameters

**Example**:
```rust
#[derive(Debug, Deserialize)]
pub struct AdvancedFilters {
    pub duration_ms_gte: Option<i32>,
    pub duration_ms_lt: Option<i32>,
    pub status_in: Option<Vec<String>>,
    pub model_contains: Option<String>,
    pub fields: Option<Vec<String>>,
}
```

### Phase 4: Rate Limiting Enhancement

**Priority**: HIGH
**Effort**: High
**Timeline**: 3 weeks

- [ ] Implement token bucket algorithm
- [ ] Add per-endpoint rate limits
- [ ] Create rate limit tiers (Viewer, Developer, Admin)
- [ ] Add rate limit headers to all responses
- [ ] Implement distributed rate limiting (Redis)
- [ ] Add rate limit monitoring/alerting

**Implementation**:
```rust
// Rate limiter middleware
pub async fn rate_limit_middleware(
    Extension(state): Extension<Arc<AppState>>,
    headers: HeaderMap,
    req: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let api_key = extract_api_key(&headers)?;
    let limits = get_rate_limits_for_key(&api_key, &state).await?;

    if !check_rate_limit(&api_key, &limits, &state).await? {
        return Err(StatusCode::TOO_MANY_REQUESTS);
    }

    Ok(next.run(req).await)
}
```

### Phase 5: Response Standardization

**Priority**: MEDIUM
**Effort**: Medium
**Timeline**: 2 weeks

- [ ] Standardize all success responses with `data` wrapper
- [ ] Implement consistent error format
- [ ] Add request IDs to all responses
- [ ] Include query metadata in responses
- [ ] Add warnings array for non-fatal issues
- [ ] Standardize timestamp formats (ISO 8601)

### Phase 6: Caching Optimization

**Priority**: MEDIUM
**Effort**: Medium
**Timeline**: 2 weeks

- [ ] Implement HTTP cache headers (ETag, Last-Modified)
- [ ] Add cache configuration per endpoint
- [ ] Implement cache warming for common queries
- [ ] Add cache hit/miss metrics
- [ ] Implement conditional requests (304 Not Modified)
- [ ] Add cache invalidation on data updates

### Phase 7: Relative Time Support

**Priority**: MEDIUM
**Effort**: Low
**Timeline**: 1 week

- [ ] Support relative time ranges (now-1h, now-24h, now-7d)
- [ ] Add time shortcuts (now/d for today, now/w for this week)
- [ ] Validate and parse time expressions
- [ ] Update documentation with examples

**Implementation**:
```rust
pub fn parse_relative_time(expr: &str) -> Result<DateTime<Utc>, ParseError> {
    let now = Utc::now();

    match expr {
        "now" => Ok(now),
        s if s.starts_with("now-") => {
            // Parse duration: now-1h, now-24h, now-7d
            parse_duration_offset(s, now)
        }
        s if s.starts_with("now/") => {
            // Parse truncation: now/d (today), now/w (this week)
            parse_time_truncation(s, now)
        }
        _ => parse_absolute_time(expr),
    }
}
```

### Phase 8: Advanced Features

**Priority**: LOW
**Effort**: High
**Timeline**: 4 weeks

- [ ] Async job processing for large exports
- [ ] Webhook support for alerts
- [ ] GraphQL endpoint optimization
- [ ] API versioning strategy (v2)
- [ ] Batch query endpoints
- [ ] Streaming responses for large datasets

### Phase 9: Documentation and Developer Experience

**Priority**: HIGH
**Effort**: Medium
**Timeline**: Ongoing

- [ ] OpenAPI/Swagger specification
- [ ] Interactive API documentation
- [ ] Code examples in multiple languages
- [ ] Postman/Insomnia collections
- [ ] API client libraries (Python, Node.js, Rust)
- [ ] Migration guides
- [ ] Video tutorials

---

## Appendix A: Example Requests

### Get Cost Analytics with Filters
```bash
curl -X GET "https://api.llm-observatory.io/api/v1/analytics/costs" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -G \
  --data-urlencode "start_time=2025-11-01T00:00:00Z" \
  --data-urlencode "end_time=2025-11-05T23:59:59Z" \
  --data-urlencode "provider=openai" \
  --data-urlencode "granularity=1day"
```

### Compare Models
```bash
curl -X GET "https://api.llm-observatory.io/api/v1/analytics/models/compare" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -G \
  --data-urlencode "models=gpt-4,claude-3-opus,gemini-pro" \
  --data-urlencode "start_time=now-7d" \
  --data-urlencode "end_time=now" \
  --data-urlencode "environment=production"
```

### Search Traces with Pagination
```bash
curl -X POST "https://api.llm-observatory.io/api/v1/traces/search" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filters": {
      "status": "error",
      "min_duration_ms": 1000,
      "from": "now-24h",
      "to": "now"
    },
    "sort": "-duration_ms",
    "limit": 100,
    "cursor": "eyJpZCI6MTIzNDU2fQ"
  }'
```

---

## Appendix B: Error Code Reference

| HTTP Code | Error Type | Description | Retry? |
|-----------|------------|-------------|--------|
| 400 | bad_request | Invalid parameters or malformed request | No |
| 401 | unauthorized | Missing or invalid authentication | No |
| 403 | forbidden | Insufficient permissions | No |
| 404 | not_found | Resource doesn't exist | No |
| 422 | unprocessable_entity | Valid syntax but semantic errors | No |
| 429 | rate_limit_exceeded | Too many requests | Yes (after delay) |
| 500 | internal_error | Server error | Yes (with backoff) |
| 503 | service_unavailable | Temporary outage | Yes (with backoff) |
| 504 | timeout | Request took too long | Yes (with longer timeout) |

---

## Appendix C: Cache TTL Recommendations

| Data Type | Volatility | Recommended TTL | Notes |
|-----------|------------|-----------------|-------|
| Real-time metrics (1min) | Very High | 30 seconds | Frequently changing |
| Recent metrics (1hour) | High | 5 minutes | Balance freshness and load |
| Historical metrics (1day) | Low | 1 hour | Static historical data |
| Aggregated analytics | Medium | 15 minutes | Pre-computed aggregations |
| Model comparisons | Medium | 30 minutes | Relative stability |
| Cost breakdowns | Low | 1 hour | Daily updates typical |
| Optimization recommendations | Medium | 30 minutes | Based on recent data |
| Static metadata | Very Low | 24 hours | Rarely changes |

---

## Appendix D: Security Checklist

- [ ] All endpoints require authentication (except health checks)
- [ ] JWT secrets are securely generated and stored
- [ ] API keys are hashed in database
- [ ] Rate limiting is enabled and configured
- [ ] CORS is properly configured for production
- [ ] Security headers are included in all responses
- [ ] Input validation on all parameters
- [ ] SQL injection prevention (parameterized queries)
- [ ] Sensitive data is not logged
- [ ] HTTPS enforced in production
- [ ] Secrets rotation policy in place
- [ ] Audit logging for sensitive operations
- [ ] Regular security scans (cargo audit)
- [ ] Dependency updates scheduled

---

## References

1. **Industry APIs**:
   - [Datadog API Documentation](https://docs.datadoghq.com/api/)
   - [Grafana HTTP API](https://grafana.com/docs/grafana/latest/developers/http_api/)
   - [Prometheus HTTP API](https://prometheus.io/docs/prometheus/latest/querying/api/)

2. **Standards and RFCs**:
   - RFC 9110: HTTP Semantics
   - RFC 9111: HTTP Caching
   - RFC 6749: OAuth 2.0
   - RFC 7519: JSON Web Tokens
   - RFC 7807: Problem Details for HTTP APIs

3. **Best Practices**:
   - [REST API Design Best Practices](https://restfulapi.net/)
   - [API Security Best Practices](https://owasp.org/www-project-api-security/)
   - [Pagination Best Practices](https://www.merge.dev/blog/cursor-pagination)

4. **Tools**:
   - [OpenAPI Specification](https://swagger.io/specification/)
   - [Postman Documentation](https://www.postman.com/api-documentation-tool/)
   - [API Blueprint](https://apiblueprint.org/)

---

**Document Maintenance**:
- Review quarterly for industry updates
- Update based on implementation feedback
- Incorporate user feedback and feature requests
- Align with evolving security standards

**Last Reviewed**: 2025-11-05
**Next Review**: 2026-02-05

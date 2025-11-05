# Analytics API - Performance Optimization Guide

## Overview

This guide provides comprehensive performance optimization strategies for the Analytics API, covering database tuning, caching strategies, query optimization, and monitoring.

## Table of Contents

1. [Performance Targets](#performance-targets)
2. [Database Optimization](#database-optimization)
3. [Caching Strategy](#caching-strategy)
4. [Query Optimization](#query-optimization)
5. [Index Management](#index-management)
6. [Connection Pooling](#connection-pooling)
7. [Rate Limiting](#rate-limiting)
8. [Monitoring & Profiling](#monitoring--profiling)
9. [Load Testing](#load-testing)
10. [Production Recommendations](#production-recommendations)

---

## Performance Targets

### Response Time Objectives

- **P50 latency**: < 100ms for simple queries
- **P95 latency**: < 500ms for trace queries
- **P99 latency**: < 2s for complex aggregations
- **Cache hit rate**: > 70% for analytics endpoints
- **Database connection pool**: 80% utilization under normal load
- **Throughput**: 1,000+ requests/second per instance

### Resource Limits

- **Memory**: < 512MB per instance under normal load
- **CPU**: < 50% per core at 1K RPS
- **Database connections**: Max 20 per instance
- **Redis connections**: Max 10 per instance

---

## Database Optimization

### 1. TimescaleDB Configuration

```sql
-- Recommended PostgreSQL/TimescaleDB settings
ALTER SYSTEM SET shared_buffers = '4GB';
ALTER SYSTEM SET effective_cache_size = '12GB';
ALTER SYSTEM SET maintenance_work_mem = '1GB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
ALTER SYSTEM SET random_page_cost = 1.1;  -- For SSD storage
ALTER SYSTEM SET effective_io_concurrency = 200;  -- For SSD storage
ALTER SYSTEM SET work_mem = '32MB';
ALTER SYSTEM SET min_wal_size = '1GB';
ALTER SYSTEM SET max_wal_size = '4GB';

-- Reload configuration
SELECT pg_reload_conf();
```

### 2. Continuous Aggregates Refresh

```sql
-- Set up automatic refresh policies for continuous aggregates
SELECT add_continuous_aggregate_policy('traces_1min',
    start_offset => INTERVAL '2 hours',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute'
);

SELECT add_continuous_aggregate_policy('traces_1hour',
    start_offset => INTERVAL '2 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

SELECT add_continuous_aggregate_policy('traces_1day',
    start_offset => INTERVAL '30 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);
```

### 3. Compression Policy

```sql
-- Enable compression for older data
ALTER TABLE traces SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'project_id, provider, model',
    timescaledb.compress_orderby = 'ts DESC'
);

-- Add compression policy (compress data older than 7 days)
SELECT add_compression_policy('traces', INTERVAL '7 days');

-- Check compression status
SELECT *
FROM timescaledb_information.compression_settings
WHERE hypertable_name = 'traces';
```

### 4. Retention Policy

```sql
-- Add data retention policy (keep 90 days)
SELECT add_retention_policy('traces', INTERVAL '90 days');

-- Check retention policies
SELECT * FROM timescaledb_information.jobs
WHERE proc_name = 'policy_retention';
```

### 5. Query Performance Analysis

```sql
-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Find slow queries
SELECT
    mean_exec_time,
    calls,
    total_exec_time,
    query
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

---

## Caching Strategy

### 1. Redis Configuration

```bash
# redis.conf optimizations
maxmemory 2gb
maxmemory-policy allkeys-lru
maxmemory-samples 10
tcp-backlog 511
timeout 300
tcp-keepalive 300
save ""  # Disable RDB snapshots for cache-only use
appendonly no
```

### 2. Cache TTL Guidelines

| Endpoint Type | TTL | Reasoning |
|--------------|-----|-----------|
| `/traces` (list) | 30s | Frequently updated |
| `/traces/:id` | 5m | Individual traces rarely change |
| `/metrics/performance` | 60s | Aggregated data, acceptable staleness |
| `/metrics/costs` | 60s | Cost data updated periodically |
| `/metrics/quality` | 60s | Quality metrics computed in batch |
| `/models/compare` | 5m | Model comparisons are expensive |
| `/export/jobs/:id` | 10s | Job status updates frequently |

### 3. Cache Key Patterns

```
# Pattern: {service}:{resource}:{id}:{query_hash}
analytics:traces:list:abc123def456
analytics:trace:550e8400-e29b-41d4-a716-446655440000
analytics:metrics:performance:org123:hash456
analytics:costs:breakdown:org123:2024-01:hash789

# Benefits:
# - Easy to invalidate by pattern
# - Clear namespace separation
# - Query hash prevents collisions
```

### 4. Cache Warming Strategy

```rust
// Warm critical caches on startup
async fn warm_caches(state: &AppState) {
    // Warm performance metrics for last hour
    let _ = get_performance_metrics(
        state,
        Some(Utc::now() - Duration::hours(1)),
        None
    ).await;

    // Warm cost summaries for current month
    let _ = get_cost_summary(
        state,
        Some(Utc::now().date_naive().with_day(1).unwrap())
    ).await;
}
```

---

## Query Optimization

### 1. Use Continuous Aggregates

```rust
// BAD: Query raw traces table for aggregations
let query = sqlx::query!(
    "SELECT
        DATE_TRUNC('hour', ts) as hour,
        AVG(duration_ms) as avg_duration
     FROM traces
     WHERE ts >= $1 AND ts < $2
     GROUP BY hour",
    start_time,
    end_time
);

// GOOD: Query pre-computed continuous aggregate
let query = sqlx::query!(
    "SELECT bucket, avg_duration_ms
     FROM traces_1hour
     WHERE bucket >= $1 AND bucket < $2",
    start_time,
    end_time
);
```

### 2. Optimize WHERE Clauses

```rust
// BAD: Non-sargable query (can't use indexes efficiently)
WHERE EXTRACT(YEAR FROM ts) = 2024

// GOOD: Sargable query (can use indexes)
WHERE ts >= '2024-01-01' AND ts < '2025-01-01'

// BAD: Function on column prevents index usage
WHERE LOWER(provider) = 'openai'

// GOOD: Use citext or appropriate collation
WHERE provider = 'openai'  -- Assuming provider uses citext
```

### 3. Limit Result Sets

```rust
// Always include LIMIT
const MAX_RESULTS: i32 = 1000;

let limit = query.limit.min(MAX_RESULTS);
let query = format!(
    "SELECT * FROM traces WHERE ... LIMIT {}",
    limit
);
```

### 4. Use Prepared Statements

```rust
// GOOD: Prepared statement (reuses query plan)
let traces = sqlx::query_as!(
    TraceRow,
    "SELECT * FROM traces WHERE project_id = $1 AND ts >= $2",
    project_id,
    start_time
)
.fetch_all(&pool)
.await?;

// Prepared statements are cached and provide:
// - Query plan reuse
// - SQL injection protection
// - Type safety
```

---

## Index Management

### 1. Essential Indexes

```sql
-- Already created in migrations, but verify:
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename = 'traces'
ORDER BY indexname;

-- Expected indexes:
-- idx_traces_project_ts (project_id, ts DESC)
-- idx_traces_provider (provider)
-- idx_traces_model (model)
-- idx_traces_user (user_id)
-- idx_traces_status (status_code)
-- idx_traces_session (session_id, ts DESC)
-- idx_traces_cost (total_cost_usd)
-- idx_traces_duration (duration_ms)
```

### 2. Monitor Index Usage

```sql
-- Find unused indexes
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelname NOT LIKE 'pg_%'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Find most used indexes
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY idx_scan DESC
LIMIT 20;
```

### 3. Index Maintenance

```sql
-- Reindex to reclaim space and update statistics
REINDEX TABLE CONCURRENTLY traces;

-- Analyze to update statistics
ANALYZE traces;

-- Auto-vacuum settings (per table)
ALTER TABLE traces SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);
```

---

## Connection Pooling

### 1. Application-Level Pool Configuration

```rust
// Optimal settings for analytics-api
let pool = PgPoolOptions::new()
    .max_connections(20)           // Limit total connections
    .min_connections(5)             // Keep warm connections
    .acquire_timeout(Duration::from_secs(30))
    .idle_timeout(Duration::from_secs(300))  // 5 minutes
    .max_lifetime(Duration::from_secs(1800)) // 30 minutes
    .test_before_acquire(true)      // Verify connections
    .connect(&database_url)
    .await?;
```

### 2. PgBouncer Configuration

```ini
[databases]
analytics = host=postgres-primary port=5432 dbname=llm_observatory

[pgbouncer]
# Connection pooling mode
pool_mode = transaction  # Best for short queries

# Pool size
default_pool_size = 20
max_client_conn = 200
reserve_pool_size = 5

# Timeouts
server_lifetime = 1800
server_idle_timeout = 300
query_timeout = 120

# Performance
max_prepared_statements = 100
```

### 3. Monitor Connection Pool

```rust
// Add metrics for pool monitoring
metrics::gauge!("db_pool_size", pool.size() as f64);
metrics::gauge!("db_pool_idle", pool.num_idle() as f64);
metrics::gauge!("db_pool_connections", (pool.size() - pool.num_idle()) as f64);
```

---

## Rate Limiting

### 1. Tiered Rate Limits

| Role | Requests/Minute | Burst Capacity |
|------|----------------|----------------|
| Admin | 100,000 | 120,000 |
| Developer | 10,000 | 12,000 |
| Viewer | 1,000 | 1,200 |
| Billing | 1,000 | 1,200 |

### 2. Per-Endpoint Limits

```rust
// Apply stricter limits to expensive endpoints
const RATE_LIMITS: &[(&str, u32)] = &[
    ("/api/v1/traces/search", 100),      // Complex searches
    ("/api/v1/export/traces", 10),        // Export jobs
    ("/api/v1/models/compare", 50),       // Model comparisons
    ("*", 1000),                          // Default
];
```

### 3. Graceful Degradation

```rust
// Return cached data when rate limited
if rate_limit_exceeded {
    if let Some(cached) = get_from_cache(&key).await {
        return Ok(cached.with_header("X-Served-From-Cache", "true"));
    }
    return Err(ApiError::rate_limit_exceeded());
}
```

---

## Monitoring & Profiling

### 1. Key Metrics to Track

```rust
// Request metrics
metrics::counter!("http_requests_total", "endpoint" => endpoint);
metrics::histogram!("http_request_duration_seconds", duration);
metrics::histogram!("http_request_size_bytes", request_size);
metrics::histogram!("http_response_size_bytes", response_size);

// Database metrics
metrics::histogram!("db_query_duration_seconds", duration);
metrics::counter!("db_queries_total", "operation" => operation);
metrics::counter!("db_errors_total", "error_type" => error_type);

// Cache metrics
metrics::counter!("cache_hits_total");
metrics::counter!("cache_misses_total");
metrics::gauge!("cache_size_bytes", size);

// Rate limit metrics
metrics::counter!("rate_limit_exceeded_total", "user_id" => user_id);
metrics::gauge!("rate_limit_remaining", remaining);
```

### 2. Prometheus Queries

```promql
# P95 request latency by endpoint
histogram_quantile(0.95,
    rate(http_request_duration_seconds_bucket[5m])
)

# Request rate
rate(http_requests_total[1m])

# Error rate
rate(http_requests_total{status=~"5.."}[1m])
/ rate(http_requests_total[1m])

# Cache hit rate
rate(cache_hits_total[5m])
/ (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m]))

# Database connection pool utilization
db_pool_connections / db_pool_size
```

### 3. Alerting Rules

```yaml
groups:
  - name: analytics_api
    rules:
      # High latency
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High request latency detected"

      # High error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[1m]) / rate(http_requests_total[1m]) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Error rate above 5%"

      # Low cache hit rate
      - alert: LowCacheHitRate
        expr: rate(cache_hits_total[5m]) / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m])) < 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Cache hit rate below 50%"
```

---

## Load Testing

### 1. Test Scenarios

```bash
# Scenario 1: List traces (read-heavy)
k6 run - <<EOF
import http from 'k6/http';
import { check } from 'k6';

export let options = {
    vus: 100,
    duration: '5m',
};

export default function() {
    let response = http.get('http://localhost:8080/api/v1/traces', {
        headers: { 'Authorization': 'Bearer \${TOKEN}' }
    });
    check(response, { 'status is 200': (r) => r.status === 200 });
}
EOF

# Scenario 2: Complex aggregations
k6 run --vus 50 --duration 2m load_tests/aggregations.js

# Scenario 3: Mixed workload
k6 run --vus 200 --duration 10m load_tests/mixed.js
```

### 2. Load Test Targets

| Scenario | VUs | RPS | P95 Latency | Success Rate |
|----------|-----|-----|-------------|--------------|
| Trace list | 100 | 1000 | < 200ms | > 99.9% |
| Aggregations | 50 | 500 | < 1s | > 99.5% |
| Mixed | 200 | 2000 | < 500ms | > 99.9% |

### 3. Stress Testing

```bash
# Gradually increase load to find breaking point
k6 run - <<EOF
import http from 'k6/http';

export let options = {
    stages: [
        { duration: '2m', target: 100 },
        { duration: '5m', target: 100 },
        { duration: '2m', target: 200 },
        { duration: '5m', target: 200 },
        { duration: '2m', target: 500 },
        { duration: '5m', target: 500 },
        { duration: '2m', target: 1000 },
        { duration: '5m', target: 1000 },
        { duration: '10m', target: 0 },
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'],
        http_req_failed: ['rate<0.01'],
    },
};

export default function() {
    http.get('http://localhost:8080/api/v1/traces', {
        headers: { 'Authorization': 'Bearer \${TOKEN}' }
    });
}
EOF
```

---

## Production Recommendations

### 1. Infrastructure

```yaml
# Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-api
spec:
  replicas: 3  # Start with 3, adjust based on load
  template:
    spec:
      containers:
      - name: analytics-api
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        env:
        - name: DATABASE_POOL_SIZE
          value: "20"
        - name: CACHE_DEFAULT_TTL
          value: "60"
```

### 2. Horizontal Scaling

```yaml
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: analytics-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: analytics-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 3. Database Replication

```sql
-- Use read replicas for analytics queries
-- Configure separate connection pools

-- Primary (write operations)
DATABASE_URL=postgres://user:pass@primary:5432/db

-- Replica (read operations)
DATABASE_READONLY_URL=postgres://user:pass@replica:5432/db
```

### 4. CDN for Static Content

```nginx
# Nginx configuration for caching
location /api/v1/metrics/ {
    proxy_pass http://analytics-api:8080;
    proxy_cache api_cache;
    proxy_cache_valid 200 60s;
    proxy_cache_key "$scheme$request_method$host$request_uri";
    add_header X-Cache-Status $upstream_cache_status;
}
```

### 5. Health Checks

```rust
// Comprehensive health check
async fn health_check(State(state): State<Arc<AppState>>)
    -> Result<Json<HealthResponse>, StatusCode>
{
    // Check database
    let db_ok = sqlx::query("SELECT 1")
        .execute(&state.db_pool)
        .await
        .is_ok();

    // Check Redis
    let redis_ok = state.redis_client
        .get_multiplexed_async_connection()
        .await
        .is_ok();

    let status = if db_ok && redis_ok {
        "healthy"
    } else {
        "degraded"
    };

    // Return appropriate status code
    if db_ok && redis_ok {
        Ok(Json(health_response))
    } else {
        Err(StatusCode::SERVICE_UNAVAILABLE)
    }
}
```

---

## Performance Checklist

### Pre-Production

- [ ] All continuous aggregates configured and refreshing
- [ ] Compression policies enabled for older data
- [ ] Retention policies configured
- [ ] All critical indexes verified
- [ ] Connection pooling optimized
- [ ] Redis cache configured with appropriate TTLs
- [ ] Rate limiting enabled and tested
- [ ] Metrics and monitoring deployed
- [ ] Load tests passed at target RPS
- [ ] Health checks working correctly

### Post-Production Monitoring

- [ ] P95/P99 latency within targets
- [ ] Cache hit rate > 70%
- [ ] Error rate < 0.1%
- [ ] Database connection pool < 80% utilized
- [ ] No connection pool timeouts
- [ ] Query performance analyzed weekly
- [ ] Index usage reviewed monthly
- [ ] Capacity planning updated quarterly

---

## Troubleshooting

### High Latency

1. Check slow query log
2. Verify cache hit rate
3. Check database connection pool
4. Look for missing indexes
5. Review continuous aggregate refresh

### High Error Rate

1. Check database connectivity
2. Verify Redis connectivity
3. Review application logs
4. Check rate limiting
5. Verify authentication/authorization

### High Memory Usage

1. Check connection pool size
2. Review cache size
3. Look for memory leaks
4. Analyze query result sizes
5. Check for large response payloads

### Database Issues

1. Check locks: `SELECT * FROM pg_locks`
2. Check active queries: `SELECT * FROM pg_stat_activity`
3. Check bloat: `SELECT * FROM pg_stat_user_tables`
4. Verify vacuum/analyze running
5. Review TimescaleDB jobs

---

## Additional Resources

- [TimescaleDB Best Practices](https://docs.timescale.com/timescaledb/latest/how-to-guides/continuous-aggregates/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Redis Best Practices](https://redis.io/docs/manual/pipelining/)
- [Axum Performance](https://github.com/tokio-rs/axum/blob/main/ECOSYSTEM.md)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)

---

## Conclusion

Following these optimization guidelines will ensure the Analytics API performs efficiently under load. Regular monitoring, testing, and tuning are essential for maintaining performance as usage grows.

For questions or issues, please open a GitHub issue or contact the platform team.

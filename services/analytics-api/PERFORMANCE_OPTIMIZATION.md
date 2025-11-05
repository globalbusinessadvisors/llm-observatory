# Phase 2 Performance Optimization Guide

## Overview
This guide provides comprehensive performance tuning recommendations for the Analytics API Phase 2 features (advanced filtering and full-text search).

## Target Performance Metrics

### Phase 2 Requirements
- **P95 Latency:** < 500ms (all endpoints)
- **P99 Latency:** < 1000ms (all endpoints)
- **Throughput:** > 1000 req/s (under normal load)

### Expected Performance by Query Type

| Query Type | P50 Latency | P95 Latency | P99 Latency | Throughput |
|-----------|-------------|-------------|-------------|------------|
| Simple equality filters | 10-20ms | 20-50ms | 50-100ms | 5000+ req/s |
| Comparison operators (gt/gte/lt/lte) | 15-30ms | 30-80ms | 80-150ms | 3000+ req/s |
| IN operator (3-5 values) | 15-30ms | 30-80ms | 80-150ms | 3000+ req/s |
| String operators (contains/starts_with) | 20-40ms | 40-100ms | 100-200ms | 2000+ req/s |
| Full-text search (GIN index) | 20-50ms | 50-100ms | 100-200ms | 1500+ req/s |
| Complex nested (3-5 levels) | 30-80ms | 80-150ms | 150-300ms | 1000+ req/s |
| Combined search + filters | 40-100ms | 100-200ms | 200-400ms | 800+ req/s |
| Large result sets (1000 rows) | 50-150ms | 150-400ms | 400-800ms | 500+ req/s |

## Running Performance Tests

### Prerequisites
```bash
# Install benchmarking tools
# Option 1: wrk (recommended)
git clone https://github.com/wg/wrk.git
cd wrk && make && sudo cp wrk /usr/local/bin/

# Option 2: Apache Bench
sudo apt-get install apache2-utils  # Ubuntu/Debian
brew install httpd                    # macOS

# Install jq for JSON processing
sudo apt-get install jq  # Ubuntu/Debian
brew install jq          # macOS
```

### Running Benchmarks
```bash
# Run all Phase 2 benchmarks
cd services/analytics-api
./benches/phase2_benchmark.sh

# Run specific test suites
./benches/phase2_benchmark.sh simple       # Simple equality filters
./benches/phase2_benchmark.sh search       # Full-text search
./benches/phase2_benchmark.sh nested       # Complex nested filters
./benches/phase2_benchmark.sh cache        # Cache performance

# With custom URL and token
./benches/phase2_benchmark.sh all http://localhost:8080 "your_jwt_token"
```

### Interpreting Results
```
Key metrics to watch:
- Latency (mean, median, p95, p99, max)
- Throughput (requests/sec)
- Transfer rate (MB/sec)
- Connection errors
- Non-2xx responses
```

## Database Optimization

### 1. Index Verification

#### Check if GIN indexes are being used
```sql
-- Enable query planning output
SET work_mem = '256MB';  -- Temporary increase for EXPLAIN
SET enable_seqscan = off;  -- Force index usage for testing

-- Test full-text search query plan
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM llm_traces
WHERE content_search @@ plainto_tsquery('english', 'authentication error')
ORDER BY ts DESC
LIMIT 50;

-- Expected: "Bitmap Index Scan on idx_traces_content_fts"
-- If you see "Seq Scan", the GIN index is not being used!
```

#### Check all Phase 2 relevant indexes
```sql
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_stat_user_indexes
WHERE tablename = 'llm_traces'
    AND indexname LIKE '%fts%' OR indexname LIKE '%traces%'
ORDER BY idx_scan DESC;
```

#### Analyze index bloat
```sql
SELECT
    schemaname,
    tablename,
    attname,
    n_distinct,
    most_common_vals,
    most_common_freqs
FROM pg_stats
WHERE tablename = 'llm_traces'
    AND attname IN ('provider', 'model', 'status_code', 'environment');
```

### 2. Query Optimization

#### Analyze slow queries
```sql
-- Enable slow query logging (postgresql.conf)
-- log_min_duration_statement = 100  # Log queries > 100ms

-- Check slow queries
SELECT
    query,
    calls,
    total_time,
    mean_time,
    max_time,
    rows
FROM pg_stat_statements
WHERE query LIKE '%llm_traces%'
ORDER BY mean_time DESC
LIMIT 20;
```

#### Optimize specific query patterns
```sql
-- 1. Simple equality with sorting
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM llm_traces
WHERE provider = 'openai'
ORDER BY ts DESC
LIMIT 50;
-- Expected: Index Scan on idx_traces_provider_model
-- Cost: < 10ms for 1M rows

-- 2. Range query with comparison operator
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM llm_traces
WHERE duration_ms >= 1000
ORDER BY ts DESC
LIMIT 50;
-- Expected: Bitmap Index Scan or Index Scan
-- Cost: < 20ms for 1M rows

-- 3. Full-text search
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM llm_traces
WHERE content_search @@ plainto_tsquery('english', 'error message')
ORDER BY ts DESC
LIMIT 50;
-- Expected: Bitmap Index Scan on idx_traces_content_fts
-- Cost: < 50ms for 1M rows

-- 4. Complex nested filter
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM llm_traces
WHERE provider = 'openai'
  AND (duration_ms > 1000 OR total_cost_usd > 0.01)
ORDER BY ts DESC
LIMIT 50;
-- Expected: Multiple index scans combined with BitmapOr
-- Cost: < 100ms for 1M rows
```

### 3. Index Tuning

#### Create additional indexes if needed
```sql
-- If seeing slow queries on specific filter combinations
-- Example: Frequent queries on model + environment
CREATE INDEX CONCURRENTLY idx_traces_model_environment
ON llm_traces (model, environment, ts DESC)
WHERE model IS NOT NULL AND environment IS NOT NULL;

-- For cost-based queries
CREATE INDEX CONCURRENTLY idx_traces_cost_range
ON llm_traces (total_cost_usd, ts DESC)
WHERE total_cost_usd > 0;

-- For duration-based queries
CREATE INDEX CONCURRENTLY idx_traces_duration_range
ON llm_traces (duration_ms, ts DESC)
WHERE duration_ms > 0;
```

#### Remove unused indexes
```sql
-- Find indexes that are never used
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND tablename = 'llm_traces'
    AND idx_scan = 0
ORDER BY pg_relation_size(indexname::regclass) DESC;

-- Drop unused indexes (be careful!)
-- DROP INDEX CONCURRENTLY idx_name_here;
```

### 4. Vacuum and Analyze

```sql
-- Regular maintenance (run weekly or after large data changes)
VACUUM ANALYZE llm_traces;

-- For GIN indexes, more aggressive settings may help
ALTER INDEX idx_traces_content_fts SET (fastupdate = off);
REINDEX INDEX CONCURRENTLY idx_traces_content_fts;

-- Check last vacuum/analyze
SELECT
    schemaname,
    relname,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    n_live_tup,
    n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'llm_traces';
```

## Redis Caching Optimization

### 1. Monitor Cache Hit Rate

```bash
# Connect to Redis
redis-cli

# Check stats
INFO stats

# Key metrics:
# - keyspace_hits / (keyspace_hits + keyspace_misses) = hit rate
# - Target: > 70% hit rate
```

### 2. Optimize Cache TTL

Current TTL: 60 seconds (configurable via `CACHE_DEFAULT_TTL` env var)

**Recommendations:**
- Recent data (last 1 hour): 30-60 seconds
- Historical data (> 1 day old): 300-600 seconds
- Aggregated metrics: 300-1800 seconds

```rust
// In code (routes/traces.rs)
let cache_ttl = if is_recent_query(&search_req) {
    60  // 1 minute for recent data
} else {
    300 // 5 minutes for historical data
};
```

### 3. Cache Key Design

Current design: Hash of (user_id, filter, sort, limit, fields)

**Best practices:**
- ✅ Include all parameters that affect results
- ✅ Use consistent serialization (JSON)
- ✅ Hash long keys to keep them short
- ❌ Don't cache paginated requests (cursor-based)
- ❌ Don't cache user-specific auth data

### 4. Monitor Memory Usage

```bash
# Check Redis memory
redis-cli INFO memory

# Set max memory (configure in redis.conf or via env)
# maxmemory 2gb
# maxmemory-policy allkeys-lru  # Evict least recently used
```

## Connection Pool Tuning

### PostgreSQL Connection Pool

Current settings (main.rs:84-89):
```rust
let db_pool = sqlx::postgres::PgPoolOptions::new()
    .max_connections(20)      // Maximum connections
    .min_connections(5)       // Minimum idle connections
    .acquire_timeout(Duration::from_secs(30))
    .idle_timeout(Duration::from_secs(300))
    .max_lifetime(Duration::from_secs(1800))
    .connect(&database_url)
    .await?;
```

**Tuning recommendations:**

| Load Level | Max Connections | Min Connections | Notes |
|-----------|----------------|----------------|-------|
| Low (<100 req/s) | 10-20 | 5 | Default |
| Medium (100-500 req/s) | 20-50 | 10 | Increase both |
| High (500-2000 req/s) | 50-100 | 20 | Monitor DB load |
| Very High (>2000 req/s) | 100-200 | 30 | Consider read replicas |

**Formula:** `max_connections ≈ (concurrent_requests * avg_query_time_sec) / response_time_target`

Example:
- 1000 concurrent requests
- 50ms average query time
- Target 100ms response time
- `max_connections = (1000 * 0.05) / 0.1 = 500 / 0.1 = 50`

### Redis Connection Pool

Redis uses multiplexed connections (single connection per worker thread).

Monitor:
```bash
# Check connected clients
redis-cli CLIENT LIST

# Max clients (redis.conf)
# maxclients 10000
```

## Application-Level Optimizations

### 1. Reduce Allocations

```rust
// Before: Multiple allocations
let filter_sql = filter.to_sql(&mut param_index)?;
let where_clause = format!(" WHERE {}", filter_sql);

// After: Single allocation
let mut sql = String::with_capacity(1024);  // Pre-allocate
sql.push_str(" WHERE ");
sql.push_str(&filter_sql);
```

### 2. Use Streaming for Large Results

```rust
// For very large result sets, consider streaming
use futures::TryStreamExt;

let mut stream = sqlx::query_as::<_, Trace>(&sql)
    .fetch(&pool);

while let Some(trace) = stream.try_next().await? {
    // Process one at a time
}
```

### 3. Batch Operations

```rust
// When inserting test data or bulk operations
let mut tx = pool.begin().await?;
for trace in traces {
    sqlx::query("INSERT ...").execute(&mut tx).await?;
}
tx.commit().await?;
```

## Monitoring and Alerting

### Key Metrics to Monitor

#### Application Metrics (Prometheus)
```
# Request rate
rate(http_requests_total[1m])

# Latency (P95, P99)
histogram_quantile(0.95, http_request_duration_seconds_bucket)
histogram_quantile(0.99, http_request_duration_seconds_bucket)

# Error rate
rate(http_requests_total{status=~"5.."}[1m])

# Database query duration
histogram_quantile(0.95, db_query_duration_seconds_bucket)
```

#### Database Metrics
```sql
-- Active connections
SELECT count(*) FROM pg_stat_activity;

-- Slow queries
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC
LIMIT 10;

-- Cache hit ratio (should be > 95%)
SELECT
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) AS cache_hit_ratio
FROM pg_statio_user_tables;
```

#### Redis Metrics
```bash
# Hit rate
redis-cli INFO stats | grep keyspace

# Memory usage
redis-cli INFO memory | grep used_memory_human

# Slow log
redis-cli SLOWLOG GET 10
```

### Alert Thresholds

```yaml
# Prometheus alert rules
groups:
  - name: phase2_performance
    rules:
      - alert: HighP95Latency
        expr: histogram_quantile(0.95, http_request_duration_seconds_bucket) > 0.5
        for: 5m
        annotations:
          summary: "P95 latency above 500ms"

      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
        for: 5m
        annotations:
          summary: "Error rate above 1%"

      - alert: LowCacheHitRate
        expr: redis_keyspace_hits / (redis_keyspace_hits + redis_keyspace_misses) < 0.7
        for: 10m
        annotations:
          summary: "Cache hit rate below 70%"
```

## Performance Tuning Checklist

### Before Deployment
- [ ] Run full benchmark suite: `./benches/phase2_benchmark.sh all`
- [ ] Verify all GIN indexes created: `\di llm_traces`
- [ ] Check query plans for common queries: `EXPLAIN ANALYZE`
- [ ] Test with 1M+ rows of data
- [ ] Test concurrent load (100+ simultaneous users)
- [ ] Verify cache hit rates > 70%
- [ ] Test failure scenarios (DB down, Redis down)

### After Deployment
- [ ] Monitor P95/P99 latency for 24 hours
- [ ] Check for slow queries: `pg_stat_statements`
- [ ] Monitor database connection pool usage
- [ ] Track cache hit rates
- [ ] Review error logs
- [ ] Check index usage statistics
- [ ] Monitor memory usage (Redis + PostgreSQL)
- [ ] Track disk I/O (PostgreSQL)

### Weekly Maintenance
- [ ] Run `VACUUM ANALYZE llm_traces`
- [ ] Review slow query log
- [ ] Check for unused indexes
- [ ] Review cache TTL effectiveness
- [ ] Analyze query patterns
- [ ] Check for index bloat
- [ ] Review connection pool statistics

## Troubleshooting Common Issues

### Issue 1: Slow Full-Text Search

**Symptoms:** Full-text search queries > 200ms

**Diagnosis:**
```sql
EXPLAIN ANALYZE
SELECT * FROM llm_traces
WHERE content_search @@ plainto_tsquery('english', 'test')
LIMIT 50;
```

**Solutions:**
1. Verify GIN index exists: `\d llm_traces`
2. Force index usage: `SET enable_seqscan = off;`
3. Reindex if bloated: `REINDEX INDEX CONCURRENTLY idx_traces_content_fts;`
4. Increase `work_mem`: `SET work_mem = '256MB';`
5. Check tsvector column populated: `SELECT COUNT(*) FROM llm_traces WHERE content_search IS NULL;`

### Issue 2: High P99 Latency

**Symptoms:** P50 is fast but P99 > 1000ms

**Causes:**
- GC pauses (rare in Rust)
- Database connection timeout
- Cache miss storms
- Lock contention

**Solutions:**
1. Increase connection pool: `max_connections = 50`
2. Add query timeout: `.acquire_timeout(Duration::from_secs(10))`
3. Implement circuit breaker pattern
4. Add retry logic with exponential backoff

### Issue 3: Low Cache Hit Rate

**Symptoms:** Cache hit rate < 50%

**Diagnosis:**
```bash
redis-cli INFO stats
# Check: keyspace_hits / (keyspace_hits + keyspace_misses)
```

**Solutions:**
1. Increase cache TTL for stable queries
2. Warm cache on startup
3. Increase Redis memory: `maxmemory 4gb`
4. Review cache key design
5. Exclude uncacheable queries (cursor-based pagination)

### Issue 4: Connection Pool Exhaustion

**Symptoms:** `Connection pool timeout` errors

**Diagnosis:**
```rust
// Add metrics to track pool usage
let active = pool.size();
let idle = pool.num_idle();
tracing::info!("Pool: active={}, idle={}", active, idle);
```

**Solutions:**
1. Increase `max_connections`: 20 → 50 → 100
2. Reduce `acquire_timeout`: 30s → 10s
3. Check for connection leaks (unclosed transactions)
4. Add connection pool metrics to monitoring

## Advanced Optimizations

### 1. Read Replicas

For high read load (> 5000 req/s):

```rust
// Route read-only queries to replicas
let read_pool = PgPoolOptions::new()
    .connect(&replica_database_url)
    .await?;

let write_pool = PgPoolOptions::new()
    .connect(&primary_database_url)
    .await?;
```

### 2. Query Result Caching at Multiple Levels

```
User Request
    ↓
Application Cache (Redis) ← 70% cache hits, < 5ms
    ↓ (cache miss)
Database Query Plan Cache ← 20% cache hits, < 10ms
    ↓ (cache miss)
Database Disk I/O ← 10% cache misses, < 100ms
```

### 3. Materialized Views

For expensive aggregations:

```sql
-- Create materialized view for common aggregations
CREATE MATERIALIZED VIEW llm_traces_hourly AS
SELECT
    date_trunc('hour', ts) as hour,
    provider,
    model,
    COUNT(*) as request_count,
    AVG(duration_ms) as avg_duration,
    SUM(total_cost_usd) as total_cost
FROM llm_traces
GROUP BY 1, 2, 3;

-- Refresh periodically (cron job)
REFRESH MATERIALIZED VIEW CONCURRENTLY llm_traces_hourly;
```

### 4. Partitioning

For very large tables (>100M rows):

```sql
-- Partition by time range
CREATE TABLE llm_traces_2025_11 PARTITION OF llm_traces
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

-- Automatically improves query performance for time-range queries
```

## References

- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [GIN Index Documentation](https://www.postgresql.org/docs/current/gin.html)
- [Redis Best Practices](https://redis.io/docs/manual/patterns/)
- [Rust sqlx Performance](https://github.com/launchbadge/sqlx/blob/main/FAQ.md#performance)

---

**Last Updated:** 2025-11-05
**Next Review:** After first production deployment

# Migration 004: Continuous Aggregates - Fix Documentation

## Overview

Migration 004 creates continuous aggregates (materialized views) for the TimescaleDB storage layer. This document details the issues found in the original migration and the fixes applied.

## Issues Fixed

### 1. PERCENTILE_CONT Not Supported (CRITICAL)

**Problem:**
```sql
-- This DOES NOT WORK in TimescaleDB 2.14 continuous aggregates
PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_ms) AS p50_duration_ms
```

**Root Cause:**
- TimescaleDB continuous aggregates only support **parallelizable aggregates**
- PERCENTILE_CONT requires ordering the entire dataset, which cannot be computed incrementally
- Continuous aggregates work by combining partial aggregates from chunks, but percentiles need complete data

**Solution:**
Instead of computing percentiles in the aggregate, we store statistics that allow percentile calculation:
```sql
-- Store basic statistics
AVG(duration_ms) AS avg_duration_ms,
MIN(duration_ms) AS min_duration_ms,
MAX(duration_ms) AS max_duration_ms,
SUM(duration_ms * duration_ms) AS sum_duration_ms_squared,  -- For stddev
```

**Percentile Options:**

1. **Query raw data directly** (recommended for accurate percentiles):
   ```sql
   SELECT
       time_bucket('1 minute', ts) AS bucket,
       provider,
       model,
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_ms) AS p50,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) AS p95,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) AS p99
   FROM llm_traces
   WHERE ts >= NOW() - INTERVAL '15 minutes'
   GROUP BY bucket, provider, model;
   ```

2. **Use TimescaleDB Toolkit** (requires additional extension):
   ```sql
   -- Install timescaledb-toolkit for approximate percentiles
   CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit;

   -- Use percentile_agg (two-step aggregation)
   SELECT
       time_bucket('1 minute', ts) AS bucket,
       approx_percentile(0.95, percentile_agg(duration_ms)) AS p95
   FROM llm_traces
   GROUP BY bucket;
   ```

3. **Statistical approximation** (from stored statistics):
   ```sql
   SELECT
       bucket,
       avg_duration_ms,
       -- Approximate stddev
       SQRT(
           GREATEST(
               (sum_duration_ms_squared / request_count) -
               (avg_duration_ms * avg_duration_ms),
               0
           )
       ) AS stddev_duration_ms,
       -- Approximate P95 (assuming normal distribution: mean + 1.645 * stddev)
       avg_duration_ms + (1.645 * stddev_duration_ms) AS approx_p95
   FROM llm_metrics_1min;
   ```

### 2. Error Rate Calculation Issue

**Problem:**
```sql
-- Original: tries to compute error_rate directly with status_code filter
SUM(CASE WHEN status_code = 'ERROR' THEN 1 ELSE 0 END)::FLOAT / COUNT(*) AS error_rate
```

**Solution:**
Store error counts separately and compute rate in queries:
```sql
-- In the aggregate
SUM(CASE WHEN status_code = 'ERROR' THEN 1 ELSE 0 END) AS error_count,
SUM(CASE WHEN status_code = 'OK' THEN 1 ELSE 0 END) AS success_count,

-- In queries
SELECT
    error_count::NUMERIC / NULLIF(request_count, 0) * 100 AS error_rate_pct
FROM llm_metrics_1hour;
```

### 3. Missing llm_error_summary Aggregate

**Problem:**
The requirements specified 4 aggregates, but the original migration created `cost_analysis_hourly` instead of `llm_error_summary`.

**Solution:**
Created dedicated `llm_error_summary` view:
```sql
CREATE MATERIALIZED VIEW llm_error_summary
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', ts) AS bucket,
    provider,
    model,
    status_code,
    environment,
    COUNT(*) AS error_count,
    MIN(error_message) AS sample_error_message,
    AVG(duration_ms) AS avg_duration_ms,
    COUNT(DISTINCT user_id) AS affected_users
FROM llm_traces
WHERE status_code != 'OK'
GROUP BY bucket, provider, model, status_code, environment;
```

## Migration Changes Summary

### Created Continuous Aggregates

1. **llm_metrics_1min** (1-minute buckets)
   - Purpose: Real-time monitoring dashboards
   - Refresh: Every 30 seconds
   - Retention: 37 days
   - Key metrics: request_count, tokens, cost, duration stats

2. **llm_metrics_1hour** (1-hour buckets)
   - Purpose: Historical analysis and trending
   - Refresh: Every 5 minutes
   - Retention: 210 days
   - Key metrics: All metrics + error counts, token breakdown

3. **llm_metrics_1day** (1-day buckets)
   - Purpose: Long-term trends and capacity planning
   - Refresh: Every 1 hour
   - Retention: 3 years (1095 days)
   - Key metrics: Cost breakdown, unique users/sessions

4. **llm_error_summary** (1-hour buckets)
   - Purpose: Error tracking and alerting
   - Refresh: Every 5 minutes
   - Retention: 210 days
   - Key metrics: Error counts, affected users, sample messages

### Schema Comparison

#### Before (with PERCENTILE_CONT - BROKEN)
```sql
-- llm_metrics_1min
bucket, provider, model, status_code,
request_count, total_tokens, total_cost_usd,
avg_duration_ms,
p50_duration_ms,  -- ❌ NOT SUPPORTED
p95_duration_ms,  -- ❌ NOT SUPPORTED
p99_duration_ms,  -- ❌ NOT SUPPORTED
min_duration_ms, max_duration_ms
```

#### After (statistics-based - WORKING)
```sql
-- llm_metrics_1min
bucket, provider, model, status_code,
request_count, total_tokens, total_cost_usd,
avg_duration_ms, min_duration_ms, max_duration_ms,
sum_duration_ms_squared,  -- ✅ For stddev calculation
avg_prompt_tokens, avg_completion_tokens  -- ✅ Added
```

## Verification Steps

### 1. Run the Migration
```bash
psql -U postgres -d llm_observatory -f 004_continuous_aggregates.sql
```

### 2. Run the Test Suite
```bash
psql -U postgres -d llm_observatory -f test_004_continuous_aggregates.sql
```

### 3. Manual Verification
```sql
-- List all continuous aggregates
SELECT view_name, refresh_lag, refresh_interval
FROM timescaledb_information.continuous_aggregates;

-- Expected output:
-- llm_metrics_1min
-- llm_metrics_1hour
-- llm_metrics_1day
-- llm_error_summary

-- Check refresh policies
SELECT
    hypertable_name,
    schedule_interval,
    config
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_refresh_continuous_aggregate';
```

### 4. Query Examples
```sql
-- Real-time metrics (last 15 minutes)
SELECT
    bucket,
    provider,
    model,
    request_count,
    ROUND(total_cost_usd::NUMERIC, 6) AS cost,
    ROUND(avg_duration_ms::NUMERIC, 2) AS avg_ms
FROM llm_metrics_1min
WHERE bucket >= NOW() - INTERVAL '15 minutes'
ORDER BY bucket DESC;

-- Error rates (last 24 hours)
SELECT
    bucket,
    provider,
    model,
    request_count,
    error_count,
    ROUND(error_count::NUMERIC / NULLIF(request_count, 0) * 100, 2) AS error_rate_pct
FROM llm_metrics_1hour
WHERE bucket >= NOW() - INTERVAL '24 hours'
ORDER BY error_rate_pct DESC NULLS LAST;

-- Daily trends (last 30 days)
SELECT
    bucket::DATE,
    provider,
    SUM(request_count) AS requests,
    ROUND(SUM(total_cost_usd)::NUMERIC, 2) AS total_cost,
    SUM(unique_users) AS users
FROM llm_metrics_1day
WHERE bucket >= NOW() - INTERVAL '30 days'
GROUP BY bucket::DATE, provider
ORDER BY bucket DESC;

-- Recent errors
SELECT
    bucket,
    provider,
    model,
    status_code,
    error_count,
    affected_users,
    sample_error_message
FROM llm_error_summary
WHERE bucket >= NOW() - INTERVAL '6 hours'
ORDER BY error_count DESC;
```

## Performance Considerations

### Benefits of Continuous Aggregates
- **50-1000x faster queries** for historical data
- **Reduced storage** compared to raw traces
- **Automatic refresh** keeps data up-to-date
- **Lower resource usage** for dashboards

### Trade-offs
- **No exact percentiles** (use approximations or query raw data)
- **Slight delay** in data availability (refresh lag)
- **Additional storage** for materialized views

### Best Practices

1. **For real-time percentiles (< 15 min):** Query raw `llm_traces` table
2. **For historical percentiles (> 1 hour):** Use statistical approximations
3. **For dashboards:** Use continuous aggregates for speed
4. **For alerts:** Use `llm_error_summary` for error detection

## Troubleshooting

### Issue: "function percentile_cont(...) not supported for continuous aggregates"

**Cause:** Using unsupported aggregate functions

**Solution:** Use the fixed migration which removes PERCENTILE_CONT

### Issue: Continuous aggregate not refreshing

**Check refresh policies:**
```sql
SELECT * FROM timescaledb_information.jobs
WHERE proc_name = 'policy_refresh_continuous_aggregate';
```

**Manual refresh:**
```sql
CALL refresh_continuous_aggregate('llm_metrics_1min', NULL, NULL);
```

### Issue: Data mismatch between aggregate and raw data

**Cause:** Aggregate not yet refreshed for recent data

**Check materialization threshold:**
```sql
SELECT
    view_name,
    completed_threshold,
    invalidation_threshold
FROM timescaledb_information.continuous_aggregate_stats;
```

**Force refresh:**
```sql
CALL refresh_continuous_aggregate('llm_metrics_1min',
    NOW() - INTERVAL '1 hour',
    NOW());
```

### Issue: High memory usage during refresh

**Solution:** Adjust refresh window sizes
```sql
-- Smaller windows = less memory, more frequent refreshes
SELECT remove_continuous_aggregate_policy('llm_metrics_1min');
SELECT add_continuous_aggregate_policy('llm_metrics_1min',
    start_offset => INTERVAL '30 minutes',  -- Reduced from 1 hour
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '30 seconds');
```

## References

- [TimescaleDB Continuous Aggregates](https://docs.timescale.com/use-timescale/latest/continuous-aggregates/)
- [Supported Aggregate Functions](https://docs.timescale.com/use-timescale/latest/continuous-aggregates/about-continuous-aggregates/#aggregate-functions)
- [TimescaleDB Toolkit](https://github.com/timescale/timescaledb-toolkit) (for approximate percentiles)
- [Refresh Policies](https://docs.timescale.com/api/latest/continuous-aggregates/add_continuous_aggregate_policy/)

## Migration History

- **2025-11-05:** Initial version with PERCENTILE_CONT (broken)
- **2025-11-05:** Fixed version without PERCENTILE_CONT (working)
  - Removed unsupported percentile functions
  - Added statistics for percentile approximation
  - Created llm_error_summary aggregate
  - Enhanced error tracking with separate counts
  - Added comprehensive documentation and test suite

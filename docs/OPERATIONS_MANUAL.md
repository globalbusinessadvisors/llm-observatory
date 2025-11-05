# LLM Observatory Storage Layer - Operations Manual

**Version:** 1.0
**Last Updated:** 2025-11-05
**Maintained By:** LLM Observatory Team
**Purpose:** Comprehensive operational procedures for the storage layer

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Daily Operations](#daily-operations)
4. [Monitoring and Alerting](#monitoring-and-alerting)
5. [Troubleshooting Guide](#troubleshooting-guide)
6. [Maintenance Procedures](#maintenance-procedures)
7. [Disaster Recovery](#disaster-recovery)
8. [Performance Tuning](#performance-tuning)
9. [Security Operations](#security-operations)
10. [Quick Reference](#quick-reference)

---

## Overview

### Purpose

This operations manual serves as the single source of truth for operating, maintaining, and troubleshooting the LLM Observatory storage layer. It provides step-by-step procedures for routine operations, incident response, and system optimization.

### Scope

The storage layer includes:

- **TimescaleDB (PostgreSQL)** - Primary time-series database for traces, metrics, and logs
- **Redis** - Optional caching layer for query optimization
- **Storage Service** - Rust-based API service providing data ingestion and query capabilities
- **Connection Pool** - Managed database connection pooling with retry logic
- **Monitoring Stack** - Prometheus metrics, Grafana dashboards, and alerting

### Document Organization

- **Sections 1-3:** Day-to-day operations and routine tasks
- **Sections 4-6:** Monitoring, troubleshooting, and maintenance
- **Sections 7-9:** Disaster recovery, performance, and security
- **Section 10:** Quick reference for common commands

### Key Contacts

See [Emergency Contacts](#emergency-contacts) section for on-call rotation and escalation paths.

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    LLM Observatory                          │
│                   Observability Platform                    │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │      Storage Layer (Rust API)       │
        │  ┌──────────────────────────────┐   │
        │  │  Writers (Instrumented)      │   │
        │  │  - TraceWriter               │   │
        │  │  - MetricWriter              │   │
        │  │  - LogWriter                 │   │
        │  │  - CopyWriter (COPY protocol)│   │
        │  └──────────────────────────────┘   │
        │  ┌──────────────────────────────┐   │
        │  │  Repositories (Instrumented) │   │
        │  │  - TraceRepository           │   │
        │  │  - MetricRepository          │   │
        │  │  - LogRepository             │   │
        │  └──────────────────────────────┘   │
        │  ┌──────────────────────────────┐   │
        │  │  Connection Pool Manager     │   │
        │  │  - PostgreSQL Pool (SQLx)    │   │
        │  │  - Redis Pool (Optional)     │   │
        │  │  - Retry Logic               │   │
        │  └──────────────────────────────┘   │
        │  ┌──────────────────────────────┐   │
        │  │  Health & Metrics Server     │   │
        │  │  - /health endpoint          │   │
        │  │  - /metrics (Prometheus)     │   │
        │  └──────────────────────────────┘   │
        └────────────┬────────────┬───────────┘
                     │            │
        ┌────────────▼───┐    ┌───▼──────────┐
        │  TimescaleDB   │    │    Redis     │
        │  (PostgreSQL)  │    │  (Optional)  │
        │                │    │              │
        │  - Hypertables │    │  - Caching   │
        │  - Continuous  │    │  - Sessions  │
        │    Aggregates  │    └──────────────┘
        │  - Compression │
        │  - Retention   │
        └────────────────┘
                │
        ┌───────▼────────┐
        │   Monitoring   │
        │  ┌──────────┐  │
        │  │Prometheus│  │
        │  └────┬─────┘  │
        │  ┌────▼─────┐  │
        │  │ Grafana  │  │
        │  └──────────┘  │
        └────────────────┘
```

### Component Details

#### Storage Service (Rust)

- **Language:** Rust 1.75+
- **Async Runtime:** Tokio
- **Database Driver:** SQLx (for queries), tokio-postgres (for COPY)
- **Deployment:** Systemd service or Docker container
- **Port:** 8080 (API), 9090 (metrics/health)
- **Configuration:** Environment variables or config file

**Key Features:**
- Zero-copy COPY protocol for high-throughput writes (50k-100k rows/sec)
- Instrumented writers with automatic Prometheus metrics
- Connection pooling with configurable retry logic
- Comprehensive error handling and validation

#### TimescaleDB (PostgreSQL)

- **Version:** PostgreSQL 16 with TimescaleDB 2.13+
- **Port:** 5432
- **Storage:** Persistent volume (minimum 100GB, production: 500GB+)
- **Backups:** Daily automated backups to local disk and S3

**Schema Components:**
- **Hypertables:** llm_traces, llm_metrics, llm_logs (time-series optimized)
- **Continuous Aggregates:** Pre-computed hourly/daily rollups
- **Compression:** Automatic compression for data older than 7 days
- **Retention:** 90-day retention with configurable policies
- **Indexes:** Optimized B-tree and BRIN indexes for time-series queries

#### Redis (Optional)

- **Version:** Redis 7.0+
- **Port:** 6379
- **Purpose:** Query result caching, session storage
- **Memory:** 2-4GB recommended
- **Eviction:** LRU (Least Recently Used)

### Data Flow

```
Write Path:
1. Application → Storage API (port 8080)
2. Storage API → InstrumentedWriter (metrics recorded)
3. InstrumentedWriter → CopyWriter or BatchWriter
4. CopyWriter → PostgreSQL COPY protocol (fastest)
   OR BatchWriter → PostgreSQL INSERT batch
5. PostgreSQL → Hypertable (partitioned by time)
6. Background: Compression, Retention, Aggregation

Query Path:
1. Application → Storage API (port 8080)
2. Storage API → InstrumentedRepository (metrics recorded)
3. InstrumentedRepository → Check Redis cache (if enabled)
4. On cache miss → PostgreSQL query
5. PostgreSQL → Hypertable or Continuous Aggregate
6. Store in Redis cache → Return to application
```

### Network Diagram

```
┌──────────────┐
│  Internet    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Load Balancer│ (443, SSL termination)
└──────┬───────┘
       │
       ▼
┌──────────────────────────────┐
│  Storage Service Instances   │ (8080)
│  ┌────┐ ┌────┐ ┌────┐        │
│  │ A  │ │ B  │ │ C  │        │
│  └────┘ └────┘ └────┘        │
└──────┬───────────────────────┘
       │
       ├─────────────┬──────────┐
       ▼             ▼          ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│TimeScale │  │  Redis   │  │Prometheus│
│   DB     │  │          │  │          │
│ (5432)   │  │  (6379)  │  │  (9090)  │
└──────────┘  └──────────┘  └──────────┘
       │
       ▼
┌──────────────┐
│  S3 Backups  │
└──────────────┘
```

### Storage Layout

#### Database Schema

```sql
-- Hypertables (time-series optimized)
llm_traces (
  id UUID PRIMARY KEY,
  trace_id UUID NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  service_name TEXT NOT NULL,
  duration_ms BIGINT,
  status_code INTEGER,
  -- ... additional fields
  -- Partitioned by: timestamp (7-day chunks)
)

llm_metrics (
  id UUID PRIMARY KEY,
  trace_id UUID NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  metric_name TEXT NOT NULL,
  value DOUBLE PRECISION,
  -- ... additional fields
  -- Partitioned by: timestamp (1-day chunks)
)

llm_logs (
  id UUID PRIMARY KEY,
  trace_id UUID NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  level TEXT NOT NULL,
  message TEXT,
  -- ... additional fields
  -- Partitioned by: timestamp (1-day chunks)
)

-- Supporting tables
trace_spans (...)
trace_events (...)
metric_labels (...)
schema_migrations (...)
```

#### File System Layout

```
/var/lib/postgresql/
├── data/                    # PostgreSQL data directory
│   ├── base/               # Database files
│   ├── pg_wal/             # Write-Ahead Log files
│   └── ...
├── wal_archive/            # Archived WAL files for PITR
│   └── 000000010000000000000001
└── backups/                # Local backups
    ├── daily/
    ├── hourly/
    └── logs/

/opt/llm-observatory/
├── storage/                # Storage service
│   ├── bin/
│   │   └── llm-observatory-storage
│   ├── config/
│   │   ├── production.yaml
│   │   └── .env
│   ├── migrations/
│   │   ├── 001_initial_schema.sql
│   │   └── ...
│   └── logs/
│       └── storage.log

/var/backups/
└── llm-observatory/
    ├── local/              # Local backup retention
    └── s3/                 # S3 sync cache
```

### Configuration Files

**Storage Service (.env):**
```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=llm_observatory
DB_USER=postgres
DB_PASSWORD=***
DB_SSL_MODE=prefer
DB_APP_NAME=llm-observatory-storage

# Connection Pool
DB_POOL_MAX_CONNECTIONS=100
DB_POOL_MIN_CONNECTIONS=20
DB_POOL_CONNECT_TIMEOUT=10
DB_POOL_IDLE_TIMEOUT=300
DB_POOL_MAX_LIFETIME=1800

# Redis (optional)
REDIS_URL=redis://localhost:6379/0
REDIS_POOL_SIZE=50
REDIS_TIMEOUT_SECS=5

# Retry Policy
DB_RETRY_MAX_ATTEMPTS=3
DB_RETRY_INITIAL_DELAY_MS=100
DB_RETRY_MAX_DELAY_MS=5000
DB_RETRY_BACKOFF_MULTIPLIER=2.0

# Observability
LOG_LEVEL=info
METRICS_ENABLED=true
HEALTH_CHECK_PORT=9090
```

**TimescaleDB (postgresql.conf):**
```conf
# Memory
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 64MB
maintenance_work_mem = 1GB

# WAL
wal_level = replica
max_wal_size = 4GB
min_wal_size = 1GB
checkpoint_timeout = 15min

# Performance
random_page_cost = 1.1  # SSD optimization
effective_io_concurrency = 200

# Connection
max_connections = 200
shared_preload_libraries = 'timescaledb'

# Logging
log_min_duration_statement = 1000  # Log queries >1s
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```

---

## Daily Operations

### Daily Operations Checklist

Perform these checks every day at 09:00 local time.

#### 1. System Health Check

```bash
# Run automated health check
./scripts/daily_health_check.sh

# Manual verification
curl -f http://localhost:9090/health | jq .

# Expected output:
# {
#   "status": "healthy",
#   "timestamp": "2025-11-05T09:00:00Z",
#   "database": {
#     "postgres": {
#       "status": "healthy",
#       "latency_ms": 2.3
#     },
#     "redis": {
#       "status": "healthy",
#       "latency_ms": 1.1
#     }
#   },
#   "pool_stats": {
#     "size": 85,
#     "active": 23,
#     "idle": 62,
#     "max_connections": 100,
#     "utilization_percent": 23.0,
#     "near_capacity": false
#   }
# }
```

**Action Items:**
- [ ] Verify status is "healthy"
- [ ] Check database latency < 10ms
- [ ] Confirm pool utilization < 80%
- [ ] Document any anomalies in operations log

#### 2. Review Overnight Alerts

```bash
# Check Prometheus alerts in last 24 hours
curl -s 'http://prometheus:9090/api/v1/alerts' | \
  jq '.data.alerts[] | select(.state=="firing")'

# Review application logs for errors
journalctl -u llm-observatory-storage \
  --since yesterday \
  --priority err \
  | grep -v "expected_noise_pattern"

# Count error occurrences
journalctl -u llm-observatory-storage \
  --since yesterday \
  | grep -c ERROR
```

**Action Items:**
- [ ] Investigate any firing alerts
- [ ] Review error logs (target: <10 errors/day)
- [ ] Create tickets for recurring issues
- [ ] Update alert thresholds if needed

#### 3. Verify Backup Completion

```bash
# Check latest backup
ls -lh /var/lib/postgresql/backups/daily/ | tail -5

# Verify backup integrity
./scripts/verify_backup.sh -v

# Check S3 backup sync
aws s3 ls s3://llm-observatory-backups/daily/ \
  --recursive | tail -5

# Verify WAL archiving
psql -h localhost -U postgres -d llm_observatory -c \
  "SELECT archived_count, last_archived_time, failed_count
   FROM pg_stat_archiver;"
```

**Action Items:**
- [ ] Confirm backup created in last 24h
- [ ] Verify backup size is reasonable (compare to yesterday)
- [ ] Check S3 sync completed
- [ ] Ensure WAL archiving has no failures
- [ ] If backup failed, investigate and retry

#### 4. Monitor Disk Space

```bash
# Check database disk usage
df -h /var/lib/postgresql/data

# Check backup disk usage
df -h /var/lib/postgresql/backups

# Database size growth
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  pg_database.datname,
  pg_size_pretty(pg_database_size(pg_database.datname)) AS size,
  pg_size_pretty(
    pg_database_size(pg_database.datname) -
    LAG(pg_database_size(pg_database.datname))
      OVER (ORDER BY pg_database.datname)
  ) AS growth
FROM pg_database
WHERE datname = 'llm_observatory';
EOF

# Table sizes and growth
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || tablename AS table_name,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
  pg_size_pretty(
    pg_total_relation_size(schemaname||'.'||tablename) -
    pg_relation_size(schemaname||'.'||tablename)
  ) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
EOF
```

**Action Items:**
- [ ] Alert if disk usage > 70%
- [ ] Plan capacity expansion if > 80%
- [ ] Review retention policies if growing too fast
- [ ] Clean up old backups if backup disk is full

#### 5. Review Connection Pool Usage

```bash
# Current pool statistics
curl -s http://localhost:9090/metrics | grep storage_pool_connections

# Database connection breakdown
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  application_name,
  state,
  COUNT(*) as connections,
  MAX(NOW() - state_change) as max_duration
FROM pg_stat_activity
WHERE datname = 'llm_observatory'
GROUP BY application_name, state
ORDER BY connections DESC;
EOF

# Long-running queries
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  pid,
  usename,
  application_name,
  state,
  NOW() - query_start AS duration,
  LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND NOW() - query_start > INTERVAL '1 minute'
ORDER BY duration DESC;
EOF
```

**Action Items:**
- [ ] Alert if pool utilization > 80%
- [ ] Investigate idle connections > 10 minutes
- [ ] Terminate long-running queries if abnormal
- [ ] Adjust pool size if consistently near capacity

#### 6. Check Query Performance

```bash
# Slow queries in last 24 hours (requires pg_stat_statements)
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  LEFT(query, 100) AS query_preview,
  calls,
  ROUND(mean_exec_time::numeric, 2) AS mean_ms,
  ROUND(max_exec_time::numeric, 2) AS max_ms,
  ROUND(total_exec_time::numeric, 2) AS total_ms,
  ROUND((100 * total_exec_time / SUM(total_exec_time) OVER ())::numeric, 2) AS pct_total_time
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = 'llm_observatory')
  AND mean_exec_time > 1000  -- queries averaging >1s
ORDER BY total_exec_time DESC
LIMIT 10;
EOF

# Cache hit ratio (should be >95%)
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname,
  relname,
  heap_blks_read,
  heap_blks_hit,
  ROUND(
    100.0 * heap_blks_hit / NULLIF(heap_blks_hit + heap_blks_read, 0),
    2
  ) AS cache_hit_ratio
FROM pg_statio_user_tables
WHERE heap_blks_hit + heap_blks_read > 0
ORDER BY heap_blks_read DESC
LIMIT 10;
EOF
```

**Action Items:**
- [ ] Investigate queries with mean time > 1s
- [ ] Create indexes for frequently scanned tables
- [ ] Alert if cache hit ratio < 95%
- [ ] Review query patterns with development team

#### 7. Verify Monitoring and Dashboards

```bash
# Check Prometheus is scraping metrics
curl -s 'http://prometheus:9090/api/v1/targets' | \
  jq '.data.activeTargets[] | select(.labels.job=="storage-layer")'

# Verify Grafana is accessible
curl -f http://grafana:3000/api/health

# Check dashboard data freshness
# (Manual: Open Grafana dashboards)
```

**Action Items:**
- [ ] Verify Prometheus scraping is active
- [ ] Check Grafana dashboards load correctly
- [ ] Ensure data is current (not stale)
- [ ] Review dashboard alerts

#### 8. Review Continuous Aggregates

```bash
# Check continuous aggregate freshness
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  view_name,
  completed_threshold,
  invalidation_threshold,
  NOW() - completed_threshold AS lag
FROM timescaledb_information.continuous_aggregates
ORDER BY view_name;
EOF

# Refresh if needed (manual)
# CALL refresh_continuous_aggregate('trace_metrics_hourly', NULL, NULL);
```

**Action Items:**
- [ ] Ensure lag < 1 hour for hourly aggregates
- [ ] Refresh aggregates if lag is excessive
- [ ] Investigate if refresh is consistently slow

#### 9. Certificate Expiry Check

```bash
# Check SSL certificate expiry
echo | openssl s_client -connect localhost:5432 -starttls postgres 2>/dev/null | \
  openssl x509 -noout -dates

# Check days until expiry
echo | openssl s_client -connect localhost:5432 -starttls postgres 2>/dev/null | \
  openssl x509 -noout -checkend $((30*86400)) && \
  echo "Certificate valid for 30+ days" || \
  echo "WARNING: Certificate expires in <30 days"
```

**Action Items:**
- [ ] Alert if certificate expires in < 30 days
- [ ] Schedule certificate renewal
- [ ] Test certificate renewal procedure

#### 10. Documentation Updates

```bash
# Check for pending documentation updates
git status docs/

# Review recent operational incidents
cat /var/log/llm-observatory/incidents.log
```

**Action Items:**
- [ ] Document any new procedures discovered
- [ ] Update troubleshooting guide with new issues
- [ ] Review and close completed incident tickets

### Daily Checklist Summary

```
┌─────────────────────────────────────────────────┐
│          Daily Operations Checklist             │
├─────────────────────────────────────────────────┤
│ □ System health check                           │
│ □ Review overnight alerts                       │
│ □ Verify backup completion                      │
│ □ Monitor disk space                            │
│ □ Review connection pool usage                  │
│ □ Check query performance                       │
│ □ Verify monitoring and dashboards              │
│ □ Review continuous aggregates                  │
│ □ Certificate expiry check                      │
│ □ Documentation updates                         │
└─────────────────────────────────────────────────┘

Target completion time: 30-45 minutes
Escalate if: Any critical issues discovered
Document: All findings in operations log
```

### Routine Maintenance Tasks

#### Every 8 Hours

```bash
# Update pool metrics
curl -X POST http://localhost:9090/admin/update_metrics

# Check for vacuum needs
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || relname AS table_name,
  n_dead_tup,
  n_live_tup,
  ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup, 0), 2) AS dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 10;
EOF
```

#### Weekly Tasks

See [Weekly Maintenance](#weekly-maintenance) section.

#### Monthly Tasks

See [Monthly Maintenance](#monthly-maintenance) section.

---

## Monitoring and Alerting

### Key Metrics Overview

#### Write Performance Metrics

| Metric | Prometheus Query | Target | Warning | Critical |
|--------|------------------|--------|---------|----------|
| Write Throughput | `rate(storage_writes_total{status="success"}[1m])` | >100/s | <50/s | <10/s |
| Write P95 Latency | `histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket[5m]))` | <100ms | >500ms | >1s |
| Write Success Rate | `(rate(storage_writes_total{status="success"}[5m]) / rate(storage_writes_total[5m])) * 100` | >99% | <99% | <95% |
| Items/Second | `rate(storage_items_written_total[1m])` | >1000/s | <500/s | <100/s |
| Batch Size (median) | `histogram_quantile(0.50, rate(storage_batch_size_bucket[5m]))` | >100 | <50 | <10 |

#### Query Performance Metrics

| Metric | Prometheus Query | Target | Warning | Critical |
|--------|------------------|--------|---------|----------|
| Query P95 Latency | `histogram_quantile(0.95, rate(storage_query_duration_seconds_bucket[5m]))` | <50ms | >200ms | >1s |
| Query Throughput | `rate(storage_query_duration_seconds_count[1m])` | >10/s | <5/s | <1/s |
| Query Success Rate | Derived from error rate | >99% | <99% | <95% |

#### Database Health Metrics

| Metric | Prometheus Query | Target | Warning | Critical |
|--------|------------------|--------|---------|----------|
| Pool Utilization | `(storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) * 100` | <70% | >80% | >90% |
| Connection Acquire Time | `histogram_quantile(0.95, rate(storage_connection_acquire_duration_seconds_bucket[5m]))` | <10ms | >50ms | >100ms |
| Error Rate | `rate(storage_errors_total[1m])` | <0.01/s | >0.1/s | >1/s |
| Cache Hit Ratio | `pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read)` | >95% | <95% | <85% |

### Grafana Dashboards

#### 1. Storage Overview Dashboard

**URL:** `http://grafana:3000/d/storage-overview`

**Panels:**
- Write throughput and latency (time series)
- Items written per second by type (stacked area)
- Connection pool utilization (gauge and graph)
- Error rate (time series with threshold lines)
- Query latency percentiles (p50, p95, p99)
- COPY vs INSERT performance comparison
- Buffer sizes by writer type
- Flush operations and success rate

**Variables:**
- `$time_range`: 5m, 15m, 1h, 6h, 24h, 7d
- `$writer_type`: all, trace, metric, log, copy
- `$repository`: all, trace_repository, metric_repository, log_repository

#### 2. Database Health Dashboard

**URL:** `http://grafana:3000/d/database-health`

**Panels:**
- Overall health status (stat panel with color coding)
- Active connections over time (line graph)
- Connection pool breakdown (pie chart: active/idle)
- Query latency heatmap (by repository and method)
- Write latency heatmap (by writer and operation)
- Error types distribution (pie chart)
- Slow queries table (query, calls, mean time)
- Cache hit ratio (gauge and time series)
- Database size and growth rate
- Table sizes (bar chart)

#### 3. Query Performance Dashboard

**URL:** `http://grafana:3000/d/query-performance`

**Panels:**
- Query latency by repository (multi-line graph)
- Query throughput by method (stacked area)
- Result count distribution (histogram)
- Slowest queries (table with EXPLAIN links)
- Index usage statistics
- Sequential scans vs index scans

### Alert Configuration

#### Critical Alerts (Immediate Response)

**1. High Error Rate**

```yaml
alert: StorageHighErrorRate
expr: rate(storage_errors_total[5m]) > 1
for: 5m
labels:
  severity: critical
  component: storage
annotations:
  summary: "Storage layer error rate is high"
  description: "Error rate is {{ $value | humanize }} errors/sec (threshold: 1/sec)"
  runbook: "https://docs.llm-observatory.io/runbooks/high-error-rate"
  dashboard: "http://grafana:3000/d/storage-overview"
```

**Response Actions:**
1. Check `/health` endpoint for database connectivity
2. Review error types: `curl -s http://localhost:9090/metrics | grep storage_errors_total`
3. Check database logs: `journalctl -u postgresql -n 100`
4. Verify network connectivity to database
5. If database is down, follow [Database Outage](#database-outage) procedure

**2. Connection Pool Near Capacity**

```yaml
alert: StoragePoolNearCapacity
expr: (storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) > 0.85
for: 5m
labels:
  severity: critical
  component: storage
annotations:
  summary: "Connection pool is near capacity"
  description: "Pool utilization is {{ $value | humanizePercentage }} (threshold: 85%)"
  runbook: "https://docs.llm-observatory.io/runbooks/pool-exhaustion"
```

**Response Actions:**
1. Check for connection leaks: See [Connection Pool Exhaustion](#connection-pool-exhaustion)
2. Terminate idle connections if safe
3. Increase pool size temporarily: `export DB_POOL_MAX_CONNECTIONS=150 && systemctl restart llm-observatory-storage`
4. Investigate root cause (slow queries, connection leaks)

**3. Low Write Success Rate**

```yaml
alert: StorageLowWriteSuccessRate
expr: (rate(storage_writes_total{status="success"}[5m]) / rate(storage_writes_total[5m])) < 0.95
for: 5m
labels:
  severity: critical
  component: storage
annotations:
  summary: "Write success rate is below threshold"
  description: "Success rate is {{ $value | humanizePercentage }} (threshold: 95%)"
```

**Response Actions:**
1. Check database write errors in logs
2. Verify disk space: `df -h /var/lib/postgresql/data`
3. Check for constraint violations or data validation errors
4. Review write error types in metrics

**4. Database Unreachable**

```yaml
alert: StorageDatabaseUnreachable
expr: up{job="llm-observatory-storage"} == 0
for: 1m
labels:
  severity: critical
  component: storage
annotations:
  summary: "Storage service is down"
  description: "Health check endpoint is not responding"
```

**Response Actions:**
1. Immediate escalation to on-call DBA
2. Check service status: `systemctl status llm-observatory-storage`
3. Check database status: `systemctl status postgresql`
4. Review system resources: `top`, `df -h`, `free -h`
5. If database crashed, follow [Database Recovery](#database-recovery) procedure

#### Warning Alerts (Investigation Required)

**1. High Write Latency**

```yaml
alert: StorageHighWriteLatency
expr: histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket[5m])) > 1
for: 10m
labels:
  severity: warning
  component: storage
annotations:
  summary: "Write latency is high"
  description: "P95 write latency is {{ $value | humanizeDuration }} (threshold: 1s)"
```

**Response Actions:**
1. Check database load: CPU, I/O wait
2. Review concurrent queries
3. Check for lock contention
4. Consider adding indexes or optimizing queries

**2. High Query Latency**

```yaml
alert: StorageHighQueryLatency
expr: histogram_quantile(0.95, rate(storage_query_duration_seconds_bucket[5m])) > 0.5
for: 10m
labels:
  severity: warning
  component: storage
annotations:
  summary: "Query latency is high"
  description: "P95 query latency is {{ $value | humanizeDuration }} (threshold: 500ms)"
```

**Response Actions:**
1. Identify slow queries: See [Slow Query Troubleshooting](#slow-queries)
2. Check for missing indexes
3. Review query patterns
4. Consider query optimization or caching

**3. High Retry Rate**

```yaml
alert: StorageHighRetryRate
expr: rate(storage_retries_total[5m]) > 5
for: 10m
labels:
  severity: warning
  component: storage
annotations:
  summary: "High retry rate detected"
  description: "Retry rate is {{ $value | humanize }} retries/sec (threshold: 5/sec)"
```

**Response Actions:**
1. Check for transient network issues
2. Review database stability
3. Check timeout configurations
4. Consider adjusting retry backoff

**4. Large Buffer Sizes**

```yaml
alert: StorageLargeBufferSizes
expr: storage_buffer_size > 1000
for: 10m
labels:
  severity: warning
  component: storage
annotations:
  summary: "Buffer sizes are large"
  description: "Buffer size for {{ $labels.writer_type }}/{{ $labels.buffer_type }} is {{ $value }}"
```

**Response Actions:**
1. Check flush operation status
2. Verify database write performance
3. Review buffer flush intervals
4. Consider reducing batch size or increasing flush frequency

### Alert Routing

**Severity Levels:**

- **Critical:** Immediate notification via PagerDuty, Slack, SMS
- **Warning:** Slack notification, email to on-call
- **Info:** Logged to monitoring system only

**Notification Channels:**

```yaml
# alertmanager.yml
route:
  group_by: ['alertname', 'severity', 'component']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 3h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
      continue: true
    - match:
        severity: critical
      receiver: 'slack-alerts'
    - match:
        severity: warning
      receiver: 'slack-alerts'

receivers:
  - name: 'default'
    email_configs:
      - to: 'llm-observatory-team@company.com'

  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: '<PAGERDUTY_KEY>'
        severity: 'critical'

  - name: 'slack-alerts'
    slack_configs:
      - api_url: '<SLACK_WEBHOOK_URL>'
        channel: '#llm-observatory-alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

### Monitoring Best Practices

1. **Dashboard Review Frequency:**
   - Storage Overview: Every 2 hours during business hours
   - Database Health: Daily at 09:00
   - Query Performance: Weekly on Mondays

2. **Alert Fatigue Prevention:**
   - Review and adjust thresholds monthly
   - Silence known issues with planned fixes
   - Group related alerts
   - Use appropriate severity levels

3. **Metric Retention:**
   - High-resolution (10s): 24 hours
   - Medium-resolution (1m): 30 days
   - Low-resolution (5m): 1 year

4. **Performance Baselines:**
   - Establish baselines during low-traffic periods
   - Update baselines quarterly
   - Compare current metrics to baseline in dashboards

---

## Troubleshooting Guide

### Common Issues and Resolutions

#### 1. High Query Latency

**Symptoms:**
- P95 query latency > 1 second
- Slow application response times
- User complaints about performance
- Dashboard queries timing out

**Diagnosis Steps:**

```bash
# Step 1: Identify slow queries
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  LEFT(query, 150) AS query_preview,
  calls,
  ROUND(mean_exec_time::numeric, 2) AS mean_ms,
  ROUND(max_exec_time::numeric, 2) AS max_ms,
  ROUND(total_exec_time::numeric, 2) AS total_ms
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = 'llm_observatory')
  AND mean_exec_time > 1000
ORDER BY mean_exec_time DESC
LIMIT 10;
EOF

# Step 2: Check for missing indexes
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname,
  tablename,
  seq_scan,
  seq_tup_read,
  idx_scan,
  idx_tup_fetch,
  CASE
    WHEN seq_scan = 0 THEN 0
    ELSE seq_tup_read::float / seq_scan
  END AS avg_seq_tup_read
FROM pg_stat_user_tables
WHERE seq_scan > 0
  AND seq_tup_read > 1000
ORDER BY seq_tup_read DESC
LIMIT 10;
EOF

# Step 3: Analyze a specific slow query
psql -h localhost -U postgres -d llm_observatory << 'EOF'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM llm_traces
WHERE service_name = 'api'
  AND timestamp > NOW() - INTERVAL '1 hour';
EOF

# Step 4: Check for bloat
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || tablename AS table_name,
  n_live_tup,
  n_dead_tup,
  ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 10;
EOF

# Step 5: Check database load
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  state,
  COUNT(*) as count,
  AVG(EXTRACT(EPOCH FROM (NOW() - query_start))) as avg_duration_secs
FROM pg_stat_activity
WHERE datname = 'llm_observatory'
GROUP BY state;
EOF
```

**Resolution Procedures:**

**A. Add Missing Index**

```sql
-- Example: Add index for common query pattern
CREATE INDEX CONCURRENTLY idx_traces_service_timestamp
ON llm_traces(service_name, timestamp DESC);

-- Verify index is used
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM llm_traces
WHERE service_name = 'api'
  AND timestamp > NOW() - INTERVAL '1 hour';

-- Expected: Index Scan using idx_traces_service_timestamp
```

**B. Optimize Query**

```sql
-- Before: Slow query with function on indexed column
SELECT * FROM llm_traces
WHERE DATE(timestamp) = '2025-11-05';

-- After: Use range on indexed column
SELECT * FROM llm_traces
WHERE timestamp >= '2025-11-05'::date
  AND timestamp < '2025-11-06'::date;
```

**C. Vacuum and Analyze**

```bash
# For specific table
psql -h localhost -U postgres -d llm_observatory -c \
  "VACUUM ANALYZE llm_traces;"

# For entire database (during maintenance window)
psql -h localhost -U postgres -d llm_observatory -c \
  "VACUUM ANALYZE;"

# Update statistics
psql -h localhost -U postgres -d llm_observatory -c \
  "ANALYZE;"
```

**D. Increase Work Memory (Temporary)**

```bash
# For specific session
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SET work_mem = '256MB';
-- Run slow query
-- Check if performance improves
EOF

# If helpful, update postgresql.conf permanently
# work_mem = 128MB  # Increase from default 64MB
# Then: systemctl reload postgresql
```

**Prevention Strategies:**
- Run VACUUM ANALYZE weekly
- Monitor pg_stat_statements daily
- Create indexes proactively for common query patterns
- Review query performance in code reviews
- Use EXPLAIN ANALYZE for new queries
- Set up slow query logging (log_min_duration_statement = 1000)

#### 2. Connection Pool Exhaustion

**Symptoms:**
- "Connection pool timeout" errors in logs
- Increased request latency
- 503 Service Unavailable errors
- Pool utilization consistently > 90%

**Diagnosis Steps:**

```bash
# Step 1: Check current pool status
curl -s http://localhost:9090/metrics | grep storage_pool_connections

# Step 2: Review database connections
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  application_name,
  state,
  COUNT(*) as connections,
  MAX(NOW() - state_change) as max_state_duration
FROM pg_stat_activity
WHERE datname = 'llm_observatory'
GROUP BY application_name, state
ORDER BY connections DESC;
EOF

# Step 3: Identify idle connections
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  pid,
  usename,
  application_name,
  state,
  NOW() - state_change as idle_duration,
  LEFT(query, 100) as last_query
FROM pg_stat_activity
WHERE state = 'idle'
  AND datname = 'llm_observatory'
  AND NOW() - state_change > INTERVAL '5 minutes'
ORDER BY idle_duration DESC;
EOF

# Step 4: Check for connection leaks (same query running from many connections)
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  LEFT(query, 100) as query_preview,
  state,
  COUNT(*) as connection_count
FROM pg_stat_activity
WHERE datname = 'llm_observatory'
GROUP BY LEFT(query, 100), state
HAVING COUNT(*) > 5
ORDER BY connection_count DESC;
EOF

# Step 5: Check connection acquisition time
curl -s http://localhost:9090/metrics | \
  grep storage_connection_acquire_duration_seconds
```

**Resolution Procedures:**

**A. Terminate Idle Connections**

```sql
-- Terminate idle connections older than 10 minutes
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
  AND datname = 'llm_observatory'
  AND NOW() - state_change > INTERVAL '10 minutes'
  AND pid != pg_backend_pid();

-- Verify termination
SELECT COUNT(*) FROM pg_stat_activity
WHERE state = 'idle' AND datname = 'llm_observatory';
```

**B. Increase Pool Size (Emergency)**

```bash
# Temporarily increase pool size
export DB_POOL_MAX_CONNECTIONS=150
systemctl restart llm-observatory-storage

# Verify new pool size
curl -s http://localhost:9090/metrics | grep storage_pool_connections
```

**C. Configure Idle Connection Timeout**

```bash
# Update .env configuration
echo "DB_POOL_IDLE_TIMEOUT=180" >> /opt/llm-observatory/storage/config/.env

# Restart service
systemctl restart llm-observatory-storage
```

**D. Identify and Fix Connection Leaks**

```bash
# Review application code for connections not being returned
# Check for missing error handling that bypasses connection release

# Example fix in Rust code:
# BEFORE (potential leak):
# let conn = pool.acquire().await?;
# // if error happens here, connection might not be released
# do_something_with_conn(&conn).await?;
#
# AFTER (guaranteed release):
# {
#   let conn = pool.acquire().await?;
#   do_something_with_conn(&conn).await?;
# } // Connection automatically released when `conn` goes out of scope
```

**E. Optimize Long-Running Queries**

```sql
-- Find and terminate long-running queries
SELECT
  pg_terminate_backend(pid),
  query
FROM pg_stat_activity
WHERE state = 'active'
  AND datname = 'llm_observatory'
  AND NOW() - query_start > INTERVAL '5 minutes';
```

**Prevention Strategies:**
- Monitor pool utilization continuously
- Set alerts at 80% utilization
- Configure appropriate timeouts (connect, idle, max lifetime)
- Review connection handling in application code
- Implement circuit breakers for database calls
- Use connection pooling best practices
- Regularly review and optimize slow queries

#### 3. Disk Space Issues

**Symptoms:**
- "No space left on device" errors
- Write operations failing
- Database refusing connections
- Backup failures

**Diagnosis Steps:**

```bash
# Step 1: Check disk space
df -h /var/lib/postgresql/data
df -h /var/lib/postgresql/backups

# Step 2: Identify largest directories
du -sh /var/lib/postgresql/data/*
du -sh /var/lib/postgresql/data/base/*

# Step 3: Check database sizes
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  datname,
  pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
EOF

# Step 4: Check table sizes
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || tablename AS table_name,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
  pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
EOF

# Step 5: Check WAL size
du -sh /var/lib/postgresql/data/pg_wal/

# Step 6: Check old backups
ls -lh /var/lib/postgresql/backups/daily/ | head -20
```

**Resolution Procedures:**

**A. Emergency: Free Immediate Space**

```bash
# 1. Clean old WAL files (if archiving is working)
psql -h localhost -U postgres -c \
  "SELECT pg_switch_wal();"

# 2. Remove old local backups (keep last 7 days)
find /var/lib/postgresql/backups/daily/ \
  -type f -mtime +7 -delete

# 3. Clear old log files
journalctl --vacuum-time=7d

# 4. Clean package manager cache
apt-get clean  # or yum clean all
```

**B. Drop Old TimescaleDB Chunks**

```sql
-- Check chunks older than retention policy
SELECT
  hypertable_name,
  chunk_name,
  range_start,
  range_end,
  chunk_tablespace,
  pg_size_pretty(total_bytes) AS chunk_size
FROM timescaledb_information.chunks
WHERE hypertable_name IN ('llm_traces', 'llm_metrics', 'llm_logs')
  AND range_end < NOW() - INTERVAL '90 days'
ORDER BY range_start;

-- Drop old chunks (CAUTION: Data will be deleted)
SELECT drop_chunks('llm_metrics', older_than => INTERVAL '90 days');
SELECT drop_chunks('llm_traces', older_than => INTERVAL '90 days');
SELECT drop_chunks('llm_logs', older_than => INTERVAL '90 days');

-- Verify space freed
VACUUM FULL ANALYZE;
```

**C. VACUUM to Reclaim Space**

```bash
# Regular VACUUM (doesn't immediately reclaim disk space)
psql -h localhost -U postgres -d llm_observatory -c "VACUUM VERBOSE;"

# VACUUM FULL (reclaims space but requires table lock)
# CAUTION: Use during maintenance window
psql -h localhost -U postgres -d llm_observatory -c "VACUUM FULL VERBOSE;"
```

**D. Compress Hypertable Chunks**

```sql
-- Enable compression for older data
ALTER TABLE llm_traces SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'service_name',
  timescaledb.compress_orderby = 'timestamp DESC'
);

-- Add compression policy (compress data older than 7 days)
SELECT add_compression_policy('llm_traces', INTERVAL '7 days');

-- Manually compress specific chunks
SELECT compress_chunk(chunk_name)
FROM timescaledb_information.chunks
WHERE hypertable_name = 'llm_traces'
  AND range_end < NOW() - INTERVAL '7 days'
  AND NOT is_compressed;

-- Check compression status
SELECT
  hypertable_name,
  pg_size_pretty(before_compression_total_bytes) AS before,
  pg_size_pretty(after_compression_total_bytes) AS after,
  ROUND(100.0 * (before_compression_total_bytes - after_compression_total_bytes)
    / before_compression_total_bytes, 2) AS compression_ratio_pct
FROM timescaledb_information.hypertables
WHERE hypertable_name IN ('llm_traces', 'llm_metrics', 'llm_logs');
```

**E. Expand Disk (Permanent Solution)**

```bash
# For AWS EBS volume
aws ec2 modify-volume \
  --volume-id vol-1234567890abcdef0 \
  --size 500  # New size in GB

# Resize partition
sudo growpart /dev/nvme0n1 1

# Resize filesystem
sudo resize2fs /dev/nvme0n1p1

# Verify
df -h /var/lib/postgresql/data
```

**F. Move Backups to S3**

```bash
# Sync local backups to S3 and delete local
./scripts/backup_to_s3.sh -b llm-observatory-backups -e

# Delete local backups after successful S3 sync
find /var/lib/postgresql/backups/daily/ \
  -type f -mtime +1 -delete
```

**Prevention Strategies:**
- Monitor disk usage with alerts at 70%, 80%, 90%
- Implement automated retention policies
- Enable compression for historical data
- Regular VACUUM schedule
- Automate backup cleanup
- Capacity planning reviews monthly
- Set up disk expansion automation

#### 4. Replication Lag (Future Feature)

**Note:** Replication is planned but not yet implemented. This section is provided for future reference.

**Symptoms:**
- Read replicas serving stale data
- Increased replication lag metric
- Application reporting inconsistencies

**Diagnosis Steps:**

```sql
-- Check replication lag on primary
SELECT
  client_addr,
  state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  sync_state,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
  EXTRACT(EPOCH FROM (NOW() - pg_last_xact_replay_timestamp())) AS lag_seconds
FROM pg_stat_replication;

-- Check replication delay on replica
SELECT
  NOW() AS current_time,
  pg_last_xact_replay_timestamp() AS last_replay,
  EXTRACT(EPOCH FROM (NOW() - pg_last_xact_replay_timestamp())) AS lag_seconds;
```

**Resolution Procedures:**

```bash
# 1. Check network latency between primary and replica
ping <replica_ip>

# 2. Check write load on primary
# High write volume can cause replication lag

# 3. Increase max_wal_senders if needed
# postgresql.conf: max_wal_senders = 10

# 4. Check for long-running queries on replica
# They can block replication

# 5. Consider promoting replica if primary is unresponsive
```

#### 5. Migration Failures

**Symptoms:**
- Migration script hangs or times out
- Constraint violation errors during migration
- Application can't connect after migration
- Data inconsistencies after migration

**Diagnosis Steps:**

```bash
# Step 1: Check migration status
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT * FROM schema_migrations
ORDER BY version DESC
LIMIT 10;
EOF

# Step 2: Check for locks during migration
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  pid,
  usename,
  pg_blocking_pids(pid) as blocked_by,
  query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
EOF

# Step 3: Check for constraint violations
psql -h localhost -U postgres -d llm_observatory << 'EOF'
-- Example: Check for orphaned records
SELECT COUNT(*) FROM llm_traces
WHERE trace_id NOT IN (
  SELECT DISTINCT trace_id FROM trace_spans
);
EOF

# Step 4: Review migration log
journalctl -u llm-observatory-storage -n 500 | grep -i migration
```

**Resolution Procedures:**

**A. Migration Timeout - Terminate Blocking Queries**

```sql
-- Find blocking queries
SELECT
  pid,
  query,
  state,
  NOW() - query_start as duration
FROM pg_stat_activity
WHERE state = 'active'
  AND datname = 'llm_observatory'
ORDER BY duration DESC;

-- Terminate blocking query (use with caution)
SELECT pg_terminate_backend(<pid>);

-- Retry migration
-- ./scripts/deploy_database.sh --retry
```

**B. Constraint Violation - Clean Up Data**

```sql
-- Example: Remove orphaned records before adding foreign key
DELETE FROM llm_traces
WHERE trace_id NOT IN (
  SELECT DISTINCT trace_id FROM trace_spans
);

-- Retry migration
```

**C. Out of Disk Space During Migration**

```bash
# Free space as described in Disk Space Issues section
# Then retry migration
./scripts/deploy_database.sh --retry
```

**D. Rollback Failed Migration**

```bash
# If migration partially applied, rollback to previous version
psql -h localhost -U postgres -d llm_observatory << 'EOF'
BEGIN;

-- Manually undo migration changes
DROP TABLE IF EXISTS new_table;
DROP INDEX IF EXISTS new_index;

-- Update migration version
DELETE FROM schema_migrations
WHERE version = 'failed_version';

COMMIT;
EOF

# Restore from backup if needed
./scripts/restore.sh -y backups/pre_migration_backup.sql.gz
```

**E. Migration Succeeded but Application Errors**

```bash
# Check schema version matches application expectation
psql -h localhost -U postgres -d llm_observatory -c \
  "SELECT MAX(version) FROM schema_migrations;"

# Verify all migrations applied
psql -h localhost -U postgres -d llm_observatory -f \
  crates/storage/migrations/verify_migrations.sql

# If schema mismatch, either:
# 1. Rollback deployment
./scripts/rollback.sh --emergency

# OR
# 2. Apply missing migrations
./scripts/deploy_database.sh
```

**Prevention Strategies:**
- Always test migrations in staging first
- Use transactions for reversible migrations
- Create backup before every migration
- Estimate migration time in staging
- Use CONCURRENTLY for index creation
- Implement zero-downtime migration strategies
- Document rollback procedures for each migration
- Use migration lock to prevent concurrent runs

#### 6. Backup Failures

**Symptoms:**
- Backup job fails in cron
- S3 sync errors
- Backup file corruption
- Insufficient disk space for backup

**Diagnosis Steps:**

```bash
# Step 1: Check backup logs
cat /var/lib/postgresql/backups/logs/backup.log | tail -100

# Step 2: Check available disk space
df -h /var/lib/postgresql/backups

# Step 3: Test database connectivity
psql -h localhost -U postgres -d llm_observatory -c "SELECT 1;"

# Step 4: Verify backup file integrity (if exists)
gzip -t /var/lib/postgresql/backups/daily/llm_observatory_latest.sql.gz

# Step 5: Check S3 access (if applicable)
aws s3 ls s3://llm-observatory-backups/
```

**Resolution Procedures:**

**A. Insufficient Disk Space**

```bash
# Free space for backup
# 1. Remove old backups
find /var/lib/postgresql/backups/daily/ -type f -mtime +7 -delete

# 2. Sync to S3 and delete local
./scripts/backup_to_s3.sh -b llm-observatory-backups
find /var/lib/postgresql/backups/daily/ -type f -mtime +1 -delete

# 3. Retry backup
./scripts/backup.sh -v
```

**B. Database Connection Failure**

```bash
# Check if database is running
systemctl status postgresql

# Check network connectivity
ping localhost

# Check PostgreSQL logs
journalctl -u postgresql -n 100

# Restart PostgreSQL if needed
systemctl restart postgresql

# Retry backup
./scripts/backup.sh -v
```

**C. S3 Upload Failure**

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check S3 bucket access
aws s3 ls s3://llm-observatory-backups/

# Test upload
echo "test" | aws s3 cp - s3://llm-observatory-backups/test.txt
aws s3 rm s3://llm-observatory-backups/test.txt

# Check IAM permissions
aws iam get-user-policy --user-name backup-user --policy-name BackupPolicy

# Retry S3 backup
./scripts/backup_to_s3.sh -b llm-observatory-backups -v
```

**D. Corrupted Backup File**

```bash
# Remove corrupted backup
rm /var/lib/postgresql/backups/daily/llm_observatory_corrupted.sql.gz

# Create new backup
./scripts/backup.sh -v

# Verify integrity
./scripts/verify_backup.sh -v
```

**E. pg_dump Timeout**

```bash
# Increase timeout in backup script
# Add to backup.sh:
# export PGCONNECT_TIMEOUT=60

# Or use parallel pg_dump for large databases
pg_dump -h localhost -U postgres \
  -d llm_observatory \
  --format=directory \
  --jobs=4 \
  --file=/var/lib/postgresql/backups/parallel/
```

**Prevention Strategies:**
- Monitor backup job completion daily
- Set up backup failure alerts
- Maintain 30% free space on backup volume
- Test backup restoration monthly
- Use parallel pg_dump for large databases
- Automate S3 sync
- Implement backup verification
- Document backup procedures

---

*This is Part 1 of the Operations Manual. Continue to Part 2 for Maintenance Procedures, Disaster Recovery, Performance Tuning, Security Operations, and Quick Reference sections.*

---

## Maintenance Procedures

### Weekly Maintenance

Perform these tasks every Monday at 10:00 AM.

#### 1. Database Maintenance

```bash
# Analyze database statistics
psql -h localhost -U postgres -d llm_observatory -c "ANALYZE VERBOSE;"

# Check for bloat
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || tablename AS table_name,
  n_live_tup,
  n_dead_tup,
  ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 10;
EOF

# VACUUM tables with >10% dead tuples
psql -h localhost -U postgres -d llm_observatory << 'EOF'
DO $$
DECLARE
  table_record RECORD;
BEGIN
  FOR table_record IN
    SELECT schemaname || '.' || tablename AS full_table_name
    FROM pg_stat_user_tables
    WHERE n_dead_tup > 1000
      AND 100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0) > 10
  LOOP
    EXECUTE 'VACUUM ANALYZE ' || table_record.full_table_name;
    RAISE NOTICE 'Vacuumed table: %', table_record.full_table_name;
  END LOOP;
END $$;
EOF

# Check index bloat
psql -h localhost -U postgres -d llm_observatory -f \
  scripts/check_index_bloat.sql

# REINDEX if needed (during maintenance window)
# REINDEX TABLE llm_traces;
```

#### 2. Performance Review

```bash
# Check slow query statistics
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  LEFT(query, 150) AS query_preview,
  calls,
  ROUND(mean_exec_time::numeric, 2) AS mean_ms,
  ROUND(max_exec_time::numeric, 2) AS max_ms,
  ROUND(total_exec_time::numeric, 2) AS total_ms,
  ROUND((100 * total_exec_time / SUM(total_exec_time) OVER ())::numeric, 2) AS pct_total
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = 'llm_observatory')
  AND calls > 100
ORDER BY total_exec_time DESC
LIMIT 20;
EOF

# Reset pg_stat_statements (after review)
# psql -h localhost -U postgres -c "SELECT pg_stat_statements_reset();"

# Check cache hit ratio by table
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || relname AS table_name,
  heap_blks_read,
  heap_blks_hit,
  ROUND(
    100.0 * heap_blks_hit / NULLIF(heap_blks_hit + heap_blks_read, 0),
    2
  ) AS cache_hit_ratio
FROM pg_statio_user_tables
WHERE heap_blks_hit + heap_blks_read > 0
ORDER BY cache_hit_ratio
LIMIT 20;
EOF
```

#### 3. Chunk and Compression Review

```bash
# Check chunk distribution
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  hypertable_name,
  COUNT(*) AS num_chunks,
  pg_size_pretty(SUM(total_bytes)) AS total_size,
  pg_size_pretty(AVG(total_bytes)) AS avg_chunk_size,
  MIN(range_start) AS oldest_chunk,
  MAX(range_end) AS newest_chunk
FROM timescaledb_information.chunks
GROUP BY hypertable_name;
EOF

# Check compression status
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  hypertable_name,
  pg_size_pretty(before_compression_total_bytes) AS uncompressed,
  pg_size_pretty(after_compression_total_bytes) AS compressed,
  ROUND(100.0 * (before_compression_total_bytes - after_compression_total_bytes)
    / NULLIF(before_compression_total_bytes, 0), 2) AS compression_ratio_pct,
  node_name
FROM timescaledb_information.compressed_hypertable_stats;
EOF

# Manually compress chunks if policy is not working
# SELECT compress_chunk(chunk_name) FROM timescaledb_information.chunks
# WHERE hypertable_name = 'llm_traces'
#   AND range_end < NOW() - INTERVAL '7 days'
#   AND NOT is_compressed;
```

#### 4. Backup Verification

```bash
# Test restore from latest backup (to test database)
LATEST_BACKUP=$(ls -t /var/lib/postgresql/backups/daily/*.sql.gz | head -1)
./scripts/verify_backup.sh "$LATEST_BACKUP" -v

# Check S3 backup inventory
aws s3api list-objects-v2 \
  --bucket llm-observatory-backups \
  --prefix backups/daily/ \
  --query 'Contents[*].[Key,LastModified,Size]' \
  --output table | tail -20

# Verify backup retention (should have 30 days)
aws s3api list-objects-v2 \
  --bucket llm-observatory-backups \
  --prefix backups/daily/ \
  --query 'length(Contents)'
```

#### 5. Security Review

```bash
# Check for failed authentication attempts
journalctl -u postgresql --since "7 days ago" | \
  grep "FATAL.*authentication" | wc -l

# Review active connections
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  usename,
  application_name,
  client_addr,
  COUNT(*) as connection_count
FROM pg_stat_activity
WHERE datname = 'llm_observatory'
GROUP BY usename, application_name, client_addr
ORDER BY connection_count DESC;
EOF

# Check for suspicious queries
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  usename,
  LEFT(query, 150) as query_preview,
  query_start
FROM pg_stat_activity
WHERE datname = 'llm_observatory'
  AND query ~* '(drop|truncate|delete.*from.*where.*true|update.*set)'
  AND state = 'active'
ORDER BY query_start;
EOF
```

#### 6. Log Rotation and Cleanup

```bash
# Rotate logs
journalctl --rotate

# Clean logs older than 30 days
journalctl --vacuum-time=30d

# Clean old application logs
find /opt/llm-observatory/storage/logs/ -type f -mtime +30 -delete

# Check log disk usage
du -sh /var/log/journal
du -sh /opt/llm-observatory/storage/logs
```

#### 7. Continuous Aggregate Refresh

```bash
# Check continuous aggregate lag
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  view_name,
  completed_threshold,
  invalidation_threshold,
  NOW() - completed_threshold AS lag,
  materialized_only
FROM timescaledb_information.continuous_aggregates
ORDER BY view_name;
EOF

# Refresh continuous aggregates
psql -h localhost -U postgres -d llm_observatory << 'EOF'
CALL refresh_continuous_aggregate('trace_metrics_hourly', NULL, NULL);
CALL refresh_continuous_aggregate('trace_metrics_daily', NULL, NULL);
CALL refresh_continuous_aggregate('metric_stats_hourly', NULL, NULL);
EOF
```

### Monthly Maintenance

Perform these tasks on the first Monday of each month.

#### 1. Capacity Planning Review

```bash
# Database growth rate (last 30 days)
psql -h localhost -U postgres -d llm_observatory << 'EOF'
WITH daily_sizes AS (
  SELECT
    date_trunc('day', timestamp) AS day,
    COUNT(*) AS row_count,
    SUM(pg_column_size(row(t.*))) AS estimated_size
  FROM llm_traces t
  WHERE timestamp > NOW() - INTERVAL '30 days'
  GROUP BY date_trunc('day', timestamp)
)
SELECT
  AVG(row_count) AS avg_daily_rows,
  pg_size_pretty(AVG(estimated_size)::bigint) AS avg_daily_size,
  pg_size_pretty((AVG(estimated_size) * 365)::bigint) AS projected_annual_size
FROM daily_sizes;
EOF

# Disk usage trend
df -h /var/lib/postgresql/data
# Compare with last month's measurement

# Connection pool utilization trend
# Review Grafana dashboard: "Storage Overview"
# Panel: "Connection Pool Utilization" (last 30 days)

# Query: What will disk usage be in 3 months?
# projection = current_size + (avg_daily_growth * 90)
```

#### 2. Performance Benchmarking

```bash
# Run performance benchmarks
cd /workspaces/llm-observatory
cargo bench --package llm-observatory-storage

# Compare with last month's results
./scripts/compare_benchmarks.sh \
  results/benchmarks_2025-10.txt \
  results/benchmarks_2025-11.txt

# Expected output:
# Metric                    Oct 2025   Nov 2025   Change
# Write throughput          95k/s      97k/s      +2.1%
# Query latency (p95)       45ms       43ms       -4.4%
```

#### 3. Security Audit

```bash
# Check for security updates
cargo audit

# Update dependencies with security fixes
cargo update

# Review database user permissions
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  r.rolname,
  r.rolsuper,
  r.rolinherit,
  r.rolcreaterole,
  r.rolcreatedb,
  r.rolcanlogin,
  r.rolconnlimit,
  r.rolvaliduntil
FROM pg_roles r
WHERE r.rolname NOT LIKE 'pg_%'
ORDER BY r.rolname;
EOF

# Review SSL configuration
psql -h localhost -U postgres -c "SHOW ssl;"
psql -h localhost -U postgres -c "SHOW ssl_ciphers;"

# Check for weak passwords (manual review)
# Rotate passwords if needed
```

#### 4. Disaster Recovery Test

```bash
# Test backup restoration to isolated environment
./scripts/test_dr_restore.sh

# Expected steps:
# 1. Download latest S3 backup
# 2. Restore to test database
# 3. Verify data integrity
# 4. Measure restoration time (target: <4 hours)
# 5. Document any issues

# Test point-in-time recovery
# 1. Create test data
# 2. Note timestamp
# 3. Delete test data
# 4. Restore to timestamp
# 5. Verify test data is restored
```

#### 5. Index Maintenance

```bash
# Identify unused indexes
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || tablename AS table_name,
  indexname,
  idx_scan AS index_scans,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey'
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
EOF

# Consider dropping unused indexes (during maintenance window)
# DROP INDEX CONCURRENTLY unused_index_name;

# REINDEX bloated indexes (during maintenance window)
REINDEX INDEX CONCURRENTLY bloated_index_name;

# Check index validity
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || tablename AS table_name,
  indexname,
  indisvalid
FROM pg_indexes
JOIN pg_class ON pg_indexes.indexname = pg_class.relname
JOIN pg_index ON pg_class.oid = pg_index.indexrelid
WHERE schemaname = 'public'
  AND NOT indisvalid;
EOF
```

#### 6. Configuration Review and Optimization

```bash
# Review PostgreSQL settings
psql -h localhost -U postgres -c "SELECT name, setting, unit, source
FROM pg_settings
WHERE source != 'default'
ORDER BY name;"

# Review storage service configuration
cat /opt/llm-observatory/storage/config/.env

# Check for recommended settings
# Compare against production best practices

# Update if needed (requires service restart)
```

### Quarterly Maintenance

Perform these tasks every 3 months.

#### 1. Major Version Updates

```bash
# Check for TimescaleDB updates
SELECT default_version, installed_version
FROM pg_available_extensions
WHERE name = 'timescaledb';

# Plan upgrade during maintenance window
# Follow upgrade guide: https://docs.timescale.com/

# Check for PostgreSQL updates
psql --version
# Compare with latest stable version

# Plan major version upgrade (requires significant downtime)
```

#### 2. Storage Tier Optimization

```bash
# Review S3 storage class distribution
aws s3api list-objects-v2 \
  --bucket llm-observatory-backups \
  --query 'Contents[*].[Key,StorageClass,LastModified]' \
  --output table

# Move old backups to cheaper storage
aws s3 cp \
  s3://llm-observatory-backups/backups/daily/old_backup.sql.gz \
  s3://llm-observatory-backups/backups/archive/old_backup.sql.gz \
  --storage-class GLACIER_IR

# Update lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
  --bucket llm-observatory-backups \
  --lifecycle-configuration file://lifecycle-policy.json
```

#### 3. Comprehensive Performance Review

```bash
# Generate performance report
./scripts/generate_performance_report.sh \
  --period quarterly \
  --output /tmp/performance_report_Q4_2025.html

# Review with team
# Identify optimization opportunities
# Plan performance improvements
```

### VACUUM and REINDEX Procedures

#### Regular VACUUM

```bash
# Routine VACUUM (runs quickly, no locks)
psql -h localhost -U postgres -d llm_observatory -c "VACUUM VERBOSE;"

# VACUUM specific table
psql -h localhost -U postgres -d llm_observatory -c \
  "VACUUM VERBOSE llm_traces;"

# Automated vacuuming (check if autovacuum is working)
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || relname AS table_name,
  last_vacuum,
  last_autovacuum,
  vacuum_count,
  autovacuum_count,
  n_dead_tup
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY last_autovacuum DESC NULLS LAST;
EOF
```

#### VACUUM FULL (Requires Maintenance Window)

```bash
# VACUUM FULL reclaims disk space but requires exclusive table lock
# Schedule during maintenance window with application downtime

# Step 1: Enable maintenance mode
./scripts/maintenance_mode.sh --enable

# Step 2: Stop application services
systemctl stop llm-observatory-storage

# Step 3: Run VACUUM FULL
psql -h localhost -U postgres -d llm_observatory << 'EOF'
VACUUM FULL VERBOSE llm_traces;
VACUUM FULL VERBOSE llm_metrics;
VACUUM FULL VERBOSE llm_logs;
EOF

# Step 4: ANALYZE after VACUUM FULL
psql -h localhost -U postgres -d llm_observatory -c "ANALYZE;"

# Step 5: Restart application
systemctl start llm-observatory-storage

# Step 6: Disable maintenance mode
./scripts/maintenance_mode.sh --disable

# Step 7: Verify service health
curl -f http://localhost:9090/health
```

#### REINDEX Procedures

```bash
# REINDEX CONCURRENTLY (no exclusive locks, production-safe)
psql -h localhost -U postgres -d llm_observatory -c \
  "REINDEX INDEX CONCURRENTLY idx_traces_timestamp;"

# REINDEX entire table concurrently
psql -h localhost -U postgres -d llm_observatory -c \
  "REINDEX TABLE CONCURRENTLY llm_traces;"

# REINDEX database (requires maintenance window)
# This requires exclusive locks - schedule downtime

# Step 1: Enable maintenance mode
./scripts/maintenance_mode.sh --enable

# Step 2: REINDEX database
psql -h localhost -U postgres -d llm_observatory -c \
  "REINDEX DATABASE llm_observatory;"

# Step 3: Disable maintenance mode
./scripts/maintenance_mode.sh --disable

# Check for invalid indexes
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  schemaname || '.' || tablename AS table_name,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
JOIN pg_index ON pg_stat_user_indexes.indexrelid = pg_index.indexrelid
WHERE NOT indisvalid
  AND schemaname = 'public';
EOF

# Drop and recreate invalid indexes
# DROP INDEX CONCURRENTLY invalid_index_name;
# CREATE INDEX CONCURRENTLY invalid_index_name ON ...;
```

### Database Upgrades

#### Minor Version Upgrade (PostgreSQL 16.1 → 16.2)

```bash
# Step 1: Backup database
./scripts/backup.sh -v
aws s3 cp latest_backup.sql.gz s3://llm-observatory-backups/pre_upgrade/

# Step 2: Update package
sudo apt update
sudo apt upgrade postgresql-16

# Step 3: Restart PostgreSQL
sudo systemctl restart postgresql

# Step 4: Verify version
psql -h localhost -U postgres -c "SELECT version();"

# Step 5: Test application
curl -f http://localhost:9090/health
./scripts/verify_deployment.sh --comprehensive
```

#### Major Version Upgrade (PostgreSQL 16 → 17)

**CAUTION:** Major version upgrades require significant downtime and testing.

```bash
# Step 1: Plan upgrade
# - Review breaking changes
# - Test in staging environment
# - Schedule maintenance window (4-8 hours)
# - Notify stakeholders

# Step 2: Pre-upgrade checklist
# - Create full backup
# - Document current configuration
# - Test backup restoration
# - Prepare rollback plan

# Step 3: Perform upgrade using pg_upgrade
# Follow official PostgreSQL upgrade guide
# https://www.postgresql.org/docs/current/pgupgrade.html

# Step 4: Post-upgrade tasks
# - Run ANALYZE
# - Update TimescaleDB extension
# - Verify all queries work
# - Monitor performance for 24 hours
```

---

## Disaster Recovery

For detailed disaster recovery procedures, see [Disaster Recovery Guide](disaster-recovery.md).

### Quick DR Reference

#### Recovery Time Objectives (RTO)

| Environment | RTO | RPO |
|-------------|-----|-----|
| Production | < 4 hours | < 15 minutes (with WAL) |
| Staging | < 8 hours | < 1 day |
| Development | < 24 hours | < 7 days |

#### Emergency Recovery Procedures

**1. Database Corruption**

```bash
# Stop application
systemctl stop llm-observatory-storage

# Restore from latest backup
./scripts/restore.sh --drop-existing -y backups/daily/latest.sql.gz

# Verify restoration
psql -h localhost -U postgres -d llm_observatory -c "SELECT COUNT(*) FROM llm_traces;"

# Restart application
systemctl start llm-observatory-storage
```

**2. Hardware Failure**

```bash
# Provision new server
# Install PostgreSQL and dependencies

# Restore from S3
./scripts/restore.sh -s -b llm-observatory-backups backups/latest.sql.gz

# Update DNS/load balancer to point to new server
# Test connectivity
```

**3. Accidental Data Deletion**

```bash
# Identify deletion timestamp
RECOVERY_TARGET="2025-11-05 14:25:00"

# Perform Point-in-Time Recovery (PITR)
# See disaster-recovery.md for detailed PITR procedure

# Or restore deleted data from temporary database
./scripts/restore.sh -t llm_observatory_recovery backup.sql.gz
pg_dump -h localhost -U postgres -d llm_observatory_recovery -t deleted_table --data-only > deleted_data.sql
psql -h localhost -U postgres -d llm_observatory -f deleted_data.sql
```

#### Backup Quick Reference

```bash
# Create backup
./scripts/backup.sh -v

# Backup to S3
./scripts/backup_to_s3.sh -b llm-observatory-backups -e

# Verify backup
./scripts/verify_backup.sh backups/latest.sql.gz -v

# Restore backup
./scripts/restore.sh backups/latest.sql.gz

# Restore from S3
./scripts/restore.sh -s -b llm-observatory-backups backups/latest.sql.gz
```

#### DR Testing Schedule

| Test Type | Frequency | Last Tested | Next Test |
|-----------|-----------|-------------|-----------|
| Backup Creation | Daily | Automated | Automated |
| Backup Verification | Weekly | Automated | Automated |
| Full Restore Test | Monthly | YYYY-MM-DD | YYYY-MM-DD |
| PITR Test | Quarterly | YYYY-MM-DD | YYYY-MM-DD |
| DR Drill | Annually | YYYY-MM-DD | YYYY-MM-DD |

---

## Performance Tuning

### Connection Pool Optimization

#### Determine Optimal Pool Size

```bash
# Formula: connections = ((core_count * 2) + effective_spindle_count)
# For SSD: effective_spindle_count = 1
# Example: 8 cores → (8 * 2) + 1 = 17 connections

# Monitor pool utilization
curl -s http://localhost:9090/metrics | grep storage_pool_connections

# Check database-side active connections
psql -h localhost -U postgres -d llm_observatory -c \
  "SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active';"

# Recommended settings:
# Development: max_connections=20, min_connections=5
# Staging: max_connections=50, min_connections=10
# Production: max_connections=100, min_connections=20
```

#### Tune Connection Timeouts

```bash
# Connection acquisition timeout (how long to wait for connection)
# Default: 10s
# Increase if pool is frequently near capacity
export DB_POOL_CONNECT_TIMEOUT=30

# Idle connection timeout (close idle connections)
# Default: 300s (5 minutes)
# Decrease to free up connections faster
export DB_POOL_IDLE_TIMEOUT=180

# Max connection lifetime (recycle connections)
# Default: 1800s (30 minutes)
# Helps prevent connection leaks
export DB_POOL_MAX_LIFETIME=1800
```

#### Connection Pool Monitoring Queries

```promql
# Pool utilization percentage
(storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) * 100

# Connection acquisition time (p95)
histogram_quantile(0.95, rate(storage_connection_acquire_duration_seconds_bucket[5m]))

# Available connections
storage_pool_connections{state="idle"}

# Predict pool exhaustion (5min trend)
predict_linear(storage_pool_connections{state="active"}[5m], 300) >
  storage_pool_connections{state="max"}
```

### Query Optimization

#### Identify Slow Queries

```sql
-- Top 10 slowest queries by average time
SELECT
  LEFT(query, 150) AS query_preview,
  calls,
  ROUND(mean_exec_time::numeric, 2) AS mean_ms,
  ROUND(max_exec_time::numeric, 2) AS max_ms,
  ROUND(total_exec_time::numeric, 2) AS total_ms
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = 'llm_observatory')
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Top 10 queries by total time
SELECT
  LEFT(query, 150) AS query_preview,
  calls,
  ROUND(mean_exec_time::numeric, 2) AS mean_ms,
  ROUND(total_exec_time::numeric, 2) AS total_ms,
  ROUND((100 * total_exec_time / SUM(total_exec_time) OVER ())::numeric, 2) AS pct_total
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = 'llm_observatory')
ORDER BY total_exec_time DESC
LIMIT 10;
```

#### Optimize Queries

**1. Use EXPLAIN ANALYZE**

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM llm_traces
WHERE service_name = 'api'
  AND timestamp > NOW() - INTERVAL '1 hour';

-- Look for:
-- - Sequential Scans (should be Index Scans)
-- - High "Buffers: shared read" (indicates cache misses)
-- - High execution time
-- - Nested loops with large outer tables
```

**2. Add Appropriate Indexes**

```sql
-- For time-range queries
CREATE INDEX CONCURRENTLY idx_traces_timestamp
ON llm_traces(timestamp DESC);

-- For service + time queries
CREATE INDEX CONCURRENTLY idx_traces_service_timestamp
ON llm_traces(service_name, timestamp DESC);

-- For filtering by multiple columns
CREATE INDEX CONCURRENTLY idx_traces_composite
ON llm_traces(service_name, status_code, timestamp DESC);

-- BRIN index for time-series data (space-efficient)
CREATE INDEX CONCURRENTLY idx_traces_timestamp_brin
ON llm_traces USING BRIN(timestamp);
```

**3. Query Optimization Techniques**

```sql
-- BEFORE: Function on indexed column (can't use index)
SELECT * FROM llm_traces WHERE DATE(timestamp) = '2025-11-05';

-- AFTER: Range on indexed column (uses index)
SELECT * FROM llm_traces
WHERE timestamp >= '2025-11-05'::date
  AND timestamp < '2025-11-06'::date;

-- BEFORE: OR condition (may not use indexes efficiently)
SELECT * FROM llm_traces
WHERE service_name = 'api' OR service_name = 'worker';

-- AFTER: Use IN clause
SELECT * FROM llm_traces
WHERE service_name IN ('api', 'worker');

-- BEFORE: Implicit type conversion
SELECT * FROM llm_traces WHERE trace_id = '123e4567-e89b-12d3-a456-426614174000';

-- AFTER: Explicit type cast
SELECT * FROM llm_traces WHERE trace_id = '123e4567-e89b-12d3-a456-426614174000'::uuid;
```

**4. Leverage Continuous Aggregates**

```sql
-- BEFORE: Expensive aggregation on raw data
SELECT
  DATE_TRUNC('hour', timestamp) AS hour,
  service_name,
  COUNT(*) as request_count,
  AVG(duration_ms) as avg_duration
FROM llm_traces
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY DATE_TRUNC('hour', timestamp), service_name;

-- AFTER: Query pre-computed aggregate
SELECT * FROM trace_metrics_hourly
WHERE bucket > NOW() - INTERVAL '7 days';
```

### Write Performance Optimization

#### Use COPY Protocol for Bulk Writes

```rust
// Use CopyWriter for high-throughput writes (50k-100k rows/sec)
let copy_writer = CopyWriter::new(pool.clone()).await?;
copy_writer.copy_traces(&traces).await?;

// Regular INSERT is fine for small batches (<100 rows)
let batch_writer = TraceWriter::new(pool.clone()).await?;
batch_writer.write_batch(&traces).await?;
```

#### Batch Write Optimization

```bash
# Optimal batch sizes
# COPY protocol: 1000-10000 rows per batch
# INSERT batch: 100-1000 rows per batch

# Configure in application
export BATCH_SIZE=1000
export FLUSH_INTERVAL_MS=5000
```

#### Reduce Write Amplification

```sql
-- Disable unnecessary indexes during bulk load
DROP INDEX CONCURRENTLY idx_rarely_used;

-- Bulk load data
COPY llm_traces FROM '/tmp/data.csv' WITH (FORMAT CSV);

-- Recreate index
CREATE INDEX CONCURRENTLY idx_rarely_used ON llm_traces(...);

-- Increase maintenance_work_mem during index creation
SET maintenance_work_mem = '1GB';
CREATE INDEX CONCURRENTLY ...;
```

### PostgreSQL Configuration Tuning

#### Memory Settings

```conf
# postgresql.conf

# Shared Buffers (25% of RAM for dedicated DB server)
shared_buffers = 8GB

# Effective Cache Size (50-75% of total RAM)
effective_cache_size = 24GB

# Work Memory (RAM / max_connections / 2)
work_mem = 64MB

# Maintenance Work Memory (10% of RAM)
maintenance_work_mem = 2GB

# Huge Pages (recommended for large shared_buffers)
huge_pages = try
```

#### WAL Settings

```conf
# WAL Checkpoints
checkpoint_timeout = 15min
max_wal_size = 4GB
min_wal_size = 1GB
checkpoint_completion_target = 0.9

# WAL Buffers (3% of shared_buffers, max 16MB)
wal_buffers = 16MB

# Commit Delay (group commits for better throughput)
commit_delay = 10
commit_siblings = 5
```

#### Query Planner Settings

```conf
# Random Page Cost (1.1 for SSD, 4.0 for HDD)
random_page_cost = 1.1

# Effective I/O Concurrency (200 for SSD, 2 for HDD)
effective_io_concurrency = 200

# Parallel Query Settings
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
```

#### Autovacuum Tuning

```conf
# Autovacuum (should be enabled)
autovacuum = on

# Autovacuum Max Workers
autovacuum_max_workers = 3

# Autovacuum Naptime
autovacuum_naptime = 1min

# Vacuum Cost Limit (higher = more aggressive)
autovacuum_vacuum_cost_limit = 500

# Scale Factor (trigger vacuum at 10% dead tuples)
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05
```

### TimescaleDB Specific Optimizations

#### Chunk Sizing

```sql
-- Check current chunk size
SELECT
  hypertable_name,
  chunk_time_interval
FROM timescaledb_information.dimensions;

-- Recommended chunk size:
-- - High write rate: 1 day chunks
-- - Moderate write rate: 7 day chunks
-- - Low write rate: 30 day chunks

-- Change chunk interval
SELECT set_chunk_time_interval('llm_traces', INTERVAL '7 days');
```

#### Compression Configuration

```sql
-- Enable compression
ALTER TABLE llm_traces SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'service_name',
  timescaledb.compress_orderby = 'timestamp DESC'
);

-- Compression policy (compress data older than 7 days)
SELECT add_compression_policy('llm_traces', INTERVAL '7 days');

-- Check compression ratio
SELECT
  hypertable_name,
  pg_size_pretty(before_compression_total_bytes) AS uncompressed,
  pg_size_pretty(after_compression_total_bytes) AS compressed,
  ROUND(100.0 * (before_compression_total_bytes - after_compression_total_bytes)
    / NULLIF(before_compression_total_bytes, 0), 2) AS compression_ratio_pct
FROM timescaledb_information.compressed_hypertable_stats;
```

#### Continuous Aggregate Optimization

```sql
-- Create efficient continuous aggregates
CREATE MATERIALIZED VIEW trace_metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', timestamp) AS bucket,
  service_name,
  COUNT(*) as request_count,
  AVG(duration_ms) as avg_duration,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration
FROM llm_traces
GROUP BY bucket, service_name;

-- Refresh policy (refresh every hour)
SELECT add_continuous_aggregate_policy('trace_metrics_hourly',
  start_offset => INTERVAL '3 hours',
  end_offset => INTERVAL '1 hour',
  schedule_interval => INTERVAL '1 hour');
```

### Caching Strategies

#### Redis Configuration

```bash
# Redis memory limit
maxmemory 4gb
maxmemory-policy allkeys-lru

# Eviction samples
maxmemory-samples 10

# Save to disk (optional)
save 900 1
save 300 10
save 60 10000
```

#### Application-Level Caching

```rust
// Cache frequently accessed queries
let cache_key = format!("trace:{}:{}", service_name, trace_id);
let cached_result = redis.get(&cache_key).await?;

if cached_result.is_some() {
    return cached_result;
}

// Query database
let result = repository.get_trace(trace_id).await?;

// Store in cache (TTL: 1 hour)
redis.setex(&cache_key, 3600, &result).await?;
```

### Monitoring Performance Improvements

```bash
# Before optimization
./scripts/run_benchmark.sh --output before.json

# Apply optimizations
# (add indexes, tune config, etc.)

# After optimization
./scripts/run_benchmark.sh --output after.json

# Compare results
./scripts/compare_benchmarks.sh before.json after.json

# Expected output:
# Metric                    Before    After     Improvement
# Write throughput          85k/s     102k/s    +20.0%
# Query latency (p95)       120ms     65ms      -45.8%
# Connection acquire time   25ms      12ms      -52.0%
```

---

## Security Operations

### Authentication and Authorization

#### Database User Management

```sql
-- Create application user with limited permissions
CREATE USER llm_observatory_app WITH PASSWORD 'strong_password_here';

-- Grant necessary permissions
GRANT CONNECT ON DATABASE llm_observatory TO llm_observatory_app;
GRANT USAGE ON SCHEMA public TO llm_observatory_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO llm_observatory_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO llm_observatory_app;

-- Create read-only user for analytics
CREATE USER llm_observatory_readonly WITH PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE llm_observatory TO llm_observatory_readonly;
GRANT USAGE ON SCHEMA public TO llm_observatory_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO llm_observatory_readonly;

-- Revoke unnecessary permissions
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE llm_observatory FROM PUBLIC;

-- Review user permissions
\du
SELECT * FROM pg_roles WHERE rolname NOT LIKE 'pg_%';
```

#### Password Rotation

```bash
# Step 1: Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Step 2: Update database password
psql -h localhost -U postgres -c \
  "ALTER USER llm_observatory_app WITH PASSWORD '$NEW_PASSWORD';"

# Step 3: Update application configuration
echo "DB_PASSWORD=$NEW_PASSWORD" >> /opt/llm-observatory/storage/config/.env.new
mv /opt/llm-observatory/storage/config/.env.new \
   /opt/llm-observatory/storage/config/.env

# Step 4: Restart application
systemctl restart llm-observatory-storage

# Step 5: Verify connectivity
curl -f http://localhost:9090/health

# Step 6: Document password change (encrypted notes)
echo "Password rotated on $(date)" >> /secure/password_rotation_log.txt
```

### SSL/TLS Configuration

#### Enable SSL for PostgreSQL

```conf
# postgresql.conf
ssl = on
ssl_cert_file = '/etc/postgresql/ssl/server.crt'
ssl_key_file = '/etc/postgresql/ssl/server.key'
ssl_ca_file = '/etc/postgresql/ssl/ca.crt'
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers = on
ssl_min_protocol_version = 'TLSv1.2'
```

```bash
# Generate self-signed certificate (testing only)
openssl req -new -x509 -days 365 -nodes \
  -out /etc/postgresql/ssl/server.crt \
  -keyout /etc/postgresql/ssl/server.key \
  -subj "/CN=llm-observatory-db"

# Set permissions
chmod 600 /etc/postgresql/ssl/server.key
chown postgres:postgres /etc/postgresql/ssl/server.*

# Restart PostgreSQL
systemctl restart postgresql

# Update application to require SSL
export DB_SSL_MODE=require
systemctl restart llm-observatory-storage
```

#### Certificate Management

```bash
# Check certificate expiry
openssl x509 -in /etc/postgresql/ssl/server.crt -noout -dates

# Check days until expiry
openssl x509 -in /etc/postgresql/ssl/server.crt -noout -checkend $((30*86400))

# Renew certificate (30 days before expiry)
# Use Let's Encrypt or your certificate authority

# Update certificate without downtime
cp new_server.crt /etc/postgresql/ssl/server.crt.new
cp new_server.key /etc/postgresql/ssl/server.key.new
chown postgres:postgres /etc/postgresql/ssl/server.*
systemctl reload postgresql
```

### Encryption at Rest

#### Enable Transparent Data Encryption (TDE)

**Note:** PostgreSQL native TDE is not available. Use filesystem-level encryption.

```bash
# Option 1: LUKS encryption for disk
# Encrypt the data partition during initial setup

# Option 2: AWS EBS encryption
aws ec2 create-volume \
  --size 500 \
  --volume-type gp3 \
  --encrypted \
  --kms-key-id arn:aws:kms:region:account:key/key-id

# Option 3: Encrypted backup storage
# Encrypt backups before uploading to S3
gpg --encrypt --recipient llm-observatory backup.sql.gz
aws s3 cp backup.sql.gz.gpg s3://backups/
```

### Audit Logging

#### Enable PostgreSQL Audit Logging

```conf
# postgresql.conf
log_destination = 'csvlog'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB

# Log connections
log_connections = on
log_disconnections = on

# Log slow queries
log_min_duration_statement = 1000  # Log queries >1s

# Log DDL statements
log_statement = 'ddl'

# Log checkpoints and locks
log_checkpoints = on
log_lock_waits = on

# Detailed logging (development only)
# log_statement = 'all'
```

#### Review Audit Logs

```bash
# Search for failed authentication
grep "FATAL.*authentication" /var/log/postgresql/postgresql-*.log

# Search for DDL changes
grep "CREATE\|ALTER\|DROP" /var/log/postgresql/postgresql-*.log

# Search for slow queries
grep "duration:" /var/log/postgresql/postgresql-*.log | \
  awk '$3 > 1000' | head -20

# Monitor live logs
tail -f /var/log/postgresql/postgresql-$(date +%Y-%m-%d)_*.log
```

### Access Control

#### IP Whitelisting

```conf
# pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer

# Application servers (IP whitelist)
hostssl llm_observatory llm_observatory_app 10.0.1.0/24         md5

# Read-only from analytics network
hostssl llm_observatory llm_observatory_readonly 10.0.2.0/24    md5

# Reject all other connections
host    all             all             0.0.0.0/0              reject
```

#### Firewall Configuration

```bash
# Allow PostgreSQL only from application servers
sudo ufw allow from 10.0.1.0/24 to any port 5432

# Allow monitoring from Prometheus
sudo ufw allow from 10.0.3.100 to any port 9090

# Deny all other traffic to database ports
sudo ufw deny 5432
sudo ufw deny 6379

# Verify rules
sudo ufw status numbered
```

### Security Monitoring

#### Security Alerts

```yaml
# prometheus-security-alerts.yml
groups:
  - name: security_alerts
    rules:
      - alert: FailedAuthenticationAttempts
        expr: rate(pg_stat_database_xact_rollback[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High rate of failed authentication attempts"

      - alert: UnauthorizedDatabaseAccess
        expr: pg_stat_activity_count{user!~"llm_observatory_.*"} > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Unauthorized user connected to database"

      - alert: SuspiciousDDLActivity
        expr: increase(pg_stat_statements_calls{query=~".*DROP.*|.*ALTER.*"}[5m]) > 5
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Suspicious DDL activity detected"
```

#### Security Checklist

Perform monthly security reviews:

```bash
# Step 1: Review database users
psql -h localhost -U postgres -c "\du"

# Step 2: Check for weak passwords (manual review)
# Ensure all passwords meet complexity requirements

# Step 3: Review permissions
psql -h localhost -U postgres -d llm_observatory << 'EOF'
SELECT
  grantee,
  table_schema,
  table_name,
  privilege_type
FROM information_schema.table_privileges
WHERE grantee NOT LIKE 'pg_%'
ORDER BY grantee, table_name;
EOF

# Step 4: Check SSL configuration
psql -h localhost -U postgres -c "SHOW ssl;"
psql -h localhost -U postgres -c "SELECT * FROM pg_stat_ssl;"

# Step 5: Review audit logs for suspicious activity
grep -i "fail\|error\|denied" /var/log/postgresql/postgresql-*.log | tail -100

# Step 6: Check for security updates
cargo audit
sudo apt update && sudo apt list --upgradable | grep postgresql

# Step 7: Verify firewall rules
sudo ufw status
sudo iptables -L -n

# Step 8: Test backup encryption
gpg --list-secret-keys
gpg --decrypt backups/encrypted/latest.sql.gz.gpg | head
```

### Vulnerability Management

```bash
# Scan for vulnerabilities
cargo audit

# Update dependencies with security fixes
cargo update

# Check for PostgreSQL CVEs
# Subscribe to: https://www.postgresql.org/support/security/

# Check for TimescaleDB security updates
# Subscribe to: https://www.timescale.com/blog

# Apply security patches
sudo apt update
sudo apt upgrade postgresql-16 timescaledb-2-postgresql-16

# Restart services after updates
sudo systemctl restart postgresql
sudo systemctl restart llm-observatory-storage
```

---

## Quick Reference

### Common SQL Queries for Diagnostics

```sql
-- Database size
SELECT pg_size_pretty(pg_database_size('llm_observatory'));

-- Table sizes
SELECT
  schemaname || '.' || tablename AS table_name,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

-- Active connections
SELECT
  application_name,
  state,
  COUNT(*) as count
FROM pg_stat_activity
WHERE datname = 'llm_observatory'
GROUP BY application_name, state;

-- Long-running queries
SELECT
  pid,
  usename,
  NOW() - query_start AS duration,
  LEFT(query, 100) AS query
FROM pg_stat_activity
WHERE state != 'idle'
  AND NOW() - query_start > INTERVAL '1 minute'
ORDER BY duration DESC;

-- Cache hit ratio
SELECT
  SUM(heap_blks_read) as heap_read,
  SUM(heap_blks_hit) as heap_hit,
  ROUND(
    100.0 * SUM(heap_blks_hit) / NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0),
    2
  ) AS cache_hit_ratio
FROM pg_statio_user_tables;

-- Slow queries (requires pg_stat_statements)
SELECT
  LEFT(query, 100) AS query,
  calls,
  ROUND(mean_exec_time::numeric, 2) AS mean_ms
FROM pg_stat_statements
WHERE mean_exec_time > 1000
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Dead tuples (need VACUUM)
SELECT
  schemaname || '.' || relname AS table_name,
  n_live_tup,
  n_dead_tup,
  ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- TimescaleDB chunk info
SELECT
  hypertable_name,
  COUNT(*) AS num_chunks,
  pg_size_pretty(SUM(total_bytes)) AS total_size
FROM timescaledb_information.chunks
GROUP BY hypertable_name;

-- Compression status
SELECT
  hypertable_name,
  pg_size_pretty(before_compression_total_bytes) AS uncompressed,
  pg_size_pretty(after_compression_total_bytes) AS compressed
FROM timescaledb_information.compressed_hypertable_stats;

-- Continuous aggregate freshness
SELECT
  view_name,
  completed_threshold,
  NOW() - completed_threshold AS lag
FROM timescaledb_information.continuous_aggregates;
```

### Important File Locations

```
/opt/llm-observatory/storage/
├── bin/
│   └── llm-observatory-storage         # Main binary
├── config/
│   ├── .env                             # Environment configuration
│   └── production.yaml                  # YAML configuration
├── migrations/
│   ├── 001_initial_schema.sql
│   └── ...
└── logs/
    └── storage.log                      # Application logs

/var/lib/postgresql/
├── data/                                # PostgreSQL data directory
├── wal_archive/                         # WAL archive for PITR
└── backups/
    ├── daily/                           # Daily backups
    ├── hourly/                          # Hourly backups
    └── logs/                            # Backup logs

/var/log/
├── postgresql/                          # PostgreSQL logs
│   └── postgresql-YYYY-MM-DD_*.log
└── journal/                             # System logs (journalctl)

/etc/postgresql/16/main/
├── postgresql.conf                      # PostgreSQL configuration
├── pg_hba.conf                          # Authentication rules
└── ssl/                                 # SSL certificates
    ├── server.crt
    ├── server.key
    └── ca.crt
```

### Service Management Commands

```bash
# Storage service
systemctl status llm-observatory-storage
systemctl start llm-observatory-storage
systemctl stop llm-observatory-storage
systemctl restart llm-observatory-storage
systemctl reload llm-observatory-storage  # Reload config without downtime
journalctl -u llm-observatory-storage -f  # Follow logs

# PostgreSQL
systemctl status postgresql
systemctl start postgresql
systemctl stop postgresql
systemctl restart postgresql
systemctl reload postgresql               # Reload config without downtime
journalctl -u postgresql -f              # Follow logs

# Redis (if used)
systemctl status redis
systemctl start redis
systemctl stop redis
systemctl restart redis
```

### Health Check Commands

```bash
# Quick health check
curl -f http://localhost:9090/health | jq .

# Liveness probe
curl -f http://localhost:9090/health/live

# Readiness probe
curl -f http://localhost:9090/health/ready

# Metrics endpoint
curl -s http://localhost:9090/metrics | grep storage_

# Database connection test
psql -h localhost -U postgres -d llm_observatory -c "SELECT 1;"

# Redis connection test (if used)
redis-cli ping
```

### Backup and Restore Commands

```bash
# Create backup
./scripts/backup.sh -v

# Backup to S3
./scripts/backup_to_s3.sh -b llm-observatory-backups -e

# Verify backup
./scripts/verify_backup.sh backups/latest.sql.gz -v

# List backups
ls -lh /var/lib/postgresql/backups/daily/

# Restore from local backup
./scripts/restore.sh backups/daily/llm_observatory_20251105_020000.sql.gz

# Restore from S3
./scripts/restore.sh -s -b llm-observatory-backups backups/latest.sql.gz

# Manual backup (PostgreSQL)
pg_dump -h localhost -U postgres -d llm_observatory \
  --format=custom \
  --compress=9 \
  --file=manual_backup.dump

# Manual restore
pg_restore -h localhost -U postgres -d llm_observatory_new \
  manual_backup.dump
```

### Emergency Contacts

#### On-Call Rotation

| Role | Primary Contact | Secondary Contact | Escalation |
|------|----------------|-------------------|------------|
| **DevOps Engineer** | Jane Doe<br>+1-555-0101<br>jane@company.com | John Smith<br>+1-555-0102<br>john@company.com | Manager<br>+1-555-0199 |
| **Database Administrator** | Alice Johnson<br>+1-555-0201<br>alice@company.com | Bob Williams<br>+1-555-0202<br>bob@company.com | Director<br>+1-555-0299 |
| **Backend Engineer** | Charlie Brown<br>+1-555-0301<br>charlie@company.com | Diana Prince<br>+1-555-0302<br>diana@company.com | Tech Lead<br>+1-555-0399 |

#### Escalation Path

1. **Level 1** (0-15 min): On-call engineer attempts resolution
2. **Level 2** (15-30 min): Escalate to secondary on-call
3. **Level 3** (30-60 min): Escalate to manager/director
4. **Level 4** (60+ min): Executive notification

#### Communication Channels

- **Slack:** #llm-observatory-alerts (for P0/P1 incidents)
- **PagerDuty:** llm-observatory service
- **Email:** llm-observatory-team@company.com
- **Status Page:** status.llm-observatory.io
- **Incident Management:** Jira Service Desk

#### External Vendors

| Service | Contact | SLA | Support Portal |
|---------|---------|-----|----------------|
| **AWS Support** | Enterprise Support<br>1-800-123-4567 | 15 min response | console.aws.amazon.com/support |
| **TimescaleDB Cloud** | support@timescale.com | 1 hour response | console.cloud.timescale.com |

### Useful PromQL Queries

```promql
# Write throughput (ops/sec)
rate(storage_writes_total{status="success"}[1m])

# Write latency (p95)
histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket[5m]))

# Query latency (p95)
histogram_quantile(0.95, rate(storage_query_duration_seconds_bucket[5m]))

# Pool utilization percentage
(storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) * 100

# Error rate (errors/sec)
rate(storage_errors_total[1m])

# Connection acquisition time (p95)
histogram_quantile(0.95, rate(storage_connection_acquire_duration_seconds_bucket[5m]))

# Items written per second
rate(storage_items_written_total[1m])

# Buffer sizes
storage_buffer_size

# Flush rate
rate(storage_flushes_total[1m])
```

### Keyboard Shortcuts for psql

```
\q                  Quit psql
\l                  List databases
\c dbname           Connect to database
\dt                 List tables
\dt+                List tables with sizes
\di                 List indexes
\du                 List users/roles
\dx                 List extensions
\df                 List functions
\dv                 List views
\x                  Toggle expanded output
\timing             Toggle query timing
\?                  Help on psql commands
\h SQL_COMMAND      Help on SQL command
```

---

## Document Maintenance

### Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-05 | LLM Observatory Team | Initial version |

### Review Schedule

- **Weekly:** On-call engineer reviews during handoff
- **Monthly:** Operations team review and update
- **Quarterly:** Comprehensive review and major updates
- **Annually:** Full document refresh

### Related Documentation

- [Disaster Recovery Guide](disaster-recovery.md) - Detailed DR procedures
- [Deployment Runbook](DEPLOYMENT_RUNBOOK.md) - Deployment procedures
- [Monitoring Guide](MONITORING.md) - Monitoring and metrics
- [Metrics Reference](METRICS_REFERENCE.md) - Prometheus metrics reference
- [Backup Quick Reference](backup-quick-reference.md) - Backup commands

### Feedback and Improvements

To suggest improvements to this operations manual:

1. Create a GitHub issue with label `documentation`
2. Submit a pull request with proposed changes
3. Contact the operations team via Slack: #llm-observatory-ops

---

**Last Updated:** 2025-11-05
**Next Review:** 2025-12-05
**Maintained By:** LLM Observatory Operations Team
**Version:** 1.0

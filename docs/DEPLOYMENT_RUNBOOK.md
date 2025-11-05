# LLM Observatory Storage Layer - Production Deployment Runbook

**Version:** 1.0
**Last Updated:** 2025-11-05
**Maintained By:** LLM Observatory Team

## Table of Contents

1. [Overview](#overview)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Deployment Environments](#deployment-environments)
4. [Database Migration Procedures](#database-migration-procedures)
5. [Application Deployment](#application-deployment)
6. [Post-Deployment Verification](#post-deployment-verification)
7. [Rollback Procedures](#rollback-procedures)
8. [Monitoring During Deployment](#monitoring-during-deployment)
9. [Operational Checklists](#operational-checklists)
10. [Troubleshooting Guide](#troubleshooting-guide)
11. [Emergency Contacts](#emergency-contacts)

---

## Overview

This runbook provides step-by-step procedures for deploying the LLM Observatory storage layer to production environments. The storage layer consists of:

- **TimescaleDB (PostgreSQL)** - Primary time-series database
- **Redis** - Caching layer (optional)
- **Storage Service** - Rust application handling data ingestion and queries

### Architecture Components

```
┌─────────────────┐
│   Application   │
│    Services     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Storage Layer  │
│   (Rust API)    │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌──────┐
│TimeDB  │ │Redis │
└────────┘ └──────┘
```

### Deployment Strategy

- **Blue-Green Deployment** for production
- **Rolling Updates** for staging
- **Canary Deployment** for critical releases
- **Zero-Downtime Migrations** using TimescaleDB features

---

## Pre-Deployment Checklist

### 1. Code Quality Gates

- [ ] All unit tests passing (`cargo test`)
- [ ] Integration tests passing (`cargo test --test '*'`)
- [ ] Performance benchmarks run (`cargo bench`)
- [ ] Code coverage > 80% (`cargo tarpaulin`)
- [ ] No critical security vulnerabilities (`cargo audit`)
- [ ] Linting passes (`cargo clippy -- -D warnings`)
- [ ] Code formatting applied (`cargo fmt --check`)

### 2. Documentation

- [ ] CHANGELOG.md updated with version changes
- [ ] API documentation generated (`cargo doc`)
- [ ] Migration notes documented
- [ ] Breaking changes highlighted
- [ ] Deployment notes reviewed

### 3. Database Preparation

- [ ] Database backup completed (< 1 hour old)
- [ ] Backup integrity verified
- [ ] Migration scripts tested in staging
- [ ] Migration rollback scripts prepared
- [ ] Database performance baseline captured
- [ ] Disk space verified (>30% free)
- [ ] Connection pool capacity checked

### 4. Infrastructure

- [ ] Resource capacity verified (CPU, RAM, Disk)
- [ ] Network connectivity tested
- [ ] SSL certificates valid (>30 days)
- [ ] DNS records configured
- [ ] Load balancer health checks configured
- [ ] Monitoring alerts configured
- [ ] Log aggregation working

### 5. Security Review

- [ ] Security scan completed
- [ ] Dependencies updated (no critical CVEs)
- [ ] Secrets rotated (if required)
- [ ] Access controls reviewed
- [ ] Audit logging enabled
- [ ] Encryption at rest verified
- [ ] Encryption in transit verified

### 6. Team Readiness

- [ ] Deployment team notified
- [ ] Stakeholders informed
- [ ] On-call engineer identified
- [ ] Rollback plan reviewed
- [ ] Communication channels ready (Slack, PagerDuty)
- [ ] Deployment window scheduled
- [ ] Change management ticket approved

### 7. Rollback Preparation

- [ ] Previous version containers tagged and available
- [ ] Database backup restoration tested
- [ ] Rollback scripts validated
- [ ] Rollback triggers defined
- [ ] Data migration reversal plan documented

---

## Deployment Environments

### Staging Environment

**Purpose:** Pre-production testing with production-like data

```bash
# Environment configuration
ENVIRONMENT=staging
DB_HOST=staging-timescaledb.internal
DB_NAME=llm_observatory_staging
DB_POOL_MAX_SIZE=20
```

**Characteristics:**
- Similar to production configuration
- Subset of production data (10-20%)
- Aggressive monitoring enabled
- Feature flags for experimental features

### Production Environment

**Purpose:** Live production system serving customer traffic

```bash
# Environment configuration
ENVIRONMENT=production
DB_HOST=prod-timescaledb.internal
DB_NAME=llm_observatory
DB_POOL_MAX_SIZE=100
DB_SSL_MODE=require
```

**Characteristics:**
- High availability setup
- Multi-AZ deployment
- Automated failover
- Read replicas for queries
- Point-in-time recovery (PITR) enabled

---

## Database Migration Procedures

### Pre-Migration Steps

1. **Verify Database Health**

```bash
# Check database connection
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT version();"

# Check active connections
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT count(*) FROM pg_stat_activity WHERE datname='llm_observatory';"

# Check database size
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT pg_size_pretty(pg_database_size('llm_observatory'));"
```

2. **Create Backup**

```bash
# Full database backup
./scripts/deploy_database.sh --backup-only

# Verify backup
pg_restore --list /backups/llm_observatory_$(date +%Y%m%d_%H%M%S).dump | head -20
```

3. **Estimate Migration Time**

```bash
# Test migration in staging
time psql -h staging-db -U postgres -d llm_observatory_staging \
  -f crates/storage/migrations/00X_new_migration.sql
```

### Migration Execution

#### Option 1: Automated Migration (Recommended)

```bash
# Run migration script with all safety checks
cd /workspaces/llm-observatory
./scripts/deploy_database.sh --environment production --dry-run

# Review the plan, then execute
./scripts/deploy_database.sh --environment production
```

#### Option 2: Manual Migration

```bash
# Set environment variables
export DB_HOST=prod-timescaledb.internal
export DB_USER=postgres
export DB_NAME=llm_observatory

# Enable maintenance mode (optional)
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "CREATE TABLE IF NOT EXISTS maintenance_mode (enabled BOOLEAN);"
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "INSERT INTO maintenance_mode VALUES (true);"

# Run migrations in transaction
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
BEGIN;

-- Run migration file
\i crates/storage/migrations/001_initial_schema.sql
\i crates/storage/migrations/002_add_hypertables.sql
\i crates/storage/migrations/003_create_indexes.sql
\i crates/storage/migrations/004_continuous_aggregates.sql
\i crates/storage/migrations/005_retention_policies.sql
\i crates/storage/migrations/006_supporting_tables.sql

-- Verify migration
\i crates/storage/migrations/verify_migrations.sql

COMMIT;
EOF

# Disable maintenance mode
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "UPDATE maintenance_mode SET enabled = false;"
```

### Zero-Downtime Migration Strategies

#### Strategy 1: Online Schema Changes

```sql
-- For adding nullable columns (instant in PostgreSQL 11+)
ALTER TABLE llm_traces ADD COLUMN new_field TEXT DEFAULT NULL;

-- For adding indexes concurrently
CREATE INDEX CONCURRENTLY idx_new_field ON llm_traces(new_field);

-- For complex changes, use multi-phase deployment:
-- Phase 1: Add new column, keep old column
-- Phase 2: Dual write to both columns
-- Phase 3: Backfill data
-- Phase 4: Switch reads to new column
-- Phase 5: Remove old column
```

#### Strategy 2: Shadow Tables

```sql
-- Create new table structure
CREATE TABLE llm_traces_v2 (LIKE llm_traces INCLUDING ALL);

-- Modify new table
ALTER TABLE llm_traces_v2 ADD COLUMN new_field TEXT;

-- Copy data in chunks
DO $$
DECLARE
  batch_size INT := 10000;
  offset_id UUID;
BEGIN
  LOOP
    INSERT INTO llm_traces_v2
    SELECT * FROM llm_traces
    WHERE id > COALESCE(offset_id, '00000000-0000-0000-0000-000000000000'::UUID)
    ORDER BY id
    LIMIT batch_size;

    IF NOT FOUND THEN EXIT; END IF;

    SELECT MAX(id) INTO offset_id FROM llm_traces_v2;
    COMMIT;
  END LOOP;
END $$;

-- Swap tables atomically
BEGIN;
ALTER TABLE llm_traces RENAME TO llm_traces_old;
ALTER TABLE llm_traces_v2 RENAME TO llm_traces;
COMMIT;
```

#### Strategy 3: TimescaleDB Continuous Aggregates

```sql
-- Refresh continuous aggregates before deployment
CALL refresh_continuous_aggregate('trace_metrics_hourly', NULL, NULL);
CALL refresh_continuous_aggregate('trace_metrics_daily', NULL, NULL);

-- Verify data freshness
SELECT view_name,
       completed_threshold,
       invalidation_threshold
FROM timescaledb_information.continuous_aggregates;
```

### Post-Migration Steps

```bash
# 1. Verify schema version
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT * FROM schema_migrations ORDER BY version DESC LIMIT 5;"

# 2. Analyze tables for query planner
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "ANALYZE;"

# 3. Verify indexes
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f \
  crates/storage/migrations/verify_migrations.sql

# 4. Check for bloat
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
EOF
```

---

## Application Deployment

### Staging Deployment

#### Step 1: Build and Test

```bash
# Build release binary
cargo build --release --package llm-observatory-storage

# Run smoke tests
cargo test --release --package llm-observatory-storage -- --test-threads=1

# Generate deployment artifacts
tar -czf storage-layer-v0.1.0.tar.gz \
  target/release/llm-observatory-storage \
  crates/storage/migrations/ \
  scripts/ \
  .env.example
```

#### Step 2: Deploy to Staging

```bash
# Deploy using deployment script
./scripts/deploy_application.sh \
  --environment staging \
  --version v0.1.0 \
  --health-check-timeout 60

# Monitor logs
journalctl -u llm-observatory-storage -f
```

#### Step 3: Staging Verification

```bash
# Run verification script
./scripts/verify_deployment.sh --environment staging

# Manual smoke tests
curl -f http://staging-api.internal:8080/health
curl -f http://staging-api.internal:8080/metrics
```

### Production Deployment

#### Blue-Green Deployment

**Advantages:**
- Zero downtime
- Instant rollback
- Full traffic switch

**Process:**

```bash
# 1. Deploy to GREEN environment (inactive)
./scripts/deploy_application.sh \
  --environment production \
  --target green \
  --version v0.1.0

# 2. Verify GREEN environment
./scripts/verify_deployment.sh \
  --environment production \
  --target green

# 3. Run smoke tests on GREEN
curl -f https://green.api.llm-observatory.io/health
# Run integration tests against GREEN

# 4. Switch traffic from BLUE to GREEN
# Update load balancer to point to GREEN
aws elbv2 modify-target-group \
  --target-group-arn $GREEN_TG_ARN \
  --health-check-enabled

# 5. Monitor traffic switch
watch -n 1 'aws elbv2 describe-target-health --target-group-arn $GREEN_TG_ARN'

# 6. Drain BLUE environment
# Wait 5 minutes for existing connections to complete
sleep 300

# 7. Keep BLUE running for 24 hours for rollback capability
```

#### Canary Deployment

**Advantages:**
- Gradual rollout
- Early issue detection
- Lower risk

**Process:**

```bash
# 1. Deploy canary (5% of traffic)
./scripts/deploy_application.sh \
  --environment production \
  --strategy canary \
  --canary-percentage 5 \
  --version v0.1.0

# 2. Monitor canary metrics for 30 minutes
./scripts/monitor_canary.sh --duration 30m

# 3. Increase to 25% if healthy
./scripts/deploy_application.sh \
  --environment production \
  --strategy canary \
  --canary-percentage 25

# 4. Monitor for 1 hour

# 5. Increase to 50%
./scripts/deploy_application.sh \
  --environment production \
  --strategy canary \
  --canary-percentage 50

# 6. Monitor for 1 hour

# 7. Complete rollout to 100%
./scripts/deploy_application.sh \
  --environment production \
  --strategy canary \
  --canary-percentage 100
```

#### Rolling Update Deployment

**Advantages:**
- Resource efficient
- Gradual rollout
- No duplicate infrastructure

**Process:**

```bash
# Deploy with rolling update (one instance at a time)
./scripts/deploy_application.sh \
  --environment production \
  --strategy rolling \
  --batch-size 1 \
  --health-check-timeout 60

# Monitor each instance as it rolls out
# Total time: ~15 minutes for 6 instances
```

### Configuration Management

```bash
# Validate configuration before deployment
./scripts/validate_config.sh --environment production

# Environment-specific configurations
# Production
export DB_POOL_MAX_SIZE=100
export DB_POOL_MIN_SIZE=20
export REDIS_POOL_SIZE=50
export LOG_LEVEL=info
export METRICS_ENABLED=true

# Staging
export DB_POOL_MAX_SIZE=20
export DB_POOL_MIN_SIZE=5
export REDIS_POOL_SIZE=10
export LOG_LEVEL=debug
export METRICS_ENABLED=true
```

---

## Post-Deployment Verification

### Automated Verification

```bash
# Run comprehensive verification suite
./scripts/verify_deployment.sh \
  --environment production \
  --comprehensive \
  --timeout 300

# Expected output:
# ✓ Database connectivity
# ✓ Redis connectivity
# ✓ Health check endpoint
# ✓ Metrics endpoint
# ✓ API endpoints responding
# ✓ Database schema version
# ✓ Performance baseline
# ✓ Error rate normal
```

### Manual Verification Checklist

#### 1. Service Health

```bash
# Health check
curl -f https://api.llm-observatory.io/health | jq .
# Expected: {"status":"healthy","postgres":true,"redis":true}

# Metrics endpoint
curl -f https://api.llm-observatory.io/metrics | grep -E 'storage_pool_size|storage_query_duration'
```

#### 2. Database Health

```bash
# Check connection pool
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT application_name, count(*)
   FROM pg_stat_activity
   WHERE datname='llm_observatory'
   GROUP BY application_name;"

# Check for long-running queries
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT pid, now() - query_start AS duration, state, query
   FROM pg_stat_activity
   WHERE state != 'idle'
   AND now() - query_start > interval '1 minute'
   ORDER BY duration DESC;"

# Verify hypertables
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT hypertable_name, num_chunks
   FROM timescaledb_information.hypertables;"
```

#### 3. Performance Validation

```bash
# Test write performance
time curl -X POST https://api.llm-observatory.io/api/v1/traces \
  -H "Content-Type: application/json" \
  -d @test_data/sample_trace.json
# Expected: < 100ms

# Test query performance
time curl -X GET 'https://api.llm-observatory.io/api/v1/traces?limit=100'
# Expected: < 200ms

# Run load test
./scripts/load_test.sh --duration 5m --rps 100
```

#### 4. Data Integrity

```bash
# Verify data counts
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT 'llm_traces' as table_name, count(*) FROM llm_traces
UNION ALL
SELECT 'llm_metrics', count(*) FROM llm_metrics
UNION ALL
SELECT 'llm_logs', count(*) FROM llm_logs;
EOF

# Check for data anomalies
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
-- Check for NULL values in required fields
SELECT 'traces_null_trace_id', count(*) FROM llm_traces WHERE trace_id IS NULL
UNION ALL
SELECT 'traces_future_timestamps', count(*) FROM llm_traces WHERE timestamp > now() + interval '1 hour';
EOF
```

#### 5. Monitoring and Alerts

```bash
# Verify Prometheus scraping
curl -f http://prometheus.internal:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="storage-layer")'

# Check alert rules
curl -f http://prometheus.internal:9090/api/v1/rules | jq '.data.groups[] | select(.name=="storage-layer")'

# Verify no firing alerts
curl -f http://prometheus.internal:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing")'
```

#### 6. Log Verification

```bash
# Check for errors in logs (last 5 minutes)
journalctl -u llm-observatory-storage --since "5 minutes ago" | grep -i error

# Check application startup
journalctl -u llm-observatory-storage -n 100 | grep -E 'Started|Initialized|Ready'

# Verify log aggregation
curl -f http://loki.internal:3100/loki/api/v1/query \
  --data-urlencode 'query={job="storage-layer"}' | jq .
```

### Performance Baseline Comparison

```bash
# Compare metrics before and after deployment
./scripts/compare_metrics.sh \
  --before "2025-11-05 10:00:00" \
  --after "2025-11-05 11:00:00" \
  --metrics "query_duration,connection_pool_usage,error_rate"

# Expected output:
# Metric                    Before   After    Change
# query_duration_p95        145ms    142ms    -2.1%   ✓
# connection_pool_usage     45%      47%      +4.4%   ✓
# error_rate               0.01%    0.01%     0%      ✓
```

---

## Rollback Procedures

### When to Rollback

**Immediate Rollback Triggers:**
- Error rate > 1%
- P95 latency > 2x baseline
- Database connection failures
- Data corruption detected
- Critical security vulnerability
- Application crashes/restarts

**Evaluate Rollback:**
- Error rate > 0.5%
- P95 latency > 1.5x baseline
- Increased resource usage (>80% CPU/Memory)
- Customer complaints
- Failed health checks

### Rollback Methods

#### Method 1: Blue-Green Rollback (Fastest - 30 seconds)

```bash
# Switch load balancer back to BLUE environment
./scripts/rollback.sh --method blue-green

# Process:
# 1. Update load balancer to point to BLUE
# 2. Verify traffic is flowing to BLUE
# 3. Investigate issues in GREEN
```

#### Method 2: Application Rollback (Fast - 5 minutes)

```bash
# Redeploy previous version
./scripts/rollback.sh --method application --version v0.0.9

# Process:
# 1. Stop current version
# 2. Deploy previous version
# 3. Verify health checks
# 4. Resume traffic
```

#### Method 3: Database Rollback (Slow - 30+ minutes)

**CAUTION:** This method involves data loss. Only use if database migration caused issues.

```bash
# Rollback database to previous state
./scripts/rollback.sh --method database --backup-file /backups/llm_observatory_20251105_100000.dump

# Process:
# 1. Stop all applications
# 2. Drop current database
# 3. Restore from backup
# 4. Verify data integrity
# 5. Restart applications
```

### Rollback Execution

#### Emergency Rollback (< 5 minutes)

```bash
# Automated emergency rollback
./scripts/rollback.sh --emergency

# This will:
# 1. Stop accepting new traffic
# 2. Drain existing connections (30s)
# 3. Deploy previous known-good version
# 4. Verify health checks
# 5. Resume traffic
# 6. Send notifications
```

#### Planned Rollback

```bash
# Step 1: Enable maintenance mode (optional)
./scripts/maintenance_mode.sh --enable

# Step 2: Execute rollback
./scripts/rollback.sh \
  --method blue-green \
  --verify \
  --notification-channel slack

# Step 3: Verify rollback
./scripts/verify_deployment.sh --environment production

# Step 4: Disable maintenance mode
./scripts/maintenance_mode.sh --disable

# Step 5: Post-mortem
# Document what went wrong and create action items
```

### Post-Rollback Actions

1. **Verify Service Health**
   ```bash
   ./scripts/verify_deployment.sh --comprehensive
   ```

2. **Check Data Integrity**
   ```bash
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f scripts/verify_data_integrity.sql
   ```

3. **Monitor for Stability** (1 hour)
   - Error rates
   - Response times
   - Resource usage
   - Customer reports

4. **Root Cause Analysis**
   - Review logs from failed deployment
   - Identify failure point
   - Document lessons learned
   - Create prevention tasks

5. **Communication**
   - Notify stakeholders of rollback
   - Provide status update
   - Share timeline for fix

---

## Monitoring During Deployment

### Key Metrics to Watch

#### 1. Application Metrics

```promql
# Request rate
rate(http_requests_total{job="storage-layer"}[5m])

# Error rate
rate(http_requests_total{job="storage-layer",status=~"5.."}[5m]) /
rate(http_requests_total{job="storage-layer"}[5m])

# Request duration (P95)
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket{job="storage-layer"}[5m]))

# Active connections
storage_pool_active_connections{job="storage-layer"}
```

#### 2. Database Metrics

```promql
# Connection pool usage
(pg_stat_database_numbackends{datname="llm_observatory"} /
 pg_settings_max_connections) * 100

# Query duration (P95)
histogram_quantile(0.95,
  rate(pg_stat_statements_total_time_bucket[5m]))

# Transaction rate
rate(pg_stat_database_xact_commit{datname="llm_observatory"}[5m])

# Cache hit rate
pg_stat_database_blks_hit{datname="llm_observatory"} /
(pg_stat_database_blks_hit{datname="llm_observatory"} +
 pg_stat_database_blks_read{datname="llm_observatory"})
```

#### 3. System Metrics

```promql
# CPU usage
rate(process_cpu_seconds_total{job="storage-layer"}[5m])

# Memory usage
process_resident_memory_bytes{job="storage-layer"}

# Disk I/O
rate(node_disk_io_time_seconds_total[5m])

# Network I/O
rate(node_network_transmit_bytes_total[5m])
```

### Monitoring Dashboard

Create a deployment dashboard in Grafana:

```json
{
  "dashboard": {
    "title": "Storage Layer Deployment",
    "panels": [
      {
        "title": "Request Rate",
        "targets": ["rate(http_requests_total[5m])"]
      },
      {
        "title": "Error Rate",
        "targets": ["rate(http_requests_total{status=~\"5..\"}[5m])"]
      },
      {
        "title": "Response Time (P95)",
        "targets": ["histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"]
      },
      {
        "title": "Database Connections",
        "targets": ["pg_stat_database_numbackends"]
      }
    ]
  }
}
```

### Alert Thresholds During Deployment

```yaml
# Stricter thresholds during deployment
- alert: HighErrorRateDuringDeployment
  expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.01
  for: 1m

- alert: SlowResponseDuringDeployment
  expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
  for: 2m

- alert: DatabaseConnectionsDuringDeployment
  expr: pg_stat_database_numbackends{datname="llm_observatory"} > 80
  for: 1m
```

### Real-Time Monitoring Commands

```bash
# Watch request rate
watch -n 5 'curl -s http://localhost:9090/metrics | grep http_requests_total | tail -5'

# Watch error logs
journalctl -u llm-observatory-storage -f | grep -i error

# Watch database connections
watch -n 5 "psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \"SELECT count(*) FROM pg_stat_activity WHERE datname='llm_observatory'\""

# Watch resource usage
watch -n 5 'docker stats llm-observatory-storage --no-stream'
```

---

## Operational Checklists

### Daily Operations Checklist

**Frequency:** Every day at 9:00 AM

- [ ] Check system health dashboard
- [ ] Review error logs from past 24 hours
- [ ] Verify backup completion (should run at 2:00 AM)
- [ ] Check disk space usage (alert if > 70%)
- [ ] Review slow query log (queries > 1s)
- [ ] Monitor connection pool usage (alert if > 80%)
- [ ] Check for failed jobs/tasks
- [ ] Review application metrics trends
- [ ] Verify monitoring alerts are working
- [ ] Check certificate expiry dates (alert if < 30 days)

**Commands:**

```bash
# Daily health check script
./scripts/daily_health_check.sh

# Review overnight issues
journalctl -u llm-observatory-storage --since yesterday | grep -E 'ERROR|WARN' | wc -l

# Check backup
ls -lh /backups/llm_observatory_*.dump | tail -1

# Database size
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT pg_size_pretty(pg_database_size('llm_observatory'));"
```

### Weekly Maintenance Tasks

**Frequency:** Every Monday at 10:00 AM

- [ ] Review and rotate logs (keep last 30 days)
- [ ] Analyze database performance metrics
- [ ] Review and update alert thresholds
- [ ] Check for security updates
- [ ] Review and prune old data based on retention policy
- [ ] Verify backup restoration process (sample restore)
- [ ] Review connection pool configuration
- [ ] Analyze slow queries and optimize
- [ ] Check for index bloat
- [ ] Review TimescaleDB chunk statistics
- [ ] Update documentation if needed
- [ ] Review capacity planning metrics

**Commands:**

```bash
# Weekly maintenance script
./scripts/weekly_maintenance.sh

# Analyze database
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "ANALYZE VERBOSE;"

# Check index bloat
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f scripts/check_index_bloat.sql

# Review chunk statistics
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT hypertable_name,
       num_chunks,
       pg_size_pretty(total_bytes) as total_size
FROM timescaledb_information.hypertables
ORDER BY total_bytes DESC;
EOF
```

### Monthly Review Items

**Frequency:** First Monday of each month

- [ ] Review capacity trends (project next 3 months)
- [ ] Analyze cost optimization opportunities
- [ ] Review and update disaster recovery plan
- [ ] Test disaster recovery procedures
- [ ] Review security audit logs
- [ ] Update dependencies and security patches
- [ ] Review and optimize retention policies
- [ ] Conduct performance benchmarking
- [ ] Review SLA compliance
- [ ] Update runbooks and documentation
- [ ] Team training on new features/changes
- [ ] Stakeholder report on system health

**Commands:**

```bash
# Monthly review script
./scripts/monthly_review.sh

# Capacity planning
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f scripts/capacity_report.sql

# Performance benchmark
./scripts/run_benchmark.sh --compare-with last-month
```

---

## Troubleshooting Guide

### Migration Failures

#### Issue: Migration Timeout

**Symptoms:**
- Migration script hangs
- No progress after 30 minutes
- Lock wait timeouts in logs

**Diagnosis:**
```bash
# Check for locks
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT pid, usename, pg_blocking_pids(pid) as blocked_by, query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
EOF
```

**Resolution:**
```bash
# 1. Identify blocking queries
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT pid, query FROM pg_stat_activity WHERE state = 'active';"

# 2. Terminate blocking queries (if safe)
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <blocking_pid>;"

# 3. Retry migration
./scripts/deploy_database.sh --retry
```

#### Issue: Migration Fails with Constraint Violation

**Symptoms:**
- Foreign key constraint errors
- Unique constraint violations
- Check constraint failures

**Diagnosis:**
```bash
# Find conflicting data
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
-- Example: Find orphaned records
SELECT * FROM llm_traces
WHERE trace_id NOT IN (SELECT DISTINCT trace_id FROM trace_spans)
LIMIT 10;
EOF
```

**Resolution:**
```bash
# 1. Clean up conflicting data
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f scripts/cleanup_orphaned_data.sql

# 2. Retry migration
./scripts/deploy_database.sh --retry
```

#### Issue: Out of Disk Space During Migration

**Symptoms:**
- "No space left on device" error
- Migration aborted
- Database unresponsive

**Diagnosis:**
```bash
# Check disk space
df -h /var/lib/postgresql/data

# Check largest tables
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT schemaname || '.' || tablename AS table,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
EOF
```

**Resolution:**
```bash
# 1. Free up space
# Drop old compression chunks if using TimescaleDB
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT drop_chunks('llm_metrics', older_than => INTERVAL '90 days');"

# 2. Vacuum to reclaim space
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "VACUUM FULL VERBOSE;"

# 3. Expand disk if needed
./scripts/expand_disk.sh --size +50GB

# 4. Retry migration
./scripts/deploy_database.sh --retry
```

### Connection Pool Exhaustion

#### Issue: Connection Pool Full

**Symptoms:**
- "Connection pool timeout" errors
- Increased request latency
- 503 Service Unavailable errors

**Diagnosis:**
```bash
# Check connection pool stats
curl http://localhost:9090/metrics | grep storage_pool

# Check database connections
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT application_name,
       state,
       count(*) as connections
FROM pg_stat_activity
WHERE datname = 'llm_observatory'
GROUP BY application_name, state
ORDER BY connections DESC;
EOF
```

**Resolution:**
```bash
# 1. Check for connection leaks
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT pid, usename, application_name, state, state_change,
       now() - state_change as duration
FROM pg_stat_activity
WHERE state = 'idle'
AND now() - state_change > interval '5 minutes'
ORDER BY state_change;
EOF

# 2. Terminate idle connections
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
AND now() - state_change > interval '10 minutes'
AND datname = 'llm_observatory';
EOF

# 3. Increase pool size (if resources allow)
# Update configuration
export DB_POOL_MAX_SIZE=100

# 4. Restart application
systemctl restart llm-observatory-storage
```

#### Issue: Connection Timeout

**Symptoms:**
- "Connection timeout" errors in logs
- Application fails to start
- Health checks failing

**Diagnosis:**
```bash
# Test database connectivity
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1;"

# Check database max_connections
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SHOW max_connections;"

# Check current connections
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT count(*) FROM pg_stat_activity;"
```

**Resolution:**
```bash
# 1. Verify network connectivity
ping $DB_HOST
telnet $DB_HOST 5432

# 2. Check firewall rules
sudo iptables -L -n | grep 5432

# 3. Increase connection timeout
export DB_POOL_CONNECT_TIMEOUT=30

# 4. Check PostgreSQL logs
sudo tail -100 /var/log/postgresql/postgresql-16-main.log | grep -i error
```

### Performance Degradation

#### Issue: Slow Queries

**Symptoms:**
- P95 latency > 1 second
- Timeout errors
- User complaints

**Diagnosis:**
```bash
# Identify slow queries
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT query,
       calls,
       total_time,
       mean_time,
       max_time
FROM pg_stat_statements
WHERE mean_time > 1000  -- queries taking > 1s on average
ORDER BY mean_time DESC
LIMIT 10;
EOF

# Check for missing indexes
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats
WHERE schemaname = 'public'
AND n_distinct > 100
AND correlation < 0.5
ORDER BY n_distinct DESC;
EOF
```

**Resolution:**
```bash
# 1. Analyze slow query
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
EXPLAIN ANALYZE
SELECT * FROM llm_traces
WHERE service_name = 'api' AND timestamp > now() - interval '1 hour';
EOF

# 2. Create missing index
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "CREATE INDEX CONCURRENTLY idx_traces_service_timestamp
   ON llm_traces(service_name, timestamp);"

# 3. Update statistics
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "ANALYZE llm_traces;"

# 4. Verify improvement
# Re-run EXPLAIN ANALYZE and compare
```

#### Issue: High CPU Usage

**Symptoms:**
- CPU usage > 80%
- Slow response times
- System sluggish

**Diagnosis:**
```bash
# Check PostgreSQL CPU usage
top -p $(pgrep -d',' postgres)

# Check active queries
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT pid, state, query_start,
       now() - query_start as duration,
       query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC;
EOF

# Check for sequential scans
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT schemaname, tablename, seq_scan, seq_tup_read,
       idx_scan, idx_tup_fetch,
       seq_scan::float / NULLIF(idx_scan, 0) as seq_to_idx_ratio
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_to_idx_ratio DESC NULLIF;
EOF
```

**Resolution:**
```bash
# 1. Terminate expensive queries (if safe)
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'active'
AND now() - query_start > interval '5 minutes';
EOF

# 2. Add indexes to reduce sequential scans
# See "Slow Queries" resolution

# 3. Scale up database instance (if needed)
# AWS RDS example:
aws rds modify-db-instance \
  --db-instance-identifier llm-observatory-prod \
  --db-instance-class db.r6g.xlarge \
  --apply-immediately
```

### Data Inconsistencies

#### Issue: Missing Data

**Symptoms:**
- Gaps in time-series data
- Null values in required fields
- Orphaned records

**Diagnosis:**
```bash
# Check for gaps in time-series
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
WITH time_series AS (
  SELECT generate_series(
    date_trunc('hour', now() - interval '24 hours'),
    date_trunc('hour', now()),
    interval '1 hour'
  ) AS hour
),
actual_data AS (
  SELECT date_trunc('hour', timestamp) AS hour,
         count(*) AS count
  FROM llm_traces
  WHERE timestamp > now() - interval '24 hours'
  GROUP BY date_trunc('hour', timestamp)
)
SELECT ts.hour, COALESCE(ad.count, 0) AS count
FROM time_series ts
LEFT JOIN actual_data ad ON ts.hour = ad.hour
WHERE COALESCE(ad.count, 0) = 0;
EOF
```

**Resolution:**
```bash
# 1. Check ingestion pipeline
# Review collector logs for errors
journalctl -u llm-observatory-collector --since "24 hours ago" | grep -i error

# 2. Verify continuous aggregates are up to date
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT view_name,
       completed_threshold,
       invalidation_threshold,
       now() - completed_threshold as lag
FROM timescaledb_information.continuous_aggregates;
EOF

# 3. Refresh continuous aggregates
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "CALL refresh_continuous_aggregate('trace_metrics_hourly', NULL, NULL);"
```

#### Issue: Duplicate Data

**Symptoms:**
- Duplicate trace IDs
- Constraint violations on insert
- Inflated data counts

**Diagnosis:**
```bash
# Find duplicates
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
SELECT trace_id, count(*) AS duplicates
FROM llm_traces
GROUP BY trace_id
HAVING count(*) > 1
ORDER BY duplicates DESC
LIMIT 10;
EOF
```

**Resolution:**
```bash
# 1. Deduplicate data
psql -h $DB_HOST -U $DB_USER -d $DB_NAME << 'EOF'
DELETE FROM llm_traces
WHERE id NOT IN (
  SELECT MIN(id)
  FROM llm_traces
  GROUP BY trace_id
);
EOF

# 2. Add unique constraint to prevent future duplicates
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "CREATE UNIQUE INDEX CONCURRENTLY idx_traces_trace_id_unique ON llm_traces(trace_id);"
```

---

## Emergency Contacts

### On-Call Rotation

| Role | Primary | Secondary | Escalation |
|------|---------|-----------|------------|
| DevOps Engineer | Jane Doe<br>+1-555-0101<br>jane@company.com | John Smith<br>+1-555-0102<br>john@company.com | Manager<br>+1-555-0199 |
| Database Administrator | Alice Johnson<br>+1-555-0201<br>alice@company.com | Bob Williams<br>+1-555-0202<br>bob@company.com | Director<br>+1-555-0299 |
| Backend Engineer | Charlie Brown<br>+1-555-0301<br>charlie@company.com | Diana Prince<br>+1-555-0302<br>diana@company.com | Tech Lead<br>+1-555-0399 |

### Escalation Path

1. **Level 1** (0-15 minutes): On-call engineer attempts resolution
2. **Level 2** (15-30 minutes): Escalate to secondary on-call
3. **Level 3** (30-60 minutes): Escalate to manager/director
4. **Level 4** (60+ minutes): Executive notification

### Communication Channels

- **Slack:** #llm-observatory-alerts (P0/P1 incidents)
- **PagerDuty:** llm-observatory service
- **Email:** llm-observatory-team@company.com
- **Status Page:** status.llm-observatory.io
- **Incident Management:** Jira Service Desk

### External Vendors

| Service | Contact | SLA | Support Portal |
|---------|---------|-----|----------------|
| AWS Support | Enterprise Support<br>1-800-123-4567 | 15 min response | console.aws.amazon.com/support |
| TimescaleDB Cloud | support@timescale.com<br>Ticket #12345 | 1 hour response | console.cloud.timescale.com |

---

## Appendix

### A. Environment Variables Reference

See `.env.example` for complete configuration options.

### B. Database Schema Versions

| Version | Date | Description | Migration Files |
|---------|------|-------------|-----------------|
| 6.0 | 2025-11-05 | Supporting tables | 006_supporting_tables.sql |
| 5.0 | 2025-11-04 | Retention policies | 005_retention_policies.sql |
| 4.0 | 2025-11-03 | Continuous aggregates | 004_continuous_aggregates.sql |
| 3.0 | 2025-11-02 | Performance indexes | 003_create_indexes.sql |
| 2.0 | 2025-11-01 | TimescaleDB hypertables | 002_add_hypertables.sql |
| 1.0 | 2025-10-31 | Initial schema | 001_initial_schema.sql |

### C. Deployment History Template

```markdown
## Deployment: v0.1.0 to Production

**Date:** 2025-11-05 14:00 UTC
**Deployed By:** Jane Doe
**Change Ticket:** JIRA-1234

### Changes
- Added new retention policy for logs
- Optimized trace query performance
- Updated continuous aggregates

### Deployment Process
- [x] Pre-deployment checklist completed
- [x] Database backup taken at 13:45 UTC
- [x] Migrations applied successfully (5 minutes)
- [x] Application deployed via blue-green (10 minutes)
- [x] Post-deployment verification passed
- [x] Monitoring for 1 hour - no issues

### Issues Encountered
None

### Rollback Performed
No

### Lessons Learned
- Migration took longer than expected (5 min vs 2 min estimated)
- Consider adding index concurrently next time
```

### D. Useful Commands Quick Reference

```bash
# Health check
curl -f https://api.llm-observatory.io/health

# Database connection test
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1;"

# View logs (last 100 lines)
journalctl -u llm-observatory-storage -n 100

# Check database size
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT pg_size_pretty(pg_database_size('llm_observatory'));"

# List active connections
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT count(*) FROM pg_stat_activity WHERE datname='llm_observatory';"

# Emergency rollback
./scripts/rollback.sh --emergency
```

---

**Document Version:** 1.0
**Last Updated:** 2025-11-05
**Next Review:** 2025-12-05

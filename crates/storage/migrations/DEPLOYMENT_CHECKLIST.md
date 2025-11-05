# Database Migration Deployment Checklist

**Date:** 2025-11-05
**Target:** LLM Observatory Storage Layer
**Database:** TimescaleDB 2.14+

---

## Pre-Deployment Checklist

### Environment Setup
- [ ] TimescaleDB 2.14+ is installed and running
- [ ] Database `llm_observatory` has been created
- [ ] Database user has sufficient privileges (CREATE, ALTER, DROP)
- [ ] Database connection string is configured
- [ ] Backup of existing database (if any) has been created

### Prerequisites
- [ ] PostgreSQL 14+ is installed
- [ ] TimescaleDB extension is available (`SELECT * FROM pg_available_extensions WHERE name = 'timescaledb';`)
- [ ] Sufficient disk space available (recommend 50GB minimum for testing)
- [ ] Database parameters are tuned (see plan section 10.4)

### Required Extensions
```sql
-- Check available extensions
SELECT name, installed_version, comment
FROM pg_available_extensions
WHERE name IN ('timescaledb', 'uuid-ossp', 'pgcrypto');

-- TimescaleDB MUST be available
-- uuid-ossp is used by api_keys table (gen_random_uuid)
```

---

## Migration Execution

### Step 1: Verify Database Connection
```bash
psql "postgresql://user:password@host:5432/llm_observatory" -c "SELECT version();"
```

**Expected:** PostgreSQL version output (14+ recommended)
- [ ] Connection successful
- [ ] Correct database selected

### Step 2: Run Migrations in Order

#### Migration 001: Initial Schema
```bash
psql "postgresql://..." -f 001_initial_schema.sql
```

**Expected Output:**
- `CREATE TABLE` x3 (llm_traces, llm_metrics, llm_logs)
- `COMMENT ON TABLE` x3
- `COMMENT ON COLUMN` x7+
- `COMMIT`

**Verification:**
```sql
SELECT tablename FROM pg_tables WHERE schemaname = 'public';
-- Should show: llm_traces, llm_metrics, llm_logs
```

- [ ] Migration 001 successful
- [ ] All 3 tables created
- [ ] No errors in output

#### Migration 002: Hypertables
```bash
psql "postgresql://..." -f 002_add_hypertables.sql
```

**Expected Output:**
- `CREATE EXTENSION` timescaledb
- `create_hypertable` x3
- `COMMIT`

**Verification:**
```sql
SELECT hypertable_name FROM timescaledb_information.hypertables;
-- Should show: llm_traces, llm_metrics, llm_logs
```

- [ ] Migration 002 successful
- [ ] All 3 hypertables created
- [ ] Chunk intervals correct (1 day, 1 hour, 1 day)

#### Migration 003: Indexes
```bash
psql "postgresql://..." -f 003_create_indexes.sql
```

**Expected Output:**
- `CREATE INDEX` x24+
- `COMMIT`

**Verification:**
```sql
SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';
-- Should show: 24+ indexes
```

- [ ] Migration 003 successful
- [ ] All indexes created
- [ ] No duplicate index warnings

#### Migration 004: Continuous Aggregates
```bash
psql "postgresql://..." -f 004_continuous_aggregates.sql
```

**Expected Output:**
- `CREATE MATERIALIZED VIEW` x4
- `add_continuous_aggregate_policy` x4
- `COMMIT`

**Verification:**
```sql
SELECT view_name FROM timescaledb_information.continuous_aggregates;
-- Should show: llm_metrics_1min, llm_metrics_1hour, llm_metrics_1day, cost_analysis_hourly
```

- [ ] Migration 004 successful
- [ ] All 4 continuous aggregates created
- [ ] All refresh policies added

#### Migration 005: Retention Policies
```bash
psql "postgresql://..." -f 005_retention_policies.sql
```

**Expected Output:**
- `ALTER TABLE` x3 (compression settings)
- `add_compression_policy` x3
- `add_retention_policy` x7
- `COMMIT`

**Verification:**
```sql
SELECT hypertable_name, proc_name FROM timescaledb_information.jobs;
-- Should show compression and retention policies
```

- [ ] Migration 005 successful
- [ ] Compression enabled on all hypertables
- [ ] All retention policies added

#### Migration 006: Supporting Tables
```bash
psql "postgresql://..." -f 006_supporting_tables.sql
```

**Expected Output:**
- `CREATE TABLE` x4 (model_pricing, api_keys, users, projects)
- `CREATE INDEX` x7+
- `ALTER TABLE ADD CONSTRAINT` x2 (foreign keys)
- `COMMIT`

**Verification:**
```sql
SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('model_pricing', 'api_keys', 'users', 'projects');
-- Should show all 4 tables
```

- [ ] Migration 006 successful
- [ ] All 4 supporting tables created
- [ ] Foreign keys created

---

## Post-Deployment Verification

### Step 3: Run Verification Script
```bash
psql "postgresql://..." -f verify_migrations.sql > verification_report.txt
```

**Review the report and verify:**
- [ ] TimescaleDB extension: Installed
- [ ] Core tables: 7 (PASS)
- [ ] Hypertables: 3 (PASS)
- [ ] Continuous aggregates: 4 (PASS)
- [ ] Compression policies: 3+ (PASS)
- [ ] Retention policies: 7+ (PASS)
- [ ] Foreign keys: 2 (PASS)

### Step 4: Check Database Health
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Check all tables exist
SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';
-- Expected: 7 tables

-- Check hypertable configuration
SELECT * FROM timescaledb_information.hypertables;
-- Expected: 3 hypertables

-- Check background jobs
SELECT job_id, hypertable_name, proc_name, schedule_interval
FROM timescaledb_information.jobs;
-- Expected: Multiple jobs for compression, retention, and aggregates
```

- [ ] Database size is reasonable (<1GB for empty DB)
- [ ] All 7 tables exist
- [ ] All 3 hypertables configured
- [ ] Background jobs scheduled

---

## Testing

### Step 5: Insert Test Data

#### Test Trace Insert
```sql
INSERT INTO llm_traces (
    ts, trace_id, span_id, span_name, span_kind,
    provider, model, input_type, duration_ms, status_code
) VALUES (
    NOW(),
    'test-trace-001',
    'test-span-001',
    'llm.chat.completion',
    'internal',
    'openai',
    'gpt-4',
    'chat',
    1500,
    'OK'
);
```

**Verification:**
```sql
SELECT * FROM llm_traces WHERE trace_id = 'test-trace-001';
-- Should return 1 row
```

- [ ] Test insert successful
- [ ] Data retrieved correctly

#### Test Metric Insert
```sql
INSERT INTO llm_metrics (
    ts, metric_name, metric_type, provider, model, value
) VALUES (
    NOW(),
    'test_metric',
    'counter',
    'openai',
    'gpt-4',
    1.0
);
```

- [ ] Test metric inserted

#### Test Log Insert
```sql
INSERT INTO llm_logs (
    ts, trace_id, span_id, log_level, message
) VALUES (
    NOW(),
    'test-trace-001',
    'test-span-001',
    'INFO',
    'Test log message'
);
```

- [ ] Test log inserted

### Step 6: Test Queries

#### Query Recent Traces
```sql
SELECT * FROM llm_traces
WHERE ts > NOW() - INTERVAL '1 hour'
ORDER BY ts DESC
LIMIT 10;
```

- [ ] Query executes successfully
- [ ] Results include test data

#### Query Continuous Aggregates
```sql
SELECT * FROM llm_metrics_1min
WHERE bucket > NOW() - INTERVAL '1 hour'
LIMIT 10;
```

- [ ] Continuous aggregate query works
- [ ] Note: May be empty until refresh policy runs

#### Test Index Usage
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM llm_traces
WHERE provider = 'openai'
    AND ts > NOW() - INTERVAL '1 hour'
ORDER BY ts DESC
LIMIT 100;
```

**Check output for:**
- [ ] Index scan (not sequential scan)
- [ ] Execution time < 100ms
- [ ] Buffers hit > read (good cache performance)

---

## Performance Validation

### Step 7: Load Testing (Optional)

#### Insert 1000 Test Traces
```sql
INSERT INTO llm_traces (
    ts, trace_id, span_id, span_name, span_kind,
    provider, model, input_type, duration_ms, status_code
)
SELECT
    NOW() - (random() * INTERVAL '7 days'),
    'trace-' || generate_series,
    'span-' || generate_series,
    'llm.chat.completion',
    'internal',
    CASE (random() * 2)::INT
        WHEN 0 THEN 'openai'
        WHEN 1 THEN 'anthropic'
        ELSE 'google'
    END,
    'test-model',
    'chat',
    (random() * 5000)::INT,
    CASE (random() * 10)::INT
        WHEN 0 THEN 'ERROR'
        ELSE 'OK'
    END
FROM generate_series(1, 1000);
```

**Verification:**
```sql
SELECT COUNT(*) FROM llm_traces;
-- Should show 1001 (1 manual + 1000 generated)

SELECT provider, COUNT(*) FROM llm_traces GROUP BY provider;
-- Should show distribution across providers
```

- [ ] Bulk insert successful
- [ ] Query performance acceptable (<100ms for recent data)
- [ ] Indexes being used (check with EXPLAIN)

---

## Rollback Plan

### If Migration Fails

#### Option 1: Drop and Recreate
```sql
-- WARNING: This will delete all data
DROP TABLE IF EXISTS llm_traces CASCADE;
DROP TABLE IF EXISTS llm_metrics CASCADE;
DROP TABLE IF EXISTS llm_logs CASCADE;
DROP TABLE IF EXISTS model_pricing CASCADE;
DROP TABLE IF EXISTS api_keys CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS projects CASCADE;

-- Then re-run migrations
```

#### Option 2: Restore from Backup
```bash
# If you created a backup before migration
pg_restore -d llm_observatory backup_file.dump
```

---

## Production Deployment Notes

### Before Production Deployment

- [ ] Test migrations on staging environment first
- [ ] Create full database backup
- [ ] Review and adjust retention policies based on storage capacity
- [ ] Review and adjust compression policies based on query patterns
- [ ] Tune PostgreSQL configuration (see plan section 10.4)
- [ ] Set up monitoring for database metrics
- [ ] Configure alerts for disk space, query performance, job failures
- [ ] Document database credentials securely
- [ ] Schedule regular backup jobs
- [ ] Test restore procedure

### Monitoring Setup

**Key Metrics to Monitor:**
- Database size growth rate
- Compression ratio (should be 85-95%)
- Query latency (p95 should be <100ms)
- Background job execution (compression, retention, aggregates)
- Disk I/O utilization
- Connection pool usage
- Index bloat
- Vacuum/autovacuum activity

**Tools:**
- TimescaleDB observability functions (see QUICK_REFERENCE.sql)
- pg_stat_statements for query analysis
- Prometheus + Grafana for dashboards
- PgBadger for log analysis

---

## Troubleshooting

### Common Issues

#### Issue: TimescaleDB extension not available
**Solution:**
```bash
# Install TimescaleDB
# Ubuntu/Debian:
sudo add-apt-repository ppa:timescale/timescaledb-ppa
sudo apt update
sudo apt install timescaledb-2-postgresql-14

# Then run:
sudo timescaledb-tune
sudo systemctl restart postgresql
```

#### Issue: Insufficient privileges
**Solution:**
```sql
-- Grant necessary privileges
GRANT CREATE ON DATABASE llm_observatory TO your_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_user;
ALTER USER your_user WITH SUPERUSER; -- If needed for TimescaleDB
```

#### Issue: Out of disk space during compression
**Solution:**
- Free up disk space
- Adjust compression policy to compress less frequently
- Implement retention policy sooner

#### Issue: Slow queries after migration
**Solution:**
- Run ANALYZE on all tables: `ANALYZE llm_traces;`
- Check index usage: See QUICK_REFERENCE.sql
- Verify BRIN indexes are being used for time-range queries
- Consider increasing shared_buffers and effective_cache_size

#### Issue: Background jobs not running
**Solution:**
```sql
-- Check job status
SELECT * FROM timescaledb_information.job_stats;

-- Restart failed jobs
SELECT run_job(job_id) FROM timescaledb_information.jobs WHERE job_id = <id>;
```

---

## Success Criteria

All items below should be checked before considering deployment complete:

### Database Structure
- [ ] All 7 tables created successfully
- [ ] All 3 hypertables configured with correct chunk intervals
- [ ] All 24+ indexes created
- [ ] All 4 continuous aggregates created
- [ ] All compression policies active
- [ ] All retention policies active
- [ ] All foreign key constraints created

### Functionality
- [ ] Can insert data into all tables
- [ ] Can query data from all tables
- [ ] Can query continuous aggregates
- [ ] Indexes are being used in queries
- [ ] Background jobs are scheduled and running

### Performance
- [ ] Query latency <100ms for recent data
- [ ] Bulk inserts work correctly
- [ ] No blocking or deadlock issues

### Documentation
- [ ] Database connection details documented
- [ ] Monitoring plan established
- [ ] Backup/restore procedures documented
- [ ] Team trained on basic operations

---

## Sign-Off

**Deployed By:** ___________________
**Date:** ___________________
**Environment:** [ ] Development [ ] Staging [ ] Production
**Verification Report Attached:** [ ] Yes [ ] No
**Issues Encountered:** ___________________
**Resolution:** ___________________

**Approved By:** ___________________
**Date:** ___________________

---

## Next Steps After Deployment

1. **Seed Pricing Data** (Optional)
   - Uncomment seed data in 006_supporting_tables.sql
   - Update with current LLM pricing
   - Run: `psql ... -f 006_supporting_tables.sql`

2. **Set Up Monitoring**
   - Configure Prometheus exporters
   - Create Grafana dashboards
   - Set up alerts for critical metrics

3. **Performance Tuning**
   - Monitor query patterns for 1 week
   - Adjust indexes based on actual usage
   - Fine-tune continuous aggregate refresh intervals

4. **Integration Testing**
   - Test OTLP collector → storage integration
   - Verify cost calculation accuracy
   - Test query API endpoints

5. **Load Testing**
   - Simulate production load (10K+ spans/sec)
   - Verify compression ratios after 7 days
   - Check retention policy execution

6. **Documentation**
   - Create team runbooks
   - Document common queries (see QUICK_REFERENCE.sql)
   - Create incident response procedures

---

## Support Resources

**Documentation:**
- Implementation Plan: `/workspaces/llm-observatory/plans/storage-layer-implementation-plan.md`
- Migration Summary: `MIGRATION_SUMMARY.md`
- Quick Reference: `QUICK_REFERENCE.sql`
- Verification Script: `verify_migrations.sql`

**External Resources:**
- TimescaleDB Docs: https://docs.timescale.com/
- PostgreSQL Docs: https://www.postgresql.org/docs/
- SQLx Docs: https://docs.rs/sqlx/

**Contact:**
- LLM Observatory Core Team
- Database Administrator: [Contact Info]
- On-Call Engineer: [Contact Info]

---

**Deployment Status:** [ ] Not Started [ ] In Progress [ ] Complete [ ] Rolled Back

# LLM Observatory - Deployment Documentation Index

**Complete Guide to Production Deployment**

This index provides quick access to all deployment documentation, scripts, and resources for the LLM Observatory storage layer.

## Quick Navigation

| Document | Purpose | Audience |
|----------|---------|----------|
| **[Deployment Summary](DEPLOYMENT_SUMMARY.md)** | Overview and quick start | Everyone |
| **[Deployment Runbook](DEPLOYMENT_RUNBOOK.md)** | Step-by-step procedures | Operators |
| **[Monitoring README](../docker/prometheus/README.md)** | Alert setup and configuration | DevOps |

## Document Hierarchy

```
1. Start Here
   └── DEPLOYMENT_INDEX.md (this file)
       ├── Quick reference and navigation
       └── Links to all resources

2. Getting Started
   └── DEPLOYMENT_SUMMARY.md
       ├── Overview of deployment infrastructure
       ├── Quick start guide
       └── Key features and workflows

3. Detailed Procedures
   └── DEPLOYMENT_RUNBOOK.md
       ├── Pre-deployment checklist
       ├── Step-by-step deployment instructions
       ├── Database migration procedures
       ├── Rollback procedures
       ├── Troubleshooting guide
       └── Operational checklists

4. Monitoring Setup
   └── docker/prometheus/README.md
       ├── Prometheus configuration
       ├── Alert rules explanation
       ├── Alertmanager setup
       └── Testing and troubleshooting
```

## Deployment Scripts

All deployment scripts are located in `/scripts/` directory:

### Database Management

| Script | Purpose | Usage Example |
|--------|---------|---------------|
| **deploy_database.sh** | Run database migrations safely | `./scripts/deploy_database.sh --environment production` |
| **backup.sh** | Create database backups | `./scripts/backup.sh --output /backups/` |
| **restore.sh** | Restore from backup | `./scripts/restore.sh --backup-file /backups/db.dump` |
| **verify_backup.sh** | Verify backup integrity | `./scripts/verify_backup.sh --backup-file /backups/db.dump` |

### Application Deployment

| Script | Purpose | Usage Example |
|--------|---------|---------------|
| **deploy_application.sh** | Deploy storage layer application | `./scripts/deploy_application.sh --version v0.1.0 --strategy blue-green` |
| **verify_deployment.sh** | Post-deployment verification | `./scripts/verify_deployment.sh --comprehensive` |
| **rollback.sh** | Emergency rollback procedures | `./scripts/rollback.sh --method blue-green --emergency` |

### Utilities

| Script | Purpose | Usage Example |
|--------|---------|---------------|
| **backup_to_s3.sh** | Backup to AWS S3 | `./scripts/backup_to_s3.sh --bucket my-backups` |
| **archive_wal.sh** | Archive WAL files | `./scripts/archive_wal.sh --archive-dir /archives/` |
| **cron-examples.sh** | Example cron jobs | `cat scripts/cron-examples.sh` |

## Monitoring Configuration

All monitoring files are located in `/docker/prometheus/` directory:

| File | Purpose | Configuration Needed |
|------|---------|---------------------|
| **storage_layer_alerts.yml** | 39 production-ready alert rules | Review thresholds |
| **alertmanager.yml** | Alert routing and notifications | Add webhook URLs, keys |
| **README.md** | Setup and configuration guide | Follow instructions |

## Common Tasks

### First-Time Setup

```bash
# 1. Review environment configuration
cat .env.example

# 2. Create production environment file
cp .env.example .env.production
vim .env.production

# 3. Review deployment documentation
cat docs/DEPLOYMENT_SUMMARY.md

# 4. Set up monitoring
cd docker/prometheus
cat README.md
```

### Staging Deployment

```bash
# 1. Deploy database migrations
./scripts/deploy_database.sh --environment staging

# 2. Deploy application
./scripts/deploy_application.sh \
  --environment staging \
  --version v0.1.0 \
  --strategy rolling

# 3. Verify deployment
./scripts/verify_deployment.sh --environment staging
```

### Production Deployment

```bash
# 1. Pre-deployment checklist
# See DEPLOYMENT_RUNBOOK.md Section 2

# 2. Create backup
./scripts/backup.sh --output /backups/

# 3. Deploy database
./scripts/deploy_database.sh \
  --environment production \
  --dry-run  # Review first

./scripts/deploy_database.sh --environment production

# 4. Deploy application (blue-green)
./scripts/deploy_application.sh \
  --environment production \
  --version v0.1.0 \
  --strategy blue-green \
  --target green

# 5. Verify and switch traffic
./scripts/verify_deployment.sh \
  --environment production \
  --target green \
  --comprehensive

# 6. Monitor for 1 hour
# Check metrics, logs, alerts
```

### Emergency Rollback

```bash
# Quick rollback (30 seconds)
./scripts/rollback.sh --emergency --method blue-green

# Application rollback (5 minutes)
./scripts/rollback.sh \
  --method application \
  --version v0.0.9

# Database rollback (CAUTION: DATA LOSS)
./scripts/rollback.sh \
  --method database \
  --backup-file /backups/latest.dump
```

## Alert Severity Guide

### Critical Alerts (Page Immediately)
- DatabaseDown
- StorageServiceDown
- ConnectionPoolExhausted
- BackupFailed
- DatabaseDiskSpaceLow

**Response:** Immediate action required

### Warning Alerts (Notify Team)
- ConnectionPoolHighUsage
- SlowQueryDetected
- HighLatency
- DatabaseMemoryPressure

**Response:** Investigate within 30 minutes

### Info Alerts (Create Ticket)
- HighQueryRate
- DatabaseGrowthHigh
- RedisCacheHitRateLow

**Response:** Review within 24 hours

## Operational Checklists

### Daily Operations (15 minutes)
- [ ] Check health dashboard
- [ ] Review error logs (past 24h)
- [ ] Verify backup completion
- [ ] Check disk space
- [ ] Review slow queries
- [ ] Monitor connection pool

**See:** DEPLOYMENT_RUNBOOK.md Section 9.1

### Weekly Maintenance (1 hour)
- [ ] Rotate logs
- [ ] Analyze performance
- [ ] Update alert thresholds
- [ ] Check security updates
- [ ] Test backup restore
- [ ] Optimize queries

**See:** DEPLOYMENT_RUNBOOK.md Section 9.2

### Monthly Review (2 hours)
- [ ] Capacity planning
- [ ] Test disaster recovery
- [ ] Security audit
- [ ] Update dependencies
- [ ] Performance benchmarking
- [ ] Team training

**See:** DEPLOYMENT_RUNBOOK.md Section 9.3

## Troubleshooting Index

### By Symptom

| Symptom | Possible Cause | See Section |
|---------|---------------|-------------|
| Service won't start | Config error, DB connection | Runbook 10.1 |
| Slow queries | Missing indexes | Runbook 10.3 |
| Connection errors | Pool exhausted | Runbook 10.2 |
| High CPU | Expensive queries | Runbook 10.3 |
| Out of disk space | Database growth | Runbook 10.1 |
| Migration timeout | Long-running locks | Runbook 10.1 |

### By Component

| Component | Common Issues | Documentation |
|-----------|--------------|---------------|
| Database | Connection, performance, space | Runbook Section 10 |
| Application | Startup, health checks | Runbook Section 10 |
| Monitoring | Alerts not firing | prometheus/README.md |
| Backups | Failed, corrupted | scripts/README.md |

## Environment Configuration

### Required Environment Variables

**Database:**
```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=llm_observatory
DB_USER=postgres
DB_PASSWORD=<secure-password>
```

**Application:**
```bash
APP_PORT=8080
METRICS_PORT=9090
LOG_LEVEL=info
```

**Monitoring:**
```bash
PROMETHEUS_URL=http://localhost:9090
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
PAGERDUTY_API_KEY=<your-key>
```

**See:** `.env.example` for complete list

## Migration Reference

### Migration Files Order

1. `001_initial_schema.sql` - Core tables
2. `002_add_hypertables.sql` - TimescaleDB setup
3. `003_create_indexes.sql` - Performance indexes
4. `004_continuous_aggregates.sql` - Analytics views
5. `005_retention_policies.sql` - Data retention
6. `006_supporting_tables.sql` - Additional tables

**See:** `/crates/storage/migrations/README.md`

### Migration Commands

```bash
# Apply all migrations
./scripts/deploy_database.sh

# Apply specific migration
./scripts/deploy_database.sh --migration 004_continuous_aggregates.sql

# Verify migrations
./scripts/deploy_database.sh --verify-only

# Dry run
./scripts/deploy_database.sh --dry-run
```

## Backup and Recovery

### Backup Schedule

| Type | Frequency | Retention | Location |
|------|-----------|-----------|----------|
| Full | Daily 2:00 AM | 30 days | /backups/ |
| Incremental | Every 6 hours | 7 days | /backups/incremental/ |
| WAL Archive | Continuous | 7 days | /backups/wal/ |

### Recovery Procedures

```bash
# List available backups
ls -lh /backups/*.dump

# Verify backup integrity
./scripts/verify_backup.sh --backup-file /backups/latest.dump

# Restore from backup
./scripts/restore.sh \
  --backup-file /backups/llm_observatory_20251105.dump \
  --target-db llm_observatory
```

**See:** DEPLOYMENT_RUNBOOK.md Section 7 for detailed procedures

## Performance Baselines

### Expected Performance

| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| Request latency (P95) | < 200ms | > 500ms |
| Error rate | < 0.1% | > 1% |
| Database query (P95) | < 100ms | > 500ms |
| Connection pool usage | < 70% | > 80% |
| Disk space free | > 30% | < 15% |

### Load Test Results

```bash
# Run benchmark
cargo bench --package llm-observatory-storage

# Run load test
./scripts/load_test.sh --duration 5m --rps 100
```

## Security Checklist

### Pre-Deployment Security
- [ ] All passwords rotated
- [ ] SSL/TLS enabled
- [ ] Security scan completed
- [ ] Access controls reviewed
- [ ] Audit logging enabled

### Runtime Security
- [ ] Monitor failed login attempts
- [ ] Review access logs weekly
- [ ] Update dependencies monthly
- [ ] Security patches applied
- [ ] Encryption verified

**See:** DEPLOYMENT_RUNBOOK.md Section 2.5

## Team Contacts

### Primary Contacts
- **On-Call Engineer:** Check PagerDuty rotation
- **Database Team:** #database-team Slack
- **DevOps Team:** #devops Slack
- **Security Team:** security@llm-observatory.io

### Escalation Path
1. On-call engineer (0-15 min)
2. Secondary on-call (15-30 min)
3. Manager/Director (30-60 min)
4. Executive notification (60+ min)

**See:** DEPLOYMENT_RUNBOOK.md Section 11

## Additional Resources

### Internal Documentation
- Architecture Overview: `/docs/ARCHITECTURE.md`
- API Documentation: `cargo doc --open`
- Database Schema: `/crates/storage/migrations/README.md`
- Monitoring Guide: `/docker/prometheus/README.md`

### External Resources
- [TimescaleDB Docs](https://docs.timescale.com/)
- [PostgreSQL Best Practices](https://www.postgresql.org/docs/current/best-practices.html)
- [Prometheus Guide](https://prometheus.io/docs/introduction/overview/)
- [Rust Deployment](https://doc.rust-lang.org/cargo/guide/)

### Training Materials
- Deployment Workshop: (scheduled monthly)
- Incident Response Training: (scheduled quarterly)
- Database Performance Tuning: (on-demand)

## Document Versions

| Document | Version | Last Updated |
|----------|---------|-------------|
| DEPLOYMENT_INDEX.md | 1.0 | 2025-11-05 |
| DEPLOYMENT_SUMMARY.md | 1.0 | 2025-11-05 |
| DEPLOYMENT_RUNBOOK.md | 1.0 | 2025-11-05 |
| prometheus/README.md | 1.0 | 2025-11-05 |

### Update Schedule
- **Weekly:** Operational checklists
- **Monthly:** Performance baselines
- **Quarterly:** Full documentation review
- **As-Needed:** After incidents or major changes

## Feedback and Improvements

### How to Contribute
1. Submit documentation issues on GitHub
2. Propose improvements in #docs-feedback Slack
3. Update procedures based on learnings
4. Share runbook improvements with team

### Documentation Standards
- Keep procedures up to date
- Include examples for all commands
- Document edge cases and gotchas
- Add troubleshooting for common issues

---

## Getting Help

**Need help with deployment?**

1. **Check the docs:** Start with DEPLOYMENT_SUMMARY.md
2. **Review runbook:** See DEPLOYMENT_RUNBOOK.md for detailed procedures
3. **Ask the team:** #llm-observatory-support Slack channel
4. **Emergency:** Page on-call via PagerDuty

**Found an issue?**
- Documentation bugs: Create GitHub issue
- Security concerns: Email security@llm-observatory.io
- Feature requests: Discuss in #llm-observatory-ideas

---

**Document Maintained By:** LLM Observatory Team
**Last Review:** 2025-11-05
**Next Review:** 2025-12-05
**Questions:** support@llm-observatory.io

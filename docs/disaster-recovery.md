# Disaster Recovery Guide

## Table of Contents

- [Overview](#overview)
- [Backup Strategy](#backup-strategy)
- [Recovery Objectives](#recovery-objectives)
- [Backup Procedures](#backup-procedures)
- [Restore Procedures](#restore-procedures)
- [Point-in-Time Recovery (PITR)](#point-in-time-recovery-pitr)
- [WAL Archiving Setup](#wal-archiving-setup)
- [Testing Schedule](#testing-schedule)
- [Disaster Recovery Scenarios](#disaster-recovery-scenarios)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [Troubleshooting](#troubleshooting)

## Overview

This document describes the disaster recovery procedures for the LLM Observatory platform, including backup strategies, restore procedures, and point-in-time recovery capabilities.

### Key Features

- **Automated Backups**: Daily full backups with configurable retention
- **S3 Integration**: Offsite backup storage with encryption
- **Point-in-Time Recovery**: WAL archiving for recovery to any point in time
- **Backup Verification**: Automated testing of backup integrity
- **Multi-tier Storage**: Cost-optimized storage tiers (Standard-IA, Glacier, Deep Archive)

## Backup Strategy

### Multi-Layered Backup Approach

```
┌─────────────────────────────────────────────────────────────┐
│                    Backup Strategy                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Hourly Local Backups  ───►  1 day retention               │
│      (Local disk)                                           │
│                                                             │
│  Daily Local Backups   ───►  30 days retention             │
│      (Local disk)                                           │
│                                                             │
│  Daily S3 Backups      ───►  90 days retention             │
│      (Standard-IA)          (lifecycle policy)              │
│                                                             │
│  Monthly Archives      ───►  7 years retention             │
│      (Glacier)              (compliance)                    │
│                                                             │
│  WAL Archiving        ───►  7 days retention               │
│      (PITR)                 (continuous)                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Backup Components

1. **Full Database Backups**
   - PostgreSQL logical dumps (pg_dump)
   - Compressed with gzip -9
   - Includes all schemas, tables, indexes, and data
   - TimescaleDB metadata preserved

2. **WAL Archives**
   - Write-Ahead Log files
   - Required for Point-in-Time Recovery
   - Continuous archiving
   - Small incremental files

3. **Configuration Backups**
   - PostgreSQL configuration files
   - Application configuration
   - Environment variables (encrypted)
   - Docker compose configurations

## Recovery Objectives

### RTO/RPO Targets

| Environment | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) |
|-------------|------------------------------|--------------------------------|
| Production  | < 4 hours                    | < 15 minutes (with WAL)        |
| Staging     | < 8 hours                    | < 1 day                        |
| Development | < 24 hours                   | < 7 days                       |

### Recovery Scenarios

- **Data Corruption**: Restore from latest backup (RPO: 0-24 hours)
- **Accidental Deletion**: Point-in-Time Recovery (RPO: 0-15 minutes)
- **Hardware Failure**: Restore to new hardware (RTO: 2-4 hours)
- **Site Disaster**: Restore from S3 to new region (RTO: 4-8 hours)

## Backup Procedures

### 1. Local Backups

#### Manual Backup

```bash
# Basic backup
cd /workspaces/llm-observatory
./scripts/backup.sh

# Verbose output
./scripts/backup.sh -v

# Custom retention period
./scripts/backup.sh -r 60

# Custom backup directory
./scripts/backup.sh -d /mnt/backups
```

#### Automated Backups

```bash
# Add to crontab (crontab -e)
# Daily backup at 2:00 AM
0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -v 2>&1 | logger -t llm-backup

# Hourly backups for critical systems
0 * * * * /workspaces/llm-observatory/scripts/backup.sh -r 1 -d /var/backups/hourly
```

### 2. S3 Backups

#### Prerequisites

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format
```

#### Manual S3 Backup

```bash
# Basic S3 backup
./scripts/backup_to_s3.sh -b my-backup-bucket

# With encryption
./scripts/backup_to_s3.sh -b my-backup-bucket -e

# With KMS encryption
./scripts/backup_to_s3.sh -b my-backup-bucket -k alias/my-kms-key

# Glacier storage class
./scripts/backup_to_s3.sh -b my-backup-bucket -s GLACIER_IR

# Custom S3 prefix
./scripts/backup_to_s3.sh -b my-backup-bucket -p production/db/
```

#### S3 Lifecycle Policy

Create an S3 lifecycle policy to automatically transition backups to cheaper storage tiers:

```json
{
  "Rules": [
    {
      "Id": "BackupLifecycle",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "backups/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER_IR"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 2555
      }
    }
  ]
}
```

Apply with AWS CLI:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-backup-bucket \
  --lifecycle-configuration file://lifecycle-policy.json
```

### 3. Backup Verification

#### Manual Verification

```bash
# Verify latest backup
./scripts/verify_backup.sh -v

# Verify specific backup
./scripts/verify_backup.sh backups/daily/llm_observatory_20240101_120000.sql.gz

# Verify S3 backup
./scripts/verify_backup.sh -s -b my-bucket backups/latest.sql.gz

# Keep test database for inspection
./scripts/verify_backup.sh --keep-test-db
```

#### Automated Verification

```bash
# Add to crontab - weekly verification on Sunday at 3:00 AM
0 3 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh -v 2>&1 | logger -t llm-verify
```

## Restore Procedures

### 1. Pre-Restore Checklist

- [ ] Identify the correct backup file to restore
- [ ] Verify backup integrity
- [ ] Ensure sufficient disk space
- [ ] Stop application services accessing the database
- [ ] Create a backup of the current state (if database is accessible)
- [ ] Notify stakeholders of downtime window
- [ ] Document the restore process and reasons

### 2. Full Database Restore

#### Restore from Local Backup

```bash
# Basic restore (overwrites existing database)
./scripts/restore.sh backups/daily/llm_observatory_20240101_120000.sql.gz

# Restore to a different database (for testing)
./scripts/restore.sh -t llm_observatory_restored backup.sql.gz

# Drop and restore
./scripts/restore.sh --drop-existing backup.sql.gz

# Skip confirmation prompts
./scripts/restore.sh -y backup.sql.gz

# Dry run (show what would be done)
./scripts/restore.sh --dry-run backup.sql.gz
```

#### Restore from S3

```bash
# Download and restore from S3
./scripts/restore.sh -s -b my-bucket backups/llm_observatory_20240101_120000.sql.gz

# With verbose output
./scripts/restore.sh -s -b my-bucket -v backups/latest.sql.gz
```

### 3. Docker-Specific Restore

If running PostgreSQL in Docker:

```bash
# Stop the application services
docker-compose stop grafana

# Restore database
./scripts/restore.sh -c .env backups/daily/latest.sql.gz

# Restart services
docker-compose start grafana
```

### 4. Manual Restore (Advanced)

```bash
# Extract compressed backup
gunzip -k backup.sql.gz

# Create new database
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -c "CREATE DATABASE llm_observatory_new;"

# Restore to new database
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory_new -f backup.sql

# Verify restore
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory_new -c "\dt+"

# If successful, rename databases
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -c "ALTER DATABASE llm_observatory RENAME TO llm_observatory_old;"
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -c "ALTER DATABASE llm_observatory_new RENAME TO llm_observatory;"
```

## Point-in-Time Recovery (PITR)

### Overview

Point-in-Time Recovery allows you to restore the database to any specific moment in time, providing protection against:

- Accidental data deletion
- Application bugs that corrupt data
- User errors
- Malicious attacks

### WAL Archiving Setup

#### 1. Configure PostgreSQL for WAL Archiving

Create or edit `docker/postgresql.conf`:

```conf
# WAL Configuration for PITR
wal_level = replica                    # Enable WAL archiving
archive_mode = on                      # Turn on archiving
archive_command = '/scripts/archive_wal.sh %p %f'  # Archive script
archive_timeout = 300                  # Force WAL switch every 5 minutes

# WAL retention
wal_keep_size = 1GB                    # Keep at least 1GB of WAL
max_wal_senders = 3                    # For replication
wal_sender_timeout = 60s

# Checkpoint settings
checkpoint_timeout = 15min             # Maximum time between checkpoints
max_wal_size = 2GB                     # Maximum WAL size before checkpoint
min_wal_size = 512MB                   # Minimum WAL size

# Logging
log_checkpoints = on                   # Log checkpoint activity
```

#### 2. Setup WAL Archive Directory

```bash
# Create WAL archive directory
sudo mkdir -p /var/lib/postgresql/wal_archive
sudo chown postgres:postgres /var/lib/postgresql/wal_archive
sudo chmod 700 /var/lib/postgresql/wal_archive

# Make archive script executable
chmod +x /workspaces/llm-observatory/scripts/archive_wal.sh
```

#### 3. Configure Environment Variables

Add to `.env`:

```bash
# WAL Archiving Configuration
WAL_ARCHIVE_DIR=/var/lib/postgresql/wal_archive
WAL_S3_BUCKET=my-wal-archive-bucket
WAL_S3_PREFIX=wal_archive/
WAL_RETENTION_DAYS=7
```

#### 4. Update Docker Compose

```yaml
# docker-compose.yml
services:
  timescaledb:
    volumes:
      - timescaledb_data:/var/lib/postgresql/data
      - ./docker/postgresql.conf:/etc/postgresql/postgresql.conf:ro
      - ./scripts/archive_wal.sh:/scripts/archive_wal.sh:ro
      - wal_archive:/var/lib/postgresql/wal_archive
    command: >
      postgres
      -c config_file=/etc/postgresql/postgresql.conf

volumes:
  wal_archive:
    name: llm-observatory-wal-archive
```

#### 5. Restart PostgreSQL

```bash
docker-compose restart timescaledb
```

#### 6. Verify WAL Archiving

```bash
# Check PostgreSQL logs
docker-compose logs timescaledb | grep archive

# Check WAL archive directory
ls -lh /var/lib/postgresql/wal_archive/

# Force WAL switch to test archiving
docker exec llm-observatory-db psql -U postgres -c "SELECT pg_switch_wal();"

# Verify archive was created
ls -lht /var/lib/postgresql/wal_archive/ | head -5
```

### Performing Point-in-Time Recovery

#### 1. Create Base Backup

```bash
# Create a base backup for PITR
./scripts/backup.sh -v

# Note the backup timestamp
BACKUP_TIME=$(date -Iseconds)
echo "Base backup created at: $BACKUP_TIME"
```

#### 2. Determine Recovery Target

```bash
# Option A: Recover to specific timestamp
RECOVERY_TARGET="2024-01-15 14:30:00"

# Option B: Recover to before a specific transaction
# Find transaction ID from logs
RECOVERY_TARGET_XID="12345"

# Option C: Recover to named restore point
# First create a restore point:
# psql -c "SELECT pg_create_restore_point('before_migration');"
RECOVERY_TARGET_NAME="before_migration"
```

#### 3. Restore Process

```bash
# Step 1: Stop the database
docker-compose stop timescaledb

# Step 2: Backup current data (if possible)
sudo mv /var/lib/postgresql/data /var/lib/postgresql/data.old

# Step 3: Restore base backup
./scripts/restore.sh backups/daily/llm_observatory_20240115_020000.sql.gz

# Step 4: Create recovery.conf (PostgreSQL 12+: recovery.signal)
cat > recovery.conf << EOF
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '$RECOVERY_TARGET'
recovery_target_action = 'promote'
EOF

# Step 5: Start PostgreSQL in recovery mode
docker-compose start timescaledb

# Step 6: Monitor recovery
docker-compose logs -f timescaledb

# Step 7: Verify recovery
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory -c "SELECT pg_is_in_recovery();"
```

#### 4. Alternative PITR Using pg_basebackup

```bash
# Create base backup with pg_basebackup
pg_basebackup \
  -h localhost \
  -U postgres \
  -D /var/backups/base \
  -Fp \
  -Xs \
  -P \
  -v

# Create recovery configuration
cat > /var/backups/base/recovery.signal << EOF
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '2024-01-15 14:30:00'
EOF

# Restore by replacing data directory
sudo systemctl stop postgresql
sudo rm -rf /var/lib/postgresql/data/*
sudo cp -a /var/backups/base/* /var/lib/postgresql/data/
sudo systemctl start postgresql
```

## Testing Schedule

### Backup Testing Matrix

| Test Type | Frequency | Responsible | Success Criteria |
|-----------|-----------|-------------|------------------|
| Backup Creation | Daily | Automated | Backup file created, verified |
| Backup Verification | Weekly | Automated | Test restore successful |
| Full Restore Test | Monthly | DBA | Database restored, data validated |
| PITR Test | Quarterly | DBA | Point-in-time recovery successful |
| Disaster Recovery Drill | Annually | Team | Complete DR procedure successful |

### Testing Procedures

#### Weekly Automated Testing

```bash
# Add to crontab
# Sunday at 3:00 AM - verify latest backup
0 3 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh -v 2>&1 | logger -t llm-verify
```

#### Monthly Manual Testing

1. **Preparation**
   - Identify a recent backup to test
   - Prepare test environment
   - Notify team of testing window

2. **Execution**
   ```bash
   # Restore to test database
   ./scripts/restore.sh -t llm_observatory_test_$(date +%Y%m%d) backup.sql.gz

   # Verify data integrity
   PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory_test_YYYYMMDD << EOF
   -- Check table counts
   SELECT schemaname, tablename, n_live_tup
   FROM pg_stat_user_tables
   ORDER BY n_live_tup DESC;

   -- Verify specific data
   SELECT COUNT(*) FROM your_important_table;

   -- Check constraints
   SELECT COUNT(*) FROM information_schema.table_constraints;
   EOF
   ```

3. **Documentation**
   - Record test results
   - Document any issues
   - Update procedures if needed

#### Quarterly PITR Testing

```bash
# Create test scenario
# 1. Note current timestamp
BEFORE_TIME=$(date -Iseconds)

# 2. Make a change
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory -c \
  "CREATE TABLE pitr_test (id serial, created timestamp default now());"

# 3. Wait 5 minutes for WAL archiving

# 4. Perform PITR to before the change
# Follow PITR procedures above using $BEFORE_TIME

# 5. Verify the table doesn't exist in recovered database
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory -c "\dt pitr_test"
# Should return "Did not find any relation"
```

## Disaster Recovery Scenarios

### Scenario 1: Database Corruption

**Symptoms**: Application errors, data inconsistencies

**Recovery Steps**:

1. **Assess the Damage**
   ```bash
   # Check database integrity
   docker exec llm-observatory-db psql -U postgres -d llm_observatory -c "VACUUM FULL VERBOSE;"
   ```

2. **Stop Application Services**
   ```bash
   docker-compose stop grafana
   ```

3. **Restore from Latest Backup**
   ```bash
   ./scripts/restore.sh --drop-existing -y backups/daily/latest.sql.gz
   ```

4. **Verify and Restart**
   ```bash
   # Verify restore
   PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory -c "SELECT COUNT(*) FROM pg_tables;"

   # Restart services
   docker-compose start grafana
   ```

### Scenario 2: Accidental Data Deletion

**Symptoms**: Critical data missing, reported by users

**Recovery Steps**:

1. **Identify Deletion Time**
   ```bash
   # Check logs for deletion
   docker-compose logs timescaledb | grep DELETE

   # Note timestamp: 2024-01-15 14:25:30
   RECOVERY_TARGET="2024-01-15 14:25:00"
   ```

2. **Perform Point-in-Time Recovery**
   ```bash
   # Restore to 5 minutes before deletion
   # Follow PITR procedures with $RECOVERY_TARGET
   ```

3. **Extract Deleted Data**
   ```bash
   # If you want to keep current data and only restore deleted records:
   # 1. Restore to temporary database
   ./scripts/restore.sh -t llm_observatory_recovery backup.sql.gz

   # 2. Extract deleted data
   pg_dump -h localhost -U postgres -d llm_observatory_recovery -t deleted_table --data-only > deleted_data.sql

   # 3. Import to production
   psql -h localhost -U postgres -d llm_observatory -f deleted_data.sql
   ```

### Scenario 3: Hardware Failure

**Symptoms**: Database server unresponsive, disk failure

**Recovery Steps**:

1. **Provision New Hardware**
   - Launch new instance/server
   - Install PostgreSQL and dependencies
   - Configure network access

2. **Retrieve Backup from S3**
   ```bash
   # List available backups
   aws s3 ls s3://my-backup-bucket/backups/ --recursive | sort

   # Download latest backup
   ./scripts/restore.sh -s -b my-backup-bucket backups/latest.sql.gz
   ```

3. **Restore Database**
   ```bash
   # Restore to new server
   ./scripts/restore.sh -y downloaded_backup.sql.gz
   ```

4. **Update DNS/Load Balancer**
   - Point application to new database server
   - Update connection strings
   - Test connectivity

### Scenario 4: Regional Disaster

**Symptoms**: Entire AWS region unavailable

**Recovery Steps**:

1. **Activate DR Site**
   - Launch infrastructure in backup region
   - Deploy application stack

2. **Cross-Region Restore**
   ```bash
   # S3 backups are available in all regions
   # Restore from replicated S3 bucket
   ./scripts/restore.sh -s -b my-backup-bucket-dr -r us-west-2 backups/latest.sql.gz
   ```

3. **Restore WAL Archives**
   ```bash
   # Download WAL files from S3
   aws s3 sync s3://my-wal-bucket/wal_archive/ /var/lib/postgresql/wal_archive/ --region us-west-2

   # Perform PITR
   # Follow PITR procedures
   ```

4. **Update Global DNS**
   - Point DNS to DR region
   - Update Route53 or equivalent
   - Monitor for issues

## Monitoring and Alerting

### Backup Monitoring

#### Check Backup Success

```bash
#!/bin/bash
# check_backup_status.sh

BACKUP_DIR="/workspaces/llm-observatory/backups/daily"
MAX_AGE_HOURS=26  # Alert if no backup in 26 hours

# Find latest backup
LATEST_BACKUP=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)

if [[ -z "$LATEST_BACKUP" ]]; then
    echo "CRITICAL: No backups found in $BACKUP_DIR"
    exit 2
fi

# Check age
BACKUP_AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y "$LATEST_BACKUP") ))
BACKUP_AGE_HOURS=$(( BACKUP_AGE_SECONDS / 3600 ))

if [[ $BACKUP_AGE_HOURS -gt $MAX_AGE_HOURS ]]; then
    echo "WARNING: Latest backup is $BACKUP_AGE_HOURS hours old"
    exit 1
else
    echo "OK: Latest backup is $BACKUP_AGE_HOURS hours old"
    exit 0
fi
```

#### Monitor S3 Backups

```bash
#!/bin/bash
# check_s3_backup.sh

BUCKET="my-backup-bucket"
PREFIX="backups/"
MAX_AGE_HOURS=26

# Get latest S3 backup
LATEST=$(aws s3 ls "s3://${BUCKET}/${PREFIX}" --recursive | sort | tail -1)

if [[ -z "$LATEST" ]]; then
    echo "CRITICAL: No backups found in S3"
    exit 2
fi

# Extract timestamp and check age
BACKUP_DATE=$(echo "$LATEST" | awk '{print $1" "$2}')
BACKUP_TIMESTAMP=$(date -d "$BACKUP_DATE" +%s)
CURRENT_TIMESTAMP=$(date +%s)
AGE_HOURS=$(( (CURRENT_TIMESTAMP - BACKUP_TIMESTAMP) / 3600 ))

if [[ $AGE_HOURS -gt $MAX_AGE_HOURS ]]; then
    echo "WARNING: Latest S3 backup is $AGE_HOURS hours old"
    exit 1
else
    echo "OK: Latest S3 backup is $AGE_HOURS hours old"
    exit 0
fi
```

#### Monitor WAL Archiving

```bash
# Check PostgreSQL WAL archiving status
docker exec llm-observatory-db psql -U postgres -c "SELECT * FROM pg_stat_archiver;"

# Expected output:
#  archived_count | last_archived_wal | last_archived_time | failed_count | ...
```

### Alerting Configuration

#### Prometheus Metrics

```yaml
# prometheus-alerts.yml
groups:
  - name: backup_alerts
    interval: 5m
    rules:
      - alert: BackupTooOld
        expr: (time() - backup_last_success_timestamp) > 86400
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Database backup is older than 24 hours"
          description: "Last successful backup was {{ $value }}s ago"

      - alert: BackupFailed
        expr: backup_last_status != 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Database backup failed"
          description: "Last backup attempt failed with status {{ $value }}"

      - alert: WALArchivingFailed
        expr: pg_stat_archiver_failed_count > 0
        for: 15m
        labels:
          severity: critical
        annotations:
          summary: "WAL archiving is failing"
          description: "{{ $value }} WAL archiving failures detected"
```

#### Email Notifications

```bash
# Add to backup scripts
send_alert() {
    local subject="$1"
    local message="$2"

    echo "$message" | mail -s "$subject" admin@example.com
}

# Usage in scripts
if ! ./scripts/backup.sh; then
    send_alert "Backup Failed" "Database backup failed at $(date)"
fi
```

## Troubleshooting

### Common Issues

#### 1. Backup Script Fails with "Permission Denied"

**Problem**: Script cannot access backup directory

**Solution**:
```bash
# Fix permissions
sudo chown -R $USER:$USER /workspaces/llm-observatory/backups
chmod 755 /workspaces/llm-observatory/backups

# Make scripts executable
chmod +x /workspaces/llm-observatory/scripts/*.sh
```

#### 2. pg_dump: Connection Refused

**Problem**: Cannot connect to database

**Solution**:
```bash
# Check if PostgreSQL is running
docker-compose ps timescaledb

# Check database logs
docker-compose logs timescaledb

# Verify connection settings in .env
cat .env | grep DB_

# Test connection manually
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory -c "SELECT 1"
```

#### 3. S3 Upload Fails

**Problem**: Cannot upload to S3

**Solution**:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://my-backup-bucket/

# Check S3 bucket policy
aws s3api get-bucket-policy --bucket my-backup-bucket

# Verify IAM permissions
aws iam get-user-policy --user-name my-user --policy-name BackupPolicy
```

#### 4. WAL Archiving Not Working

**Problem**: WAL files not being archived

**Solution**:
```bash
# Check PostgreSQL configuration
docker exec llm-observatory-db psql -U postgres -c "SHOW archive_mode;"
docker exec llm-observatory-db psql -U postgres -c "SHOW archive_command;"

# Check archive script permissions
ls -l /workspaces/llm-observatory/scripts/archive_wal.sh

# Check archive directory
ls -lh /var/lib/postgresql/wal_archive/

# Check logs
tail -f /var/lib/postgresql/wal_archive/archive.log

# Force WAL switch to test
docker exec llm-observatory-db psql -U postgres -c "SELECT pg_switch_wal();"
```

#### 5. Restore Fails with "Database Already Exists"

**Problem**: Target database already exists

**Solution**:
```bash
# Use --drop-existing flag
./scripts/restore.sh --drop-existing backup.sql.gz

# Or restore to different database
./scripts/restore.sh -t llm_observatory_new backup.sql.gz

# Or manually drop database first
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -c "DROP DATABASE llm_observatory;"
```

#### 6. Backup File Corrupted

**Problem**: Backup verification fails

**Solution**:
```bash
# Test gzip integrity
gzip -t backup.sql.gz

# If corrupted, try alternative backup
ls -lh /workspaces/llm-observatory/backups/daily/

# Download from S3 if local backup corrupted
aws s3 cp s3://my-backup-bucket/backups/latest.sql.gz ./backup_from_s3.sql.gz

# Verify S3 backup
./scripts/verify_backup.sh backup_from_s3.sql.gz
```

### Getting Help

- **Documentation**: Check this guide and script help messages (`--help`)
- **Logs**: Review backup logs in `/workspaces/llm-observatory/backups/logs/`
- **Database Logs**: `docker-compose logs timescaledb`
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **TimescaleDB Documentation**: https://docs.timescale.com/

### Emergency Contacts

In case of disaster:

1. **Primary DBA**: [Contact Info]
2. **Backup DBA**: [Contact Info]
3. **DevOps Lead**: [Contact Info]
4. **AWS Support**: [Support Plan Info]

---

**Last Updated**: 2024-01-15
**Version**: 1.0
**Maintainer**: LLM Observatory Team

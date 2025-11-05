# Backup and Restore Scripts

## Overview

This directory contains production-ready scripts for backing up and restoring the LLM Observatory database. The scripts support local backups, S3 integration, point-in-time recovery, and automated verification.

## Scripts

| Script | Description | Use Case |
|--------|-------------|----------|
| `backup.sh` | Local database backup | Daily backups to local storage |
| `backup_to_s3.sh` | S3 database backup | Production offsite backups |
| `restore.sh` | Database restore | Recovery operations |
| `verify_backup.sh` | Backup verification | Test backup integrity |
| `archive_wal.sh` | WAL archiving | Point-in-time recovery |
| `cron-examples.sh` | Cron job examples | Automated scheduling |

## Quick Start

### 1. Setup

```bash
# Make scripts executable
chmod +x /workspaces/llm-observatory/scripts/*.sh

# Configure environment variables in .env
cp .env.example .env
# Edit .env with your database credentials

# Create backup directory
mkdir -p /workspaces/llm-observatory/backups
```

### 2. Create Your First Backup

```bash
# Local backup
./scripts/backup.sh -v

# S3 backup (requires AWS credentials)
./scripts/backup_to_s3.sh -b my-backup-bucket -e
```

### 3. Verify Backup

```bash
# Verify the latest backup
./scripts/verify_backup.sh -v
```

### 4. Restore Database

```bash
# Restore from local backup
./scripts/restore.sh backups/daily/llm_observatory_20240101_120000.sql.gz

# Restore from S3
./scripts/restore.sh -s -b my-bucket backups/latest.sql.gz
```

## Detailed Usage

### backup.sh - Local Backup

Creates a compressed backup of the database to local storage.

**Basic Usage:**
```bash
./scripts/backup.sh [OPTIONS]
```

**Options:**
- `-c, --config FILE`: Path to config file (default: .env)
- `-d, --dir DIR`: Backup directory (default: ./backups)
- `-r, --retention DAYS`: Retention period in days (default: 30)
- `-v, --verbose`: Verbose output
- `-h, --help`: Show help message

**Examples:**
```bash
# Default backup (30-day retention)
./scripts/backup.sh

# Custom retention period
./scripts/backup.sh -r 60

# Custom backup directory
./scripts/backup.sh -d /mnt/backups

# Verbose output
./scripts/backup.sh -v
```

**Output:**
- Compressed SQL dump: `backups/daily/llm_observatory_YYYYMMDD_HHMMSS.sql.gz`
- Metadata file: `backups/daily/llm_observatory_YYYYMMDD_HHMMSS.sql.meta`
- Log file: `backups/logs/backup_YYYYMMDD_HHMMSS.log`

### backup_to_s3.sh - S3 Backup

Creates a database backup and uploads it to AWS S3.

**Basic Usage:**
```bash
./scripts/backup_to_s3.sh -b BUCKET [OPTIONS]
```

**Options:**
- `-c, --config FILE`: Path to config file (default: .env)
- `-b, --bucket BUCKET`: S3 bucket name (required)
- `-p, --prefix PREFIX`: S3 prefix/path (default: backups/)
- `-e, --encrypt`: Enable S3 server-side encryption
- `-k, --kms-key KEY`: KMS key ID for encryption
- `-r, --region REGION`: AWS region (default: us-east-1)
- `-s, --storage CLASS`: S3 storage class (default: STANDARD_IA)
- `-v, --verbose`: Verbose output

**Storage Classes:**
- `STANDARD`: Standard storage (frequent access)
- `STANDARD_IA`: Infrequent access (recommended for backups)
- `INTELLIGENT_TIERING`: Automatic cost optimization
- `GLACIER_IR`: Glacier Instant Retrieval
- `GLACIER`: Glacier (3-5 hour retrieval)
- `DEEP_ARCHIVE`: Deep Archive (12 hour retrieval, cheapest)

**Examples:**
```bash
# Basic S3 backup
./scripts/backup_to_s3.sh -b my-backup-bucket

# With encryption
./scripts/backup_to_s3.sh -b my-backup-bucket -e

# With KMS encryption
./scripts/backup_to_s3.sh -b my-backup-bucket -k alias/my-kms-key

# Glacier storage
./scripts/backup_to_s3.sh -b my-backup-bucket -s GLACIER_IR

# Custom prefix
./scripts/backup_to_s3.sh -b my-backup-bucket -p production/db/
```

**Prerequisites:**
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
```

### restore.sh - Database Restore

Restores a PostgreSQL/TimescaleDB database from a backup file.

**Basic Usage:**
```bash
./scripts/restore.sh [OPTIONS] BACKUP_FILE
```

**Options:**
- `-c, --config FILE`: Path to config file (default: .env)
- `-d, --database NAME`: Target database name
- `-t, --target-db NAME`: Create new database instead of overwriting
- `-s, --from-s3`: Download backup from S3
- `-b, --bucket BUCKET`: S3 bucket name (required if --from-s3)
- `-r, --region REGION`: AWS region (default: us-east-1)
- `--no-verify`: Skip backup verification
- `--drop-existing`: Drop existing database before restore
- `--dry-run`: Show what would be done
- `-v, --verbose`: Verbose output
- `-y, --yes`: Skip confirmation prompts

**Examples:**
```bash
# Restore from local backup
./scripts/restore.sh backups/daily/llm_observatory_20240101_120000.sql.gz

# Restore from S3
./scripts/restore.sh -s -b my-bucket backups/llm_observatory_20240101_120000.sql.gz

# Restore to a new database (for testing)
./scripts/restore.sh -t llm_observatory_test backup.sql.gz

# Drop and restore
./scripts/restore.sh --drop-existing backup.sql.gz

# Dry run (preview)
./scripts/restore.sh --dry-run backup.sql.gz

# Skip confirmations (automated)
./scripts/restore.sh -y backup.sql.gz
```

**Warning:** Restore operations can overwrite existing data. Always:
1. Verify the backup file before restoring
2. Create a backup of the current state if possible
3. Use `--dry-run` to preview the operation
4. Consider using `-t` to restore to a new database first

### verify_backup.sh - Backup Verification

Verifies backup integrity by restoring to a test database.

**Basic Usage:**
```bash
./scripts/verify_backup.sh [OPTIONS] [BACKUP_FILE]
```

**Options:**
- `-c, --config FILE`: Path to config file (default: .env)
- `-s, --from-s3`: Download backup from S3
- `-b, --bucket BUCKET`: S3 bucket name
- `-r, --region REGION`: AWS region
- `--test-db NAME`: Test database name (default: llm_observatory_test)
- `--keep-test-db`: Keep test database after verification
- `--skip-data-check`: Skip data integrity checks
- `-v, --verbose`: Verbose output

**Examples:**
```bash
# Verify latest backup
./scripts/verify_backup.sh

# Verify specific backup
./scripts/verify_backup.sh backups/daily/llm_observatory_20240101_120000.sql.gz

# Verify S3 backup
./scripts/verify_backup.sh -s -b my-bucket backups/latest.sql.gz

# Keep test database for inspection
./scripts/verify_backup.sh --keep-test-db -v
```

**What It Checks:**
- Backup file format and compression
- SQL dump validity
- Database structure (tables, views, functions)
- Data integrity (row counts, constraints)
- TimescaleDB extensions

### archive_wal.sh - WAL Archiving

Archives PostgreSQL Write-Ahead Log files for point-in-time recovery.

**Note:** This script is called automatically by PostgreSQL, not manually.

**PostgreSQL Configuration:**
```conf
# postgresql.conf
wal_level = replica
archive_mode = on
archive_command = '/path/to/archive_wal.sh %p %f'
archive_timeout = 300
```

**Environment Variables:**
- `WAL_ARCHIVE_DIR`: Local archive directory (default: /var/lib/postgresql/wal_archive)
- `WAL_S3_BUCKET`: S3 bucket for WAL archives
- `WAL_S3_PREFIX`: S3 prefix (default: wal_archive/)
- `WAL_RETENTION_DAYS`: Retention period (default: 7)

## Automated Backups

### Using Cron

See `cron-examples.sh` for detailed cron job examples.

**Recommended Schedule:**

```bash
# Edit crontab
crontab -e

# Add these entries:

# Daily backup at 2:00 AM
0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -v 2>&1 | logger -t llm-backup

# Daily S3 backup at 3:00 AM
0 3 * * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b prod-backups -e -v 2>&1 | logger -t llm-s3-backup

# Weekly verification on Sunday at 4:00 AM
0 4 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh -v 2>&1 | logger -t llm-verify
```

### Using Docker Compose

Run on-demand backups using the backup service:

```bash
# Run backup service
docker-compose --profile backup run --rm backup

# Schedule with cron
0 2 * * * cd /workspaces/llm-observatory && docker-compose --profile backup run --rm backup 2>&1 | logger -t llm-docker-backup
```

### Using Systemd Timers

Create systemd timer and service files:

**`/etc/systemd/system/llm-backup.service`:**
```ini
[Unit]
Description=LLM Observatory Database Backup
After=network.target

[Service]
Type=oneshot
User=postgres
ExecStart=/workspaces/llm-observatory/scripts/backup.sh -v
StandardOutput=journal
StandardError=journal
```

**`/etc/systemd/system/llm-backup.timer`:**
```ini
[Unit]
Description=Daily LLM Observatory Backup
Requires=llm-backup.service

[Timer]
OnCalendar=daily
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:
```bash
sudo systemctl enable llm-backup.timer
sudo systemctl start llm-backup.timer
sudo systemctl status llm-backup.timer
```

## Backup Strategy

### Multi-Tier Approach

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

### Implementation

```bash
# 1. Hourly local backups (1 day retention)
0 * * * * /workspaces/llm-observatory/scripts/backup.sh -d /var/backups/llm/hourly -r 1 -v 2>&1 | logger -t llm-hourly

# 2. Daily local backups (30 days retention)
0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -d /var/backups/llm/daily -r 30 -v 2>&1 | logger -t llm-daily

# 3. Daily S3 backup (Standard-IA)
0 3 * * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b prod-backups -p daily/ -e -v 2>&1 | logger -t llm-s3-daily

# 4. Weekly verification
0 4 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh -v 2>&1 | logger -t llm-verify

# 5. Monthly archive to Glacier
0 5 1 * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b prod-archives -s GLACIER -p monthly/$(date +\%Y-\%m)/ -e -v 2>&1 | logger -t llm-monthly
```

## Monitoring

### Check Backup Status

```bash
# Check if backup ran today
find /workspaces/llm-observatory/backups/daily -name "*.sql.gz" -mtime -1

# Check S3 backups
aws s3 ls s3://my-backup-bucket/backups/ --recursive | tail -5

# Check WAL archiving status
docker exec llm-observatory-db psql -U postgres -c "SELECT * FROM pg_stat_archiver;"
```

### Monitoring Script

```bash
#!/bin/bash
# check_backup_status.sh

BACKUP_DIR="/workspaces/llm-observatory/backups/daily"
MAX_AGE_HOURS=26

LATEST_BACKUP=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)

if [[ -z "$LATEST_BACKUP" ]]; then
    echo "CRITICAL: No backups found"
    exit 2
fi

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

### Alerting

```bash
# Email notification on failure
0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -v || echo "Backup failed" | mail -s "Backup Alert" admin@example.com

# Slack notification (using webhook)
0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -v && curl -X POST -H 'Content-type: application/json' --data '{"text":"Backup successful"}' https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## Point-in-Time Recovery

See [docs/disaster-recovery.md](../docs/disaster-recovery.md) for detailed PITR setup and procedures.

**Quick Setup:**

1. **Configure PostgreSQL:**
```conf
wal_level = replica
archive_mode = on
archive_command = '/workspaces/llm-observatory/scripts/archive_wal.sh %p %f'
```

2. **Create Base Backup:**
```bash
./scripts/backup.sh -v
```

3. **Perform Recovery:**
```bash
# Restore to specific timestamp
./scripts/restore.sh backup.sql.gz
# Then configure recovery.conf with target time
```

## Disaster Recovery

### RTO/RPO Targets

| Environment | RTO | RPO |
|-------------|-----|-----|
| Production  | < 4 hours | < 15 minutes |
| Staging     | < 8 hours | < 1 day |
| Development | < 24 hours | < 7 days |

### Recovery Procedures

1. **Database Corruption**
   - Restore from latest backup
   - Verify data integrity
   - Restart services

2. **Accidental Deletion**
   - Use point-in-time recovery
   - Restore to before deletion
   - Extract and reimport data

3. **Hardware Failure**
   - Provision new server
   - Restore from S3
   - Update DNS/connections

4. **Regional Disaster**
   - Activate DR site
   - Cross-region restore
   - Update global DNS

## Troubleshooting

### Common Issues

**Backup Fails with "Permission Denied"**
```bash
# Fix permissions
chmod +x /workspaces/llm-observatory/scripts/*.sh
chown -R $USER:$USER /workspaces/llm-observatory/backups
```

**Cannot Connect to Database**
```bash
# Test connection
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory -c "SELECT 1"

# Check Docker container
docker-compose ps timescaledb
docker-compose logs timescaledb
```

**S3 Upload Fails**
```bash
# Test AWS credentials
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://my-backup-bucket/
```

**WAL Archiving Not Working**
```bash
# Check configuration
docker exec llm-observatory-db psql -U postgres -c "SHOW archive_mode;"
docker exec llm-observatory-db psql -U postgres -c "SHOW archive_command;"

# Check logs
tail -f /var/lib/postgresql/wal_archive/archive.log
```

## Best Practices

1. **Test Backups Regularly**
   - Weekly automated verification
   - Monthly manual restore tests
   - Quarterly DR drills

2. **Use Multiple Storage Tiers**
   - Local for fast recovery
   - S3 for offsite protection
   - Glacier for long-term archival

3. **Monitor Backup Success**
   - Set up alerts for failures
   - Track backup age
   - Monitor storage usage

4. **Document Procedures**
   - Keep runbooks updated
   - Document restore steps
   - Record DR test results

5. **Secure Backups**
   - Enable encryption at rest
   - Use IAM roles, not access keys
   - Restrict access with bucket policies
   - Encrypt sensitive configuration

6. **Automate Everything**
   - Use cron or systemd timers
   - Implement automatic verification
   - Set up monitoring and alerting

## Additional Resources

- **Main Documentation**: [docs/disaster-recovery.md](../docs/disaster-recovery.md)
- **PostgreSQL Backup**: https://www.postgresql.org/docs/current/backup.html
- **TimescaleDB Backup**: https://docs.timescale.com/use-timescale/latest/backup-restore/
- **AWS S3**: https://docs.aws.amazon.com/s3/
- **pg_dump**: https://www.postgresql.org/docs/current/app-pgdump.html

## Support

For issues or questions:
1. Check this README and disaster-recovery.md
2. Review script logs
3. Test with `--dry-run` and `--verbose` flags
4. Consult PostgreSQL documentation

---

**Last Updated**: 2024-01-15
**Version**: 1.0
**Maintainer**: LLM Observatory Team

# Backup and Restore Quick Reference

## Quick Start Commands

### Create Backup

```bash
# Local backup (simplest)
./scripts/backup.sh

# Local backup with verbose output
./scripts/backup.sh -v

# S3 backup (production)
./scripts/backup_to_s3.sh -b my-backup-bucket -e
```

### Restore Database

```bash
# Restore from local backup
./scripts/restore.sh backups/daily/llm_observatory_20240101_120000.sql.gz

# Restore from S3
./scripts/restore.sh -s -b my-bucket backups/latest.sql.gz

# Restore to test database first (safe)
./scripts/restore.sh -t llm_observatory_test backup.sql.gz
```

### Verify Backup

```bash
# Verify latest backup
./scripts/verify_backup.sh

# Verify specific backup
./scripts/verify_backup.sh backups/daily/backup.sql.gz
```

## Common Operations

### List Backups

```bash
# List local backups
ls -lht /workspaces/llm-observatory/backups/daily/

# List S3 backups
aws s3 ls s3://my-backup-bucket/backups/ --recursive
```

### Check Backup Age

```bash
# Find latest local backup
find /workspaces/llm-observatory/backups/daily -name "*.sql.gz" -printf '%T@ %p\n' | sort -nr | head -1

# Check S3 backup age
aws s3 ls s3://my-backup-bucket/backups/ --recursive | sort | tail -1
```

### Manual Database Backup (Alternative)

```bash
# Using pg_dump directly
PGPASSWORD=$DB_PASSWORD pg_dump \
  -h localhost \
  -U postgres \
  -d llm_observatory \
  --format=plain \
  --no-owner \
  --no-acl \
  --clean \
  --if-exists | gzip -9 > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Manual Database Restore (Alternative)

```bash
# Extract and restore
gunzip -c backup.sql.gz | PGPASSWORD=$DB_PASSWORD psql \
  -h localhost \
  -U postgres \
  -d llm_observatory
```

## Cron Schedule Examples

```bash
# Edit crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /workspaces/llm-observatory/scripts/backup.sh -v 2>&1 | logger -t llm-backup

# Daily S3 backup at 3 AM
0 3 * * * /workspaces/llm-observatory/scripts/backup_to_s3.sh -b prod-backups -e -v 2>&1 | logger -t llm-s3-backup

# Weekly verification on Sunday at 4 AM
0 4 * * 0 /workspaces/llm-observatory/scripts/verify_backup.sh -v 2>&1 | logger -t llm-verify
```

## Docker Compose Commands

```bash
# Run backup using Docker Compose
docker-compose --profile backup run --rm backup

# Schedule with cron
0 2 * * * cd /workspaces/llm-observatory && docker-compose --profile backup run --rm backup
```

## Emergency Recovery

### Scenario 1: Database Corrupted

```bash
# 1. Stop services
docker-compose stop grafana

# 2. Find latest backup
ls -lt /workspaces/llm-observatory/backups/daily/ | head -5

# 3. Restore
./scripts/restore.sh --drop-existing -y backups/daily/latest.sql.gz

# 4. Restart services
docker-compose start grafana
```

### Scenario 2: Accidental Data Deletion

```bash
# 1. Stop writes to database
docker-compose stop grafana

# 2. Restore to test database
./scripts/restore.sh -t llm_observatory_recovery backups/daily/latest.sql.gz

# 3. Extract deleted data
pg_dump -h localhost -U postgres -d llm_observatory_recovery \
  -t deleted_table --data-only > deleted_data.sql

# 4. Import to production
psql -h localhost -U postgres -d llm_observatory -f deleted_data.sql

# 5. Restart services
docker-compose start grafana
```

### Scenario 3: Need to Restore from S3

```bash
# 1. List available S3 backups
aws s3 ls s3://my-backup-bucket/backups/ --recursive | sort

# 2. Download and restore
./scripts/restore.sh -s -b my-backup-bucket -y backups/latest.sql.gz
```

## Point-in-Time Recovery (PITR)

### Prerequisites

WAL archiving must be enabled. Check:

```bash
docker exec llm-observatory-db psql -U postgres -c "SHOW archive_mode;"
docker exec llm-observatory-db psql -U postgres -c "SHOW archive_command;"
```

### Perform PITR

```bash
# 1. Note the timestamp to recover to
RECOVERY_TARGET="2024-01-15 14:25:00"

# 2. Stop database
docker-compose stop timescaledb

# 3. Restore base backup
./scripts/restore.sh backups/daily/base_backup.sql.gz

# 4. Create recovery configuration
cat > recovery.conf << EOF
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '$RECOVERY_TARGET'
recovery_target_action = 'promote'
EOF

# 5. Start database in recovery mode
docker-compose start timescaledb

# 6. Monitor logs
docker-compose logs -f timescaledb
```

## Monitoring

### Check Backup Status

```bash
# Check if backup ran today
if [ $(find /workspaces/llm-observatory/backups/daily -name "*.sql.gz" -mtime -1 | wc -l) -eq 0 ]; then
  echo "WARNING: No backup in last 24 hours"
else
  echo "OK: Backup found"
fi
```

### Check WAL Archiving

```bash
# Check archiving status
docker exec llm-observatory-db psql -U postgres -c "SELECT * FROM pg_stat_archiver;"

# Check WAL files
ls -lht /var/lib/postgresql/wal_archive/ | head -10
```

### Check S3 Storage

```bash
# Check S3 bucket size
aws s3 ls s3://my-backup-bucket --recursive --summarize | grep "Total Size"

# Count backups in S3
aws s3 ls s3://my-backup-bucket/backups/ --recursive | wc -l
```

## Troubleshooting

### Backup Script Fails

```bash
# Check permissions
ls -l /workspaces/llm-observatory/scripts/backup.sh

# Fix permissions
chmod +x /workspaces/llm-observatory/scripts/*.sh

# Test database connection
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory -c "SELECT 1"

# Check disk space
df -h /workspaces/llm-observatory/backups
```

### Restore Fails

```bash
# Check if backup file exists
ls -lh backup.sql.gz

# Test gzip integrity
gzip -t backup.sql.gz

# Check available disk space
df -h

# Drop existing database manually
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -c "DROP DATABASE llm_observatory;"
```

### S3 Issues

```bash
# Test AWS credentials
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://my-backup-bucket/

# Check IAM permissions
aws iam get-user-policy --user-name my-user --policy-name BackupPolicy
```

## Configuration

### Environment Variables (.env)

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=llm_observatory
DB_USER=postgres
DB_PASSWORD=your_password

# Backup
BACKUP_RETENTION=30
S3_BACKUP_BUCKET=my-backup-bucket
S3_BACKUP_PREFIX=backups/
S3_STORAGE_CLASS=STANDARD_IA

# WAL
WAL_ARCHIVE_DIR=/var/lib/postgresql/wal_archive
WAL_S3_BUCKET=my-wal-bucket
WAL_RETENTION_DAYS=7

# AWS
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
```

### S3 Lifecycle Policy

```json
{
  "Rules": [
    {
      "Id": "BackupLifecycle",
      "Status": "Enabled",
      "Filter": {"Prefix": "backups/"},
      "Transitions": [
        {"Days": 30, "StorageClass": "STANDARD_IA"},
        {"Days": 90, "StorageClass": "GLACIER_IR"},
        {"Days": 365, "StorageClass": "DEEP_ARCHIVE"}
      ],
      "Expiration": {"Days": 2555}
    }
  ]
}
```

Apply:
```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-backup-bucket \
  --lifecycle-configuration file://lifecycle-policy.json
```

## Testing

### Test Backup Creation

```bash
# Create test backup
./scripts/backup.sh -v

# Verify it was created
ls -lh /workspaces/llm-observatory/backups/daily/ | head -1
```

### Test Backup Verification

```bash
# Verify backup
./scripts/verify_backup.sh -v

# Check for success message
echo $?  # Should be 0 for success
```

### Test Restore Process

```bash
# Restore to test database
./scripts/restore.sh -t llm_observatory_test backups/daily/latest.sql.gz

# Verify test database
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d llm_observatory_test -c "\dt+"

# Cleanup test database
PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -c "DROP DATABASE llm_observatory_test;"
```

## Script Options Reference

### backup.sh

| Option | Description | Default |
|--------|-------------|---------|
| `-c FILE` | Config file path | `.env` |
| `-d DIR` | Backup directory | `./backups` |
| `-r DAYS` | Retention period | `30` |
| `-v` | Verbose output | Off |
| `-h` | Help message | - |

### backup_to_s3.sh

| Option | Description | Default |
|--------|-------------|---------|
| `-b BUCKET` | S3 bucket name | Required |
| `-p PREFIX` | S3 prefix | `backups/` |
| `-e` | Enable encryption | Off |
| `-k KEY` | KMS key ID | None |
| `-r REGION` | AWS region | `us-east-1` |
| `-s CLASS` | Storage class | `STANDARD_IA` |

### restore.sh

| Option | Description | Default |
|--------|-------------|---------|
| `-t NAME` | Target database | Current DB |
| `-s` | From S3 | Off |
| `-b BUCKET` | S3 bucket | - |
| `--drop-existing` | Drop first | Off |
| `--dry-run` | Preview only | Off |
| `-y` | Skip prompts | Off |

### verify_backup.sh

| Option | Description | Default |
|--------|-------------|---------|
| `--test-db NAME` | Test DB name | `llm_observatory_test` |
| `--keep-test-db` | Keep test DB | Off |
| `--skip-data-check` | Skip data checks | Off |
| `-s` | From S3 | Off |

## Exit Codes

All scripts use these exit codes:

- `0` - Success
- `1` - General error
- `2` - Configuration error
- `3` - Backup/verification failed
- `4` - Restore/upload failed
- `5` - User cancelled / Data check failed

## Additional Resources

- **Full Documentation**: [docs/disaster-recovery.md](disaster-recovery.md)
- **Script README**: [scripts/README.md](../scripts/README.md)
- **PostgreSQL Docs**: https://www.postgresql.org/docs/current/backup.html
- **TimescaleDB Docs**: https://docs.timescale.com/use-timescale/latest/backup-restore/

---

**Last Updated**: 2024-01-15
**Quick Reference Version**: 1.0

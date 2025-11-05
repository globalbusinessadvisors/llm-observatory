# CLI Tools Documentation

## Overview

The LLM Observatory CLI Tools container provides a comprehensive suite of database management and utility operations. It includes tools for migrations, backups, seeding, and administrative tasks.

## Features

- **Database Migrations**: Run, rollback, and manage database schema changes using sqlx-cli
- **Data Seeding**: Populate database with initial or test data
- **Backup & Restore**: Create and restore database backups with compression and S3 support
- **Database Reset**: Safely reset database to initial state
- **Interactive Shell**: Access PostgreSQL shell for manual operations
- **Health Checks**: Verify database connectivity and status

## Architecture

### Container Components

```
llm-observatory-cli
├── sqlx-cli (v0.7.3)          # Database migration tool
├── postgresql-client          # PostgreSQL command-line tools
├── AWS CLI                    # S3 backup integration
└── Custom Scripts             # Utility operations
    ├── cli-entrypoint.sh     # Main command router
    ├── run-migrations.sh     # Migration execution
    ├── seed-data.sh          # Data seeding
    ├── reset-database.sh     # Database reset
    ├── backup-database.sh    # Backup creation
    └── restore-database.sh   # Backup restoration
```

### Volume Mounts

- `/app/migrations` → `./crates/storage/migrations` (read-only)
- `/app/scripts` → `./docker/scripts/utilities` (read-only)
- `/app/backups` → Docker volume `backup_data`
- `/app/data` → `./docker/data` (read-only)

## Quick Start

### Prerequisites

1. Database must be running:
   ```bash
   docker compose up -d timescaledb
   ```

2. Build the CLI container:
   ```bash
   docker compose --profile tools build cli
   ```

### Basic Usage

Run any CLI command using:
```bash
docker compose --profile tools run --rm cli <command> [arguments]
```

## Commands Reference

### Migration Commands

#### `migrate`
Run all pending database migrations.

```bash
docker compose --profile tools run --rm cli migrate
```

**What it does:**
- Creates database if it doesn't exist
- Executes all pending migrations in order
- Records migration history
- Verifies successful execution

**Output:**
```
[INFO] Waiting for database to be ready...
[SUCCESS] Database is ready
[INFO] Running database migrations...
[SUCCESS] Migrations completed successfully
```

#### `migrate-status`
Check the current migration status.

```bash
docker compose --profile tools run --rm cli migrate-status
```

**Shows:**
- Applied migrations
- Pending migrations
- Migration checksums
- Last migration date

#### `migrate-rollback`
Rollback the most recent migration.

```bash
docker compose --profile tools run --rm cli migrate-rollback
```

**Warning:** This is a destructive operation. Only the last migration can be rolled back.

### Data Management Commands

#### `seed`
Populate database with initial data.

```bash
docker compose --profile tools run --rm cli seed
```

**What it seeds:**
- Sample projects with API keys
- LLM model definitions (GPT-4, Claude, Gemini, etc.)
- Default configurations
- Test data (development/test environments only)

**Environment-specific:**
```bash
# Production seeding (no test data)
docker compose --profile tools run --rm cli seed --env production

# Development seeding (includes test data)
docker compose --profile tools run --rm cli seed --env development
```

#### `reset`
Reset database to clean state (drop, recreate, migrate, seed).

```bash
# Interactive (requires confirmation)
docker compose --profile tools run --rm cli reset

# Force reset (no confirmation)
docker compose --profile tools run --rm cli reset --force

# Reset without seeding
docker compose --profile tools run --rm cli reset --force --no-seed
```

**Warning:** This deletes ALL data in the database!

**Steps performed:**
1. Terminates active connections
2. Drops existing database
3. Creates new database
4. Runs all migrations
5. Seeds initial data (unless `--no-seed`)

### Backup & Restore Commands

#### `backup`
Create a database backup.

```bash
# Basic backup (custom format, compressed)
docker compose --profile tools run --rm cli backup

# Plain SQL backup
docker compose --profile tools run --rm cli backup --format plain

# Compressed plain SQL
docker compose --profile tools run --rm cli backup --format plain --compress

# Directory format (parallel backup)
docker compose --profile tools run --rm cli backup --format directory --jobs 8

# Schema only
docker compose --profile tools run --rm cli backup --schema-only

# Data only
docker compose --profile tools run --rm cli backup --data-only

# Specific tables
docker compose --profile tools run --rm cli backup --tables "projects,models,traces"

# Exclude tables
docker compose --profile tools run --rm cli backup --exclude-table logs

# Upload to S3
docker compose --profile tools run --rm cli backup --s3-upload
```

**Backup formats:**
- `custom` (default): Compressed binary format, fastest restore
- `plain`: SQL text file, human-readable
- `directory`: Parallel backup/restore, good for large databases

**Backup naming:**
```
llm_observatory_backup_20240101_120000.dump
llm_observatory_backup_20240101_120000_schema.dump
llm_observatory_backup_20240101_120000_data.sql.gz
```

**Retention:**
Backups older than `BACKUP_RETENTION_DAYS` (default: 30) are automatically deleted.

#### `restore`
Restore database from backup.

```bash
# Basic restore (interactive)
docker compose --profile tools run --rm cli restore /app/backups/backup-file.dump

# Force restore (no confirmation)
docker compose --profile tools run --rm cli restore /app/backups/backup-file.dump --force

# Clean restore (drop existing objects first)
docker compose --profile tools run --rm cli restore /app/backups/backup-file.dump --clean

# Create database before restore
docker compose --profile tools run --rm cli restore /app/backups/backup-file.dump --create

# Restore schema only
docker compose --profile tools run --rm cli restore /app/backups/backup-file.dump --schema-only

# Restore data only
docker compose --profile tools run --rm cli restore /app/backups/backup-file.dump --data-only

# Parallel restore (directory format)
docker compose --profile tools run --rm cli restore /app/backups/backup-dir --jobs 8

# Download from S3 and restore
docker compose --profile tools run --rm cli restore backup-file.dump --s3-download
```

**Warning:** Restore may overwrite existing data!

### SQL Execution Commands

#### `sql`
Execute SQL file.

```bash
docker compose --profile tools run --rm cli sql /app/data/custom-query.sql
```

**Use case:** Run custom SQL scripts, data fixes, or manual migrations.

#### `exec`
Execute SQL command directly.

```bash
docker compose --profile tools run --rm cli exec 'SELECT COUNT(*) FROM projects;'

docker compose --profile tools run --rm cli exec 'UPDATE configurations SET value = true WHERE key = '\''enable_caching'\'';'
```

**Note:** Quote escaping required for complex queries.

#### `shell`
Open interactive PostgreSQL shell.

```bash
docker compose --profile tools run --rm cli shell
```

**Inside the shell:**
```sql
-- List tables
\dt

-- Describe table
\d+ projects

-- Run queries
SELECT * FROM models WHERE provider = 'openai';

-- Exit
\q
```

### Utility Commands

#### `verify`
Verify database connection and status.

```bash
docker compose --profile tools run --rm cli verify
```

**Checks:**
- Database connectivity
- PostgreSQL version
- TimescaleDB extension
- Basic query execution

#### `help`
Show help information.

```bash
docker compose --profile tools run --rm cli help
```

## Environment Variables

### Database Connection

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | Database hostname | `timescaledb` |
| `DB_PORT` | Database port | `5432` |
| `DB_NAME` | Database name | `llm_observatory` |
| `DB_USER` | Database user | `postgres` |
| `DB_PASSWORD` | Database password | `postgres` |
| `DATABASE_URL` | Full connection URL | Auto-generated |

### Paths

| Variable | Description | Default |
|----------|-------------|---------|
| `MIGRATIONS_DIR` | Migrations directory | `/app/migrations` |
| `SCRIPTS_DIR` | Scripts directory | `/app/scripts` |
| `BACKUPS_DIR` | Backups directory | `/app/backups` |
| `DATA_DIR` | Data files directory | `/app/data` |

### Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `LOG_LEVEL` | Logging level | `info` |
| `RUST_LOG` | Rust logging config | `sqlx=info` |
| `BACKUP_RETENTION_DAYS` | Backup retention period | `30` |
| `ENVIRONMENT` | Environment name | `development` |

### AWS S3 (Optional)

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | - |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - |
| `AWS_REGION` | AWS region | `us-east-1` |
| `S3_BACKUP_BUCKET` | S3 bucket name | - |
| `S3_BACKUP_PREFIX` | S3 key prefix | `backups/` |

### Configuration in .env

```bash
# Database
DB_HOST=timescaledb
DB_PORT=5432
DB_NAME=llm_observatory
DB_USER=postgres
DB_PASSWORD=your_secure_password

# Backups
BACKUP_RETENTION_DAYS=30

# AWS S3 (optional)
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
S3_BACKUP_BUCKET=llm-observatory-backups
S3_BACKUP_PREFIX=production/backups/
```

## Common Workflows

### Initial Setup

```bash
# 1. Start database
docker compose up -d timescaledb

# 2. Wait for database to be ready
docker compose ps timescaledb

# 3. Run migrations
docker compose --profile tools run --rm cli migrate

# 4. Seed initial data
docker compose --profile tools run --rm cli seed

# 5. Verify setup
docker compose --profile tools run --rm cli verify
```

### Development Workflow

```bash
# Create new migration (on host)
sqlx migrate add -r my_new_feature

# Edit migration files
# ./crates/storage/migrations/XXXXXX_my_new_feature.up.sql
# ./crates/storage/migrations/XXXXXX_my_new_feature.down.sql

# Test migration
docker compose --profile tools run --rm cli migrate

# If issues, rollback
docker compose --profile tools run --rm cli migrate-rollback

# Fix and retry
docker compose --profile tools run --rm cli migrate

# Reset for testing
docker compose --profile tools run --rm cli reset --force
```

### Backup Workflow

```bash
# Daily backup (add to cron)
docker compose --profile tools run --rm cli backup --s3-upload

# Pre-deployment backup
docker compose --profile tools run --rm cli backup \
  --format custom \
  --output-dir /app/backups/pre-deployment

# Schema-only backup (for reference)
docker compose --profile tools run --rm cli backup \
  --schema-only \
  --format plain \
  --output-dir /app/backups/schemas
```

### Disaster Recovery

```bash
# 1. Stop application
docker compose down

# 2. Start database only
docker compose up -d timescaledb

# 3. Download backup from S3 (if needed)
docker compose --profile tools run --rm cli restore \
  backup-file.dump \
  --s3-download \
  --create \
  --force

# 4. Verify restoration
docker compose --profile tools run --rm cli verify

# 5. Restart application
docker compose up -d
```

### Data Migration Between Environments

```bash
# On source environment
docker compose --profile tools run --rm cli backup \
  --format custom \
  --s3-upload

# On target environment
docker compose --profile tools run --rm cli restore \
  backup-file.dump \
  --s3-download \
  --clean \
  --force

# Update environment-specific configurations
docker compose --profile tools run --rm cli shell
```

## Troubleshooting

### Database Connection Issues

**Problem:** CLI can't connect to database

**Solutions:**
```bash
# Check database is running
docker compose ps timescaledb

# Check database logs
docker compose logs timescaledb

# Verify network connectivity
docker compose --profile tools run --rm cli verify

# Check environment variables
docker compose --profile tools run --rm cli exec 'SELECT version();'
```

### Migration Failures

**Problem:** Migration fails midway

**Solutions:**
```bash
# Check migration status
docker compose --profile tools run --rm cli migrate-status

# Review error in logs
docker compose --profile tools logs cli

# Rollback if possible
docker compose --profile tools run --rm cli migrate-rollback

# Fix migration file
# Edit ./crates/storage/migrations/XXXXXX_failed_migration.sql

# Retry migration
docker compose --profile tools run --rm cli migrate

# If unfixable, reset database
docker compose --profile tools run --rm cli reset --force
```

### Backup/Restore Issues

**Problem:** Backup fails or is too large

**Solutions:**
```bash
# Use directory format for large databases
docker compose --profile tools run --rm cli backup \
  --format directory \
  --jobs 8

# Exclude large tables
docker compose --profile tools run --rm cli backup \
  --exclude-table large_log_table \
  --exclude-table temp_data

# Schema-only backup for structure
docker compose --profile tools run --rm cli backup --schema-only
```

**Problem:** Restore fails with errors

**Solutions:**
```bash
# Use --clean to drop existing objects
docker compose --profile tools run --rm cli restore \
  backup-file.dump \
  --clean \
  --force

# Restore in steps
# 1. Schema only
docker compose --profile tools run --rm cli restore \
  backup-file.dump \
  --schema-only

# 2. Data only
docker compose --profile tools run --rm cli restore \
  backup-file.dump \
  --data-only
```

### Permission Issues

**Problem:** Permission denied errors

**Solutions:**
```bash
# Check volume permissions
ls -la /var/lib/docker/volumes/llm-observatory-backup-data/_data/

# Ensure container can write to backups
docker compose --profile tools run --rm cli exec \
  'SELECT current_user, session_user;'

# Verify database user permissions
docker compose --profile tools run --rm cli shell
\du
```

## Best Practices

### Migration Management

1. **Always test migrations locally first**
   ```bash
   docker compose --profile tools run --rm cli migrate
   docker compose --profile tools run --rm cli migrate-rollback
   ```

2. **Create reversible migrations when possible**
   - Write both up and down migrations
   - Test rollback before deploying

3. **Use transactions in migrations**
   ```sql
   BEGIN;
   -- Your migration code
   COMMIT;
   ```

4. **Keep migrations small and focused**
   - One logical change per migration
   - Easier to debug and rollback

### Backup Strategy

1. **Regular automated backups**
   - Daily full backups
   - Weekly schema-only backups
   - Pre-deployment backups

2. **Test restore procedures**
   ```bash
   # Periodically test restore
   docker compose --profile tools run --rm cli restore latest-backup.dump
   ```

3. **Store backups in multiple locations**
   - Local disk
   - S3 or other cloud storage
   - Off-site backup

4. **Document retention policy**
   - Keep daily backups for 7 days
   - Keep weekly backups for 4 weeks
   - Keep monthly backups for 12 months

### Security

1. **Use strong database passwords**
   - Generate random passwords
   - Store in .env (gitignored)
   - Rotate regularly

2. **Encrypt backups**
   - Use encrypted S3 buckets
   - Encrypt sensitive backups locally

3. **Limit CLI access**
   - Only run in profile mode
   - Control who can run CLI commands
   - Audit CLI usage

4. **Review SQL before execution**
   - Always review custom SQL scripts
   - Test in development first
   - Use transactions for safety

## Advanced Usage

### Custom Scripts

Add custom scripts to `/docker/scripts/utilities/`:

```bash
# my-custom-script.sh
#!/usr/bin/env bash
set -euo pipefail

# Your custom operations
psql "${DATABASE_URL}" -c "SELECT COUNT(*) FROM projects;"
```

Make it executable:
```bash
chmod +x docker/scripts/utilities/my-custom-script.sh
```

Use it:
```bash
docker compose --profile tools run --rm cli shell -c \
  "/app/scripts/my-custom-script.sh"
```

### Automated Backups with Cron

Add to crontab (on host):
```bash
# Daily backup at 2 AM
0 2 * * * cd /path/to/llm-observatory && \
  docker compose --profile tools run --rm cli backup --s3-upload >> /var/log/llm-observatory-backup.log 2>&1
```

### CI/CD Integration

```yaml
# .github/workflows/database.yml
- name: Run Migrations
  run: |
    docker compose up -d timescaledb
    docker compose --profile tools run --rm cli migrate

- name: Verify Database
  run: |
    docker compose --profile tools run --rm cli verify
```

## Support

For issues or questions:
- Check logs: `docker compose logs cli`
- Review documentation: `docker compose --profile tools run --rm cli help`
- Open issue on GitHub
- Contact: support@llm-observatory.io

## Version History

- **0.1.0** (2024-01-01): Initial release
  - Database migrations
  - Backup/restore functionality
  - Data seeding
  - Interactive shell

## License

Apache 2.0 - See LICENSE file for details

# CLI Tools Quick Reference

## Common Commands

```bash
# Run migrations
docker compose --profile tools run --rm cli migrate

# Check migration status
docker compose --profile tools run --rm cli migrate-status

# Seed database
docker compose --profile tools run --rm cli seed

# Create backup
docker compose --profile tools run --rm cli backup

# Restore backup
docker compose --profile tools run --rm cli restore /app/backups/backup.dump

# Reset database
docker compose --profile tools run --rm cli reset --force

# Open shell
docker compose --profile tools run --rm cli shell

# Verify connection
docker compose --profile tools run --rm cli verify
```

## Backup Options

```bash
# Custom format (default, recommended)
docker compose --profile tools run --rm cli backup

# Plain SQL (human-readable)
docker compose --profile tools run --rm cli backup --format plain --compress

# Directory (parallel, large databases)
docker compose --profile tools run --rm cli backup --format directory --jobs 8

# Schema only
docker compose --profile tools run --rm cli backup --schema-only

# With S3 upload
docker compose --profile tools run --rm cli backup --s3-upload
```

## Restore Options

```bash
# Basic restore
docker compose --profile tools run --rm cli restore /app/backups/backup.dump

# Force (no confirmation)
docker compose --profile tools run --rm cli restore /app/backups/backup.dump --force

# Clean first (drop existing objects)
docker compose --profile tools run --rm cli restore /app/backups/backup.dump --clean --force

# Create database if needed
docker compose --profile tools run --rm cli restore /app/backups/backup.dump --create
```

## Workflows

### Initial Setup
```bash
docker compose up -d timescaledb
docker compose --profile tools run --rm cli migrate
docker compose --profile tools run --rm cli seed
```

### Fresh Start
```bash
docker compose --profile tools run --rm cli reset --force
```

### Before Deployment
```bash
docker compose --profile tools run --rm cli backup --s3-upload
```

### After Failed Migration
```bash
docker compose --profile tools run --rm cli migrate-rollback
# Fix migration file
docker compose --profile tools run --rm cli migrate
```

## Environment Variables

Set in `.env`:
```bash
DB_HOST=timescaledb
DB_PORT=5432
DB_NAME=llm_observatory
DB_USER=postgres
DB_PASSWORD=your_password
BACKUP_RETENTION_DAYS=30
```

## Troubleshooting

```bash
# Check if database is ready
docker compose ps timescaledb

# View database logs
docker compose logs timescaledb

# Test connection
docker compose --profile tools run --rm cli verify

# Access database directly
docker compose --profile tools run --rm cli shell
```

## Full Documentation

See [docs/CLI_TOOLS.md](/docs/CLI_TOOLS.md) for complete documentation.

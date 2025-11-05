# Docker CLI Scripts

This directory contains the CLI tools entrypoint and utility scripts for database management.

## Directory Structure

```
scripts/
├── cli-entrypoint.sh          # Main entrypoint (routes commands)
├── utilities/                 # Utility scripts
│   ├── run-migrations.sh     # Execute database migrations
│   ├── seed-data.sh          # Seed initial/test data
│   ├── reset-database.sh     # Reset database to clean state
│   ├── backup-database.sh    # Create database backups
│   └── restore-database.sh   # Restore from backups
└── README.md                 # This file
```

## Scripts Overview

### cli-entrypoint.sh

Main entrypoint script that routes commands to appropriate utilities.

**Features:**
- Command routing and validation
- Database readiness checking
- Connection verification
- Comprehensive help text
- Colorized output
- Error handling

**Usage:**
```bash
docker compose --profile tools run --rm cli <command> [args]
```

### run-migrations.sh

Executes database migrations using sqlx-cli.

**Features:**
- Automatic database creation
- Migration status tracking
- Dry-run mode
- Migration verification

**Usage:**
```bash
./run-migrations.sh [--dry-run]
```

**Environment Variables:**
- `MIGRATIONS_DIR`: Path to migrations directory
- `DATABASE_URL`: Database connection URL

### seed-data.sh

Populates database with initial or test data.

**Features:**
- Environment-specific seeding (production/development/test)
- Sample projects and API keys
- LLM model definitions
- Default configurations
- Test data (non-production only)

**Usage:**
```bash
./seed-data.sh [--env production|development|test]
```

**What Gets Seeded:**
- Projects (with hashed API keys)
- Models (OpenAI, Anthropic, Google)
- Configurations (system settings)
- Test data (development/test only)

### reset-database.sh

Resets database to clean state (drop, recreate, migrate, seed).

**Features:**
- Interactive confirmation
- Force mode (--force)
- Optional seeding skip (--no-seed)
- Connection termination
- Full verification

**Usage:**
```bash
./reset-database.sh [--force] [--no-seed]
```

**Warning:** This deletes ALL data!

**Steps:**
1. Confirm operation
2. Terminate connections
3. Drop database
4. Create database
5. Run migrations
6. Seed data (optional)
7. Verify result

### backup-database.sh

Creates compressed database backups with multiple format options.

**Features:**
- Multiple formats (custom, plain, directory)
- Compression support
- Parallel backup (directory format)
- Schema-only or data-only options
- Table filtering
- S3 upload support
- Automatic retention management
- Metadata generation

**Usage:**
```bash
./backup-database.sh [options]

Options:
  --output-dir <dir>      Output directory (default: /app/backups)
  --format <format>       Format: custom|plain|directory (default: custom)
  --compress              Compress plain format backups
  --jobs <n>              Parallel jobs for directory format
  --schema-only           Backup schema only
  --data-only             Backup data only
  --tables <tables>       Specific tables (comma-separated)
  --exclude-table <tbl>   Exclude table
  --s3-upload             Upload to S3
```

**Backup Formats:**
- **custom**: Binary format, compressed, fast restore (recommended)
- **plain**: SQL text, human-readable, portable
- **directory**: Parallel operations, best for very large databases

**Examples:**
```bash
# Default backup
./backup-database.sh

# Plain SQL, compressed
./backup-database.sh --format plain --compress

# Schema only
./backup-database.sh --schema-only

# With S3 upload
./backup-database.sh --s3-upload
```

### restore-database.sh

Restores database from backup files.

**Features:**
- Auto-format detection
- Decompression support
- Interactive confirmation
- Force mode
- Clean restore (drop objects first)
- Database creation option
- Schema/data-only restore
- Parallel restore (directory format)
- S3 download support
- Verification

**Usage:**
```bash
./restore-database.sh <backup-file> [options]

Options:
  --force           Skip confirmation
  --clean           Drop existing objects
  --create          Create database before restore
  --data-only       Restore data only
  --schema-only     Restore schema only
  --jobs <n>        Parallel jobs (directory format)
  --s3-download     Download from S3 first
```

**Examples:**
```bash
# Basic restore
./restore-database.sh /app/backups/backup.dump

# Force restore with clean
./restore-database.sh /app/backups/backup.dump --force --clean

# From S3
./restore-database.sh backup.dump --s3-download --force
```

## Environment Variables

All scripts use these common environment variables:

### Database Connection
```bash
DB_HOST=timescaledb          # Database hostname
DB_PORT=5432                 # Database port
DB_NAME=llm_observatory      # Database name
DB_USER=postgres             # Database user
DB_PASSWORD=postgres         # Database password
DATABASE_URL=postgresql://...  # Full connection URL
```

### Paths
```bash
MIGRATIONS_DIR=/app/migrations  # Migrations location
SCRIPTS_DIR=/app/scripts        # Scripts location
BACKUPS_DIR=/app/backups        # Backup storage
DATA_DIR=/app/data              # Data files
```

### Configuration
```bash
LOG_LEVEL=info                    # Logging level
ENVIRONMENT=development           # Environment name
BACKUP_RETENTION_DAYS=30          # Backup retention period
```

### AWS S3 (Optional)
```bash
AWS_ACCESS_KEY_ID=...            # AWS access key
AWS_SECRET_ACCESS_KEY=...        # AWS secret key
AWS_REGION=us-east-1             # AWS region
S3_BACKUP_BUCKET=...             # S3 bucket name
S3_BACKUP_PREFIX=backups/        # S3 key prefix
```

## Script Standards

All scripts follow these standards:

### Error Handling
```bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

### Logging
```bash
log_info "Information message"
log_success "Success message"
log_warning "Warning message"
log_error "Error message"
```

### Exit Codes
- `0`: Success
- `1`: General error
- Other: Specific error codes

### Environment Loading
```bash
if [ -f /app/.env ]; then
    source /app/.env
fi
```

## Adding Custom Scripts

To add a custom utility script:

1. Create script in `utilities/` directory
2. Make it executable: `chmod +x script.sh`
3. Follow standards (error handling, logging)
4. Source environment variables
5. Add documentation

Example template:
```bash
#!/usr/bin/env bash
#
# Script Name
# Purpose: Brief description
# Usage: ./script.sh [options]
#

set -euo pipefail

# Source environment
if [ -f /app/.env ]; then
    source /app/.env
fi

# Configuration
readonly VAR="${ENV_VAR:-default}"

# Logging functions
log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Main function
main() {
    log_info "Starting operation..."
    # Your code here
}

main "$@"
```

## Testing Scripts

### Local Testing (without Docker)

```bash
# Set environment variables
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=llm_observatory
export DB_USER=postgres
export DB_PASSWORD=postgres
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/llm_observatory"

# Run script
./utilities/run-migrations.sh
```

### Docker Testing

```bash
# Build CLI container
docker compose --profile tools build cli

# Test command
docker compose --profile tools run --rm cli migrate

# Check logs
docker compose --profile tools logs cli
```

### Dry Run Testing

Some scripts support dry-run mode:
```bash
docker compose --profile tools run --rm cli migrate --dry-run
```

## Troubleshooting

### Script Not Executable
```bash
chmod +x docker/scripts/cli-entrypoint.sh
chmod +x docker/scripts/utilities/*.sh
```

### Permission Denied in Container
```bash
# Check volume mounts in docker-compose.yml
# Ensure scripts are mounted read-only: :ro
```

### Environment Variables Not Set
```bash
# Check .env file exists
ls -la .env

# Check variables are exported in container
docker compose --profile tools run --rm cli exec 'env | grep DB_'
```

### Command Not Found
```bash
# Ensure entrypoint.sh is set in Dockerfile
# Check CMD/ENTRYPOINT configuration
docker compose --profile tools run --rm cli help
```

## Security Considerations

1. **Passwords**: Never hardcode passwords in scripts
2. **File Permissions**: Keep scripts read-only in container
3. **Input Validation**: Validate all user inputs
4. **SQL Injection**: Use parameterized queries
5. **Backup Encryption**: Encrypt sensitive backups
6. **Audit Logging**: Log all administrative operations

## Maintenance

### Regular Tasks

- Review and update scripts monthly
- Test backup/restore procedures quarterly
- Update dependencies (sqlx-cli, etc.)
- Review retention policies
- Audit security settings

### Version Control

- All scripts are version controlled in git
- Use meaningful commit messages
- Tag releases: v0.1.0, v0.2.0, etc.
- Document breaking changes

## Contributing

When contributing scripts:

1. Follow bash best practices
2. Add comprehensive error handling
3. Include usage documentation
4. Add logging at key points
5. Test thoroughly
6. Update README.md

## Support

For issues with scripts:
- Check script help: `./script.sh --help`
- Review logs: `docker compose logs cli`
- Check environment variables
- See full documentation: `/docs/CLI_TOOLS.md`

## License

Apache 2.0 - See LICENSE file for details

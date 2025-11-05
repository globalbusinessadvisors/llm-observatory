#!/usr/bin/env bash
#
# CLI Tools Usage Examples
# Purpose: Demonstrate common CLI workflows
# Note: This is a reference script - review before executing!
#

# Exit on any error
set -e

echo "LLM Observatory CLI Tools - Usage Examples"
echo "=========================================="
echo
echo "This script demonstrates common CLI workflows."
echo "Review each section before executing."
echo

# =============================================================================
# INITIAL SETUP
# =============================================================================

initial_setup() {
    echo "=== Initial Setup ==="
    echo

    # 1. Start database
    echo "Starting database..."
    docker compose up -d timescaledb

    # 2. Wait for database to be ready
    echo "Waiting for database..."
    sleep 5

    # 3. Build CLI tools container
    echo "Building CLI tools container..."
    docker compose --profile tools build cli

    # 4. Run migrations
    echo "Running migrations..."
    docker compose --profile tools run --rm cli migrate

    # 5. Seed initial data
    echo "Seeding data..."
    docker compose --profile tools run --rm cli seed

    # 6. Verify setup
    echo "Verifying setup..."
    docker compose --profile tools run --rm cli verify

    echo "Initial setup complete!"
    echo
}

# =============================================================================
# DEVELOPMENT WORKFLOW
# =============================================================================

development_workflow() {
    echo "=== Development Workflow ==="
    echo

    # Check current migration status
    echo "Checking migration status..."
    docker compose --profile tools run --rm cli migrate-status

    # Test migrations in dry-run mode
    echo "Testing migrations (dry-run)..."
    docker compose --profile tools run --rm cli migrate --dry-run || true

    # Run migrations
    echo "Running migrations..."
    docker compose --profile tools run --rm cli migrate

    # If something goes wrong, rollback
    # docker compose --profile tools run --rm cli migrate-rollback

    # Reset database for testing
    echo "Resetting database for fresh test..."
    docker compose --profile tools run --rm cli reset --force

    echo "Development workflow complete!"
    echo
}

# =============================================================================
# BACKUP WORKFLOWS
# =============================================================================

backup_workflows() {
    echo "=== Backup Workflows ==="
    echo

    # 1. Standard backup (custom format, recommended)
    echo "Creating standard backup..."
    docker compose --profile tools run --rm cli backup

    # 2. Plain SQL backup (human-readable)
    echo "Creating plain SQL backup..."
    docker compose --profile tools run --rm cli backup \
        --format plain \
        --compress

    # 3. Directory format backup (parallel, for large databases)
    echo "Creating directory format backup..."
    docker compose --profile tools run --rm cli backup \
        --format directory \
        --jobs 8

    # 4. Schema-only backup (for reference)
    echo "Creating schema-only backup..."
    docker compose --profile tools run --rm cli backup \
        --schema-only \
        --format plain

    # 5. Backup specific tables
    echo "Backing up specific tables..."
    docker compose --profile tools run --rm cli backup \
        --tables "projects,models,configurations"

    # 6. Backup with S3 upload (requires AWS credentials)
    echo "Creating backup with S3 upload..."
    docker compose --profile tools run --rm cli backup \
        --s3-upload || echo "S3 upload skipped (credentials not configured)"

    echo "Backup workflows complete!"
    echo
}

# =============================================================================
# RESTORE WORKFLOWS
# =============================================================================

restore_workflows() {
    echo "=== Restore Workflows ==="
    echo

    # Find latest backup
    LATEST_BACKUP=$(docker compose --profile tools run --rm cli exec \
        "ls -t /app/backups/*.dump 2>/dev/null | head -n1" || echo "")

    if [ -z "$LATEST_BACKUP" ]; then
        echo "No backups found. Creating one first..."
        docker compose --profile tools run --rm cli backup
        LATEST_BACKUP="/app/backups/$(docker compose --profile tools run --rm cli exec \
            'ls -t /app/backups/*.dump 2>/dev/null | head -n1')"
    fi

    echo "Using backup: $LATEST_BACKUP"

    # 1. Basic restore (with confirmation)
    echo "Performing basic restore..."
    # docker compose --profile tools run --rm cli restore "$LATEST_BACKUP"

    # 2. Force restore (no confirmation)
    echo "Performing force restore..."
    docker compose --profile tools run --rm cli restore \
        "$LATEST_BACKUP" \
        --force

    # 3. Clean restore (drop existing objects first)
    echo "Performing clean restore..."
    docker compose --profile tools run --rm cli restore \
        "$LATEST_BACKUP" \
        --clean \
        --force

    # 4. Restore from S3 (requires AWS credentials)
    echo "Restoring from S3..."
    docker compose --profile tools run --rm cli restore \
        "backup-file.dump" \
        --s3-download \
        --force || echo "S3 restore skipped (credentials not configured)"

    echo "Restore workflows complete!"
    echo
}

# =============================================================================
# DATABASE OPERATIONS
# =============================================================================

database_operations() {
    echo "=== Database Operations ==="
    echo

    # 1. Check migration status
    echo "Checking migration status..."
    docker compose --profile tools run --rm cli migrate-status

    # 2. Verify database connection
    echo "Verifying database connection..."
    docker compose --profile tools run --rm cli verify

    # 3. Execute SQL command
    echo "Executing SQL command..."
    docker compose --profile tools run --rm cli exec \
        "SELECT COUNT(*) as project_count FROM projects;"

    # 4. Execute SQL file
    echo "Creating sample SQL file..."
    cat > /tmp/sample-query.sql <<EOF
SELECT
    provider,
    model_name,
    model_version,
    is_active
FROM models
WHERE is_active = true
ORDER BY provider, model_name;
EOF

    echo "Executing SQL file..."
    docker compose --profile tools run --rm cli sql /tmp/sample-query.sql

    # 5. Open interactive shell (commented - requires manual input)
    # echo "Opening interactive shell..."
    # docker compose --profile tools run --rm cli shell

    echo "Database operations complete!"
    echo
}

# =============================================================================
# MAINTENANCE WORKFLOWS
# =============================================================================

maintenance_workflows() {
    echo "=== Maintenance Workflows ==="
    echo

    # 1. Create pre-deployment backup
    echo "Creating pre-deployment backup..."
    docker compose --profile tools run --rm cli backup \
        --format custom \
        --s3-upload || echo "S3 upload skipped"

    # 2. Run pending migrations
    echo "Running pending migrations..."
    docker compose --profile tools run --rm cli migrate

    # 3. Verify database after migration
    echo "Verifying database..."
    docker compose --profile tools run --rm cli verify

    # 4. Create post-deployment backup
    echo "Creating post-deployment backup..."
    docker compose --profile tools run --rm cli backup

    # 5. Check database statistics
    echo "Checking database statistics..."
    docker compose --profile tools run --rm cli exec "
        SELECT
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
        FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
        LIMIT 10;
    "

    echo "Maintenance workflows complete!"
    echo
}

# =============================================================================
# DISASTER RECOVERY WORKFLOW
# =============================================================================

disaster_recovery() {
    echo "=== Disaster Recovery Workflow ==="
    echo

    # 1. Stop application services
    echo "Stopping application services..."
    docker compose down

    # 2. Start only database
    echo "Starting database..."
    docker compose up -d timescaledb

    # 3. Wait for database
    echo "Waiting for database..."
    sleep 5

    # 4. Find latest backup
    LATEST_BACKUP=$(docker compose --profile tools run --rm cli exec \
        "ls -t /app/backups/*.dump 2>/dev/null | head -n1" || echo "")

    if [ -z "$LATEST_BACKUP" ]; then
        echo "ERROR: No backup found for restore!"
        return 1
    fi

    echo "Restoring from: $LATEST_BACKUP"

    # 5. Restore database
    echo "Restoring database..."
    docker compose --profile tools run --rm cli restore \
        "$LATEST_BACKUP" \
        --clean \
        --force

    # 6. Verify restoration
    echo "Verifying restoration..."
    docker compose --profile tools run --rm cli verify

    # 7. Restart all services
    echo "Restarting all services..."
    docker compose up -d

    echo "Disaster recovery complete!"
    echo
}

# =============================================================================
# ENVIRONMENT MIGRATION
# =============================================================================

environment_migration() {
    echo "=== Environment Migration (Dev -> Staging) ==="
    echo

    echo "On SOURCE environment:"
    echo "---------------------"

    # 1. Create backup with all data
    echo "Creating full backup..."
    docker compose --profile tools run --rm cli backup \
        --format custom

    # 2. Upload to S3
    echo "Uploading to S3..."
    docker compose --profile tools run --rm cli backup \
        --s3-upload || echo "S3 upload skipped"

    echo
    echo "On TARGET environment:"
    echo "---------------------"

    # 3. Download from S3 and restore
    echo "Downloading from S3 and restoring..."
    # docker compose --profile tools run --rm cli restore \
    #     backup-file.dump \
    #     --s3-download \
    #     --clean \
    #     --force

    # 4. Update environment-specific configurations
    echo "Updating environment-specific configurations..."
    docker compose --profile tools run --rm cli exec "
        UPDATE configurations
        SET value = 'staging'
        WHERE key = 'environment';
    "

    # 5. Verify target environment
    echo "Verifying target environment..."
    docker compose --profile tools run --rm cli verify

    echo "Environment migration complete!"
    echo
}

# =============================================================================
# AUTOMATION EXAMPLES
# =============================================================================

automation_examples() {
    echo "=== Automation Examples ==="
    echo

    echo "Example 1: Daily Backup Script"
    echo "-------------------------------"
    cat <<'SCRIPT'
#!/bin/bash
# daily-backup.sh - Add to cron

cd /path/to/llm-observatory

# Create backup with S3 upload
docker compose --profile tools run --rm cli backup \
    --format custom \
    --s3-upload

# Log result
if [ $? -eq 0 ]; then
    echo "$(date): Backup successful" >> /var/log/llm-observatory-backup.log
else
    echo "$(date): Backup failed" >> /var/log/llm-observatory-backup.log
    # Send alert email
    mail -s "Backup Failed" admin@example.com < /dev/null
fi
SCRIPT

    echo
    echo "Example 2: Pre-Deployment Script"
    echo "---------------------------------"
    cat <<'SCRIPT'
#!/bin/bash
# pre-deploy.sh - Run before deployments

set -e

cd /path/to/llm-observatory

# Create backup
echo "Creating pre-deployment backup..."
docker compose --profile tools run --rm cli backup --s3-upload

# Run migrations
echo "Running migrations..."
docker compose --profile tools run --rm cli migrate

# Verify
echo "Verifying database..."
docker compose --profile tools run --rm cli verify

echo "Pre-deployment checks complete!"
SCRIPT

    echo
    echo "Example 3: Monitoring Script"
    echo "----------------------------"
    cat <<'SCRIPT'
#!/bin/bash
# check-database.sh - Monitor database health

cd /path/to/llm-observatory

# Check database connection
if ! docker compose --profile tools run --rm cli verify; then
    echo "Database health check failed!"
    # Send alert
    exit 1
fi

# Check database size
SIZE=$(docker compose --profile tools run --rm cli exec \
    "SELECT pg_size_pretty(pg_database_size('llm_observatory'));")

echo "Database size: $SIZE"

# Check backup age
LAST_BACKUP=$(find /var/lib/docker/volumes/llm-observatory-backup-data/_data/ \
    -name "*.dump" -mtime -1 | wc -l)

if [ "$LAST_BACKUP" -eq 0 ]; then
    echo "WARNING: No backup in last 24 hours!"
    # Send alert
fi
SCRIPT

    echo
    echo "Automation examples complete!"
    echo
}

# =============================================================================
# CI/CD INTEGRATION
# =============================================================================

cicd_integration() {
    echo "=== CI/CD Integration Example ==="
    echo

    cat <<'YAML'
# .github/workflows/database.yml
name: Database Operations

on:
  push:
    paths:
      - 'crates/storage/migrations/**'
  pull_request:
    paths:
      - 'crates/storage/migrations/**'

jobs:
  test-migrations:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Start Database
        run: docker compose up -d timescaledb

      - name: Wait for Database
        run: sleep 10

      - name: Run Migrations
        run: docker compose --profile tools run --rm cli migrate

      - name: Verify Database
        run: docker compose --profile tools run --rm cli verify

      - name: Seed Test Data
        run: docker compose --profile tools run --rm cli seed --env test

      - name: Run Tests
        run: docker compose --profile tools run --rm cli exec \
          "SELECT COUNT(*) FROM projects;"

  backup-production:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Create Backup
        run: docker compose --profile tools run --rm cli backup \
          --s3-upload
YAML

    echo
    echo "CI/CD integration example complete!"
    echo
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_menu() {
    echo "Select a workflow to run:"
    echo
    echo "1) Initial Setup"
    echo "2) Development Workflow"
    echo "3) Backup Workflows"
    echo "4) Restore Workflows"
    echo "5) Database Operations"
    echo "6) Maintenance Workflows"
    echo "7) Disaster Recovery"
    echo "8) Environment Migration"
    echo "9) Automation Examples (display only)"
    echo "10) CI/CD Integration (display only)"
    echo "11) Run All (except recovery/migration)"
    echo "0) Exit"
    echo
    read -p "Enter choice [0-11]: " choice

    case $choice in
        1) initial_setup ;;
        2) development_workflow ;;
        3) backup_workflows ;;
        4) restore_workflows ;;
        5) database_operations ;;
        6) maintenance_workflows ;;
        7) disaster_recovery ;;
        8) environment_migration ;;
        9) automation_examples ;;
        10) cicd_integration ;;
        11)
            initial_setup
            development_workflow
            backup_workflows
            database_operations
            maintenance_workflows
            ;;
        0) exit 0 ;;
        *) echo "Invalid choice. Try again." ;;
    esac
}

# Run interactive menu if no arguments
if [ $# -eq 0 ]; then
    while true; do
        show_menu
        echo
        read -p "Press Enter to continue..."
        clear
    done
else
    # Run specific workflow if provided as argument
    case "$1" in
        initial) initial_setup ;;
        dev) development_workflow ;;
        backup) backup_workflows ;;
        restore) restore_workflows ;;
        db) database_operations ;;
        maintenance) maintenance_workflows ;;
        recovery) disaster_recovery ;;
        migration) environment_migration ;;
        automation) automation_examples ;;
        cicd) cicd_integration ;;
        all)
            initial_setup
            development_workflow
            backup_workflows
            database_operations
            maintenance_workflows
            ;;
        *)
            echo "Unknown workflow: $1"
            echo "Available workflows: initial, dev, backup, restore, db, maintenance, recovery, migration, automation, cicd, all"
            exit 1
            ;;
    esac
fi

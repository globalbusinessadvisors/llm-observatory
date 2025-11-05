#!/bin/bash

################################################################################
# Database Deployment Script for LLM Observatory
#
# This script safely runs database migrations with comprehensive safety checks,
# backup creation, and rollback capabilities.
#
# Usage:
#   ./deploy_database.sh [OPTIONS]
#
# Options:
#   --environment ENV       Environment to deploy to (staging|production)
#   --dry-run              Show what would be done without executing
#   --backup-only          Only create a backup, don't run migrations
#   --skip-backup          Skip backup creation (dangerous!)
#   --retry                Retry failed migration
#   --migration FILE       Run specific migration file
#   --verify-only          Only verify migrations, don't apply
#   --help                 Show this help message
#
# Environment Variables:
#   DB_HOST                Database host
#   DB_PORT                Database port (default: 5432)
#   DB_NAME                Database name
#   DB_USER                Database user
#   DB_PASSWORD            Database password
#   BACKUP_DIR             Backup directory (default: /backups)
#
# Author: LLM Observatory Team
# Version: 1.0.0
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
ENVIRONMENT="${ENVIRONMENT:-staging}"
DRY_RUN=false
BACKUP_ONLY=false
SKIP_BACKUP=false
RETRY=false
MIGRATION_FILE=""
VERIFY_ONLY=false
BACKUP_DIR="${BACKUP_DIR:-/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATIONS_DIR="$PROJECT_ROOT/crates/storage/migrations"

# Migration files in order
MIGRATION_FILES=(
    "001_initial_schema.sql"
    "002_add_hypertables.sql"
    "003_create_indexes.sql"
    "004_continuous_aggregates.sql"
    "005_retention_policies.sql"
    "006_supporting_tables.sql"
)

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# //g' | sed 's/^#//g'
    exit 0
}

################################################################################
# Parse Command Line Arguments
################################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --backup-only)
                BACKUP_ONLY=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --retry)
                RETRY=true
                shift
                ;;
            --migration)
                MIGRATION_FILE="$2"
                shift 2
                ;;
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

################################################################################
# Environment Setup
################################################################################

load_environment() {
    log_info "Loading environment configuration for: $ENVIRONMENT"

    # Load environment-specific configuration
    local env_file="$PROJECT_ROOT/.env.$ENVIRONMENT"
    if [[ -f "$env_file" ]]; then
        log_info "Loading configuration from $env_file"
        set -a
        source "$env_file"
        set +a
    elif [[ -f "$PROJECT_ROOT/.env" ]]; then
        log_info "Loading configuration from .env"
        set -a
        source "$PROJECT_ROOT/.env"
        set +a
    else
        log_warning "No .env file found, using environment variables"
    fi

    # Validate required environment variables
    local required_vars=("DB_HOST" "DB_NAME" "DB_USER" "DB_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done

    DB_PORT="${DB_PORT:-5432}"

    # Build connection string
    export PGHOST="$DB_HOST"
    export PGPORT="$DB_PORT"
    export PGDATABASE="$DB_NAME"
    export PGUSER="$DB_USER"
    export PGPASSWORD="$DB_PASSWORD"

    log_success "Environment loaded: $ENVIRONMENT"
    log_info "Database: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
}

################################################################################
# Pre-flight Checks
################################################################################

check_dependencies() {
    log_info "Checking dependencies..."

    local deps=("psql" "pg_dump")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' not found"
            exit 1
        fi
    done

    log_success "All dependencies found"
}

check_database_connection() {
    log_info "Testing database connection..."

    if ! psql -c "SELECT 1" &> /dev/null; then
        log_error "Failed to connect to database"
        log_error "Host: $DB_HOST:$DB_PORT"
        log_error "Database: $DB_NAME"
        log_error "User: $DB_USER"
        exit 1
    fi

    log_success "Database connection successful"
}

check_database_version() {
    log_info "Checking PostgreSQL version..."

    local version
    version=$(psql -t -c "SELECT version();" | head -1)
    log_info "PostgreSQL version: $version"

    # Check for TimescaleDB
    local timescale_version
    timescale_version=$(psql -t -c "SELECT extversion FROM pg_extension WHERE extname='timescaledb';" | tr -d '[:space:]')

    if [[ -z "$timescale_version" ]]; then
        log_error "TimescaleDB extension not found"
        log_error "Please install TimescaleDB before running migrations"
        exit 1
    fi

    log_success "TimescaleDB version: $timescale_version"
}

check_disk_space() {
    log_info "Checking disk space..."

    local db_size
    db_size=$(psql -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | tr -d '[:space:]')
    log_info "Current database size: $db_size"

    # Check available disk space on backup directory
    if [[ -d "$BACKUP_DIR" ]]; then
        local available
        available=$(df -h "$BACKUP_DIR" | awk 'NR==2 {print $4}')
        log_info "Available space in backup directory: $available"
    fi

    log_success "Disk space check completed"
}

check_active_connections() {
    log_info "Checking active connections..."

    local connection_count
    connection_count=$(psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='$DB_NAME';" | tr -d '[:space:]')
    log_info "Active connections: $connection_count"

    if [[ "$connection_count" -gt 50 ]] && [[ "$ENVIRONMENT" == "production" ]]; then
        log_warning "High number of active connections detected"
        log_warning "Consider running migration during low-traffic period"

        if [[ "$DRY_RUN" == "false" ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Migration cancelled"
                exit 1
            fi
        fi
    fi

    log_success "Connection check completed"
}

################################################################################
# Backup Functions
################################################################################

create_backup() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        log_warning "Skipping backup as requested (dangerous!)"
        return 0
    fi

    log_info "Creating database backup..."

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    local backup_file="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create backup: $backup_file"
        return 0
    fi

    # Create backup using pg_dump with custom format
    if pg_dump -Fc -f "$backup_file"; then
        log_success "Backup created: $backup_file"

        # Get backup size
        local backup_size
        backup_size=$(du -h "$backup_file" | cut -f1)
        log_info "Backup size: $backup_size"

        # Verify backup integrity
        log_info "Verifying backup integrity..."
        if pg_restore --list "$backup_file" > /dev/null 2>&1; then
            log_success "Backup integrity verified"

            # Save backup file path for potential rollback
            echo "$backup_file" > "$BACKUP_DIR/latest_backup.txt"
        else
            log_error "Backup integrity check failed"
            exit 1
        fi
    else
        log_error "Failed to create backup"
        exit 1
    fi
}

################################################################################
# Migration Functions
################################################################################

get_current_schema_version() {
    # Check if schema_migrations table exists
    local table_exists
    table_exists=$(psql -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'schema_migrations');" | tr -d '[:space:]')

    if [[ "$table_exists" == "t" ]]; then
        local version
        version=$(psql -t -c "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1;" | tr -d '[:space:]')
        echo "${version:-0}"
    else
        echo "0"
    fi
}

create_migrations_table() {
    log_info "Creating schema_migrations table if not exists..."

    psql -c "
    CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        checksum VARCHAR(64),
        execution_time_ms INTEGER
    );" > /dev/null

    log_success "schema_migrations table ready"
}

is_migration_applied() {
    local migration_number=$1

    local exists
    exists=$(psql -t -c "SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE version = $migration_number);" | tr -d '[:space:]')

    [[ "$exists" == "t" ]]
}

apply_migration() {
    local migration_file=$1
    local migration_number
    migration_number=$(echo "$migration_file" | grep -oP '^\d+')
    local migration_name
    migration_name=$(echo "$migration_file" | sed 's/\.sql$//')

    log_info "Applying migration: $migration_file"

    # Check if already applied
    if is_migration_applied "$migration_number"; then
        log_info "Migration $migration_number already applied, skipping"
        return 0
    fi

    local migration_path="$MIGRATIONS_DIR/$migration_file"

    if [[ ! -f "$migration_path" ]]; then
        log_error "Migration file not found: $migration_path"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would apply migration: $migration_file"
        log_info "[DRY RUN] File: $migration_path"
        return 0
    fi

    # Calculate checksum
    local checksum
    checksum=$(md5sum "$migration_path" | cut -d' ' -f1)

    # Run migration in a transaction with timing
    local start_time
    start_time=$(date +%s%3N)

    if psql -v ON_ERROR_STOP=1 -f "$migration_path" > /dev/null; then
        local end_time
        end_time=$(date +%s%3N)
        local execution_time=$((end_time - start_time))

        # Record migration in schema_migrations table
        psql -c "INSERT INTO schema_migrations (version, name, applied_at, checksum, execution_time_ms)
                 VALUES ($migration_number, '$migration_name', NOW(), '$checksum', $execution_time);" > /dev/null

        log_success "Migration $migration_file applied successfully (${execution_time}ms)"
        return 0
    else
        log_error "Failed to apply migration: $migration_file"
        return 1
    fi
}

run_migrations() {
    log_info "Running database migrations..."

    create_migrations_table

    local current_version
    current_version=$(get_current_schema_version)
    log_info "Current schema version: $current_version"

    # If specific migration file specified, run only that
    if [[ -n "$MIGRATION_FILE" ]]; then
        if apply_migration "$MIGRATION_FILE"; then
            log_success "Migration completed successfully"
        else
            log_error "Migration failed"
            return 1
        fi
        return 0
    fi

    # Run all migrations in order
    local failed=false
    for migration_file in "${MIGRATION_FILES[@]}"; do
        if ! apply_migration "$migration_file"; then
            failed=true
            break
        fi
    done

    if [[ "$failed" == "true" ]]; then
        log_error "Migration sequence failed"
        return 1
    fi

    log_success "All migrations applied successfully"
    return 0
}

verify_migrations() {
    log_info "Verifying database schema..."

    local verify_script="$MIGRATIONS_DIR/verify_migrations.sql"

    if [[ ! -f "$verify_script" ]]; then
        log_warning "Verification script not found: $verify_script"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run verification script"
        return 0
    fi

    if psql -f "$verify_script"; then
        log_success "Schema verification passed"
        return 0
    else
        log_error "Schema verification failed"
        return 1
    fi
}

################################################################################
# Post-Migration Functions
################################################################################

analyze_database() {
    log_info "Analyzing database for query planner..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run ANALYZE"
        return 0
    fi

    if psql -c "ANALYZE;" > /dev/null; then
        log_success "Database analysis completed"
    else
        log_warning "Database analysis failed (non-critical)"
    fi
}

show_migration_summary() {
    log_info "Migration Summary:"

    local total_migrations
    total_migrations=$(psql -t -c "SELECT count(*) FROM schema_migrations;" | tr -d '[:space:]')

    log_info "Total migrations applied: $total_migrations"

    log_info "Recent migrations:"
    psql -c "SELECT version, name, applied_at, execution_time_ms
             FROM schema_migrations
             ORDER BY version DESC
             LIMIT 5;" || true
}

################################################################################
# Main Function
################################################################################

main() {
    log_info "LLM Observatory Database Deployment Script"
    log_info "============================================"

    # Parse arguments
    parse_args "$@"

    # Load environment
    load_environment

    # Pre-flight checks
    check_dependencies
    check_database_connection
    check_database_version
    check_disk_space
    check_active_connections

    # Create backup
    if [[ "$VERIFY_ONLY" == "false" ]]; then
        create_backup

        if [[ "$BACKUP_ONLY" == "true" ]]; then
            log_success "Backup completed. Exiting as requested."
            exit 0
        fi
    fi

    # Run migrations
    if [[ "$VERIFY_ONLY" == "false" ]]; then
        if ! run_migrations; then
            log_error "Migration failed. Database state may be inconsistent."
            log_error "You can restore from backup: $BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"
            exit 1
        fi
    fi

    # Verify migrations
    verify_migrations

    # Post-migration tasks
    if [[ "$VERIFY_ONLY" == "false" ]] && [[ "$DRY_RUN" == "false" ]]; then
        analyze_database
        show_migration_summary
    fi

    log_success "Database deployment completed successfully!"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "This was a dry run. No changes were made."
    fi
}

# Run main function
main "$@"

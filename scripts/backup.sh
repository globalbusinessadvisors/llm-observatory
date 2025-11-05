#!/bin/bash

################################################################################
# LLM Observatory - Local Database Backup Script
################################################################################
#
# Description:
#   Creates a local backup of the TimescaleDB database using pg_dump.
#   Includes compression, rotation, and verification.
#
# Usage:
#   ./backup.sh [OPTIONS]
#
# Options:
#   -c, --config FILE    Path to config file (default: .env)
#   -d, --dir DIR        Backup directory (default: ./backups)
#   -r, --retention DAYS Retention period in days (default: 30)
#   -v, --verbose        Verbose output
#   -h, --help           Show this help message
#
# Environment Variables:
#   DB_HOST              Database host (default: localhost)
#   DB_PORT              Database port (default: 5432)
#   DB_NAME              Database name (default: llm_observatory)
#   DB_USER              Database user (default: postgres)
#   DB_PASSWORD          Database password
#   BACKUP_DIR           Backup directory override
#   BACKUP_RETENTION     Retention period override (days)
#
# Exit Codes:
#   0  - Success
#   1  - General error
#   2  - Configuration error
#   3  - Backup failed
#   4  - Verification failed
#   5  - Rotation failed
#
################################################################################

set -euo pipefail

# Script metadata
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
CONFIG_FILE="${PROJECT_ROOT}/.env"
BACKUP_DIR="${PROJECT_ROOT}/backups"
RETENTION_DAYS=30
VERBOSE=false
LOG_FILE=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

# Print formatted log message
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        INFO)
            echo -e "${BLUE}[INFO]${NC} ${timestamp} - ${message}"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} ${timestamp} - ${message}"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - ${message}"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${timestamp} - ${message}"
            ;;
    esac

    # Also log to file if LOG_FILE is set
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${level}] ${timestamp} - ${message}" >> "$LOG_FILE"
    fi
}

# Print verbose message
verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        log INFO "$@"
    fi
}

# Print error and exit
die() {
    log ERROR "$@"
    exit "${2:-1}"
}

# Show usage information
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Creates a local backup of the TimescaleDB database.

OPTIONS:
    -c, --config FILE    Path to config file (default: .env)
    -d, --dir DIR        Backup directory (default: ./backups)
    -r, --retention DAYS Retention period in days (default: 30)
    -v, --verbose        Verbose output
    -h, --help           Show this help message

EXAMPLES:
    # Create backup with defaults
    ${SCRIPT_NAME}

    # Custom backup directory with 60-day retention
    ${SCRIPT_NAME} -d /mnt/backups -r 60

    # Verbose output
    ${SCRIPT_NAME} -v

EXIT CODES:
    0  - Success
    1  - General error
    2  - Configuration error
    3  - Backup failed
    4  - Verification failed
    5  - Rotation failed

EOF
    exit 0
}

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -r|--retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                die "Unknown option: $1" 2
                ;;
        esac
    done
}

# Load configuration from .env file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        verbose "Loading configuration from: $CONFIG_FILE"
        # Export variables from .env, ignoring comments and empty lines
        set -a
        source <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | sed 's/\r$//')
        set +a
    else
        log WARN "Configuration file not found: $CONFIG_FILE"
        log WARN "Using default configuration"
    fi

    # Set defaults if not provided
    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:-llm_observatory}"
    DB_USER="${DB_USER:-postgres}"

    # Override with environment variables if set
    BACKUP_DIR="${BACKUP_DIR:-${BACKUP_DIR}}"
    RETENTION_DAYS="${BACKUP_RETENTION:-${RETENTION_DAYS}}"

    # Validate required configuration
    if [[ -z "${DB_PASSWORD:-}" ]]; then
        die "DB_PASSWORD not set. Please set it in $CONFIG_FILE or as an environment variable." 2
    fi
}

# Check prerequisites
check_prerequisites() {
    verbose "Checking prerequisites..."

    # Check for required commands
    local required_cmds=("pg_dump" "psql" "gzip" "date")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            die "Required command not found: $cmd" 1
        fi
    done

    # Check database connectivity
    verbose "Testing database connection..."
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" &> /dev/null; then
        die "Cannot connect to database: $DB_HOST:$DB_PORT/$DB_NAME" 2
    fi

    verbose "Prerequisites check passed"
}

# Create backup directory structure
setup_backup_dir() {
    verbose "Setting up backup directory: $BACKUP_DIR"

    # Create main backup directory
    mkdir -p "$BACKUP_DIR"

    # Create subdirectories for organization
    mkdir -p "$BACKUP_DIR/daily"
    mkdir -p "$BACKUP_DIR/logs"

    # Set log file path
    LOG_FILE="$BACKUP_DIR/logs/backup_$(date '+%Y%m%d_%H%M%S').log"

    verbose "Backup directory structure created"
}

# Get database size
get_database_size() {
    local size=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c \
        "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));")
    echo "$size" | tr -d '[:space:]'
}

# Create database backup
create_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${BACKUP_DIR}/daily/llm_observatory_${timestamp}.sql"
    local compressed_file="${backup_file}.gz"
    local metadata_file="${backup_file}.meta"

    log INFO "Starting database backup..."
    log INFO "Database: $DB_NAME"
    log INFO "Host: $DB_HOST:$DB_PORT"

    # Get database size before backup
    local db_size=$(get_database_size)
    log INFO "Database size: $db_size"

    # Create backup with pg_dump
    verbose "Running pg_dump..."
    local start_time=$(date +%s)

    if PGPASSWORD="$DB_PASSWORD" pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --format=plain \
        --verbose \
        --no-owner \
        --no-acl \
        --clean \
        --if-exists \
        --file="$backup_file" 2>> "$LOG_FILE"; then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log SUCCESS "Backup created successfully in ${duration}s"
    else
        die "pg_dump failed. Check log: $LOG_FILE" 3
    fi

    # Compress backup
    log INFO "Compressing backup..."
    if gzip -9 "$backup_file"; then
        local compressed_size=$(du -h "$compressed_file" | cut -f1)
        log SUCCESS "Backup compressed: $compressed_size"
    else
        die "Compression failed" 3
    fi

    # Create metadata file
    cat > "$metadata_file" << EOF
Backup Metadata
===============
Timestamp: $(date -Iseconds)
Database: $DB_NAME
Host: $DB_HOST:$DB_PORT
User: $DB_USER
Database Size: $db_size
Backup File: $(basename "$compressed_file")
Compressed Size: $(du -h "$compressed_file" | cut -f1)
Checksum (SHA256): $(sha256sum "$compressed_file" | cut -d' ' -f1)
PostgreSQL Version: $(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version();" | tr -d '\n' | xargs)
TimescaleDB Version: $(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT extversion FROM pg_extension WHERE extname='timescaledb';" | tr -d '\n' | xargs)
Backup Duration: ${duration}s
EOF

    verbose "Metadata file created: $metadata_file"

    # Export backup path for verification
    BACKUP_FILE="$compressed_file"
}

# Verify backup integrity
verify_backup() {
    log INFO "Verifying backup integrity..."

    if [[ ! -f "$BACKUP_FILE" ]]; then
        die "Backup file not found: $BACKUP_FILE" 4
    fi

    # Test gzip integrity
    verbose "Testing gzip integrity..."
    if ! gzip -t "$BACKUP_FILE" 2>> "$LOG_FILE"; then
        die "Backup file is corrupted (gzip test failed)" 4
    fi

    # Check if backup contains SQL data
    verbose "Checking backup content..."
    if ! zcat "$BACKUP_FILE" | head -n 100 | grep -q "PostgreSQL database dump"; then
        die "Backup file does not contain valid PostgreSQL dump" 4
    fi

    # Calculate checksum
    local checksum=$(sha256sum "$BACKUP_FILE" | cut -d' ' -f1)
    verbose "Backup checksum: $checksum"

    log SUCCESS "Backup verification passed"
}

# Rotate old backups
rotate_backups() {
    log INFO "Rotating old backups (retention: ${RETENTION_DAYS} days)..."

    local deleted_count=0
    local kept_count=0

    # Find and delete backups older than retention period
    while IFS= read -r old_backup; do
        if [[ -n "$old_backup" ]]; then
            verbose "Deleting old backup: $(basename "$old_backup")"
            rm -f "$old_backup" "${old_backup%.gz}.meta"
            ((deleted_count++))
        fi
    done < <(find "$BACKUP_DIR/daily" -name "*.sql.gz" -type f -mtime +${RETENTION_DAYS})

    # Count remaining backups
    kept_count=$(find "$BACKUP_DIR/daily" -name "*.sql.gz" -type f | wc -l)

    log INFO "Rotation complete: ${deleted_count} deleted, ${kept_count} retained"

    # Rotate log files (keep last 90 days)
    local log_deleted=0
    while IFS= read -r old_log; do
        if [[ -n "$old_log" ]]; then
            rm -f "$old_log"
            ((log_deleted++))
        fi
    done < <(find "$BACKUP_DIR/logs" -name "*.log" -type f -mtime +90)

    if [[ $log_deleted -gt 0 ]]; then
        verbose "Deleted $log_deleted old log files"
    fi
}

# Print backup summary
print_summary() {
    log SUCCESS "========================================="
    log SUCCESS "Backup completed successfully!"
    log SUCCESS "========================================="
    log INFO "Backup file: $BACKUP_FILE"
    log INFO "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
    log INFO "Log file: $LOG_FILE"
    log INFO "Active backups: $(find "$BACKUP_DIR/daily" -name "*.sql.gz" -type f | wc -l)"
    log SUCCESS "========================================="
}

################################################################################
# Main Function
################################################################################

main() {
    log INFO "========================================="
    log INFO "LLM Observatory - Database Backup"
    log INFO "========================================="

    # Parse command-line arguments
    parse_args "$@"

    # Load configuration
    load_config

    # Check prerequisites
    check_prerequisites

    # Setup backup directory
    setup_backup_dir

    # Create backup
    create_backup

    # Verify backup
    verify_backup

    # Rotate old backups
    rotate_backups

    # Print summary
    print_summary

    exit 0
}

# Run main function
main "$@"

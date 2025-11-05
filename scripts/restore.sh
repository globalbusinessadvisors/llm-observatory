#!/bin/bash

################################################################################
# LLM Observatory - Database Restore Script
################################################################################
#
# Description:
#   Restores a PostgreSQL/TimescaleDB database from a backup file.
#   Supports both local backups and S3 backups.
#
# Usage:
#   ./restore.sh [OPTIONS] BACKUP_FILE
#
# Options:
#   -c, --config FILE      Path to config file (default: .env)
#   -d, --database NAME    Target database name (default: from config)
#   -t, --target-db NAME   Create new database instead of overwriting
#   -s, --from-s3          Download backup from S3
#   -b, --bucket BUCKET    S3 bucket name (required if --from-s3)
#   -r, --region REGION    AWS region (default: us-east-1)
#   --no-verify            Skip backup verification
#   --drop-existing        Drop existing database before restore
#   --dry-run              Show what would be done without executing
#   -v, --verbose          Verbose output
#   -y, --yes              Skip confirmation prompts
#   -h, --help             Show this help message
#
# Arguments:
#   BACKUP_FILE           Path to backup file (local or S3 key)
#
# Examples:
#   # Restore from local backup
#   ./restore.sh backups/daily/llm_observatory_20240101_120000.sql.gz
#
#   # Restore from S3
#   ./restore.sh -s -b my-bucket backups/llm_observatory_20240101_120000.sql.gz
#
#   # Restore to a new database
#   ./restore.sh -t llm_observatory_test backup.sql.gz
#
#   # Dry run
#   ./restore.sh --dry-run backup.sql.gz
#
# Exit Codes:
#   0  - Success
#   1  - General error
#   2  - Configuration error
#   3  - Verification failed
#   4  - Restore failed
#   5  - User cancelled
#
################################################################################

set -euo pipefail

# Script metadata
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
CONFIG_FILE="${PROJECT_ROOT}/.env"
BACKUP_FILE=""
TARGET_DB=""
FROM_S3=false
S3_BUCKET=""
S3_REGION="${AWS_REGION:-us-east-1}"
VERIFY=true
DROP_EXISTING=false
DRY_RUN=false
VERBOSE=false
AUTO_YES=false
TEMP_DIR=""
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
    cleanup
    exit "${2:-1}"
}

# Cleanup temporary files
cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        verbose "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# Show usage information
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] BACKUP_FILE

Restores a PostgreSQL/TimescaleDB database from a backup file.

OPTIONS:
    -c, --config FILE      Path to config file (default: .env)
    -d, --database NAME    Target database name (default: from config)
    -t, --target-db NAME   Create new database instead of overwriting
    -s, --from-s3          Download backup from S3
    -b, --bucket BUCKET    S3 bucket name (required if --from-s3)
    -r, --region REGION    AWS region (default: us-east-1)
    --no-verify            Skip backup verification
    --drop-existing        Drop existing database before restore
    --dry-run              Show what would be done without executing
    -v, --verbose          Verbose output
    -y, --yes              Skip confirmation prompts
    -h, --help             Show this help message

ARGUMENTS:
    BACKUP_FILE           Path to backup file (local or S3 key)

EXAMPLES:
    # Restore from local backup
    ${SCRIPT_NAME} backups/daily/llm_observatory_20240101_120000.sql.gz

    # Restore from S3
    ${SCRIPT_NAME} -s -b my-bucket backups/llm_observatory_20240101_120000.sql.gz

    # Restore to a new database
    ${SCRIPT_NAME} -t llm_observatory_test backup.sql.gz

    # Drop and restore
    ${SCRIPT_NAME} --drop-existing backup.sql.gz

EXIT CODES:
    0  - Success
    1  - General error
    2  - Configuration error
    3  - Verification failed
    4  - Restore failed
    5  - User cancelled

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
            -d|--database)
                TARGET_DB="$2"
                shift 2
                ;;
            -t|--target-db)
                TARGET_DB="$2"
                shift 2
                ;;
            -s|--from-s3)
                FROM_S3=true
                shift
                ;;
            -b|--bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            -r|--region)
                S3_REGION="$2"
                shift 2
                ;;
            --no-verify)
                VERIFY=false
                shift
                ;;
            --drop-existing)
                DROP_EXISTING=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                die "Unknown option: $1" 2
                ;;
            *)
                BACKUP_FILE="$1"
                shift
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$BACKUP_FILE" ]]; then
        die "Backup file is required. See --help for usage." 2
    fi

    if [[ "$FROM_S3" == "true" && -z "$S3_BUCKET" ]]; then
        die "S3 bucket is required when using --from-s3" 2
    fi
}

# Load configuration from .env file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        verbose "Loading configuration from: $CONFIG_FILE"
        set -a
        source <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | sed 's/\r$//')
        set +a
    else
        log WARN "Configuration file not found: $CONFIG_FILE"
    fi

    # Set defaults if not provided
    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:-llm_observatory}"
    DB_USER="${DB_USER:-postgres}"

    # Use target database if specified
    if [[ -z "$TARGET_DB" ]]; then
        TARGET_DB="$DB_NAME"
    fi

    # Validate required configuration
    if [[ -z "${DB_PASSWORD:-}" ]]; then
        die "DB_PASSWORD not set" 2
    fi
}

# Check prerequisites
check_prerequisites() {
    verbose "Checking prerequisites..."

    # Check for required commands
    local required_cmds=("psql" "gzip" "zcat")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            die "Required command not found: $cmd" 1
        fi
    done

    # Check for AWS CLI if using S3
    if [[ "$FROM_S3" == "true" ]]; then
        if ! command -v aws &> /dev/null; then
            die "AWS CLI not found (required for S3 downloads)" 1
        fi

        # Test AWS credentials
        verbose "Testing AWS credentials..."
        if ! aws sts get-caller-identity --region "$S3_REGION" &> /dev/null; then
            die "AWS credentials are invalid or not configured" 2
        fi
    fi

    # Check database connectivity
    verbose "Testing database connection..."
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "SELECT 1" &> /dev/null; then
        die "Cannot connect to database server: $DB_HOST:$DB_PORT" 2
    fi

    verbose "Prerequisites check passed"
}

# Setup temporary directory
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d -t llm-observatory-restore-XXXXXX)
    verbose "Created temporary directory: $TEMP_DIR"

    # Create log file
    LOG_FILE="${TEMP_DIR}/restore.log"
}

# Download backup from S3
download_from_s3() {
    log INFO "Downloading backup from S3..."
    log INFO "Bucket: s3://${S3_BUCKET}/${BACKUP_FILE}"

    local local_file="${TEMP_DIR}/$(basename "$BACKUP_FILE")"
    local s3_path="s3://${S3_BUCKET}/${BACKUP_FILE}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "[DRY RUN] Would download: $s3_path -> $local_file"
        return 0
    fi

    # Download from S3
    if aws s3 cp "$s3_path" "$local_file" --region "$S3_REGION" 2>> "$LOG_FILE"; then
        log SUCCESS "Downloaded from S3"
        BACKUP_FILE="$local_file"
    else
        die "Failed to download from S3: $s3_path" 4
    fi
}

# Verify backup file
verify_backup() {
    if [[ "$VERIFY" != "true" ]]; then
        log WARN "Skipping backup verification (--no-verify)"
        return 0
    fi

    log INFO "Verifying backup file..."

    if [[ ! -f "$BACKUP_FILE" ]]; then
        die "Backup file not found: $BACKUP_FILE" 3
    fi

    # Check file size
    local file_size=$(du -h "$BACKUP_FILE" | cut -f1)
    verbose "Backup file size: $file_size"

    # Test gzip integrity if compressed
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        verbose "Testing gzip integrity..."
        if ! gzip -t "$BACKUP_FILE" 2>> "$LOG_FILE"; then
            die "Backup file is corrupted (gzip test failed)" 3
        fi
    fi

    # Check if backup contains SQL data
    verbose "Checking backup content..."
    local head_cmd="head -n 100"
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        head_cmd="zcat | head -n 100"
    fi

    if ! eval "$head_cmd" "$BACKUP_FILE" | grep -q "PostgreSQL database dump"; then
        die "Backup file does not contain valid PostgreSQL dump" 3
    fi

    log SUCCESS "Backup verification passed"
}

# Confirm restore operation
confirm_restore() {
    if [[ "$AUTO_YES" == "true" || "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    log WARN "========================================="
    log WARN "WARNING: Database Restore Operation"
    log WARN "========================================="
    log WARN "This will restore to database: $TARGET_DB"
    log WARN "Host: $DB_HOST:$DB_PORT"
    log WARN "Backup file: $BACKUP_FILE"

    if [[ "$DROP_EXISTING" == "true" ]]; then
        log WARN "EXISTING DATABASE WILL BE DROPPED!"
    fi

    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log INFO "Restore cancelled by user"
        exit 5
    fi
}

# Check if database exists
database_exists() {
    local db_name=$1
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='$db_name'" | grep -q 1
}

# Drop existing database
drop_database() {
    if [[ "$DROP_EXISTING" != "true" ]]; then
        return 0
    fi

    log INFO "Checking if database exists: $TARGET_DB"

    if database_exists "$TARGET_DB"; then
        log WARN "Dropping existing database: $TARGET_DB"

        if [[ "$DRY_RUN" == "true" ]]; then
            log INFO "[DRY RUN] Would drop database: $TARGET_DB"
            return 0
        fi

        # Terminate existing connections
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c \
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$TARGET_DB' AND pid <> pg_backend_pid();" \
            &>> "$LOG_FILE" || true

        # Drop database
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c \
            "DROP DATABASE IF EXISTS \"$TARGET_DB\";" &>> "$LOG_FILE"; then
            log SUCCESS "Database dropped: $TARGET_DB"
        else
            die "Failed to drop database: $TARGET_DB" 4
        fi
    else
        verbose "Database does not exist: $TARGET_DB"
    fi
}

# Create database if it doesn't exist
create_database() {
    if database_exists "$TARGET_DB"; then
        verbose "Database already exists: $TARGET_DB"
        return 0
    fi

    log INFO "Creating database: $TARGET_DB"

    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "[DRY RUN] Would create database: $TARGET_DB"
        return 0
    fi

    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c \
        "CREATE DATABASE \"$TARGET_DB\";" &>> "$LOG_FILE"; then
        log SUCCESS "Database created: $TARGET_DB"
    else
        die "Failed to create database: $TARGET_DB" 4
    fi
}

# Restore database from backup
restore_database() {
    log INFO "Restoring database from backup..."
    log INFO "Target database: $TARGET_DB"
    log INFO "Backup file: $BACKUP_FILE"

    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "[DRY RUN] Would restore backup to: $TARGET_DB"
        return 0
    fi

    local start_time=$(date +%s)
    local restore_cmd=""

    # Build restore command based on file type
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        restore_cmd="zcat '$BACKUP_FILE' | PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -p '$DB_PORT' -U '$DB_USER' -d '$TARGET_DB'"
    else
        restore_cmd="PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -p '$DB_PORT' -U '$DB_USER' -d '$TARGET_DB' -f '$BACKUP_FILE'"
    fi

    verbose "Restore command: $restore_cmd"

    # Execute restore
    if eval "$restore_cmd" &>> "$LOG_FILE"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log SUCCESS "Database restored in ${duration}s"
    else
        die "Database restore failed. Check log: $LOG_FILE" 4
    fi
}

# Verify restore
verify_restore() {
    log INFO "Verifying database restore..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "[DRY RUN] Would verify restore"
        return 0
    fi

    # Check if database exists and is accessible
    if ! database_exists "$TARGET_DB"; then
        die "Database does not exist after restore: $TARGET_DB" 4
    fi

    # Get database size
    local db_size=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TARGET_DB" -t -c \
        "SELECT pg_size_pretty(pg_database_size('$TARGET_DB'));")
    log INFO "Restored database size: $(echo $db_size | xargs)"

    # Check if TimescaleDB extension exists
    local has_timescaledb=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TARGET_DB" -tAc \
        "SELECT COUNT(*) FROM pg_extension WHERE extname='timescaledb';")

    if [[ "$has_timescaledb" -gt 0 ]]; then
        verbose "TimescaleDB extension detected"
    fi

    # Count tables
    local table_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TARGET_DB" -tAc \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema');")
    log INFO "Number of tables: $table_count"

    log SUCCESS "Restore verification passed"
}

# Print restore summary
print_summary() {
    log SUCCESS "========================================="
    log SUCCESS "Database restored successfully!"
    log SUCCESS "========================================="
    log INFO "Database: $TARGET_DB"
    log INFO "Host: $DB_HOST:$DB_PORT"
    log INFO "Backup file: $BACKUP_FILE"
    if [[ -n "$LOG_FILE" ]]; then
        log INFO "Log file: $LOG_FILE"
    fi
    log SUCCESS "========================================="
}

################################################################################
# Main Function
################################################################################

main() {
    # Setup cleanup trap
    trap cleanup EXIT INT TERM

    log INFO "========================================="
    log INFO "LLM Observatory - Database Restore"
    log INFO "========================================="

    # Parse command-line arguments
    parse_args "$@"

    # Load configuration
    load_config

    # Check prerequisites
    check_prerequisites

    # Setup temporary directory
    setup_temp_dir

    # Download from S3 if needed
    if [[ "$FROM_S3" == "true" ]]; then
        download_from_s3
    fi

    # Verify backup file
    verify_backup

    # Confirm restore operation
    confirm_restore

    # Drop existing database if requested
    drop_database

    # Create database if it doesn't exist
    create_database

    # Restore database
    restore_database

    # Verify restore
    verify_restore

    # Print summary
    print_summary

    exit 0
}

# Run main function
main "$@"

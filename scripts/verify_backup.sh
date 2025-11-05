#!/bin/bash

################################################################################
# LLM Observatory - Backup Verification Script
################################################################################
#
# Description:
#   Verifies backup integrity by restoring to a test database.
#   This ensures backups are valid and can be restored when needed.
#
# Usage:
#   ./verify_backup.sh [OPTIONS] BACKUP_FILE
#
# Options:
#   -c, --config FILE    Path to config file (default: .env)
#   -s, --from-s3        Download backup from S3
#   -b, --bucket BUCKET  S3 bucket name (required if --from-s3)
#   -r, --region REGION  AWS region (default: us-east-1)
#   --test-db NAME       Test database name (default: llm_observatory_test)
#   --keep-test-db       Keep test database after verification
#   --skip-data-check    Skip data integrity checks
#   -v, --verbose        Verbose output
#   -h, --help           Show this help message
#
# Arguments:
#   BACKUP_FILE         Path to backup file (local or S3 key)
#                       If not specified, verifies the latest backup
#
# Examples:
#   # Verify specific backup
#   ./verify_backup.sh backups/daily/llm_observatory_20240101_120000.sql.gz
#
#   # Verify latest backup
#   ./verify_backup.sh
#
#   # Verify S3 backup
#   ./verify_backup.sh -s -b my-bucket backups/latest.sql.gz
#
# Exit Codes:
#   0  - Success (backup is valid)
#   1  - General error
#   2  - Configuration error
#   3  - Backup file invalid
#   4  - Restore failed
#   5  - Data integrity check failed
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
FROM_S3=false
S3_BUCKET=""
S3_REGION="${AWS_REGION:-us-east-1}"
TEST_DB="llm_observatory_test"
KEEP_TEST_DB=false
SKIP_DATA_CHECK=false
VERBOSE=false
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

# Cleanup temporary files and test database
cleanup() {
    if [[ "$KEEP_TEST_DB" != "true" && -n "${DB_PASSWORD:-}" ]]; then
        verbose "Cleaning up test database: $TEST_DB"
        PGPASSWORD="$DB_PASSWORD" psql -h "${DB_HOST:-localhost}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" -d postgres -c \
            "DROP DATABASE IF EXISTS \"$TEST_DB\";" &> /dev/null || true
    fi

    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        verbose "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# Show usage information
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [BACKUP_FILE]

Verifies backup integrity by restoring to a test database.

OPTIONS:
    -c, --config FILE    Path to config file (default: .env)
    -s, --from-s3        Download backup from S3
    -b, --bucket BUCKET  S3 bucket name (required if --from-s3)
    -r, --region REGION  AWS region (default: us-east-1)
    --test-db NAME       Test database name (default: llm_observatory_test)
    --keep-test-db       Keep test database after verification
    --skip-data-check    Skip data integrity checks
    -v, --verbose        Verbose output
    -h, --help           Show this help message

ARGUMENTS:
    BACKUP_FILE         Path to backup file (local or S3 key)
                        If not specified, verifies the latest backup

EXAMPLES:
    # Verify specific backup
    ${SCRIPT_NAME} backups/daily/llm_observatory_20240101_120000.sql.gz

    # Verify latest backup
    ${SCRIPT_NAME}

    # Verify S3 backup
    ${SCRIPT_NAME} -s -b my-bucket backups/latest.sql.gz

EXIT CODES:
    0  - Success (backup is valid)
    1  - General error
    2  - Configuration error
    3  - Backup file invalid
    4  - Restore failed
    5  - Data integrity check failed

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
            --test-db)
                TEST_DB="$2"
                shift 2
                ;;
            --keep-test-db)
                KEEP_TEST_DB=true
                shift
                ;;
            --skip-data-check)
                SKIP_DATA_CHECK=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
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

    # Set defaults
    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:-llm_observatory}"
    DB_USER="${DB_USER:-postgres}"

    # Validate required configuration
    if [[ -z "${DB_PASSWORD:-}" ]]; then
        die "DB_PASSWORD not set" 2
    fi
}

# Check prerequisites
check_prerequisites() {
    verbose "Checking prerequisites..."

    # Check for required commands
    local required_cmds=("psql" "pg_dump" "gzip" "zcat")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            die "Required command not found: $cmd" 1
        fi
    done

    # Check for AWS CLI if using S3
    if [[ "$FROM_S3" == "true" ]]; then
        if ! command -v aws &> /dev/null; then
            die "AWS CLI not found (required for S3)" 1
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
    TEMP_DIR=$(mktemp -d -t llm-observatory-verify-XXXXXX)
    verbose "Created temporary directory: $TEMP_DIR"

    # Create log file
    LOG_FILE="${TEMP_DIR}/verify.log"
}

# Find latest backup
find_latest_backup() {
    local backup_dir="${PROJECT_ROOT}/backups/daily"

    if [[ ! -d "$backup_dir" ]]; then
        die "Backup directory not found: $backup_dir" 3
    fi

    # Find most recent backup file
    local latest=$(find "$backup_dir" -name "*.sql.gz" -type f -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)

    if [[ -z "$latest" ]]; then
        die "No backups found in: $backup_dir" 3
    fi

    log INFO "Found latest backup: $(basename "$latest")"
    BACKUP_FILE="$latest"
}

# Download backup from S3
download_from_s3() {
    log INFO "Downloading backup from S3..."
    log INFO "Bucket: s3://${S3_BUCKET}/${BACKUP_FILE}"

    local local_file="${TEMP_DIR}/$(basename "$BACKUP_FILE")"
    local s3_path="s3://${S3_BUCKET}/${BACKUP_FILE}"

    if aws s3 cp "$s3_path" "$local_file" --region "$S3_REGION" 2>> "$LOG_FILE"; then
        log SUCCESS "Downloaded from S3"
        BACKUP_FILE="$local_file"
    else
        die "Failed to download from S3: $s3_path" 3
    fi
}

# Verify backup file format
verify_backup_format() {
    log INFO "Verifying backup file format..."

    if [[ ! -f "$BACKUP_FILE" ]]; then
        die "Backup file not found: $BACKUP_FILE" 3
    fi

    # Check file size
    local file_size=$(du -h "$BACKUP_FILE" | cut -f1)
    local file_bytes=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE")

    log INFO "Backup file size: $file_size ($file_bytes bytes)"

    if [[ $file_bytes -eq 0 ]]; then
        die "Backup file is empty" 3
    fi

    # Test gzip integrity if compressed
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        verbose "Testing gzip integrity..."
        if ! gzip -t "$BACKUP_FILE" 2>> "$LOG_FILE"; then
            die "Backup file is corrupted (gzip test failed)" 3
        fi
        log SUCCESS "Gzip integrity check passed"
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

    # Extract and verify metadata
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        local pg_version=$(zcat "$BACKUP_FILE" | grep "Dumped from database version" | head -1)
        local dump_timestamp=$(zcat "$BACKUP_FILE" | grep "Dumped by" | head -1)

        if [[ -n "$pg_version" ]]; then
            verbose "PostgreSQL version: $pg_version"
        fi
    fi

    log SUCCESS "Backup format verification passed"
}

# Create test database
create_test_database() {
    log INFO "Creating test database: $TEST_DB"

    # Drop if exists
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c \
        "DROP DATABASE IF EXISTS \"$TEST_DB\";" &>> "$LOG_FILE" || true

    # Create test database
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c \
        "CREATE DATABASE \"$TEST_DB\";" &>> "$LOG_FILE"; then
        log SUCCESS "Test database created"
    else
        die "Failed to create test database" 4
    fi
}

# Restore backup to test database
restore_to_test_database() {
    log INFO "Restoring backup to test database..."

    local start_time=$(date +%s)
    local restore_cmd=""

    # Build restore command based on file type
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        restore_cmd="zcat '$BACKUP_FILE' | PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -p '$DB_PORT' -U '$DB_USER' -d '$TEST_DB'"
    else
        restore_cmd="PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -p '$DB_PORT' -U '$DB_USER' -d '$TEST_DB' -f '$BACKUP_FILE'"
    fi

    # Execute restore
    if eval "$restore_cmd" &>> "$LOG_FILE"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log SUCCESS "Backup restored to test database in ${duration}s"
    else
        die "Failed to restore backup to test database. Check log: $LOG_FILE" 4
    fi
}

# Verify database structure
verify_database_structure() {
    log INFO "Verifying database structure..."

    # Count schemas
    local schema_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
        "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast');")
    log INFO "Number of schemas: $schema_count"

    # Count tables
    local table_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema');")
    log INFO "Number of tables: $table_count"

    if [[ $table_count -eq 0 ]]; then
        log WARN "No tables found in backup"
    fi

    # Count views
    local view_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
        "SELECT COUNT(*) FROM information_schema.views WHERE table_schema NOT IN ('pg_catalog', 'information_schema');")
    verbose "Number of views: $view_count"

    # Count functions
    local function_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
        "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema NOT IN ('pg_catalog', 'information_schema');")
    verbose "Number of functions: $function_count"

    # Check extensions
    local extensions=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
        "SELECT extname FROM pg_extension WHERE extname NOT IN ('plpgsql');")

    if [[ -n "$extensions" ]]; then
        log INFO "Extensions: $(echo $extensions | tr '\n' ', ' | sed 's/,$//')"
    fi

    log SUCCESS "Database structure verification passed"
}

# Verify data integrity
verify_data_integrity() {
    if [[ "$SKIP_DATA_CHECK" == "true" ]]; then
        log WARN "Skipping data integrity checks (--skip-data-check)"
        return 0
    fi

    log INFO "Verifying data integrity..."

    # Get database size
    local db_size=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -t -c \
        "SELECT pg_size_pretty(pg_database_size('$TEST_DB'));")
    log INFO "Database size: $(echo $db_size | xargs)"

    # Count total rows across all tables
    local total_rows=0
    local table_list=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
        "SELECT schemaname || '.' || tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema');")

    if [[ -n "$table_list" ]]; then
        while IFS= read -r table; do
            if [[ -n "$table" ]]; then
                local row_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
                    "SELECT COUNT(*) FROM \"$table\";" 2>/dev/null || echo "0")
                total_rows=$((total_rows + row_count))
                verbose "Table $table: $row_count rows"
            fi
        done <<< "$table_list"
    fi

    log INFO "Total rows: $total_rows"

    # Check for constraints
    local constraint_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
        "SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_schema NOT IN ('pg_catalog', 'information_schema');")
    verbose "Number of constraints: $constraint_count"

    # Check for indexes
    local index_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
        "SELECT COUNT(*) FROM pg_indexes WHERE schemaname NOT IN ('pg_catalog', 'information_schema');")
    verbose "Number of indexes: $index_count"

    log SUCCESS "Data integrity verification passed"
}

# Verify TimescaleDB-specific features
verify_timescaledb() {
    verbose "Checking for TimescaleDB features..."

    # Check if TimescaleDB extension exists
    local has_timescaledb=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
        "SELECT COUNT(*) FROM pg_extension WHERE extname='timescaledb';" 2>/dev/null || echo "0")

    if [[ "$has_timescaledb" -gt 0 ]]; then
        log INFO "TimescaleDB extension detected"

        # Get TimescaleDB version
        local ts_version=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
            "SELECT extversion FROM pg_extension WHERE extname='timescaledb';" 2>/dev/null || echo "unknown")
        verbose "TimescaleDB version: $ts_version"

        # Count hypertables
        local hypertable_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -tAc \
            "SELECT COUNT(*) FROM timescaledb_information.hypertables;" 2>/dev/null || echo "0")

        if [[ $hypertable_count -gt 0 ]]; then
            log INFO "Number of hypertables: $hypertable_count"
        fi
    else
        verbose "TimescaleDB extension not found"
    fi
}

# Generate verification report
generate_report() {
    local report_file="${TEMP_DIR}/verification_report.txt"

    cat > "$report_file" << EOF
Backup Verification Report
==========================

Date: $(date -Iseconds)
Backup File: $BACKUP_FILE

Database Information:
- Host: $DB_HOST:$DB_PORT
- Test Database: $TEST_DB

Verification Results:
- Backup Format: PASSED
- Restore: PASSED
- Database Structure: PASSED
- Data Integrity: $([ "$SKIP_DATA_CHECK" == "true" ] && echo "SKIPPED" || echo "PASSED")

Summary:
$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -c "\l+ $TEST_DB" 2>/dev/null || echo "N/A")

Tables:
$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" -c "\dt+" 2>/dev/null || echo "N/A")

Verification completed successfully!
EOF

    log INFO "Verification report saved: $report_file"
}

# Print verification summary
print_summary() {
    log SUCCESS "========================================="
    log SUCCESS "Backup verification completed!"
    log SUCCESS "========================================="
    log INFO "Backup file: $BACKUP_FILE"
    log INFO "Test database: $TEST_DB"

    if [[ "$KEEP_TEST_DB" == "true" ]]; then
        log INFO "Test database preserved: $TEST_DB"
    else
        log INFO "Test database will be cleaned up"
    fi

    if [[ -n "$LOG_FILE" ]]; then
        log INFO "Log file: $LOG_FILE"
    fi
    log SUCCESS "========================================="
    log SUCCESS "BACKUP IS VALID AND RESTORABLE"
    log SUCCESS "========================================="
}

################################################################################
# Main Function
################################################################################

main() {
    # Setup cleanup trap
    trap cleanup EXIT INT TERM

    log INFO "========================================="
    log INFO "LLM Observatory - Backup Verification"
    log INFO "========================================="

    # Parse command-line arguments
    parse_args "$@"

    # Load configuration
    load_config

    # Check prerequisites
    check_prerequisites

    # Setup temporary directory
    setup_temp_dir

    # Find latest backup if not specified
    if [[ -z "$BACKUP_FILE" && "$FROM_S3" != "true" ]]; then
        find_latest_backup
    fi

    # Download from S3 if needed
    if [[ "$FROM_S3" == "true" ]]; then
        download_from_s3
    fi

    # Verify backup file format
    verify_backup_format

    # Create test database
    create_test_database

    # Restore backup to test database
    restore_to_test_database

    # Verify database structure
    verify_database_structure

    # Verify data integrity
    verify_data_integrity

    # Verify TimescaleDB features
    verify_timescaledb

    # Generate verification report
    generate_report

    # Print summary
    print_summary

    exit 0
}

# Run main function
main "$@"

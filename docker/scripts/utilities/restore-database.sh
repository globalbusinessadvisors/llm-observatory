#!/usr/bin/env bash
#
# Restore Database
# Purpose: Restore database from backup
# Usage: ./restore-database.sh <backup-file> [options]
#
# Options:
#   --force                Skip confirmation prompt
#   --clean                Drop existing objects before restore
#   --create               Create database before restore
#   --data-only            Restore data only (no schema)
#   --schema-only          Restore schema only (no data)
#   --jobs <n>             Number of parallel jobs (for directory format)
#   --s3-download          Download from S3 before restore
#

set -euo pipefail

# Source environment variables
if [ -f /app/.env ]; then
    # shellcheck disable=SC1091
    source /app/.env
fi

# Configuration
readonly DB_HOST="${DB_HOST:-timescaledb}"
readonly DB_PORT="${DB_PORT:-5432}"
readonly DB_NAME="${DB_NAME:-llm_observatory}"
readonly DB_USER="${DB_USER:-postgres}"
readonly DB_PASSWORD="${DB_PASSWORD:-postgres}"
readonly BACKUPS_DIR="${BACKUPS_DIR:-/app/backups}"

# AWS S3 configuration (optional)
readonly S3_BUCKET="${S3_BACKUP_BUCKET:-}"
readonly S3_PREFIX="${S3_BACKUP_PREFIX:-backups/}"
readonly AWS_REGION="${AWS_REGION:-us-east-1}"

# Colors
readonly COLOR_RESET="\033[0m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_BLUE="\033[0;34m"
readonly COLOR_YELLOW="\033[0;33m"
readonly COLOR_RED="\033[0;31m"

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"
}

# Check if backup file is provided
if [ $# -lt 1 ]; then
    log_error "Backup file not specified"
    echo "Usage: $0 <backup-file> [options]"
    exit 1
fi

BACKUP_FILE="$1"
shift

# Default options
FORCE=false
CLEAN=false
CREATE_DB=false
DATA_ONLY=false
SCHEMA_ONLY=false
PARALLEL_JOBS=4
S3_DOWNLOAD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --create)
            CREATE_DB=true
            shift
            ;;
        --data-only)
            DATA_ONLY=true
            shift
            ;;
        --schema-only)
            SCHEMA_ONLY=true
            shift
            ;;
        --jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --s3-download)
            S3_DOWNLOAD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Download from S3 if needed
download_from_s3() {
    if [ "${S3_DOWNLOAD}" != true ]; then
        return 0
    fi

    if [ -z "${S3_BUCKET}" ]; then
        log_error "S3 bucket not configured"
        return 1
    fi

    log_info "Downloading from S3..."

    local backup_filename
    backup_filename=$(basename "${BACKUP_FILE}")
    local s3_path="s3://${S3_BUCKET}/${S3_PREFIX}${backup_filename}"
    local local_path="${BACKUPS_DIR}/${backup_filename}"

    if command -v aws &> /dev/null; then
        if aws s3 cp "${s3_path}" "${local_path}" --region "${AWS_REGION}"; then
            BACKUP_FILE="${local_path}"
            log_success "Downloaded from S3: ${local_path}"
        else
            log_error "S3 download failed"
            return 1
        fi
    else
        log_error "AWS CLI not found"
        return 1
    fi
}

# Determine backup format
detect_backup_format() {
    local file="$1"

    if [ -d "${file}" ]; then
        echo "directory"
    elif [[ "${file}" == *.sql.gz ]]; then
        echo "plain-compressed"
    elif [[ "${file}" == *.sql ]]; then
        echo "plain"
    elif [[ "${file}" == *.dump ]]; then
        echo "custom"
    else
        echo "unknown"
    fi
}

# Decompress if needed
decompress_if_needed() {
    local file="$1"

    if [[ "${file}" == *.gz ]]; then
        log_info "Decompressing backup..."
        local decompressed="${file%.gz}"

        if gunzip -c "${file}" > "${decompressed}"; then
            log_success "Backup decompressed"
            echo "${decompressed}"
        else
            log_error "Decompression failed"
            return 1
        fi
    else
        echo "${file}"
    fi
}

# Confirm restore
confirm_restore() {
    if [ "${FORCE}" = true ]; then
        return 0
    fi

    log_warning "This will restore the database: ${DB_NAME}"
    log_warning "Existing data may be overwritten!"
    echo
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi
}

# Create database if needed
create_database_if_needed() {
    if [ "${CREATE_DB}" != true ]; then
        return 0
    fi

    log_info "Creating database: ${DB_NAME}"

    local postgres_url="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/postgres"

    if psql "${postgres_url}" -c "CREATE DATABASE ${DB_NAME};" 2>/dev/null; then
        log_success "Database created"
    else
        log_info "Database already exists or creation failed"
    fi
}

# Build pg_restore command
build_pgrestore_command() {
    local backup_file="$1"
    local format="$2"
    local pgrestore_cmd

    if [ "${format}" = "plain" ] || [ "${format}" = "plain-compressed" ]; then
        # Use psql for plain SQL
        pgrestore_cmd="psql"
        pgrestore_cmd="${pgrestore_cmd} -h ${DB_HOST}"
        pgrestore_cmd="${pgrestore_cmd} -p ${DB_PORT}"
        pgrestore_cmd="${pgrestore_cmd} -U ${DB_USER}"
        pgrestore_cmd="${pgrestore_cmd} -d ${DB_NAME}"
        pgrestore_cmd="${pgrestore_cmd} -f ${backup_file}"

        if [ "${SCHEMA_ONLY}" = true ]; then
            log_warning "SCHEMA_ONLY not supported for plain SQL format"
        fi
        if [ "${DATA_ONLY}" = true ]; then
            log_warning "DATA_ONLY not supported for plain SQL format"
        fi
    else
        # Use pg_restore for custom/directory format
        pgrestore_cmd="pg_restore"
        pgrestore_cmd="${pgrestore_cmd} -h ${DB_HOST}"
        pgrestore_cmd="${pgrestore_cmd} -p ${DB_PORT}"
        pgrestore_cmd="${pgrestore_cmd} -U ${DB_USER}"
        pgrestore_cmd="${pgrestore_cmd} -d ${DB_NAME}"

        # Clean option
        if [ "${CLEAN}" = true ]; then
            pgrestore_cmd="${pgrestore_cmd} --clean"
        fi

        # Schema/Data options
        if [ "${SCHEMA_ONLY}" = true ]; then
            pgrestore_cmd="${pgrestore_cmd} --schema-only"
        elif [ "${DATA_ONLY}" = true ]; then
            pgrestore_cmd="${pgrestore_cmd} --data-only"
        fi

        # Parallel jobs for directory format
        if [ "${format}" = "directory" ]; then
            pgrestore_cmd="${pgrestore_cmd} -j ${PARALLEL_JOBS}"
        fi

        # Error handling
        pgrestore_cmd="${pgrestore_cmd} --no-owner"
        pgrestore_cmd="${pgrestore_cmd} --no-privileges"
        pgrestore_cmd="${pgrestore_cmd} --verbose"

        pgrestore_cmd="${pgrestore_cmd} ${backup_file}"
    fi

    echo "${pgrestore_cmd}"
}

# Perform restore
perform_restore() {
    local backup_file="$1"

    log_info "Starting restore..."
    log_info "Database: ${DB_NAME}"
    log_info "Backup file: ${backup_file}"

    # Detect format
    local format
    format=$(detect_backup_format "${backup_file}")
    log_info "Backup format: ${format}"

    if [ "${format}" = "unknown" ]; then
        log_error "Unknown backup format"
        return 1
    fi

    # Decompress if needed
    if [ "${format}" = "plain-compressed" ]; then
        backup_file=$(decompress_if_needed "${backup_file}")
        format="plain"
    fi

    # Export password
    export PGPASSWORD="${DB_PASSWORD}"

    # Build and execute restore command
    local pgrestore_cmd
    pgrestore_cmd=$(build_pgrestore_command "${backup_file}" "${format}")

    log_info "Executing restore..."

    if eval "${pgrestore_cmd}"; then
        log_success "Restore completed successfully"
    else
        log_warning "Restore completed with warnings/errors"
        log_info "This is normal for some backup formats"
    fi

    unset PGPASSWORD
}

# Verify restore
verify_restore() {
    log_info "Verifying restore..."

    export PGPASSWORD="${DB_PASSWORD}"

    # Check database connectivity
    if ! psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1;" > /dev/null 2>&1; then
        log_error "Database is not accessible"
        unset PGPASSWORD
        return 1
    fi

    # Count tables
    local table_count
    table_count=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE';")
    log_info "Tables restored: ${table_count}"

    # Check TimescaleDB extension
    local has_timescaledb
    has_timescaledb=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*)
        FROM pg_extension
        WHERE extname = 'timescaledb';")

    if [ "${has_timescaledb}" -gt 0 ]; then
        log_success "TimescaleDB extension is installed"
    else
        log_warning "TimescaleDB extension not found"
    fi

    # Get database size
    local db_size
    db_size=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));")
    log_info "Database size: ${db_size}"

    unset PGPASSWORD
}

# Main execution
main() {
    log_info "Database Restore Utility"
    echo

    # Download from S3 if needed
    download_from_s3 || exit 1

    # Check if backup file exists
    if [ ! -e "${BACKUP_FILE}" ]; then
        log_error "Backup file not found: ${BACKUP_FILE}"
        exit 1
    fi

    # Confirm restore
    confirm_restore

    # Create database if needed
    create_database_if_needed

    # Perform restore
    perform_restore "${BACKUP_FILE}" || exit 1

    # Verify restore
    echo
    verify_restore || exit 1

    echo
    log_success "Database restore completed!"
    log_info "Database: ${DB_NAME}"
    log_info "Status: Ready for use"
}

main "$@"

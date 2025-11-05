#!/usr/bin/env bash
#
# Backup Database
# Purpose: Create compressed backups of the database
# Usage: ./backup-database.sh [options]
#
# Options:
#   --output-dir <dir>     Backup output directory (default: /app/backups)
#   --format <format>      Backup format: custom|plain|directory (default: custom)
#   --compress             Compress backup with gzip (for plain format)
#   --jobs <n>             Number of parallel jobs for directory format
#   --schema-only          Backup schema only (no data)
#   --data-only            Backup data only (no schema)
#   --tables <tables>      Backup specific tables (comma-separated)
#   --exclude-table <tbl>  Exclude specific table
#   --s3-upload            Upload to S3 after backup
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
readonly RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

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

# Default options
OUTPUT_DIR="${BACKUPS_DIR}"
BACKUP_FORMAT="custom"
COMPRESS=false
PARALLEL_JOBS=4
SCHEMA_ONLY=false
DATA_ONLY=false
SPECIFIC_TABLES=""
EXCLUDE_TABLES=""
S3_UPLOAD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --format)
            BACKUP_FORMAT="$2"
            shift 2
            ;;
        --compress)
            COMPRESS=true
            shift
            ;;
        --jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --schema-only)
            SCHEMA_ONLY=true
            shift
            ;;
        --data-only)
            DATA_ONLY=true
            shift
            ;;
        --tables)
            SPECIFIC_TABLES="$2"
            shift 2
            ;;
        --exclude-table)
            EXCLUDE_TABLES="${EXCLUDE_TABLES} -T $2"
            shift 2
            ;;
        --s3-upload)
            S3_UPLOAD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate format
validate_format() {
    case "${BACKUP_FORMAT}" in
        custom|plain|directory)
            return 0
            ;;
        *)
            log_error "Invalid format: ${BACKUP_FORMAT}"
            log_info "Valid formats: custom, plain, directory"
            exit 1
            ;;
    esac
}

# Create backup directory
create_backup_dir() {
    if [ ! -d "${OUTPUT_DIR}" ]; then
        log_info "Creating backup directory: ${OUTPUT_DIR}"
        mkdir -p "${OUTPUT_DIR}"
    fi
}

# Generate backup filename
generate_backup_filename() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    local filename="${DB_NAME}_backup_${timestamp}"

    # Add suffix based on options
    if [ "${SCHEMA_ONLY}" = true ]; then
        filename="${filename}_schema"
    elif [ "${DATA_ONLY}" = true ]; then
        filename="${filename}_data"
    fi

    # Add extension based on format
    case "${BACKUP_FORMAT}" in
        custom)
            filename="${filename}.dump"
            ;;
        plain)
            filename="${filename}.sql"
            if [ "${COMPRESS}" = true ]; then
                filename="${filename}.gz"
            fi
            ;;
        directory)
            filename="${filename}.dir"
            ;;
    esac

    echo "${filename}"
}

# Build pg_dump command
build_pgdump_command() {
    local output_file="$1"
    local pgdump_cmd="pg_dump"

    # Connection parameters
    pgdump_cmd="${pgdump_cmd} -h ${DB_HOST}"
    pgdump_cmd="${pgdump_cmd} -p ${DB_PORT}"
    pgdump_cmd="${pgdump_cmd} -U ${DB_USER}"
    pgdump_cmd="${pgdump_cmd} -d ${DB_NAME}"

    # Format
    case "${BACKUP_FORMAT}" in
        custom)
            pgdump_cmd="${pgdump_cmd} -F c"
            pgdump_cmd="${pgdump_cmd} -Z 6"  # Compression level
            ;;
        plain)
            pgdump_cmd="${pgdump_cmd} -F p"
            ;;
        directory)
            pgdump_cmd="${pgdump_cmd} -F d"
            pgdump_cmd="${pgdump_cmd} -j ${PARALLEL_JOBS}"
            ;;
    esac

    # Schema/Data options
    if [ "${SCHEMA_ONLY}" = true ]; then
        pgdump_cmd="${pgdump_cmd} --schema-only"
    elif [ "${DATA_ONLY}" = true ]; then
        pgdump_cmd="${pgdump_cmd} --data-only"
    fi

    # Specific tables
    if [ -n "${SPECIFIC_TABLES}" ]; then
        IFS=',' read -ra TABLES <<< "${SPECIFIC_TABLES}"
        for table in "${TABLES[@]}"; do
            pgdump_cmd="${pgdump_cmd} -t ${table}"
        done
    fi

    # Exclude tables
    if [ -n "${EXCLUDE_TABLES}" ]; then
        pgdump_cmd="${pgdump_cmd} ${EXCLUDE_TABLES}"
    fi

    # Output file
    pgdump_cmd="${pgdump_cmd} -f ${output_file}"

    echo "${pgdump_cmd}"
}

# Perform backup
perform_backup() {
    local backup_file="$1"
    local backup_path="${OUTPUT_DIR}/${backup_file}"

    log_info "Starting backup..."
    log_info "Database: ${DB_NAME}"
    log_info "Format: ${BACKUP_FORMAT}"
    log_info "Output: ${backup_path}"

    # Export password for pg_dump
    export PGPASSWORD="${DB_PASSWORD}"

    # Build and execute pg_dump command
    local pgdump_cmd
    pgdump_cmd=$(build_pgdump_command "${backup_path}")

    log_info "Executing: pg_dump..."

    if eval "${pgdump_cmd}"; then
        log_success "Backup created successfully"
    else
        log_error "Backup failed"
        unset PGPASSWORD
        return 1
    fi

    # Compress if needed (for plain format)
    if [ "${BACKUP_FORMAT}" = "plain" ] && [ "${COMPRESS}" = true ]; then
        log_info "Compressing backup..."
        if gzip "${backup_path}"; then
            backup_path="${backup_path}.gz"
            log_success "Backup compressed"
        else
            log_warning "Compression failed"
        fi
    fi

    unset PGPASSWORD

    # Get backup size
    local backup_size
    if [ -f "${backup_path}" ]; then
        backup_size=$(du -h "${backup_path}" | cut -f1)
        log_info "Backup size: ${backup_size}"
    elif [ -d "${backup_path}" ]; then
        backup_size=$(du -sh "${backup_path}" | cut -f1)
        log_info "Backup size: ${backup_size}"
    fi

    echo "${backup_path}"
}

# Upload to S3
upload_to_s3() {
    local backup_path="$1"

    if [ "${S3_UPLOAD}" != true ]; then
        return 0
    fi

    if [ -z "${S3_BUCKET}" ]; then
        log_warning "S3 bucket not configured, skipping upload"
        return 0
    fi

    log_info "Uploading to S3..."
    log_info "Bucket: ${S3_BUCKET}"
    log_info "Prefix: ${S3_PREFIX}"

    local backup_filename
    backup_filename=$(basename "${backup_path}")
    local s3_path="s3://${S3_BUCKET}/${S3_PREFIX}${backup_filename}"

    if command -v aws &> /dev/null; then
        if aws s3 cp "${backup_path}" "${s3_path}" --region "${AWS_REGION}"; then
            log_success "Uploaded to S3: ${s3_path}"
        else
            log_error "S3 upload failed"
            return 1
        fi
    else
        log_warning "AWS CLI not found, skipping S3 upload"
    fi
}

# Clean old backups
clean_old_backups() {
    log_info "Cleaning backups older than ${RETENTION_DAYS} days..."

    local deleted_count=0

    # Find and delete old backups
    while IFS= read -r old_backup; do
        if [ -n "${old_backup}" ]; then
            log_info "Deleting old backup: ${old_backup}"
            rm -rf "${old_backup}"
            deleted_count=$((deleted_count + 1))
        fi
    done < <(find "${OUTPUT_DIR}" -type f -name "${DB_NAME}_backup_*" -mtime +"${RETENTION_DAYS}" 2>/dev/null)

    if [ ${deleted_count} -gt 0 ]; then
        log_success "Deleted ${deleted_count} old backup(s)"
    else
        log_info "No old backups to delete"
    fi
}

# Generate backup metadata
generate_metadata() {
    local backup_path="$1"
    local metadata_file="${backup_path}.meta.json"

    log_info "Generating backup metadata..."

    local backup_size
    if [ -f "${backup_path}" ]; then
        backup_size=$(stat -f%z "${backup_path}" 2>/dev/null || stat -c%s "${backup_path}" 2>/dev/null || echo "unknown")
    elif [ -d "${backup_path}" ]; then
        backup_size=$(du -sb "${backup_path}" | cut -f1)
    else
        backup_size="unknown"
    fi

    cat > "${metadata_file}" <<EOF
{
  "database": "${DB_NAME}",
  "host": "${DB_HOST}",
  "port": ${DB_PORT},
  "backup_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "backup_file": "$(basename "${backup_path}")",
  "backup_format": "${BACKUP_FORMAT}",
  "backup_size_bytes": ${backup_size},
  "schema_only": ${SCHEMA_ONLY},
  "data_only": ${DATA_ONLY},
  "compressed": ${COMPRESS},
  "postgresql_version": "$(psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d ${DB_NAME} -t -c 'SELECT version();' | head -n1 || echo 'unknown')"
}
EOF

    log_success "Metadata saved to: ${metadata_file}"
}

# Main execution
main() {
    log_info "Database Backup Utility"
    echo

    # Validate
    validate_format

    # Create backup directory
    create_backup_dir

    # Generate backup filename
    local backup_filename
    backup_filename=$(generate_backup_filename)

    # Perform backup
    local backup_path
    backup_path=$(perform_backup "${backup_filename}")

    if [ -z "${backup_path}" ]; then
        log_error "Backup failed"
        exit 1
    fi

    # Generate metadata
    generate_metadata "${backup_path}"

    # Upload to S3
    upload_to_s3 "${backup_path}"

    # Clean old backups
    clean_old_backups

    echo
    log_success "Backup completed successfully!"
    log_info "Backup location: ${backup_path}"
}

main "$@"

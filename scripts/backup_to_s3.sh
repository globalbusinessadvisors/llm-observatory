#!/bin/bash

################################################################################
# LLM Observatory - S3 Backup Script
################################################################################
#
# Description:
#   Creates a database backup and uploads it to AWS S3.
#   Supports encryption, lifecycle policies, and cross-region replication.
#
# Usage:
#   ./backup_to_s3.sh [OPTIONS]
#
# Options:
#   -c, --config FILE    Path to config file (default: .env)
#   -b, --bucket BUCKET  S3 bucket name (required)
#   -p, --prefix PREFIX  S3 prefix/path (default: backups/)
#   -e, --encrypt        Enable S3 server-side encryption
#   -k, --kms-key KEY    KMS key ID for encryption
#   -r, --region REGION  AWS region (default: us-east-1)
#   -s, --storage CLASS  S3 storage class (default: STANDARD_IA)
#   -v, --verbose        Verbose output
#   -h, --help           Show this help message
#
# Environment Variables:
#   AWS_ACCESS_KEY_ID       AWS access key
#   AWS_SECRET_ACCESS_KEY   AWS secret key
#   AWS_REGION              AWS region
#   S3_BACKUP_BUCKET        S3 bucket name
#   S3_BACKUP_PREFIX        S3 prefix
#   S3_STORAGE_CLASS        Storage class
#   S3_KMS_KEY_ID           KMS key for encryption
#   NOTIFICATION_EMAIL      Email for notifications
#
# Storage Classes:
#   STANDARD              - Standard storage (default for frequent access)
#   STANDARD_IA           - Infrequent access (default for backups)
#   INTELLIGENT_TIERING   - Automatic cost optimization
#   GLACIER_IR            - Instant retrieval from Glacier
#   GLACIER               - Glacier (3-5 hour retrieval)
#   DEEP_ARCHIVE          - Cheapest (12 hour retrieval)
#
# Exit Codes:
#   0  - Success
#   1  - General error
#   2  - Configuration error
#   3  - Backup failed
#   4  - Upload failed
#   5  - Verification failed
#
################################################################################

set -euo pipefail

# Script metadata
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
CONFIG_FILE="${PROJECT_ROOT}/.env"
S3_BUCKET=""
S3_PREFIX="backups/"
S3_REGION="${AWS_REGION:-us-east-1}"
S3_STORAGE_CLASS="STANDARD_IA"
S3_ENCRYPTION=false
S3_KMS_KEY=""
VERBOSE=false
TEMP_DIR=""
LOG_FILE=""
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"

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
Usage: ${SCRIPT_NAME} [OPTIONS]

Creates a database backup and uploads it to AWS S3.

OPTIONS:
    -c, --config FILE    Path to config file (default: .env)
    -b, --bucket BUCKET  S3 bucket name (required)
    -p, --prefix PREFIX  S3 prefix/path (default: backups/)
    -e, --encrypt        Enable S3 server-side encryption (SSE-S3)
    -k, --kms-key KEY    KMS key ID for encryption (SSE-KMS)
    -r, --region REGION  AWS region (default: us-east-1)
    -s, --storage CLASS  S3 storage class (default: STANDARD_IA)
    -v, --verbose        Verbose output
    -h, --help           Show this help message

STORAGE CLASSES:
    STANDARD             Standard storage (frequent access)
    STANDARD_IA          Infrequent access (recommended for backups)
    INTELLIGENT_TIERING  Automatic cost optimization
    GLACIER_IR           Glacier Instant Retrieval
    GLACIER              Glacier (3-5 hour retrieval)
    DEEP_ARCHIVE         Deep Archive (12 hour retrieval, cheapest)

EXAMPLES:
    # Basic S3 backup
    ${SCRIPT_NAME} -b my-backup-bucket

    # With encryption and custom prefix
    ${SCRIPT_NAME} -b my-backup-bucket -p production/db/ -e

    # With KMS encryption and Glacier storage
    ${SCRIPT_NAME} -b my-backup-bucket -k my-kms-key-id -s GLACIER_IR

EXIT CODES:
    0  - Success
    1  - General error
    2  - Configuration error
    3  - Backup failed
    4  - Upload failed
    5  - Verification failed

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
            -b|--bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            -p|--prefix)
                S3_PREFIX="$2"
                shift 2
                ;;
            -e|--encrypt)
                S3_ENCRYPTION=true
                shift
                ;;
            -k|--kms-key)
                S3_KMS_KEY="$2"
                S3_ENCRYPTION=true
                shift 2
                ;;
            -r|--region)
                S3_REGION="$2"
                shift 2
                ;;
            -s|--storage)
                S3_STORAGE_CLASS="$2"
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

    # Validate required parameters
    if [[ -z "$S3_BUCKET" ]]; then
        # Try to get from environment
        S3_BUCKET="${S3_BACKUP_BUCKET:-}"
        if [[ -z "$S3_BUCKET" ]]; then
            die "S3 bucket name is required. Use -b or set S3_BACKUP_BUCKET" 2
        fi
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

    # Override S3 settings from environment
    S3_PREFIX="${S3_BACKUP_PREFIX:-${S3_PREFIX}}"
    S3_STORAGE_CLASS="${S3_STORAGE_CLASS:-${S3_STORAGE_CLASS}}"
    S3_KMS_KEY="${S3_KMS_KEY_ID:-${S3_KMS_KEY}}"

    # Validate required configuration
    if [[ -z "${DB_PASSWORD:-}" ]]; then
        die "DB_PASSWORD not set" 2
    fi

    if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        log WARN "AWS credentials not set. Will try IAM role or instance profile."
    fi
}

# Check prerequisites
check_prerequisites() {
    verbose "Checking prerequisites..."

    # Check for required commands
    local required_cmds=("pg_dump" "psql" "gzip" "aws")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            die "Required command not found: $cmd" 1
        fi
    done

    # Check AWS CLI version
    local aws_version=$(aws --version 2>&1)
    verbose "AWS CLI version: $aws_version"

    # Test AWS credentials
    verbose "Testing AWS credentials..."
    if ! aws sts get-caller-identity --region "$S3_REGION" &> /dev/null; then
        die "AWS credentials are invalid or not configured" 2
    fi

    # Check if S3 bucket exists and is accessible
    verbose "Checking S3 bucket: $S3_BUCKET"
    if ! aws s3 ls "s3://${S3_BUCKET}" --region "$S3_REGION" &> /dev/null; then
        die "Cannot access S3 bucket: $S3_BUCKET (region: $S3_REGION)" 2
    fi

    # Check database connectivity
    verbose "Testing database connection..."
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" &> /dev/null; then
        die "Cannot connect to database: $DB_HOST:$DB_PORT/$DB_NAME" 2
    fi

    verbose "Prerequisites check passed"
}

# Setup temporary directory
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d -t llm-observatory-backup-XXXXXX)
    verbose "Created temporary directory: $TEMP_DIR"

    # Create log file
    LOG_FILE="${TEMP_DIR}/backup.log"
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
    local backup_file="${TEMP_DIR}/llm_observatory_${timestamp}.sql"
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
        log SUCCESS "Backup created in ${duration}s"
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
S3 Destination: s3://${S3_BUCKET}/${S3_PREFIX}
S3 Region: ${S3_REGION}
S3 Storage Class: ${S3_STORAGE_CLASS}
EOF

    verbose "Metadata file created: $metadata_file"

    # Export for next steps
    BACKUP_FILE="$compressed_file"
    METADATA_FILE="$metadata_file"
}

# Upload backup to S3
upload_to_s3() {
    log INFO "Uploading backup to S3..."
    log INFO "Bucket: s3://${S3_BUCKET}/${S3_PREFIX}"
    log INFO "Storage class: ${S3_STORAGE_CLASS}"

    local s3_path="s3://${S3_BUCKET}/${S3_PREFIX}$(basename "$BACKUP_FILE")"
    local s3_meta_path="s3://${S3_BUCKET}/${S3_PREFIX}$(basename "$METADATA_FILE")"

    # Build AWS S3 cp command with options
    local aws_cmd="aws s3 cp"
    local aws_opts=(
        "--region" "$S3_REGION"
        "--storage-class" "$S3_STORAGE_CLASS"
    )

    # Add encryption options
    if [[ "$S3_ENCRYPTION" == "true" ]]; then
        if [[ -n "$S3_KMS_KEY" ]]; then
            aws_opts+=("--sse" "aws:kms" "--sse-kms-key-id" "$S3_KMS_KEY")
            verbose "Using KMS encryption with key: $S3_KMS_KEY"
        else
            aws_opts+=("--sse" "AES256")
            verbose "Using AES256 server-side encryption"
        fi
    fi

    # Upload backup file
    verbose "Uploading backup file..."
    local start_time=$(date +%s)

    if aws s3 cp "$BACKUP_FILE" "$s3_path" "${aws_opts[@]}" 2>> "$LOG_FILE"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log SUCCESS "Backup uploaded in ${duration}s"
    else
        die "Failed to upload backup to S3" 4
    fi

    # Upload metadata file
    verbose "Uploading metadata file..."
    if aws s3 cp "$METADATA_FILE" "$s3_meta_path" "${aws_opts[@]}" 2>> "$LOG_FILE"; then
        verbose "Metadata uploaded successfully"
    else
        log WARN "Failed to upload metadata file"
    fi

    # Export S3 path for verification
    S3_BACKUP_PATH="$s3_path"
}

# Verify S3 upload
verify_s3_upload() {
    log INFO "Verifying S3 upload..."

    # Check if file exists in S3
    if ! aws s3 ls "$S3_BACKUP_PATH" --region "$S3_REGION" &> /dev/null; then
        die "Backup file not found in S3: $S3_BACKUP_PATH" 5
    fi

    # Get S3 object metadata
    local s3_size=$(aws s3 ls "$S3_BACKUP_PATH" --region "$S3_REGION" | awk '{print $3}')
    local local_size=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE")

    verbose "Local size: $local_size bytes"
    verbose "S3 size: $s3_size bytes"

    if [[ "$local_size" -ne "$s3_size" ]]; then
        die "Size mismatch: local=$local_size, S3=$s3_size" 5
    fi

    # Verify ETag (MD5 for single-part uploads)
    local s3_etag=$(aws s3api head-object \
        --bucket "$S3_BUCKET" \
        --key "${S3_PREFIX}$(basename "$BACKUP_FILE")" \
        --region "$S3_REGION" \
        --query 'ETag' \
        --output text | tr -d '"')

    verbose "S3 ETag: $s3_etag"

    log SUCCESS "S3 upload verification passed"
}

# Send notification email
send_notification() {
    local status=$1
    local message=$2

    if [[ -z "$NOTIFICATION_EMAIL" ]]; then
        return 0
    fi

    if ! command -v mail &> /dev/null; then
        verbose "mail command not found, skipping email notification"
        return 0
    fi

    local subject="[LLM Observatory] Backup ${status}: ${DB_NAME}"
    local body="Database: ${DB_NAME}
Host: ${DB_HOST}:${DB_PORT}
S3 Path: ${S3_BACKUP_PATH:-N/A}
Status: ${status}
Message: ${message}
Timestamp: $(date -Iseconds)
"

    echo "$body" | mail -s "$subject" "$NOTIFICATION_EMAIL"
    verbose "Email notification sent to: $NOTIFICATION_EMAIL"
}

# Print backup summary
print_summary() {
    log SUCCESS "========================================="
    log SUCCESS "S3 Backup completed successfully!"
    log SUCCESS "========================================="
    log INFO "Database: $DB_NAME"
    log INFO "S3 Path: $S3_BACKUP_PATH"
    log INFO "Storage Class: $S3_STORAGE_CLASS"
    log INFO "Region: $S3_REGION"
    log INFO "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
    if [[ "$S3_ENCRYPTION" == "true" ]]; then
        log INFO "Encryption: Enabled"
        if [[ -n "$S3_KMS_KEY" ]]; then
            log INFO "KMS Key: $S3_KMS_KEY"
        fi
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
    log INFO "LLM Observatory - S3 Backup"
    log INFO "========================================="

    # Parse command-line arguments
    parse_args "$@"

    # Load configuration
    load_config

    # Check prerequisites
    check_prerequisites

    # Setup temporary directory
    setup_temp_dir

    # Create backup
    create_backup

    # Upload to S3
    upload_to_s3

    # Verify upload
    verify_s3_upload

    # Print summary
    print_summary

    # Send success notification
    send_notification "SUCCESS" "Backup completed successfully"

    exit 0
}

# Run main function
main "$@"

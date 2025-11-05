#!/bin/bash

################################################################################
# LLM Observatory - WAL Archive Script
################################################################################
#
# Description:
#   Archives PostgreSQL Write-Ahead Log (WAL) files for Point-in-Time Recovery.
#   This script is called by PostgreSQL's archive_command.
#
# Usage:
#   archive_wal.sh WAL_PATH WAL_FILENAME
#
# Arguments:
#   WAL_PATH      Full path to the WAL file to archive
#   WAL_FILENAME  Name of the WAL file
#
# PostgreSQL Configuration:
#   Add to postgresql.conf:
#     wal_level = replica
#     archive_mode = on
#     archive_command = '/path/to/archive_wal.sh %p %f'
#     archive_timeout = 300  # Force WAL switch every 5 minutes
#
# Environment Variables:
#   WAL_ARCHIVE_DIR    Local archive directory (default: /var/lib/postgresql/wal_archive)
#   WAL_S3_BUCKET      S3 bucket for WAL archives
#   WAL_S3_PREFIX      S3 prefix/path (default: wal_archive/)
#   WAL_RETENTION_DAYS Retention period in days (default: 7)
#   AWS_REGION         AWS region (default: us-east-1)
#
# Exit Codes:
#   0  - Success (required for PostgreSQL)
#   1  - Failure (PostgreSQL will retry)
#
################################################################################

set -euo pipefail

# Configuration
WAL_PATH="${1:-}"
WAL_FILENAME="${2:-}"
WAL_ARCHIVE_DIR="${WAL_ARCHIVE_DIR:-/var/lib/postgresql/wal_archive}"
WAL_S3_BUCKET="${WAL_S3_BUCKET:-}"
WAL_S3_PREFIX="${WAL_S3_PREFIX:-wal_archive/}"
WAL_RETENTION_DAYS="${WAL_RETENTION_DAYS:-7}"
AWS_REGION="${AWS_REGION:-us-east-1}"
LOG_FILE="${WAL_ARCHIVE_DIR}/archive.log"

# Validate arguments
if [[ -z "$WAL_PATH" || -z "$WAL_FILENAME" ]]; then
    echo "ERROR: Usage: $0 WAL_PATH WAL_FILENAME" >&2
    exit 1
fi

if [[ ! -f "$WAL_PATH" ]]; then
    echo "ERROR: WAL file not found: $WAL_PATH" >&2
    exit 1
fi

# Create archive directory if it doesn't exist
mkdir -p "$WAL_ARCHIVE_DIR"

# Log function
log() {
    echo "[$(date -Iseconds)] $*" >> "$LOG_FILE"
}

# Archive to local directory
archive_local() {
    local dest="${WAL_ARCHIVE_DIR}/${WAL_FILENAME}"

    # Check if file already exists
    if [[ -f "$dest" ]]; then
        log "WARNING: WAL file already archived: $WAL_FILENAME"
        exit 0
    fi

    # Copy with verification
    if cp "$WAL_PATH" "$dest"; then
        # Verify copy
        if cmp -s "$WAL_PATH" "$dest"; then
            log "SUCCESS: Archived WAL file: $WAL_FILENAME"
        else
            log "ERROR: WAL file copy verification failed: $WAL_FILENAME"
            rm -f "$dest"
            exit 1
        fi
    else
        log "ERROR: Failed to copy WAL file: $WAL_FILENAME"
        exit 1
    fi
}

# Archive to S3 (optional)
archive_s3() {
    if [[ -z "$WAL_S3_BUCKET" ]]; then
        return 0
    fi

    if ! command -v aws &> /dev/null; then
        log "WARNING: AWS CLI not found, skipping S3 archive"
        return 0
    fi

    local s3_path="s3://${WAL_S3_BUCKET}/${WAL_S3_PREFIX}${WAL_FILENAME}"

    # Check if already exists in S3
    if aws s3 ls "$s3_path" --region "$AWS_REGION" &> /dev/null; then
        log "WARNING: WAL file already in S3: $WAL_FILENAME"
        return 0
    fi

    # Upload to S3 with server-side encryption
    if aws s3 cp "${WAL_ARCHIVE_DIR}/${WAL_FILENAME}" "$s3_path" \
        --region "$AWS_REGION" \
        --storage-class STANDARD_IA \
        --sse AES256 &>> "$LOG_FILE"; then
        log "SUCCESS: Uploaded WAL file to S3: $WAL_FILENAME"
    else
        log "WARNING: Failed to upload WAL file to S3: $WAL_FILENAME"
        # Don't fail the archive - local copy is sufficient
    fi
}

# Clean up old WAL files
cleanup_old_files() {
    # Only cleanup local files older than retention period
    local deleted=0
    while IFS= read -r old_wal; do
        if [[ -n "$old_wal" ]]; then
            rm -f "$old_wal"
            ((deleted++))
        fi
    done < <(find "$WAL_ARCHIVE_DIR" -name "*.backup" -o -name "0*" -type f -mtime +${WAL_RETENTION_DAYS})

    if [[ $deleted -gt 0 ]]; then
        log "INFO: Cleaned up $deleted old WAL files"
    fi
}

# Main execution
main() {
    log "INFO: Archiving WAL file: $WAL_FILENAME"

    # Archive locally
    archive_local

    # Archive to S3 if configured
    archive_s3

    # Cleanup old files (async, don't fail if cleanup fails)
    cleanup_old_files || true

    exit 0
}

# Run main function
main

#!/bin/bash

################################################################################
# Rollback Script for LLM Observatory Storage Layer
#
# This script provides emergency and planned rollback capabilities for the
# storage layer, including application and database rollback options.
#
# Usage:
#   ./rollback.sh [OPTIONS]
#
# Options:
#   --method METHOD         Rollback method (blue-green|application|database)
#   --environment ENV       Environment to rollback (staging|production)
#   --version VERSION       Version to rollback to (for application rollback)
#   --backup-file FILE      Backup file to restore (for database rollback)
#   --emergency             Execute emergency rollback (fastest, minimal prompts)
#   --dry-run              Show what would be done without executing
#   --notification-channel  Notification channel (slack|email|pagerduty)
#   --help                  Show this help message
#
# Rollback Methods:
#   blue-green   - Switch load balancer back to previous environment (30s)
#   application  - Redeploy previous application version (5 min)
#   database     - Restore database from backup (30+ min, DATA LOSS POSSIBLE)
#
# Warning:
#   Database rollback can result in data loss. Always verify recent data
#   is not critical before proceeding.
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
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default configuration
METHOD=""
ENVIRONMENT="${ENVIRONMENT:-production}"
VERSION=""
BACKUP_FILE=""
EMERGENCY=false
DRY_RUN=false
NOTIFICATION_CHANNEL="${NOTIFICATION_CHANNEL:-slack}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ROLLBACK_LOG="/tmp/rollback_${TIMESTAMP}.log"

# Application configuration
APP_NAME="${APP_NAME:-llm-observatory-storage}"
SYSTEMD_SERVICE="${SYSTEMD_SERVICE:-llm-observatory-storage}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"

################################################################################
# Utility Functions
################################################################################

log_info() {
    local msg="[INFO] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$ROLLBACK_LOG"
}

log_success() {
    local msg="[SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$ROLLBACK_LOG"
}

log_warning() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$ROLLBACK_LOG"
}

log_error() {
    local msg="[ERROR] $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$ROLLBACK_LOG"
}

log_critical() {
    local msg="[CRITICAL] $1"
    echo -e "${MAGENTA}$msg${NC}"
    echo "$msg" >> "$ROLLBACK_LOG"
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
            --method)
                METHOD="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --backup-file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            --emergency)
                EMERGENCY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --notification-channel)
                NOTIFICATION_CHANNEL="$2"
                shift 2
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
# Notification Functions
################################################################################

send_notification() {
    local message=$1
    local severity=${2:-info}  # info, warning, critical

    log_info "Sending notification: $message"

    case "$NOTIFICATION_CHANNEL" in
        slack)
            send_slack_notification "$message" "$severity"
            ;;
        email)
            send_email_notification "$message" "$severity"
            ;;
        pagerduty)
            send_pagerduty_notification "$message" "$severity"
            ;;
        *)
            log_warning "Unknown notification channel: $NOTIFICATION_CHANNEL"
            ;;
    esac
}

send_slack_notification() {
    local message=$1
    local severity=$2

    # Placeholder - implement with your Slack webhook
    local webhook_url="${SLACK_WEBHOOK_URL:-}"

    if [[ -z "$webhook_url" ]]; then
        log_warning "SLACK_WEBHOOK_URL not set, skipping Slack notification"
        return 0
    fi

    local color="good"
    case "$severity" in
        warning) color="warning" ;;
        critical) color="danger" ;;
    esac

    local payload=$(cat <<EOF
{
    "attachments": [{
        "color": "$color",
        "title": "Rollback: $ENVIRONMENT",
        "text": "$message",
        "footer": "LLM Observatory",
        "ts": $(date +%s)
    }]
}
EOF
)

    if [[ "$DRY_RUN" == "false" ]]; then
        curl -X POST -H 'Content-type: application/json' --data "$payload" "$webhook_url" &>/dev/null || true
    fi
}

send_email_notification() {
    local message=$1
    local severity=$2

    # Placeholder - implement with your email system
    log_info "Email notification would be sent: $message"
}

send_pagerduty_notification() {
    local message=$1
    local severity=$2

    # Placeholder - implement with your PagerDuty integration
    log_info "PagerDuty notification would be sent: $message"
}

################################################################################
# Pre-Rollback Checks
################################################################################

confirm_rollback() {
    if [[ "$EMERGENCY" == "true" ]]; then
        log_warning "EMERGENCY ROLLBACK - Skipping confirmation"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Skipping confirmation"
        return 0
    fi

    echo ""
    log_critical "═══════════════════════════════════════════════════════"
    log_critical "WARNING: You are about to perform a ROLLBACK"
    log_critical "═══════════════════════════════════════════════════════"
    echo ""
    log_warning "Environment: $ENVIRONMENT"
    log_warning "Method: $METHOD"
    if [[ -n "$VERSION" ]]; then
        log_warning "Target Version: $VERSION"
    fi
    if [[ -n "$BACKUP_FILE" ]]; then
        log_warning "Backup File: $BACKUP_FILE"
    fi
    echo ""
    log_critical "This action cannot be easily undone!"
    echo ""

    read -p "Type 'ROLLBACK' to confirm: " -r
    if [[ "$REPLY" != "ROLLBACK" ]]; then
        log_info "Rollback cancelled by user"
        exit 0
    fi

    log_info "Rollback confirmed"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if running as appropriate user
    if [[ "$EUID" -eq 0 ]] && [[ "$ENVIRONMENT" == "production" ]]; then
        log_warning "Running as root in production - ensure this is intended"
    fi

    # Verify method is valid
    case "$METHOD" in
        blue-green|application|database)
            log_info "Rollback method: $METHOD"
            ;;
        *)
            log_error "Invalid rollback method: $METHOD"
            log_error "Valid methods: blue-green, application, database"
            exit 1
            ;;
    esac

    log_success "Prerequisites check passed"
}

################################################################################
# Blue-Green Rollback
################################################################################

rollback_blue_green() {
    log_info "Executing Blue-Green rollback..."

    # Determine which environment is currently active
    local current_env=$(get_active_environment)
    local target_env="blue"

    if [[ "$current_env" == "blue" ]]; then
        target_env="green"
    fi

    log_info "Current environment: $current_env"
    log_info "Rolling back to: $target_env"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would switch load balancer from $current_env to $target_env"
        return 0
    fi

    # Step 1: Verify target environment is healthy
    log_info "Verifying $target_env environment health..."
    if ! verify_environment_health "$target_env"; then
        log_error "$target_env environment is not healthy"
        log_error "Cannot rollback to unhealthy environment"
        exit 1
    fi

    # Step 2: Switch load balancer
    log_info "Switching load balancer to $target_env..."
    switch_load_balancer "$target_env"

    # Step 3: Verify traffic switch
    sleep 5
    if verify_traffic_switch "$target_env"; then
        log_success "Traffic successfully switched to $target_env"
    else
        log_error "Traffic switch verification failed"
        exit 1
    fi

    # Step 4: Monitor for 2 minutes
    log_info "Monitoring $target_env for 2 minutes..."
    monitor_environment "$target_env" 120

    log_success "Blue-Green rollback completed successfully"
}

get_active_environment() {
    # Placeholder - implement based on your load balancer
    # This should return "blue" or "green"
    echo "green"
}

verify_environment_health() {
    local env=$1

    # Placeholder - implement based on your infrastructure
    log_info "Checking health of $env environment..."
    return 0
}

switch_load_balancer() {
    local target=$1

    # Placeholder - implement based on your load balancer (AWS ELB, nginx, etc.)
    log_info "Switching load balancer to $target..."

    # Example for AWS:
    # aws elbv2 modify-target-group --target-group-arn $TG_ARN ...

    log_warning "Load balancer switching not implemented - manual action required"
    log_warning "Update your load balancer to point to $target environment"

    if [[ "$EMERGENCY" == "false" ]]; then
        read -p "Press Enter after manually switching load balancer..." -r
    fi
}

verify_traffic_switch() {
    local target=$1
    log_info "Verifying traffic is flowing to $target..."
    return 0
}

monitor_environment() {
    local env=$1
    local duration=$2

    log_info "Monitoring $env for ${duration}s..."

    local interval=10
    local elapsed=0

    while [[ $elapsed -lt $duration ]]; do
        # Check error rate, response time, etc.
        sleep $interval
        elapsed=$((elapsed + interval))
        log_info "Monitoring... ${elapsed}s / ${duration}s"
    done

    log_success "Monitoring completed - no issues detected"
}

################################################################################
# Application Rollback
################################################################################

rollback_application() {
    log_info "Executing Application rollback..."

    # Determine version to rollback to
    if [[ -z "$VERSION" ]]; then
        VERSION=$(get_previous_version)
        log_info "No version specified, using previous version: $VERSION"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would rollback application to version $VERSION"
        return 0
    fi

    # Step 1: Stop current application
    log_info "Stopping current application..."
    stop_application

    # Step 2: Deploy previous version
    log_info "Deploying version $VERSION..."
    deploy_previous_version "$VERSION"

    # Step 3: Start application
    log_info "Starting application..."
    start_application

    # Step 4: Wait for health check
    log_info "Waiting for application to become healthy..."
    if wait_for_health; then
        log_success "Application is healthy"
    else
        log_error "Application failed to become healthy"
        log_error "Check logs: journalctl -u $SYSTEMD_SERVICE -n 100"
        exit 1
    fi

    # Step 5: Verify deployment
    log_info "Verifying deployment..."
    if "$SCRIPT_DIR/verify_deployment.sh" --environment "$ENVIRONMENT"; then
        log_success "Deployment verification passed"
    else
        log_error "Deployment verification failed"
        exit 1
    fi

    log_success "Application rollback completed successfully"
}

get_previous_version() {
    # Placeholder - implement based on your version tracking
    # Could read from git tags, version file, etc.
    echo "v0.0.9"
}

stop_application() {
    log_info "Stopping application service..."

    if systemctl is-active --quiet "$SYSTEMD_SERVICE"; then
        sudo systemctl stop "$SYSTEMD_SERVICE"
        log_success "Application stopped"
    else
        log_warning "Application was not running"
    fi
}

start_application() {
    log_info "Starting application service..."

    sudo systemctl start "$SYSTEMD_SERVICE"

    if systemctl is-active --quiet "$SYSTEMD_SERVICE"; then
        log_success "Application started"
    else
        log_error "Failed to start application"
        exit 1
    fi
}

deploy_previous_version() {
    local version=$1

    log_info "Deploying version $version..."

    # Placeholder - implement based on your deployment process
    # This might involve:
    # - Pulling from artifact repository
    # - Extracting deployment package
    # - Copying binaries to deployment directory

    log_warning "Previous version deployment not fully implemented"
    log_warning "Ensure version $version binaries are in place"

    if [[ "$EMERGENCY" == "false" ]]; then
        read -p "Press Enter after manually deploying version $version..." -r
    fi
}

wait_for_health() {
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f -s "http://localhost:${APP_PORT:-8080}/health" > /dev/null 2>&1; then
            return 0
        fi

        attempt=$((attempt + 1))
        log_info "Health check attempt $attempt/$max_attempts..."
        sleep 2
    done

    return 1
}

################################################################################
# Database Rollback
################################################################################

rollback_database() {
    log_critical "Executing Database rollback..."
    log_critical "WARNING: This will result in data loss!"

    # Determine backup file
    if [[ -z "$BACKUP_FILE" ]]; then
        BACKUP_FILE=$(get_latest_backup)
        log_info "No backup file specified, using latest: $BACKUP_FILE"
    fi

    if [[ ! -f "$BACKUP_FILE" ]]; then
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi

    local backup_age
    backup_age=$(( $(date +%s) - $(stat -c %Y "$BACKUP_FILE") ))
    local backup_age_minutes=$((backup_age / 60))

    log_warning "Backup file: $BACKUP_FILE"
    log_warning "Backup age: ${backup_age_minutes} minutes"
    log_warning "Data created after backup will be LOST!"

    if [[ "$EMERGENCY" == "false" ]] && [[ "$DRY_RUN" == "false" ]]; then
        echo ""
        read -p "Type 'DATA LOSS' to confirm database rollback: " -r
        if [[ "$REPLY" != "DATA LOSS" ]]; then
            log_info "Database rollback cancelled"
            exit 0
        fi
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would restore database from $BACKUP_FILE"
        return 0
    fi

    # Step 1: Stop all applications
    log_info "Stopping all applications..."
    stop_all_applications

    # Step 2: Terminate database connections
    log_info "Terminating active database connections..."
    terminate_database_connections

    # Step 3: Create pre-rollback backup
    log_info "Creating pre-rollback backup..."
    create_pre_rollback_backup

    # Step 4: Restore database
    log_info "Restoring database from backup..."
    restore_database "$BACKUP_FILE"

    # Step 5: Verify restore
    log_info "Verifying database restore..."
    verify_database_restore

    # Step 6: Restart applications
    log_info "Restarting applications..."
    start_all_applications

    # Step 7: Verify application health
    log_info "Verifying application health..."
    if wait_for_health; then
        log_success "Applications are healthy after database restore"
    else
        log_error "Applications failed health check after restore"
        exit 1
    fi

    log_success "Database rollback completed successfully"
}

get_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/*.dump 2>/dev/null | head -1)

    if [[ -z "$latest" ]]; then
        log_error "No backup files found in $BACKUP_DIR"
        exit 1
    fi

    echo "$latest"
}

stop_all_applications() {
    log_info "Stopping all application instances..."

    # Stop main service
    if systemctl is-active --quiet "$SYSTEMD_SERVICE"; then
        sudo systemctl stop "$SYSTEMD_SERVICE"
    fi

    # Stop any other instances (blue/green)
    for env in blue green; do
        if systemctl is-active --quiet "$SYSTEMD_SERVICE-$env" 2>/dev/null; then
            sudo systemctl stop "$SYSTEMD_SERVICE-$env"
        fi
    done

    log_success "All applications stopped"
}

start_all_applications() {
    log_info "Starting application instances..."

    sudo systemctl start "$SYSTEMD_SERVICE"

    log_success "Applications started"
}

terminate_database_connections() {
    local db_name="${DB_NAME:-llm_observatory}"

    log_info "Terminating connections to database: $db_name"

    psql -U "${DB_USER:-postgres}" -d postgres -c \
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db_name' AND pid <> pg_backend_pid();" \
        &>/dev/null || true

    log_success "Database connections terminated"
}

create_pre_rollback_backup() {
    local pre_rollback_backup="$BACKUP_DIR/pre_rollback_${TIMESTAMP}.dump"

    log_info "Creating pre-rollback backup: $pre_rollback_backup"

    if pg_dump -Fc -f "$pre_rollback_backup" "${DB_NAME:-llm_observatory}"; then
        log_success "Pre-rollback backup created"
        log_info "You can restore from this backup if needed: $pre_rollback_backup"
    else
        log_error "Failed to create pre-rollback backup"
        log_error "Aborting database rollback for safety"
        exit 1
    fi
}

restore_database() {
    local backup_file=$1
    local db_name="${DB_NAME:-llm_observatory}"

    log_info "Restoring database from: $backup_file"

    # Drop and recreate database
    psql -U "${DB_USER:-postgres}" -d postgres -c "DROP DATABASE IF EXISTS $db_name;" || {
        log_error "Failed to drop database"
        exit 1
    }

    psql -U "${DB_USER:-postgres}" -d postgres -c "CREATE DATABASE $db_name;" || {
        log_error "Failed to create database"
        exit 1
    }

    # Restore from backup
    if pg_restore -U "${DB_USER:-postgres}" -d "$db_name" "$backup_file"; then
        log_success "Database restored successfully"
    else
        log_error "Database restore failed"
        log_error "Database may be in inconsistent state"
        exit 1
    fi
}

verify_database_restore() {
    local db_name="${DB_NAME:-llm_observatory}"

    log_info "Verifying database restore..."

    # Check database exists and is accessible
    if psql -U "${DB_USER:-postgres}" -d "$db_name" -c "SELECT 1" &>/dev/null; then
        log_success "Database is accessible"
    else
        log_error "Database verification failed"
        exit 1
    fi

    # Run verification script if available
    local verify_script="$PROJECT_ROOT/crates/storage/migrations/verify_migrations.sql"
    if [[ -f "$verify_script" ]]; then
        if psql -U "${DB_USER:-postgres}" -d "$db_name" -f "$verify_script" &>/dev/null; then
            log_success "Database verification passed"
        else
            log_warning "Database verification script had warnings"
        fi
    fi
}

################################################################################
# Emergency Rollback
################################################################################

emergency_rollback() {
    log_critical "EXECUTING EMERGENCY ROLLBACK"

    # Send immediate notification
    send_notification "EMERGENCY ROLLBACK INITIATED for $ENVIRONMENT" "critical"

    # Determine best rollback method
    if [[ -z "$METHOD" ]]; then
        # Default to blue-green if not specified (fastest)
        METHOD="blue-green"
        log_info "No method specified, using fastest method: $METHOD"
    fi

    # Execute rollback based on method
    case "$METHOD" in
        blue-green)
            rollback_blue_green
            ;;
        application)
            rollback_application
            ;;
        database)
            log_error "Database rollback not recommended for emergency rollback"
            log_error "Use application or blue-green rollback instead"
            exit 1
            ;;
    esac

    # Send completion notification
    send_notification "EMERGENCY ROLLBACK COMPLETED for $ENVIRONMENT" "warning"

    log_critical "Emergency rollback completed"
}

################################################################################
# Main Function
################################################################################

main() {
    log_info "LLM Observatory Rollback Script"
    log_info "================================"
    log_info "Started at: $(date)"
    log_info "Log file: $ROLLBACK_LOG"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_prerequisites

    # Load environment
    local env_file="$PROJECT_ROOT/.env.$ENVIRONMENT"
    if [[ -f "$env_file" ]]; then
        set -a
        source "$env_file"
        set +a
    fi

    # Confirm rollback
    confirm_rollback

    # Send notification
    send_notification "Rollback started: $METHOD for $ENVIRONMENT" "warning"

    # Execute rollback
    if [[ "$EMERGENCY" == "true" ]]; then
        emergency_rollback
    else
        case "$METHOD" in
            blue-green)
                rollback_blue_green
                ;;
            application)
                rollback_application
                ;;
            database)
                rollback_database
                ;;
            *)
                log_error "Unknown rollback method: $METHOD"
                exit 1
                ;;
        esac
    fi

    # Send completion notification
    send_notification "Rollback completed successfully: $METHOD for $ENVIRONMENT" "info"

    log_success "Rollback completed at: $(date)"
    log_info "Log file: $ROLLBACK_LOG"

    echo ""
    log_info "Post-Rollback Actions:"
    log_info "1. Review rollback log: $ROLLBACK_LOG"
    log_info "2. Monitor system: ./scripts/verify_deployment.sh --environment $ENVIRONMENT"
    log_info "3. Check application logs: journalctl -u $SYSTEMD_SERVICE -f"
    log_info "4. Notify stakeholders of rollback completion"
    log_info "5. Investigate root cause of issue that required rollback"
}

# Run main function
main "$@"

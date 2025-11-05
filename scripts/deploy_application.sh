#!/bin/bash

################################################################################
# Application Deployment Script for LLM Observatory Storage Layer
#
# This script deploys the storage layer application with support for multiple
# deployment strategies including blue-green, canary, and rolling updates.
#
# Usage:
#   ./deploy_application.sh [OPTIONS]
#
# Options:
#   --environment ENV          Environment to deploy to (staging|production)
#   --version VERSION          Version to deploy (e.g., v0.1.0)
#   --strategy STRATEGY        Deployment strategy (blue-green|canary|rolling)
#   --target TARGET            Deployment target (blue|green) for blue-green
#   --canary-percentage PCT    Percentage for canary deployment (5|25|50|100)
#   --batch-size SIZE          Batch size for rolling updates (default: 1)
#   --health-check-timeout SEC Timeout for health checks (default: 60)
#   --dry-run                  Show what would be done without executing
#   --skip-tests               Skip pre-deployment tests
#   --help                     Show this help message
#
# Environment Variables:
#   APP_NAME                   Application name (default: llm-observatory-storage)
#   APP_PORT                   Application port (default: 8080)
#   METRICS_PORT              Metrics port (default: 9090)
#   BUILD_DIR                  Build directory (default: target/release)
#   DEPLOY_DIR                Deployment directory (default: /opt/llm-observatory)
#   SYSTEMD_SERVICE           Systemd service name
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
VERSION=""
STRATEGY="blue-green"
TARGET=""
CANARY_PERCENTAGE=5
BATCH_SIZE=1
HEALTH_CHECK_TIMEOUT=60
DRY_RUN=false
SKIP_TESTS=false

# Application configuration
APP_NAME="${APP_NAME:-llm-observatory-storage}"
APP_PORT="${APP_PORT:-8080}"
METRICS_PORT="${METRICS_PORT:-9090}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/target/release}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/llm-observatory}"
SYSTEMD_SERVICE="${SYSTEMD_SERVICE:-llm-observatory-storage}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

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
            --version)
                VERSION="$2"
                shift 2
                ;;
            --strategy)
                STRATEGY="$2"
                shift 2
                ;;
            --target)
                TARGET="$2"
                shift 2
                ;;
            --canary-percentage)
                CANARY_PERCENTAGE="$2"
                shift 2
                ;;
            --batch-size)
                BATCH_SIZE="$2"
                shift 2
                ;;
            --health-check-timeout)
                HEALTH_CHECK_TIMEOUT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
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

    # Validate required arguments
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required. Use --version v0.1.0"
        exit 1
    fi
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

    log_success "Environment loaded: $ENVIRONMENT"
}

################################################################################
# Pre-deployment Checks
################################################################################

check_dependencies() {
    log_info "Checking dependencies..."

    local deps=("cargo" "systemctl" "curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' not found"
            exit 1
        fi
    done

    log_success "All dependencies found"
}

check_build_artifacts() {
    log_info "Checking build artifacts..."

    local binary="$BUILD_DIR/$APP_NAME"

    if [[ ! -f "$binary" ]]; then
        log_error "Binary not found: $binary"
        log_error "Run 'cargo build --release' first"
        exit 1
    fi

    log_success "Build artifacts found"
    log_info "Binary: $binary"
    log_info "Size: $(du -h "$binary" | cut -f1)"
}

run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log_warning "Skipping tests as requested"
        return 0
    fi

    log_info "Running pre-deployment tests..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: cargo test --release"
        return 0
    fi

    cd "$PROJECT_ROOT"

    if cargo test --release --package llm-observatory-storage -- --test-threads=1; then
        log_success "All tests passed"
    else
        log_error "Tests failed. Fix issues before deploying."
        exit 1
    fi
}

verify_database_connection() {
    log_info "Verifying database connection..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would verify database connection"
        return 0
    fi

    # Test database connection using psql
    if psql -h "${DB_HOST:-localhost}" -U "${DB_USER:-postgres}" -d "${DB_NAME:-llm_observatory}" -c "SELECT 1" &> /dev/null; then
        log_success "Database connection verified"
    else
        log_error "Failed to connect to database"
        log_error "Ensure database is running and migrations are applied"
        exit 1
    fi
}

################################################################################
# Build and Package
################################################################################

build_application() {
    log_info "Building application for release..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: cargo build --release"
        return 0
    fi

    cd "$PROJECT_ROOT"

    if cargo build --release --package llm-observatory-storage; then
        log_success "Build completed successfully"
    else
        log_error "Build failed"
        exit 1
    fi
}

create_deployment_package() {
    log_info "Creating deployment package..."

    local package_dir="$PROJECT_ROOT/deploy/$APP_NAME-$VERSION"
    local package_file="$PROJECT_ROOT/deploy/$APP_NAME-$VERSION.tar.gz"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create package: $package_file"
        return 0
    fi

    # Create package directory
    mkdir -p "$package_dir/bin"
    mkdir -p "$package_dir/config"
    mkdir -p "$package_dir/scripts"

    # Copy binary
    cp "$BUILD_DIR/$APP_NAME" "$package_dir/bin/"

    # Copy configuration files
    if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
        cp "$PROJECT_ROOT/.env.example" "$package_dir/config/"
    fi

    # Copy systemd service file if exists
    if [[ -f "$PROJECT_ROOT/systemd/$SYSTEMD_SERVICE.service" ]]; then
        cp "$PROJECT_ROOT/systemd/$SYSTEMD_SERVICE.service" "$package_dir/config/"
    fi

    # Create tarball
    tar -czf "$package_file" -C "$PROJECT_ROOT/deploy" "$APP_NAME-$VERSION"

    log_success "Deployment package created: $package_file"
    log_info "Package size: $(du -h "$package_file" | cut -f1)"

    # Clean up temporary directory
    rm -rf "$package_dir"
}

################################################################################
# Deployment Strategies
################################################################################

deploy_blue_green() {
    local target=${TARGET:-green}

    log_info "Deploying using Blue-Green strategy to: $target"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy to $target environment"
        return 0
    fi

    # Deploy to target environment
    deploy_to_target "$target"

    # Verify target health
    if verify_target_health "$target"; then
        log_success "Target $target is healthy"

        # Prompt for traffic switch
        if [[ "$ENVIRONMENT" == "production" ]]; then
            log_warning "Ready to switch traffic to $target"
            read -p "Switch traffic now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                switch_traffic "$target"
            else
                log_info "Traffic switch cancelled. You can switch manually later."
            fi
        else
            # Auto-switch in staging
            switch_traffic "$target"
        fi
    else
        log_error "Target $target health check failed"
        exit 1
    fi
}

deploy_canary() {
    local percentage=$CANARY_PERCENTAGE

    log_info "Deploying using Canary strategy: $percentage%"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy canary with $percentage% traffic"
        return 0
    fi

    # Deploy canary instance
    deploy_canary_instance

    # Configure load balancer for canary traffic
    configure_canary_traffic "$percentage"

    # Monitor canary
    log_info "Monitoring canary deployment for 5 minutes..."
    sleep 300

    # Check canary health
    if verify_canary_health; then
        log_success "Canary deployment successful"

        if [[ "$percentage" -eq 100 ]]; then
            log_success "Full rollout completed"
        else
            log_info "Canary running with $percentage% traffic"
            log_info "Increase percentage with: --canary-percentage 25/50/100"
        fi
    else
        log_error "Canary health check failed"
        log_error "Rolling back canary deployment"
        rollback_canary
        exit 1
    fi
}

deploy_rolling() {
    local batch_size=$BATCH_SIZE

    log_info "Deploying using Rolling Update strategy: batch size $batch_size"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would perform rolling update"
        return 0
    fi

    # Get list of instances
    local instances=("instance-1" "instance-2" "instance-3")  # TODO: Get from infrastructure

    for instance in "${instances[@]}"; do
        log_info "Updating instance: $instance"

        # Stop instance
        stop_instance "$instance"

        # Deploy new version
        deploy_to_instance "$instance"

        # Start instance
        start_instance "$instance"

        # Wait for health check
        if ! wait_for_health "$instance"; then
            log_error "Instance $instance failed health check"
            log_error "Rolling back deployment"
            # TODO: Implement rollback logic
            exit 1
        fi

        log_success "Instance $instance updated successfully"

        # Wait before next batch
        if [[ "$instance" != "${instances[-1]}" ]]; then
            log_info "Waiting 30 seconds before next instance..."
            sleep 30
        fi
    done

    log_success "Rolling update completed successfully"
}

################################################################################
# Deployment Implementation
################################################################################

deploy_to_target() {
    local target=$1

    log_info "Deploying application to $target..."

    # Create deployment directory
    local target_dir="$DEPLOY_DIR/$target"
    mkdir -p "$target_dir"

    # Stop existing service (if running)
    if systemctl is-active --quiet "$SYSTEMD_SERVICE-$target"; then
        log_info "Stopping existing service: $SYSTEMD_SERVICE-$target"
        sudo systemctl stop "$SYSTEMD_SERVICE-$target"
    fi

    # Copy binary
    sudo cp "$BUILD_DIR/$APP_NAME" "$target_dir/"

    # Copy configuration
    if [[ -f "$PROJECT_ROOT/.env.$ENVIRONMENT" ]]; then
        sudo cp "$PROJECT_ROOT/.env.$ENVIRONMENT" "$target_dir/.env"
    fi

    # Set permissions
    sudo chmod +x "$target_dir/$APP_NAME"

    # Create/update systemd service
    create_systemd_service "$target"

    # Start service
    log_info "Starting service: $SYSTEMD_SERVICE-$target"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SYSTEMD_SERVICE-$target"
    sudo systemctl start "$SYSTEMD_SERVICE-$target"

    # Wait for startup
    log_info "Waiting for application to start..."
    sleep 5

    log_success "Application deployed to $target"
}

create_systemd_service() {
    local target=$1
    local service_file="/etc/systemd/system/$SYSTEMD_SERVICE-$target.service"

    log_info "Creating systemd service: $service_file"

    sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=LLM Observatory Storage Layer ($target)
After=network.target postgresql.service

[Service]
Type=simple
User=llm-observatory
Group=llm-observatory
WorkingDirectory=$DEPLOY_DIR/$target
EnvironmentFile=$DEPLOY_DIR/$target/.env
ExecStart=$DEPLOY_DIR/$target/$APP_NAME
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$APP_NAME-$target

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/llm-observatory

[Install]
WantedBy=multi-user.target
EOF

    log_success "Systemd service created"
}

################################################################################
# Health Check Functions
################################################################################

verify_target_health() {
    local target=$1
    local url="http://localhost:$APP_PORT/health"

    log_info "Verifying health of $target..."

    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            local health_status
            health_status=$(curl -s "$url" | jq -r '.status')

            if [[ "$health_status" == "healthy" ]]; then
                log_success "Health check passed for $target"
                return 0
            fi
        fi

        attempt=$((attempt + 1))
        log_info "Health check attempt $attempt/$max_attempts..."
        sleep 2
    done

    log_error "Health check failed for $target after $max_attempts attempts"
    return 1
}

wait_for_health() {
    local instance=$1
    local timeout=$HEALTH_CHECK_TIMEOUT

    log_info "Waiting for $instance to become healthy (timeout: ${timeout}s)..."

    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if systemctl is-active --quiet "$SYSTEMD_SERVICE"; then
            if curl -f -s "http://localhost:$APP_PORT/health" > /dev/null 2>&1; then
                log_success "Instance $instance is healthy"
                return 0
            fi
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done

    log_error "Instance $instance failed to become healthy within ${timeout}s"
    return 1
}

################################################################################
# Traffic Management (Placeholder - Implement based on your load balancer)
################################################################################

switch_traffic() {
    local target=$1

    log_info "Switching traffic to $target..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would switch traffic to $target"
        return 0
    fi

    # TODO: Implement based on your load balancer (AWS ELB, nginx, etc.)
    # Example for AWS:
    # aws elbv2 modify-target-group --target-group-arn $TARGET_GROUP_ARN ...

    log_warning "Traffic switching not implemented - manual intervention required"
    log_info "Update your load balancer to point to $target"
}

configure_canary_traffic() {
    local percentage=$1

    log_info "Configuring canary traffic: $percentage%"

    # TODO: Implement based on your load balancer
    # Example: Update load balancer weights

    log_warning "Canary traffic configuration not implemented - manual intervention required"
}

################################################################################
# Instance Management (Placeholder)
################################################################################

stop_instance() {
    local instance=$1
    log_info "Stopping instance: $instance"

    sudo systemctl stop "$SYSTEMD_SERVICE"
}

start_instance() {
    local instance=$1
    log_info "Starting instance: $instance"

    sudo systemctl start "$SYSTEMD_SERVICE"
}

deploy_to_instance() {
    local instance=$1
    log_info "Deploying to instance: $instance"

    # Copy new binary
    sudo cp "$BUILD_DIR/$APP_NAME" "$DEPLOY_DIR/"
}

################################################################################
# Main Function
################################################################################

main() {
    log_info "LLM Observatory Application Deployment Script"
    log_info "=============================================="

    # Parse arguments
    parse_args "$@"

    log_info "Deployment Configuration:"
    log_info "  Environment: $ENVIRONMENT"
    log_info "  Version: $VERSION"
    log_info "  Strategy: $STRATEGY"

    # Load environment
    load_environment

    # Pre-deployment checks
    check_dependencies
    check_build_artifacts
    run_tests
    verify_database_connection

    # Execute deployment based on strategy
    case "$STRATEGY" in
        blue-green)
            deploy_blue_green
            ;;
        canary)
            deploy_canary
            ;;
        rolling)
            deploy_rolling
            ;;
        *)
            log_error "Unknown deployment strategy: $STRATEGY"
            log_error "Supported strategies: blue-green, canary, rolling"
            exit 1
            ;;
    esac

    log_success "Deployment completed successfully!"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "This was a dry run. No changes were made."
    fi

    # Show next steps
    log_info ""
    log_info "Next Steps:"
    log_info "1. Monitor application logs: journalctl -u $SYSTEMD_SERVICE -f"
    log_info "2. Check application health: curl http://localhost:$APP_PORT/health"
    log_info "3. View metrics: curl http://localhost:$METRICS_PORT/metrics"
    log_info "4. Run verification: ./scripts/verify_deployment.sh --environment $ENVIRONMENT"
}

# Run main function
main "$@"

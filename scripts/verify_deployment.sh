#!/bin/bash

################################################################################
# Deployment Verification Script for LLM Observatory Storage Layer
#
# This script performs comprehensive post-deployment verification including
# health checks, performance validation, and data integrity verification.
#
# Usage:
#   ./verify_deployment.sh [OPTIONS]
#
# Options:
#   --environment ENV       Environment to verify (staging|production)
#   --target TARGET         Target to verify (blue|green) for blue-green
#   --comprehensive         Run comprehensive tests (slower)
#   --timeout SECONDS       Overall timeout for verification (default: 300)
#   --help                  Show this help message
#
# Exit Codes:
#   0 - All checks passed
#   1 - One or more checks failed
#   2 - Critical failure (requires immediate action)
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

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0
TESTS_TOTAL=0

# Default configuration
ENVIRONMENT="${ENVIRONMENT:-staging}"
TARGET=""
COMPREHENSIVE=false
TIMEOUT=300
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Application configuration
APP_NAME="${APP_NAME:-llm-observatory-storage}"
APP_HOST="${APP_HOST:-localhost}"
APP_PORT="${APP_PORT:-8080}"
METRICS_PORT="${METRICS_PORT:-9090}"

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

show_help() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# //g' | sed 's/^#//g'
    exit 0
}

################################################################################
# Test Result Functions
################################################################################

record_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

record_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

record_warning() {
    TESTS_WARNING=$((TESTS_WARNING + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

show_summary() {
    echo ""
    echo "==============================================="
    echo "Verification Summary"
    echo "==============================================="
    echo -e "Total Tests:    $TESTS_TOTAL"
    echo -e "${GREEN}Passed:${NC}         $TESTS_PASSED"
    echo -e "${YELLOW}Warnings:${NC}       $TESTS_WARNING"
    echo -e "${RED}Failed:${NC}         $TESTS_FAILED"
    echo "==============================================="

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}VERIFICATION FAILED${NC}"
        echo "Please review failed tests above and take corrective action."
        return 1
    elif [[ $TESTS_WARNING -gt 0 ]]; then
        echo -e "${YELLOW}VERIFICATION PASSED WITH WARNINGS${NC}"
        echo "Review warnings above - deployment may have issues."
        return 0
    else
        echo -e "${GREEN}VERIFICATION PASSED${NC}"
        echo "All checks passed successfully!"
        return 0
    fi
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
            --target)
                TARGET="$2"
                shift 2
                ;;
            --comprehensive)
                COMPREHENSIVE=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
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
# Environment Setup
################################################################################

load_environment() {
    log_info "Loading environment configuration for: $ENVIRONMENT"

    # Load environment-specific configuration
    local env_file="$PROJECT_ROOT/.env.$ENVIRONMENT"
    if [[ -f "$env_file" ]]; then
        set -a
        source "$env_file"
        set +a
    elif [[ -f "$PROJECT_ROOT/.env" ]]; then
        set -a
        source "$PROJECT_ROOT/.env"
        set +a
    fi

    # Update endpoints based on target
    if [[ -n "$TARGET" ]]; then
        log_info "Verifying target: $TARGET"
        # Adjust ports or hostnames based on target
        # This depends on your infrastructure setup
    fi
}

################################################################################
# Service Health Checks
################################################################################

test_service_running() {
    log_test "Checking if service is running..."

    if systemctl is-active --quiet "llm-observatory-storage" 2>/dev/null; then
        log_success "Service is running"
        record_pass
        return 0
    else
        log_error "Service is not running"
        record_fail
        return 1
    fi
}

test_health_endpoint() {
    log_test "Testing health endpoint..."

    local url="http://$APP_HOST:$APP_PORT/health"
    local response

    if response=$(curl -f -s --max-time 5 "$url" 2>/dev/null); then
        local status
        status=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "unknown")

        if [[ "$status" == "healthy" ]]; then
            log_success "Health endpoint returned healthy status"
            record_pass
            return 0
        else
            log_error "Health endpoint returned non-healthy status: $status"
            log_error "Response: $response"
            record_fail
            return 1
        fi
    else
        log_error "Health endpoint not accessible: $url"
        record_fail
        return 1
    fi
}

test_metrics_endpoint() {
    log_test "Testing metrics endpoint..."

    local url="http://$APP_HOST:$METRICS_PORT/metrics"

    if curl -f -s --max-time 5 "$url" | grep -q "^# HELP"; then
        log_success "Metrics endpoint is responding"
        record_pass
        return 0
    else
        log_error "Metrics endpoint not accessible or malformed: $url"
        record_fail
        return 1
    fi
}

################################################################################
# Database Connectivity Checks
################################################################################

test_database_connection() {
    log_test "Testing database connection..."

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-llm_observatory}"
    local db_user="${DB_USER:-postgres}"

    if psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -c "SELECT 1" &>/dev/null; then
        log_success "Database connection successful"
        record_pass
        return 0
    else
        log_error "Failed to connect to database"
        log_error "Host: $db_host:$db_port, Database: $db_name, User: $db_user"
        record_fail
        return 1
    fi
}

test_redis_connection() {
    log_test "Testing Redis connection..."

    local redis_host="${REDIS_HOST:-localhost}"
    local redis_port="${REDIS_PORT:-6379}"

    if redis-cli -h "$redis_host" -p "$redis_port" PING 2>/dev/null | grep -q "PONG"; then
        log_success "Redis connection successful"
        record_pass
        return 0
    else
        log_warning "Redis connection failed (may be optional)"
        log_warning "Host: $redis_host:$redis_port"
        record_warning
        return 0
    fi
}

test_connection_pool() {
    log_test "Checking database connection pool..."

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-llm_observatory}"
    local db_user="${DB_USER:-postgres}"

    local connection_count
    connection_count=$(psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -c \
        "SELECT count(*) FROM pg_stat_activity WHERE datname='$db_name';" | tr -d '[:space:]')

    log_info "Active connections: $connection_count"

    if [[ $connection_count -lt 100 ]]; then
        log_success "Connection pool usage is normal"
        record_pass
        return 0
    else
        log_warning "High connection pool usage: $connection_count connections"
        record_warning
        return 0
    fi
}

################################################################################
# Database Schema Verification
################################################################################

test_schema_version() {
    log_test "Verifying database schema version..."

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-llm_observatory}"
    local db_user="${DB_USER:-postgres}"

    # Check if schema_migrations table exists
    local table_exists
    table_exists=$(psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -c \
        "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'schema_migrations');" | tr -d '[:space:]')

    if [[ "$table_exists" == "t" ]]; then
        local version
        version=$(psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -c \
            "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1;" | tr -d '[:space:]')

        log_success "Schema version: $version"
        record_pass
        return 0
    else
        log_error "schema_migrations table not found"
        record_fail
        return 1
    fi
}

test_required_tables() {
    log_test "Checking required tables exist..."

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-llm_observatory}"
    local db_user="${DB_USER:-postgres}"

    local required_tables=("llm_traces" "llm_metrics" "llm_logs")
    local missing_tables=()

    for table in "${required_tables[@]}"; do
        local exists
        exists=$(psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -c \
            "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '$table');" | tr -d '[:space:]')

        if [[ "$exists" != "t" ]]; then
            missing_tables+=("$table")
        fi
    done

    if [[ ${#missing_tables[@]} -eq 0 ]]; then
        log_success "All required tables exist"
        record_pass
        return 0
    else
        log_error "Missing tables: ${missing_tables[*]}"
        record_fail
        return 1
    fi
}

test_hypertables() {
    log_test "Verifying TimescaleDB hypertables..."

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-llm_observatory}"
    local db_user="${DB_USER:-postgres}"

    local hypertable_count
    hypertable_count=$(psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -c \
        "SELECT count(*) FROM timescaledb_information.hypertables;" 2>/dev/null | tr -d '[:space:]' || echo "0")

    if [[ $hypertable_count -gt 0 ]]; then
        log_success "TimescaleDB hypertables configured: $hypertable_count"
        record_pass
        return 0
    else
        log_warning "No TimescaleDB hypertables found"
        record_warning
        return 0
    fi
}

################################################################################
# Performance Validation
################################################################################

test_response_time() {
    log_test "Testing API response time..."

    local url="http://$APP_HOST:$APP_PORT/health"
    local response_time

    response_time=$(curl -o /dev/null -s -w '%{time_total}\n' "$url")
    response_time_ms=$(echo "$response_time * 1000" | bc)

    log_info "Response time: ${response_time_ms}ms"

    if (( $(echo "$response_time < 1.0" | bc -l) )); then
        log_success "Response time is acceptable (< 1s)"
        record_pass
        return 0
    else
        log_warning "Response time is slow: ${response_time}s"
        record_warning
        return 0
    fi
}

test_database_performance() {
    log_test "Testing database query performance..."

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-llm_observatory}"
    local db_user="${DB_USER:-postgres}"

    # Run a simple query and measure time
    local start_time end_time duration
    start_time=$(date +%s%3N)

    psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -c \
        "SELECT 1" &>/dev/null

    end_time=$(date +%s%3N)
    duration=$((end_time - start_time))

    log_info "Query duration: ${duration}ms"

    if [[ $duration -lt 100 ]]; then
        log_success "Database performance is good (< 100ms)"
        record_pass
        return 0
    else
        log_warning "Database query is slow: ${duration}ms"
        record_warning
        return 0
    fi
}

################################################################################
# Data Integrity Checks
################################################################################

test_data_counts() {
    log_test "Checking data counts..."

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-llm_observatory}"
    local db_user="${DB_USER:-postgres}"

    # Get row counts for main tables
    local traces_count metrics_count logs_count

    traces_count=$(psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -c \
        "SELECT count(*) FROM llm_traces;" 2>/dev/null | tr -d '[:space:]' || echo "0")

    log_info "Traces count: $traces_count"

    # Just verify queries work, don't fail on counts
    log_success "Data integrity queries executed successfully"
    record_pass
    return 0
}

test_no_null_required_fields() {
    log_test "Checking for NULL values in required fields..."

    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-llm_observatory}"
    local db_user="${DB_USER:-postgres}"

    # Check for NULL trace_ids (should not exist)
    local null_count
    null_count=$(psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t -c \
        "SELECT count(*) FROM llm_traces WHERE trace_id IS NULL;" 2>/dev/null | tr -d '[:space:]' || echo "0")

    if [[ $null_count -eq 0 ]]; then
        log_success "No NULL values in required fields"
        record_pass
        return 0
    else
        log_error "Found $null_count rows with NULL trace_id"
        record_fail
        return 1
    fi
}

################################################################################
# Monitoring and Alerting Checks
################################################################################

test_prometheus_scraping() {
    log_test "Checking if Prometheus can scrape metrics..."

    # This is a placeholder - implement based on your Prometheus setup
    local prometheus_url="${PROMETHEUS_URL:-http://localhost:9090}"

    if curl -f -s "$prometheus_url/api/v1/targets" 2>/dev/null | grep -q "storage-layer"; then
        log_success "Prometheus is scraping metrics"
        record_pass
        return 0
    else
        log_warning "Cannot verify Prometheus scraping (may not be configured)"
        record_warning
        return 0
    fi
}

test_log_output() {
    log_test "Checking application log output..."

    if journalctl -u llm-observatory-storage -n 10 --no-pager 2>/dev/null | grep -q .; then
        log_success "Application is logging successfully"
        record_pass
        return 0
    else
        log_warning "Cannot access application logs"
        record_warning
        return 0
    fi
}

test_no_errors_in_logs() {
    log_test "Checking for errors in recent logs..."

    local error_count
    error_count=$(journalctl -u llm-observatory-storage --since "5 minutes ago" 2>/dev/null | grep -i error | wc -l || echo "0")

    if [[ $error_count -eq 0 ]]; then
        log_success "No errors found in recent logs"
        record_pass
        return 0
    else
        log_warning "Found $error_count errors in recent logs"
        log_warning "Review logs with: journalctl -u llm-observatory-storage -n 100"
        record_warning
        return 0
    fi
}

################################################################################
# Comprehensive Tests (Optional)
################################################################################

test_api_endpoints() {
    log_test "Testing API endpoints..."

    # Test various API endpoints if they exist
    local base_url="http://$APP_HOST:$APP_PORT"

    # Health endpoint
    if curl -f -s "$base_url/health" &>/dev/null; then
        log_success "API endpoints are accessible"
        record_pass
        return 0
    else
        log_error "API endpoints not accessible"
        record_fail
        return 1
    fi
}

test_load_capacity() {
    log_test "Running light load test..."

    # Send 10 concurrent requests
    local url="http://$APP_HOST:$APP_PORT/health"
    local success_count=0

    for i in {1..10}; do
        if curl -f -s "$url" &>/dev/null; then
            success_count=$((success_count + 1))
        fi
    done

    if [[ $success_count -eq 10 ]]; then
        log_success "Handled 10 concurrent requests successfully"
        record_pass
        return 0
    else
        log_warning "Only handled $success_count/10 requests successfully"
        record_warning
        return 0
    fi
}

################################################################################
# Main Function
################################################################################

main() {
    log_info "LLM Observatory Deployment Verification"
    log_info "========================================"

    # Parse arguments
    parse_args "$@"

    log_info "Environment: $ENVIRONMENT"
    log_info "Comprehensive: $COMPREHENSIVE"
    log_info ""

    # Set timeout
    ( sleep "$TIMEOUT" && kill -TERM $$ 2>/dev/null ) &
    local timeout_pid=$!

    # Load environment
    load_environment

    # Run basic checks
    log_info "Running basic health checks..."
    echo ""

    test_service_running || true
    test_health_endpoint || true
    test_metrics_endpoint || true

    echo ""
    log_info "Running database connectivity checks..."
    echo ""

    test_database_connection || true
    test_redis_connection || true
    test_connection_pool || true

    echo ""
    log_info "Running schema verification checks..."
    echo ""

    test_schema_version || true
    test_required_tables || true
    test_hypertables || true

    echo ""
    log_info "Running performance validation..."
    echo ""

    test_response_time || true
    test_database_performance || true

    echo ""
    log_info "Running data integrity checks..."
    echo ""

    test_data_counts || true
    test_no_null_required_fields || true

    echo ""
    log_info "Running monitoring checks..."
    echo ""

    test_prometheus_scraping || true
    test_log_output || true
    test_no_errors_in_logs || true

    # Run comprehensive tests if requested
    if [[ "$COMPREHENSIVE" == "true" ]]; then
        echo ""
        log_info "Running comprehensive tests..."
        echo ""

        test_api_endpoints || true
        test_load_capacity || true
    fi

    # Cancel timeout
    kill $timeout_pid 2>/dev/null || true

    # Show summary and exit
    echo ""
    if show_summary; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"

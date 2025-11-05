#!/bin/bash
# ============================================================================
# Storage Service Entrypoint Script (Production)
# ============================================================================
# This script:
# 1. Waits for database to be ready
# 2. Runs database migrations
# 3. Starts the storage service
# ============================================================================

set -e

# Color output for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# Configuration validation
# ============================================================================

if [ -z "$DATABASE_URL" ]; then
    log_error "DATABASE_URL environment variable is not set"
    exit 1
fi

log_info "Storage Service starting..."
log_info "Environment: ${ENVIRONMENT:-production}"
log_info "Log level: ${RUST_LOG:-info}"

# ============================================================================
# Wait for database to be ready
# ============================================================================

log_info "Waiting for database to be ready..."

MAX_RETRIES=30
RETRY_COUNT=0
RETRY_DELAY=2

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if sqlx database create --database-url "$DATABASE_URL" 2>/dev/null || \
       psql "$DATABASE_URL" -c "SELECT 1" >/dev/null 2>&1; then
        log_success "Database is ready"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        log_error "Database is not ready after $MAX_RETRIES attempts"
        exit 1
    fi

    log_warn "Database not ready, retrying in ${RETRY_DELAY}s... (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep $RETRY_DELAY
done

# ============================================================================
# Run database migrations
# ============================================================================

if [ "${SKIP_MIGRATIONS:-false}" = "true" ]; then
    log_warn "Skipping migrations (SKIP_MIGRATIONS=true)"
else
    log_info "Running database migrations..."

    cd /app/migrations || {
        log_error "Migrations directory not found"
        exit 1
    }

    # Set DATABASE_URL for sqlx
    export DATABASE_URL

    # Run migrations with sqlx
    if sqlx migrate run --source /app/migrations 2>&1 | tee /tmp/migration.log; then
        log_success "Migrations completed successfully"
    else
        log_error "Migration failed:"
        cat /tmp/migration.log
        exit 1
    fi

    cd /app
fi

# ============================================================================
# Validate configuration
# ============================================================================

log_info "Validating configuration..."

# Check required environment variables
REQUIRED_VARS=(
    "DATABASE_URL"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Validate Redis URL if provided
if [ -n "$REDIS_URL" ]; then
    log_info "Redis URL configured: ${REDIS_URL%%@*}@***" # Mask password
fi

# Validate connection pool settings
log_info "Connection pool configuration:"
log_info "  Min size: ${DB_POOL_MIN_SIZE:-5}"
log_info "  Max size: ${DB_POOL_MAX_SIZE:-20}"
log_info "  Timeout: ${DB_POOL_TIMEOUT:-30}s"

# Validate COPY protocol settings
log_info "COPY protocol configuration:"
log_info "  Batch size: ${COPY_BATCH_SIZE:-10000}"
log_info "  Flush interval: ${COPY_FLUSH_INTERVAL:-1000}ms"
log_info "  Buffer size: ${COPY_BUFFER_SIZE:-8192} bytes"

# Validate server configuration
log_info "Server configuration:"
log_info "  API host: ${APP_HOST:-0.0.0.0}"
log_info "  API port: ${APP_PORT:-8080}"
log_info "  Metrics port: ${METRICS_PORT:-9090}"

log_success "Configuration validated"

# ============================================================================
# Start the storage service
# ============================================================================

log_info "Starting storage service..."
log_info "Command: $*"

# Execute the command passed as arguments (default: storage-service)
exec "$@"

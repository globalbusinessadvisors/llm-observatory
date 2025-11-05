#!/bin/bash
# ============================================================================
# Storage Service Entrypoint Script (Development)
# ============================================================================
# This script:
# 1. Waits for database to be ready
# 2. Runs database migrations
# 3. Installs/updates dependencies if needed
# 4. Starts the storage service with hot reload
# ============================================================================

set -e

# Color output for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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

log_dev() {
    echo -e "${MAGENTA}[DEV]${NC} $1"
}

# ============================================================================
# Development banner
# ============================================================================

echo ""
echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                              ║${NC}"
echo -e "${MAGENTA}║        LLM Observatory Storage Service (Development)        ║${NC}"
echo -e "${MAGENTA}║                                                              ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Configuration validation
# ============================================================================

if [ -z "$DATABASE_URL" ]; then
    log_error "DATABASE_URL environment variable is not set"
    exit 1
fi

log_dev "Development mode enabled"
log_info "Environment: ${ENVIRONMENT:-development}"
log_info "Log level: ${RUST_LOG:-debug}"
log_info "Auto-reload: ${AUTO_RELOAD:-true}"

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

    # Check if migrations directory exists
    if [ ! -d "/app/crates/storage/migrations" ]; then
        log_warn "Migrations directory not found, skipping migrations"
    else
        cd /app/crates/storage/migrations || {
            log_error "Failed to enter migrations directory"
            exit 1
        }

        # Set DATABASE_URL for sqlx
        export DATABASE_URL

        # Run migrations with sqlx
        if sqlx migrate run --source /app/crates/storage/migrations 2>&1 | tee /tmp/migration.log; then
            log_success "Migrations completed successfully"
        else
            log_warn "Migration failed (continuing in development mode):"
            cat /tmp/migration.log
        fi

        cd /app
    fi
fi

# ============================================================================
# Check and update dependencies
# ============================================================================

log_dev "Checking Cargo dependencies..."

# Check if Cargo.lock has changed
if [ -f "/app/Cargo.lock" ]; then
    if [ -f "/tmp/.cargo_lock_hash" ]; then
        OLD_HASH=$(cat /tmp/.cargo_lock_hash)
        NEW_HASH=$(md5sum /app/Cargo.lock | cut -d' ' -f1)

        if [ "$OLD_HASH" != "$NEW_HASH" ]; then
            log_info "Cargo.lock changed, updating dependencies..."
            cargo fetch
            echo "$NEW_HASH" > /tmp/.cargo_lock_hash
            log_success "Dependencies updated"
        else
            log_dev "Dependencies up to date"
        fi
    else
        NEW_HASH=$(md5sum /app/Cargo.lock | cut -d' ' -f1)
        echo "$NEW_HASH" > /tmp/.cargo_lock_hash
        cargo fetch
    fi
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
else
    log_warn "Redis URL not configured (optional for development)"
fi

# Validate connection pool settings
log_dev "Connection pool configuration:"
log_dev "  Min size: ${DB_POOL_MIN_SIZE:-2}"
log_dev "  Max size: ${DB_POOL_MAX_SIZE:-10}"
log_dev "  Timeout: ${DB_POOL_TIMEOUT:-30}s"

# Validate COPY protocol settings
log_dev "COPY protocol configuration:"
log_dev "  Batch size: ${COPY_BATCH_SIZE:-1000}"
log_dev "  Flush interval: ${COPY_FLUSH_INTERVAL:-500}ms"
log_dev "  Buffer size: ${COPY_BUFFER_SIZE:-4096} bytes"

# Validate server configuration
log_dev "Server configuration:"
log_dev "  API host: ${APP_HOST:-0.0.0.0}"
log_dev "  API port: ${APP_PORT:-8080}"
log_dev "  Metrics port: ${METRICS_PORT:-9090}"

log_success "Configuration validated"

# ============================================================================
# Development tools info
# ============================================================================

log_dev "Development tools available:"
log_dev "  • cargo watch  - Hot reload on file changes"
log_dev "  • cargo nextest - Fast test runner"
log_dev "  • sqlx         - Database migrations and queries"
log_dev "  • psql         - PostgreSQL client"
log_dev "  • redis-cli    - Redis client"
echo ""
log_dev "Useful commands:"
log_dev "  • cargo watch -x 'run --bin storage-service'"
log_dev "  • cargo nextest run"
log_dev "  • cargo bench"
log_dev "  • sqlx migrate run"
log_dev "  • psql \$DATABASE_URL"
echo ""

# ============================================================================
# Start the storage service
# ============================================================================

log_success "Starting storage service in development mode..."
log_info "Command: $*"
echo ""

# Execute the command passed as arguments (default: cargo watch)
exec "$@"

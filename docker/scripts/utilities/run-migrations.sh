#!/usr/bin/env bash
#
# Run Database Migrations
# Purpose: Execute pending database migrations using sqlx-cli
# Usage: ./run-migrations.sh [--dry-run]
#

set -euo pipefail

# Source environment variables
if [ -f /app/.env ]; then
    # shellcheck disable=SC1091
    source /app/.env
fi

# Configuration
readonly MIGRATIONS_DIR="${MIGRATIONS_DIR:-/app/migrations}"
readonly DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@timescaledb:5432/llm_observatory}"

# Colors
readonly COLOR_RESET="\033[0m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_BLUE="\033[0;34m"
readonly COLOR_YELLOW="\033[0;33m"

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
}

# Parse arguments
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Starting migration process"
    log_info "Migrations directory: ${MIGRATIONS_DIR}"
    log_info "Database: ${DB_NAME:-llm_observatory}"

    # Verify migrations directory exists
    if [ ! -d "${MIGRATIONS_DIR}" ]; then
        echo "Error: Migrations directory not found: ${MIGRATIONS_DIR}"
        exit 1
    fi

    # Count migration files
    local migration_count
    migration_count=$(find "${MIGRATIONS_DIR}" -name "[0-9]*.sql" | wc -l)
    log_info "Found ${migration_count} migration files"

    if [ "${DRY_RUN}" = true ]; then
        log_warning "DRY RUN MODE - No changes will be made"
        log_info "Migration status:"
        sqlx migrate info --source "${MIGRATIONS_DIR}" --database-url "${DATABASE_URL}"
        exit 0
    fi

    # Ensure database exists
    log_info "Ensuring database exists..."
    if sqlx database create --database-url "${DATABASE_URL}" 2>/dev/null; then
        log_info "Database created or already exists"
    fi

    # Show current status
    log_info "Current migration status:"
    sqlx migrate info --source "${MIGRATIONS_DIR}" --database-url "${DATABASE_URL}" || true

    # Run migrations
    log_info "Running migrations..."
    if sqlx migrate run --source "${MIGRATIONS_DIR}" --database-url "${DATABASE_URL}"; then
        log_success "All migrations completed successfully"

        # Show final status
        echo
        log_info "Final migration status:"
        sqlx migrate info --source "${MIGRATIONS_DIR}" --database-url "${DATABASE_URL}"

        exit 0
    else
        echo "Error: Migration failed"
        exit 1
    fi
}

main "$@"

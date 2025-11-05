#!/usr/bin/env bash
#
# Reset Database
# Purpose: Drop and recreate database, run migrations, and optionally seed data
# Usage: ./reset-database.sh [--force] [--no-seed]
#
# WARNING: This will delete all data in the database!
#

set -euo pipefail

# Source environment variables
if [ -f /app/.env ]; then
    # shellcheck disable=SC1091
    source /app/.env
fi

# Configuration
readonly DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@timescaledb:5432/llm_observatory}"
readonly DB_HOST="${DB_HOST:-timescaledb}"
readonly DB_PORT="${DB_PORT:-5432}"
readonly DB_NAME="${DB_NAME:-llm_observatory}"
readonly DB_USER="${DB_USER:-postgres}"
readonly DB_PASSWORD="${DB_PASSWORD:-postgres}"
readonly MIGRATIONS_DIR="${MIGRATIONS_DIR:-/app/migrations}"
readonly SCRIPTS_DIR="${SCRIPTS_DIR:-/app/scripts}"

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

# Parse arguments
FORCE=false
NO_SEED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --no-seed)
            NO_SEED=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force] [--no-seed]"
            exit 1
            ;;
    esac
done

# Confirmation prompt
confirm_reset() {
    if [ "${FORCE}" = true ]; then
        return 0
    fi

    log_warning "This will DELETE ALL DATA in the database: ${DB_NAME}"
    log_warning "This action CANNOT be undone!"
    echo
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Reset cancelled"
        exit 0
    fi
}

# Drop database
drop_database() {
    log_warning "Dropping database: ${DB_NAME}"

    # Construct postgres URL (to connect to postgres database, not target database)
    local postgres_url="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/postgres"

    # Terminate existing connections
    psql "${postgres_url}" -c "
        SELECT pg_terminate_backend(pg_stat_activity.pid)
        FROM pg_stat_activity
        WHERE pg_stat_activity.datname = '${DB_NAME}'
          AND pid <> pg_backend_pid();" 2>/dev/null || true

    # Drop database
    if psql "${postgres_url}" -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null; then
        log_success "Database dropped"
    else
        log_error "Failed to drop database"
        return 1
    fi
}

# Create database
create_database() {
    log_info "Creating database: ${DB_NAME}"

    if sqlx database create --database-url "${DATABASE_URL}"; then
        log_success "Database created"
    else
        log_error "Failed to create database"
        return 1
    fi
}

# Run migrations
run_migrations() {
    log_info "Running migrations..."

    if [ -f "${SCRIPTS_DIR}/run-migrations.sh" ]; then
        bash "${SCRIPTS_DIR}/run-migrations.sh"
    else
        # Fallback to direct sqlx call
        if sqlx migrate run --source "${MIGRATIONS_DIR}" --database-url "${DATABASE_URL}"; then
            log_success "Migrations completed"
        else
            log_error "Migration failed"
            return 1
        fi
    fi
}

# Seed database
seed_database() {
    if [ "${NO_SEED}" = true ]; then
        log_info "Skipping database seeding (--no-seed flag)"
        return 0
    fi

    log_info "Seeding database..."

    if [ -f "${SCRIPTS_DIR}/seed-data.sh" ]; then
        bash "${SCRIPTS_DIR}/seed-data.sh"
    else
        log_warning "Seed script not found, skipping seeding"
    fi
}

# Verify reset
verify_reset() {
    log_info "Verifying database reset..."

    # Check if database exists and is accessible
    if psql "${DATABASE_URL}" -c "SELECT version();" > /dev/null 2>&1; then
        log_success "Database is accessible"
    else
        log_error "Database verification failed"
        return 1
    fi

    # Check for tables
    local table_count
    table_count=$(psql "${DATABASE_URL}" -t -c "
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE';")

    log_info "Tables created: ${table_count}"

    # Check for TimescaleDB extension
    local has_timescaledb
    has_timescaledb=$(psql "${DATABASE_URL}" -t -c "
        SELECT COUNT(*)
        FROM pg_extension
        WHERE extname = 'timescaledb';")

    if [ "${has_timescaledb}" -gt 0 ]; then
        log_success "TimescaleDB extension is installed"
    else
        log_warning "TimescaleDB extension not found"
    fi

    # Show database size
    local db_size
    db_size=$(psql "${DATABASE_URL}" -t -c "
        SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));")
    log_info "Database size: ${db_size}"
}

# Main execution
main() {
    log_warning "Database Reset Utility"
    echo

    # Confirm reset
    confirm_reset

    # Execute reset steps
    log_info "Starting database reset process..."
    echo

    # Step 1: Drop database
    drop_database || exit 1

    # Step 2: Create database
    create_database || exit 1

    # Step 3: Run migrations
    run_migrations || exit 1

    # Step 4: Seed database (optional)
    seed_database || log_warning "Seeding failed or skipped"

    # Step 5: Verify
    echo
    verify_reset || exit 1

    echo
    log_success "Database reset completed successfully!"
    log_info "Database: ${DB_NAME}"
    log_info "Status: Ready for use"
}

main "$@"

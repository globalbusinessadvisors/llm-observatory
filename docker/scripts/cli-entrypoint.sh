#!/usr/bin/env bash
#
# LLM Observatory CLI Tools Entrypoint
# Purpose: Main entrypoint for database management and utility operations
# Author: LLM Observatory Contributors
# Version: 0.1.0
#

set -euo pipefail

# Colors for output
readonly COLOR_RESET="\033[0m"
readonly COLOR_RED="\033[0;31m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_YELLOW="\033[0;33m"
readonly COLOR_BLUE="\033[0;34m"
readonly COLOR_CYAN="\033[0;36m"
readonly COLOR_BOLD="\033[1m"

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*" >&2
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

log_step() {
    echo -e "${COLOR_CYAN}[STEP]${COLOR_RESET} $*" >&2
}

# Print banner
print_banner() {
    cat << 'EOF'
  _    _    __  __   ___  _                           _
 | |  | |  |  \/  | / _ \| |__  ___  ___ _ ____   ___| |_ ___  _ __ _   _
 | |  | |  | |\/| || | | | '_ \/ __|/ _ \ '__\ \ / / _` __/ _ \| '__| | | |
 | |__| |__| |  | || |_| | |_) \__ \  __/ |   \ V / (_| || (_) | |  | |_| |
 |____|____|_|  |_| \___/|_.__/|___/\___|_|    \_/ \__,_| \___/|_|   \__, |
                                                                      |___/
                          CLI Tools - Database Management
EOF
    echo
}

# Check if database is ready
wait_for_database() {
    local max_attempts=30
    local attempt=1

    log_step "Waiting for database to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" > /dev/null 2>&1; then
            log_success "Database is ready"
            return 0
        fi

        log_info "Attempt $attempt/$max_attempts: Database not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done

    log_error "Database failed to become ready after $max_attempts attempts"
    return 1
}

# Verify database connection
verify_database_connection() {
    log_step "Verifying database connection..."

    if psql "${DATABASE_URL}" -c "SELECT version();" > /dev/null 2>&1; then
        log_success "Database connection verified"
        return 0
    else
        log_error "Failed to connect to database"
        return 1
    fi
}

# Run migrations
run_migrations() {
    log_step "Running database migrations..."

    if [ ! -d "${MIGRATIONS_DIR}" ]; then
        log_error "Migrations directory not found: ${MIGRATIONS_DIR}"
        return 1
    fi

    # Count migration files
    local migration_count
    migration_count=$(find "${MIGRATIONS_DIR}" -name "*.sql" -not -name "test_*.sql" -not -name "verify_*.sql" -not -name "*README*" -not -name "*SUMMARY*" -not -name "*REFERENCE*" -not -name "*NOTES*" -not -name "*CHECKLIST*" -not -name "*REPORT*" -not -name "*queries*" -not -name "deploy_*.sh" | wc -l)

    log_info "Found $migration_count migration files"

    # Run migrations with sqlx
    if sqlx database create --database-url "${DATABASE_URL}" 2>/dev/null; then
        log_info "Database created or already exists"
    fi

    if sqlx migrate run --source "${MIGRATIONS_DIR}" --database-url "${DATABASE_URL}"; then
        log_success "Migrations completed successfully"
        return 0
    else
        log_error "Migration failed"
        return 1
    fi
}

# Seed database
seed_database() {
    log_step "Seeding database with initial data..."

    local seed_script="${SCRIPTS_DIR}/seed-data.sh"

    if [ -f "${seed_script}" ]; then
        bash "${seed_script}"
    else
        log_warning "Seed script not found: ${seed_script}"
        log_info "Skipping database seeding"
        return 0
    fi
}

# Reset database
reset_database() {
    log_warning "This will drop and recreate the database!"

    # In production, we'd want confirmation, but in Docker we assume intent
    log_step "Resetting database..."

    local reset_script="${SCRIPTS_DIR}/reset-database.sh"

    if [ -f "${reset_script}" ]; then
        bash "${reset_script}"
    else
        log_error "Reset script not found: ${reset_script}"
        return 1
    fi
}

# Backup database
backup_database() {
    log_step "Creating database backup..."

    local backup_script="${SCRIPTS_DIR}/backup-database.sh"

    if [ -f "${backup_script}" ]; then
        bash "${backup_script}" "$@"
    else
        log_error "Backup script not found: ${backup_script}"
        return 1
    fi
}

# Restore database
restore_database() {
    local backup_file="$1"

    if [ -z "${backup_file}" ]; then
        log_error "Backup file not specified"
        log_info "Usage: restore <backup-file>"
        return 1
    fi

    log_step "Restoring database from backup: ${backup_file}"

    local restore_script="${SCRIPTS_DIR}/restore-database.sh"

    if [ -f "${restore_script}" ]; then
        bash "${restore_script}" "${backup_file}"
    else
        log_error "Restore script not found: ${restore_script}"
        return 1
    fi
}

# Check migration status
check_migration_status() {
    log_step "Checking migration status..."

    sqlx migrate info --source "${MIGRATIONS_DIR}" --database-url "${DATABASE_URL}"
}

# Rollback last migration
rollback_migration() {
    log_warning "Rolling back last migration..."

    sqlx migrate revert --source "${MIGRATIONS_DIR}" --database-url "${DATABASE_URL}"
}

# Run SQL file
run_sql_file() {
    local sql_file="$1"

    if [ -z "${sql_file}" ]; then
        log_error "SQL file not specified"
        log_info "Usage: sql <file>"
        return 1
    fi

    if [ ! -f "${sql_file}" ]; then
        log_error "SQL file not found: ${sql_file}"
        return 1
    fi

    log_step "Executing SQL file: ${sql_file}"

    psql "${DATABASE_URL}" -f "${sql_file}"
}

# Execute SQL command
run_sql_command() {
    local sql_command="$*"

    if [ -z "${sql_command}" ]; then
        log_error "SQL command not specified"
        log_info "Usage: exec '<sql-command>'"
        return 1
    fi

    log_step "Executing SQL command"

    psql "${DATABASE_URL}" -c "${sql_command}"
}

# Open interactive psql shell
open_shell() {
    log_info "Opening interactive PostgreSQL shell"
    log_info "Database: ${DB_NAME}"
    log_info "User: ${DB_USER}"
    echo

    psql "${DATABASE_URL}"
}

# Show help
show_help() {
    print_banner

    cat << EOF
${COLOR_BOLD}USAGE:${COLOR_RESET}
    cli <command> [arguments]

${COLOR_BOLD}COMMANDS:${COLOR_RESET}
    ${COLOR_GREEN}migrate${COLOR_RESET}              Run all pending database migrations
    ${COLOR_GREEN}migrate-status${COLOR_RESET}       Check migration status
    ${COLOR_GREEN}migrate-rollback${COLOR_RESET}     Rollback the last migration

    ${COLOR_GREEN}seed${COLOR_RESET}                 Seed database with initial data
    ${COLOR_GREEN}reset${COLOR_RESET}                Reset database (drop and recreate)

    ${COLOR_GREEN}backup${COLOR_RESET} [options]     Create database backup
    ${COLOR_GREEN}restore${COLOR_RESET} <file>       Restore database from backup

    ${COLOR_GREEN}sql${COLOR_RESET} <file>           Execute SQL file
    ${COLOR_GREEN}exec${COLOR_RESET} '<command>'     Execute SQL command
    ${COLOR_GREEN}shell${COLOR_RESET}                Open interactive psql shell

    ${COLOR_GREEN}verify${COLOR_RESET}               Verify database connection
    ${COLOR_GREEN}help${COLOR_RESET}                 Show this help message

${COLOR_BOLD}EXAMPLES:${COLOR_RESET}
    # Run migrations
    docker compose --profile tools run --rm cli migrate

    # Seed database
    docker compose --profile tools run --rm cli seed

    # Create backup
    docker compose --profile tools run --rm cli backup

    # Restore from backup
    docker compose --profile tools run --rm cli restore /app/backups/backup-2024-01-01.sql.gz

    # Check migration status
    docker compose --profile tools run --rm cli migrate-status

    # Execute SQL file
    docker compose --profile tools run --rm cli sql /app/data/custom.sql

    # Open interactive shell
    docker compose --profile tools run --rm cli shell

${COLOR_BOLD}ENVIRONMENT VARIABLES:${COLOR_RESET}
    DB_HOST                Database host (default: timescaledb)
    DB_PORT                Database port (default: 5432)
    DB_NAME                Database name (default: llm_observatory)
    DB_USER                Database user (default: postgres)
    DB_PASSWORD            Database password (default: postgres)
    DATABASE_URL           Full database URL
    MIGRATIONS_DIR         Migrations directory (default: /app/migrations)
    BACKUPS_DIR            Backups directory (default: /app/backups)

${COLOR_BOLD}VERSION:${COLOR_RESET}
    0.1.0

${COLOR_BOLD}DOCUMENTATION:${COLOR_RESET}
    https://docs.llm-observatory.io/cli-tools

EOF
}

# Main command handler
main() {
    local command="${1:-help}"
    shift || true

    # Wait for database to be ready (except for help)
    if [ "${command}" != "help" ]; then
        wait_for_database || exit 1
    fi

    # Handle commands
    case "${command}" in
        migrate)
            verify_database_connection || exit 1
            run_migrations || exit 1
            ;;

        migrate-status|status)
            verify_database_connection || exit 1
            check_migration_status || exit 1
            ;;

        migrate-rollback|rollback)
            verify_database_connection || exit 1
            rollback_migration || exit 1
            ;;

        seed)
            verify_database_connection || exit 1
            seed_database || exit 1
            ;;

        reset)
            verify_database_connection || exit 1
            reset_database || exit 1
            ;;

        backup)
            verify_database_connection || exit 1
            backup_database "$@" || exit 1
            ;;

        restore)
            verify_database_connection || exit 1
            restore_database "$@" || exit 1
            ;;

        sql)
            verify_database_connection || exit 1
            run_sql_file "$@" || exit 1
            ;;

        exec|execute)
            verify_database_connection || exit 1
            run_sql_command "$@" || exit 1
            ;;

        shell|psql)
            verify_database_connection || exit 1
            open_shell || exit 1
            ;;

        verify|test)
            verify_database_connection || exit 1
            log_success "All checks passed"
            ;;

        help|--help|-h)
            show_help
            ;;

        *)
            log_error "Unknown command: ${command}"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

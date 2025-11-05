#!/bin/bash
# Development environment helper script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Compose files
COMPOSE_FILES="-f docker-compose.yml -f docker-compose.dev.yml"

# Function to print colored messages
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [command]

Development environment helper for LLM Observatory

Commands:
    start           Start all development services
    stop            Stop all services
    restart         Restart all services
    logs [service]  Show logs (optionally for specific service)
    clean           Stop and remove containers and volumes
    rebuild         Rebuild all services
    seed            Seed database with sample data
    reset           Reset database to clean state
    shell [service] Open shell in service container
    test [service]  Run tests in service container
    help            Show this help message

Examples:
    $0 start                    # Start development environment
    $0 logs api                 # Show API logs
    $0 shell collector          # Open shell in collector container
    $0 test api                 # Run API tests

EOF
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to check if .env file exists
check_env() {
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        warning ".env file not found. Creating from .env.example..."
        if [ -f "$PROJECT_ROOT/.env.example" ]; then
            cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
            success ".env file created. Please review and update as needed."
        else
            error ".env.example not found. Cannot create .env file."
            exit 1
        fi
    fi
}

# Function to start services
start() {
    info "Starting development environment..."
    check_docker
    check_env
    docker-compose $COMPOSE_FILES up "$@"
}

# Function to stop services
stop() {
    info "Stopping development environment..."
    docker-compose $COMPOSE_FILES down
    success "Services stopped"
}

# Function to restart services
restart() {
    info "Restarting development environment..."
    stop
    start "$@"
}

# Function to show logs
logs() {
    local service=$1
    if [ -z "$service" ]; then
        docker-compose $COMPOSE_FILES logs -f --tail=100
    else
        docker-compose $COMPOSE_FILES logs -f --tail=100 "$service"
    fi
}

# Function to clean environment
clean() {
    warning "This will remove all containers, networks, and volumes."
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Cleaning development environment..."
        docker-compose $COMPOSE_FILES down -v
        docker volume prune -f
        success "Environment cleaned"
    else
        info "Clean cancelled"
    fi
}

# Function to rebuild services
rebuild() {
    info "Rebuilding services..."
    docker-compose $COMPOSE_FILES build --no-cache
    success "Services rebuilt"
}

# Function to seed database
seed() {
    info "Seeding database with sample data..."
    docker-compose $COMPOSE_FILES run --rm dev-utils sh -c "psql < /seed-data/seed.sql"
    success "Database seeded"
}

# Function to reset database
reset() {
    warning "This will delete all data in the database."
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Resetting database..."
        docker-compose $COMPOSE_FILES run --rm dev-utils sh -c "psql < /seed-data/reset.sql"
        success "Database reset"

        read -p "Would you like to seed with sample data? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            seed
        fi
    else
        info "Reset cancelled"
    fi
}

# Function to open shell in service
shell() {
    local service=$1
    if [ -z "$service" ]; then
        error "Please specify a service: collector, api, storage, timescaledb, redis"
        exit 1
    fi
    info "Opening shell in $service container..."
    docker-compose $COMPOSE_FILES exec "$service" sh
}

# Function to run tests
test() {
    local service=$1
    if [ -z "$service" ]; then
        info "Running tests in all services..."
        docker-compose $COMPOSE_FILES exec collector cargo test
        docker-compose $COMPOSE_FILES exec api cargo test
        docker-compose $COMPOSE_FILES exec storage cargo test
    else
        info "Running tests in $service..."
        docker-compose $COMPOSE_FILES exec "$service" cargo test
    fi
    success "Tests completed"
}

# Main command handling
case "${1:-}" in
    start)
        shift
        start "$@"
        ;;
    stop)
        stop
        ;;
    restart)
        shift
        restart "$@"
        ;;
    logs)
        logs "$2"
        ;;
    clean)
        clean
        ;;
    rebuild)
        rebuild
        ;;
    seed)
        seed
        ;;
    reset)
        reset
        ;;
    shell)
        shell "$2"
        ;;
    test)
        test "$2"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        if [ -n "$1" ]; then
            error "Unknown command: $1"
            echo
        fi
        usage
        exit 1
        ;;
esac

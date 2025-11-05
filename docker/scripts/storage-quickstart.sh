#!/bin/bash
# ============================================================================
# Storage Service Quick Start Script
# ============================================================================
# This script helps quickly start and manage the storage service
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT"

# Functions
print_header() {
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                              ║${NC}"
    echo -e "${MAGENTA}║           LLM Observatory Storage Service                   ║${NC}"
    echo -e "${MAGENTA}║                   Quick Start Script                         ║${NC}"
    echo -e "${MAGENTA}║                                                              ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_command() {
    echo -e "${CYAN}  → $1${NC}"
}

show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start         Start storage service (production)"
    echo "  start-dev     Start storage service (development with hot reload)"
    echo "  stop          Stop storage service"
    echo "  restart       Restart storage service"
    echo "  logs          View storage service logs"
    echo "  health        Check storage service health"
    echo "  metrics       View storage service metrics"
    echo "  shell         Open shell in storage container"
    echo "  migrate       Run database migrations"
    echo "  test          Run storage service tests"
    echo "  bench         Run storage service benchmarks"
    echo "  clean         Clean storage volumes and containers"
    echo "  status        Show storage service status"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start              # Start in production mode"
    echo "  $0 start-dev          # Start in development mode"
    echo "  $0 logs -f            # Follow logs"
    echo "  $0 bench              # Run benchmarks"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
}

check_env() {
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        print_warn ".env file not found"
        print_info "Creating .env from .env.example..."
        cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
        print_success ".env file created"
        print_warn "Please update .env with your configuration"
        exit 0
    fi
}

start_storage() {
    print_info "Starting storage service (production)..."
    print_command "docker-compose up -d timescaledb redis storage"
    docker-compose up -d timescaledb redis storage
    print_success "Storage service started"
    echo ""
    print_info "Waiting for services to be healthy..."
    sleep 5
    check_health
}

start_storage_dev() {
    print_info "Starting storage service (development)..."
    print_command "docker-compose --profile dev up -d timescaledb redis storage-dev"
    docker-compose --profile dev up -d timescaledb redis storage-dev
    print_success "Storage service started in development mode"
    echo ""
    print_info "Waiting for services to be healthy..."
    sleep 5
    check_health_dev
}

stop_storage() {
    print_info "Stopping storage service..."
    print_command "docker-compose stop storage storage-dev"
    docker-compose stop storage storage-dev 2>/dev/null || true
    print_success "Storage service stopped"
}

restart_storage() {
    stop_storage
    echo ""
    start_storage
}

show_logs() {
    print_info "Showing storage service logs..."
    print_command "docker-compose logs storage $*"
    docker-compose logs $* storage 2>/dev/null || docker-compose logs $* storage-dev
}

check_health() {
    print_info "Checking storage service health..."

    if curl -sf http://localhost:8082/health > /dev/null 2>&1; then
        print_success "Storage service is healthy"
        echo ""
        print_info "Health details:"
        curl -s http://localhost:8082/health | jq '.' 2>/dev/null || curl -s http://localhost:8082/health
    else
        print_error "Storage service is not responding"
        print_info "Check logs with: $0 logs"
        exit 1
    fi
}

check_health_dev() {
    print_info "Checking storage service health (dev)..."

    if curl -sf http://localhost:8082/health > /dev/null 2>&1; then
        print_success "Storage service is healthy"
        echo ""
        print_info "Health details:"
        curl -s http://localhost:8082/health | jq '.' 2>/dev/null || curl -s http://localhost:8082/health
    else
        print_warn "Storage service is not yet ready"
        print_info "It may still be starting up. Check logs with: $0 logs"
    fi
}

show_metrics() {
    print_info "Fetching storage service metrics..."

    if curl -sf http://localhost:9092/metrics > /dev/null 2>&1; then
        print_success "Metrics endpoint is available"
        echo ""
        print_info "Prometheus metrics:"
        curl -s http://localhost:9092/metrics | grep "^storage_" | head -20
        echo ""
        print_info "Full metrics available at: http://localhost:9092/metrics"
    else
        print_error "Metrics endpoint is not responding"
        exit 1
    fi
}

open_shell() {
    print_info "Opening shell in storage container..."
    print_command "docker-compose exec storage bash"
    docker-compose exec storage bash 2>/dev/null || docker-compose exec storage-dev bash
}

run_migrations() {
    print_info "Running database migrations..."
    print_command "docker-compose run --rm storage sqlx migrate run"
    docker-compose run --rm storage sqlx migrate run --source /app/migrations
    print_success "Migrations completed"
}

run_tests() {
    print_info "Running storage service tests..."
    print_command "docker-compose --profile test up storage-test"
    docker-compose -f docker-compose.yml -f docker/docker-compose.storage.yml --profile test up --abort-on-container-exit storage-test
}

run_benchmarks() {
    print_info "Running storage service benchmarks..."
    print_command "docker-compose --profile bench up storage-bench"
    docker-compose -f docker-compose.yml -f docker/docker-compose.storage.yml --profile bench up --abort-on-container-exit storage-bench
}

clean_storage() {
    print_warn "This will remove all storage containers and volumes"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleaning storage containers..."
        docker-compose rm -f -s -v storage storage-dev 2>/dev/null || true

        print_info "Cleaning storage volumes..."
        docker volume rm llm-observatory-storage-target 2>/dev/null || true
        docker volume rm llm-observatory-storage-cargo-registry 2>/dev/null || true
        docker volume rm llm-observatory-storage-cargo-git 2>/dev/null || true

        print_success "Storage cleaned"
    else
        print_info "Clean cancelled"
    fi
}

show_status() {
    print_info "Storage service status:"
    echo ""

    # Check containers
    print_info "Containers:"
    docker-compose ps storage storage-dev 2>/dev/null || true
    echo ""

    # Check health
    print_info "Health check:"
    if curl -sf http://localhost:8082/health > /dev/null 2>&1; then
        print_success "Storage service is healthy"
        curl -s http://localhost:8082/health | jq '.pool' 2>/dev/null || true
    else
        print_error "Storage service is not responding"
    fi
    echo ""

    # Check metrics
    print_info "Metrics:"
    if curl -sf http://localhost:9092/metrics > /dev/null 2>&1; then
        print_success "Metrics endpoint is available"
        echo "  URL: http://localhost:9092/metrics"
    else
        print_error "Metrics endpoint is not responding"
    fi
    echo ""

    # Check database
    print_info "Database connection:"
    docker-compose exec -T timescaledb pg_isready -U postgres 2>/dev/null && \
        print_success "Database is ready" || \
        print_error "Database is not ready"
}

# Main
print_header

# Check requirements
check_docker
check_env

# Parse command
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    start)
        start_storage
        ;;
    start-dev)
        start_storage_dev
        ;;
    stop)
        stop_storage
        ;;
    restart)
        restart_storage
        ;;
    logs)
        show_logs "$@"
        ;;
    health)
        check_health
        ;;
    metrics)
        show_metrics
        ;;
    shell)
        open_shell
        ;;
    migrate)
        run_migrations
        ;;
    test)
        run_tests
        ;;
    bench)
        run_benchmarks
        ;;
    clean)
        clean_storage
        ;;
    status)
        show_status
        ;;
    help|-h|--help)
        show_usage
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac

#!/bin/bash
# Validate development environment setup

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  LLM Observatory - Dev Environment Validator  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Track validation results
PASSED=0
FAILED=0
WARNINGS=0

# Function to check file exists
check_file() {
    local file=$1
    local description=$2

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description (missing: $file)"
        ((FAILED++))
        return 1
    fi
}

# Function to check directory exists
check_dir() {
    local dir=$1
    local description=$2

    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description (missing: $dir)"
        ((FAILED++))
        return 1
    fi
}

# Function to check command exists
check_command() {
    local cmd=$1
    local description=$2

    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $description (not found: $cmd)"
        ((WARNINGS++))
        return 1
    fi
}

echo "Checking prerequisites..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_command "docker" "Docker installed"
check_command "docker-compose" "Docker Compose installed (legacy)" || true
check_command "make" "Make installed"

# Check Docker is running
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon running"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Docker daemon not running"
    ((FAILED++))
fi

echo ""
echo "Checking configuration files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_file "docker-compose.yml" "Production docker-compose.yml"
check_file "docker-compose.dev.yml" "Development docker-compose.dev.yml"
check_file ".dockerignore" ".dockerignore file"
check_file ".env.example" "Environment template"
check_file "Makefile" "Makefile"

if [ -f ".env" ]; then
    echo -e "${GREEN}✓${NC} .env file exists"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} .env file not found (will be created on first run)"
    ((WARNINGS++))
fi

echo ""
echo "Checking Docker files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_file "docker/Dockerfile.dev" "Development Dockerfile"
check_dir "docker/init" "Database init scripts directory"
check_file "docker/init/01-init-timescaledb.sql" "TimescaleDB init script"
check_dir "docker/seed" "Database seed directory"
check_file "docker/seed/seed.sql" "Seed data script"
check_file "docker/seed/reset.sql" "Database reset script"

echo ""
echo "Checking scripts..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_dir "scripts" "Scripts directory"
check_file "scripts/dev.sh" "Development helper script"

if [ -x "scripts/dev.sh" ]; then
    echo -e "${GREEN}✓${NC} dev.sh is executable"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} dev.sh is not executable"
    ((WARNINGS++))
fi

echo ""
echo "Checking documentation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_dir "docs" "Documentation directory"
check_file "docs/DEVELOPMENT.md" "Development guide"
check_file "QUICKSTART.md" "Quick start guide"
check_file "docker/README.md" "Docker README"
check_file "docker/README.dev.md" "Docker development guide"
check_file "docker/seed/README.md" "Seed data documentation"

echo ""
echo "Checking project structure..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_file "Cargo.toml" "Workspace Cargo.toml"
check_file "Cargo.lock" "Cargo.lock"
check_dir "crates" "Crates directory"
check_dir "crates/core" "Core crate"
check_dir "crates/collector" "Collector crate"
check_dir "crates/api" "API crate"
check_dir "crates/storage" "Storage crate"

echo ""
echo "Validating docker-compose.dev.yml..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker compose -f docker-compose.yml -f docker-compose.dev.yml config &> /dev/null; then
    echo -e "${GREEN}✓${NC} docker-compose.dev.yml is valid"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} docker-compose.dev.yml has syntax errors"
    ((FAILED++))
fi

# Check for required services in docker-compose.dev.yml
for service in collector api storage dev-utils; do
    if grep -q "^  $service:" docker-compose.dev.yml; then
        echo -e "${GREEN}✓${NC} Service '$service' configured"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Service '$service' not found"
        ((FAILED++))
    fi
done

# Check for required volumes
for volume in cargo_registry cargo_git collector_target api_target storage_target; do
    if grep -q "$volume:" docker-compose.dev.yml; then
        echo -e "${GREEN}✓${NC} Volume '$volume' configured"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Volume '$volume' not found"
        ((FAILED++))
    fi
done

echo ""
echo "Checking port availability..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if ports are available
for port in 5432 6379 3000 4317 4318 8080 8081 9091 9092 9093; do
    if ! lsof -i :$port &> /dev/null && ! netstat -an 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓${NC} Port $port is available"
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} Port $port is in use (may cause conflicts)"
        ((WARNINGS++))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC}   $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ Development environment is ready!          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Start the environment: make dev-start"
    echo "  2. Seed the database: make dev-seed"
    echo "  3. View logs: make dev-logs"
    echo "  4. Read the docs: less docs/DEVELOPMENT.md"
    echo ""
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ Validation failed - please fix errors      ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 1
fi

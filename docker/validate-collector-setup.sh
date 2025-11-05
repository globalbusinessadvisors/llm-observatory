#!/bin/bash

# =============================================================================
# Collector Service - Setup Validation Script
# =============================================================================
# Validates that all required files and configurations are in place
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Collector Service Setup Validation${NC}"
echo -e "${BLUE}=====================================${NC}\n"

# Function to check file exists
check_file() {
    local file=$1
    local description=$2

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description: ${file}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description: ${file} (NOT FOUND)"
        ((FAILED++))
        return 1
    fi
}

# Function to check directory exists
check_dir() {
    local dir=$1
    local description=$2

    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description: ${dir}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description: ${dir} (NOT FOUND)"
        ((FAILED++))
        return 1
    fi
}

# Function to check file content
check_content() {
    local file=$1
    local pattern=$2
    local description=$3

    if [ -f "$file" ] && grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $description (WARNING)"
        ((WARNINGS++))
        return 1
    fi
}

# Navigate to project root
cd "$(dirname "$0")/.."

echo -e "${BLUE}Checking Dockerfiles...${NC}"
check_file "docker/Dockerfile.collector" "Production Dockerfile"
check_file "docker/Dockerfile.collector.dev" "Development Dockerfile"

echo -e "\n${BLUE}Checking Docker Compose files...${NC}"
check_file "docker-compose.yml" "Base Docker Compose"
check_file "docker-compose.app.yml" "Application Docker Compose"
check_file "docker-compose.dev.yml" "Development Docker Compose"

echo -e "\n${BLUE}Checking Configuration files...${NC}"
check_dir "docker/config" "Config directory"
check_file "docker/config/collector.yaml" "Collector configuration"

echo -e "\n${BLUE}Checking Environment files...${NC}"
check_file ".env.example" "Environment template"
check_content ".env.example" "COLLECTOR_OTLP_GRPC_PORT" "Collector env vars in .env.example"

echo -e "\n${BLUE}Checking Documentation...${NC}"
check_file "docker/COLLECTOR_README.md" "Collector README"
check_file "docker/QUICKSTART.collector.md" "Quick Start Guide"
check_file "docker/DOCKER_SETUP_SUMMARY.md" "Setup Summary"
check_file "docker/FILES_CREATED.md" "Files Created List"

echo -e "\n${BLUE}Checking Tooling...${NC}"
check_file "docker/Makefile.collector" "Collector Makefile"
check_file "docker/validate-collector-setup.sh" "This validation script"

echo -e "\n${BLUE}Checking Docker Compose Services...${NC}"
check_content "docker-compose.app.yml" "collector:" "Collector service defined"
check_content "docker-compose.app.yml" "storage:" "Storage service defined"
check_content "docker-compose.app.yml" "collector-dev:" "Dev collector service defined"

echo -e "\n${BLUE}Checking Port Configurations...${NC}"
check_content "docker-compose.app.yml" "4327" "Collector OTLP gRPC port"
check_content "docker-compose.app.yml" "4328" "Collector OTLP HTTP port"
check_content "docker-compose.app.yml" "9091" "Collector metrics port"
check_content "docker-compose.app.yml" "8082" "Collector health port"

echo -e "\n${BLUE}Checking LLM Processing Features...${NC}"
check_content "docker-compose.app.yml" "COLLECTOR_LLM_ENRICHMENT_ENABLED" "LLM enrichment config"
check_content "docker-compose.app.yml" "COLLECTOR_TOKEN_COUNTING_ENABLED" "Token counting config"
check_content "docker-compose.app.yml" "COLLECTOR_COST_CALCULATION_ENABLED" "Cost calculation config"

echo -e "\n${BLUE}Checking Health Checks...${NC}"
check_content "docker-compose.app.yml" "healthcheck:" "Health checks configured"
check_content "docker/Dockerfile.collector" "HEALTHCHECK" "Health check in Dockerfile"

echo -e "\n${BLUE}Checking Security Features...${NC}"
check_content "docker/Dockerfile.collector" "USER collector" "Non-root user in production"
check_content "docker/Dockerfile.collector" "strip" "Binary stripping for size"

echo -e "\n${BLUE}Checking Build Optimization...${NC}"
check_content "docker/Dockerfile.collector" "multi-stage" "Multi-stage build mentioned"
check_content "docker/Dockerfile.collector" "dependencies" "Dependency caching layer"

# Additional optional checks
echo -e "\n${BLUE}Optional Checks...${NC}"

if [ -f ".env" ]; then
    echo -e "${GREEN}✓${NC} Local .env file exists"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Local .env file not found (copy from .env.example)"
    ((WARNINGS++))
fi

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker is installed"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Docker is not installed"
    ((FAILED++))
fi

if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker Compose is available"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Docker Compose is not available"
    ((FAILED++))
fi

if command -v make &> /dev/null; then
    echo -e "${GREEN}✓${NC} Make is installed (for Makefile)"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Make is not installed (optional, but recommended)"
    ((WARNINGS++))
fi

# Summary
echo -e "\n${BLUE}=====================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC}   $FAILED"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All critical checks passed!${NC}"
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo -e "1. Copy .env file: ${YELLOW}cp .env.example .env${NC}"
    echo -e "2. Build collector: ${YELLOW}make -f docker/Makefile.collector build${NC}"
    echo -e "3. Start services: ${YELLOW}make -f docker/Makefile.collector up${NC}"
    echo -e "4. Check health: ${YELLOW}make -f docker/Makefile.collector health${NC}"
    echo -e "\n${BLUE}Documentation:${NC}"
    echo -e "- Quick Start: ${YELLOW}docker/QUICKSTART.collector.md${NC}"
    echo -e "- Full Docs: ${YELLOW}docker/COLLECTOR_README.md${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Validation failed. Please fix the issues above.${NC}"
    exit 1
fi

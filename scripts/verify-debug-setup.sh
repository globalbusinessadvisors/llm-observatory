#!/bin/bash
# LLM Observatory - Debug Setup Verification Script
# This script verifies that all debugging tools and configurations are properly set up

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  LLM Observatory - Debug Setup Verification               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if a command exists
check_command() {
    local cmd=$1
    local name=$2
    local required=$3

    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -n1)
        echo -e "${GREEN}✓${NC} $name installed: $version"
        ((CHECKS_PASSED++))
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}✗${NC} $name not found (REQUIRED)"
            ((CHECKS_FAILED++))
        else
            echo -e "${YELLOW}⚠${NC} $name not found (optional)"
            ((CHECKS_WARNING++))
        fi
        return 1
    fi
}

# Function to check if a file exists
check_file() {
    local file=$1
    local name=$2

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $name exists"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $name not found"
        ((CHECKS_FAILED++))
        return 1
    fi
}

# Function to check if a directory exists
check_directory() {
    local dir=$1
    local name=$2

    if [ -d "$dir" ]; then
        local count=$(find "$dir" -type f | wc -l)
        echo -e "${GREEN}✓${NC} $name exists ($count files)"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $name not found"
        ((CHECKS_FAILED++))
        return 1
    fi
}

echo -e "${BLUE}═══ System Tools ═══${NC}"
check_command "cargo" "Rust/Cargo" "required"
check_command "rustc" "Rust Compiler" "required"
check_command "lldb" "LLDB Debugger" "required"
check_command "rust-lldb" "Rust LLDB Wrapper" "optional"
check_command "gdb" "GDB Debugger" "optional"
check_command "rust-gdb" "Rust GDB Wrapper" "optional"
check_command "docker" "Docker" "required"
check_command "docker-compose" "Docker Compose" "required"
echo ""

echo -e "${BLUE}═══ Debug Tools (Optional) ═══${NC}"
check_command "valgrind" "Valgrind (Memory Debugger)" "optional"
check_command "heaptrack" "Heaptrack (Heap Profiler)" "optional"
check_command "perf" "Perf (CPU Profiler)" "optional"
check_command "strace" "Strace (System Call Tracer)" "optional"
echo ""

echo -e "${BLUE}═══ VSCode Configuration Files ═══${NC}"
check_file ".vscode/launch.json" "VSCode Launch Config"
check_file ".vscode/tasks.json" "VSCode Tasks Config"
check_file ".vscode/settings.json" "VSCode Settings"
check_file ".vscode/extensions.json" "VSCode Extensions"
check_file ".vscode/QUICK_START.md" "VSCode Quick Start Guide"
echo ""

echo -e "${BLUE}═══ IntelliJ/RustRover Configurations ═══${NC}"
check_directory ".run" "Run Configurations Directory"
check_file ".run/README.md" "Run Configurations Guide"
check_file ".run/Collector.run.xml" "Collector Run Config"
check_file ".run/API.run.xml" "API Run Config"
check_file ".run/All Tests.run.xml" "All Tests Config"
echo ""

echo -e "${BLUE}═══ Docker Debug Configurations ═══${NC}"
check_file "docker-compose.debug.yml" "Debug Docker Compose"
check_file "docker/Dockerfile.collector.debug" "Collector Debug Dockerfile"
check_file "docker/Dockerfile.api.debug" "API Debug Dockerfile"
echo ""

echo -e "${BLUE}═══ Documentation ═══${NC}"
check_file "docs/DEBUGGING.md" "Debugging Guide"
echo ""

echo -e "${BLUE}═══ Project Structure ═══${NC}"
check_file "Cargo.toml" "Workspace Cargo.toml"
check_file "docker-compose.yml" "Main Docker Compose"
check_file ".env.example" "Environment Template"

# Check if .env exists
if [ -f ".env" ]; then
    echo -e "${GREEN}✓${NC} .env file exists"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} .env file not found (copy from .env.example)"
    ((CHECKS_WARNING++))
fi
echo ""

echo -e "${BLUE}═══ Cargo Build Profiles ═══${NC}"
if grep -q "\[profile.release-with-debug\]" Cargo.toml; then
    echo -e "${GREEN}✓${NC} release-with-debug profile configured"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} release-with-debug profile not found in Cargo.toml"
    ((CHECKS_WARNING++))
fi
echo ""

echo -e "${BLUE}═══ Docker Status ═══${NC}"
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon is running"
    ((CHECKS_PASSED++))

    # Check if containers are running
    if docker-compose ps 2>&1 | grep -q "Up"; then
        echo -e "${GREEN}✓${NC} Docker Compose services are running"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} Docker Compose services not running (run: docker-compose up -d)"
        ((CHECKS_WARNING++))
    fi
else
    echo -e "${RED}✗${NC} Docker daemon is not running"
    ((CHECKS_FAILED++))
fi
echo ""

echo -e "${BLUE}═══ VSCode Extensions (if VSCode is installed) ═══${NC}"
if command -v code &> /dev/null; then
    echo -e "${GREEN}✓${NC} VSCode CLI available"
    ((CHECKS_PASSED++))

    # Check key extensions
    if code --list-extensions 2>&1 | grep -q "rust-lang.rust-analyzer"; then
        echo -e "${GREEN}✓${NC} rust-analyzer extension installed"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} rust-analyzer extension not installed"
        echo -e "   Install with: code --install-extension rust-lang.rust-analyzer"
        ((CHECKS_WARNING++))
    fi

    if code --list-extensions 2>&1 | grep -q "vadimcn.vscode-lldb"; then
        echo -e "${GREEN}✓${NC} CodeLLDB extension installed"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} CodeLLDB extension not installed"
        echo -e "   Install with: code --install-extension vadimcn.vscode-lldb"
        ((CHECKS_WARNING++))
    fi
else
    echo -e "${YELLOW}⚠${NC} VSCode CLI not found (optional)"
    ((CHECKS_WARNING++))
fi
echo ""

echo -e "${BLUE}═══ Build Test ═══${NC}"
if [ "$1" = "--skip-build" ]; then
    echo -e "${YELLOW}⚠${NC} Build test skipped (use without --skip-build to test)"
    ((CHECKS_WARNING++))
else
    echo "Testing debug build..."
    if cargo build --workspace --all-targets &> /tmp/cargo-build.log; then
        echo -e "${GREEN}✓${NC} Debug build successful"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} Debug build failed"
        echo "   Check /tmp/cargo-build.log for details"
        ((CHECKS_FAILED++))
    fi
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Summary                                                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Checks passed:  ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks failed:  ${RED}$CHECKS_FAILED${NC}"
echo -e "Warnings:       ${YELLOW}$CHECKS_WARNING${NC}"
echo ""

# Recommendations
if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${RED}═══ Action Required ═══${NC}"
    echo "Some critical checks failed. Please address the issues above."
    echo ""
fi

if [ $CHECKS_WARNING -gt 0 ]; then
    echo -e "${YELLOW}═══ Recommendations ═══${NC}"
    echo "Some optional components are missing. Consider installing them for better debugging experience."
    echo ""
fi

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}═══ Getting Started ═══${NC}"
    echo "Your debug environment is ready! Here's what you can do:"
    echo ""
    echo "1. Start infrastructure:"
    echo "   docker-compose up -d"
    echo ""
    echo "2. VSCode debugging:"
    echo "   - Open project in VSCode"
    echo "   - Press F5 to start debugging"
    echo "   - See .vscode/QUICK_START.md for more info"
    echo ""
    echo "3. IntelliJ/RustRover:"
    echo "   - Open project in IDE"
    echo "   - Select run configuration from dropdown"
    echo "   - See .run/README.md for more info"
    echo ""
    echo "4. Debug with Docker:"
    echo "   docker-compose -f docker-compose.yml -f docker-compose.debug.yml up --build"
    echo ""
    echo "5. Read the full guide:"
    echo "   docs/DEBUGGING.md"
    echo ""
fi

# Exit code
if [ $CHECKS_FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi

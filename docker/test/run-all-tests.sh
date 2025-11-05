#!/bin/bash
# Run all tests with comprehensive reporting
# This script is designed to run inside the test container

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
TEST_RESULTS_DIR="${WORKSPACE_DIR}/test-results"
NEXTEST_PROFILE="${NEXTEST_PROFILE:-ci}"
RUST_BACKTRACE="${RUST_BACKTRACE:-1}"
TEST_THREADS="${TEST_THREADS:-4}"

# Create results directory
mkdir -p "${TEST_RESULTS_DIR}"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}               LLM Observatory - Comprehensive Test Suite${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Function to wait for service
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    local max_attempts=30
    local attempt=1

    print_status "Waiting for ${service} at ${host}:${port}..."

    while ! nc -z "${host}" "${port}" 2>/dev/null; do
        if [ ${attempt} -eq ${max_attempts} ]; then
            print_error "${service} not available after ${max_attempts} attempts"
            return 1
        fi
        echo -n "."
        sleep 1
        ((attempt++))
    done

    echo ""
    print_status "${service} is ready!"
    return 0
}

# Check dependencies
print_status "Checking dependencies..."

if ! command -v cargo &> /dev/null; then
    print_error "cargo not found"
    exit 1
fi

if ! command -v cargo-nextest &> /dev/null; then
    print_warning "cargo-nextest not found, installing..."
    cargo install cargo-nextest --locked
fi

# Wait for database if DATABASE_URL is set
if [ -n "${DATABASE_URL}" ]; then
    DB_HOST=$(echo "${DATABASE_URL}" | sed -n 's/.*@\(.*\):.*/\1/p')
    DB_PORT=$(echo "${DATABASE_URL}" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')

    if [ -n "${DB_HOST}" ] && [ -n "${DB_PORT}" ]; then
        wait_for_service "${DB_HOST}" "${DB_PORT}" "PostgreSQL"
    fi
fi

# Wait for Redis if REDIS_URL is set
if [ -n "${REDIS_URL}" ]; then
    REDIS_HOST=$(echo "${REDIS_URL}" | sed -n 's/.*@\(.*\):.*/\1/p')
    REDIS_PORT=$(echo "${REDIS_URL}" | sed -n 's/.*:\([0-9]*\).*/\1/p')

    if [ -n "${REDIS_HOST}" ] && [ -n "${REDIS_PORT}" ]; then
        wait_for_service "${REDIS_HOST}" "${REDIS_PORT}" "Redis"
    fi
fi

# Run database migrations if sqlx is available
if [ -n "${DATABASE_URL}" ] && command -v sqlx &> /dev/null; then
    print_status "Running database migrations..."
    if [ -d "${WORKSPACE_DIR}/migrations" ]; then
        sqlx migrate run --source "${WORKSPACE_DIR}/migrations" || {
            print_warning "Migration failed, continuing with tests..."
        }
    fi
fi

echo ""
print_status "Starting test execution..."
echo ""

# Track test failures
FAILED_TESTS=()
EXIT_CODE=0

# Run lint checks
print_status "Running lint checks..."
if cargo clippy --workspace --all-features --all-targets -- -D warnings 2>&1 | tee "${TEST_RESULTS_DIR}/clippy.log"; then
    echo -e "${GREEN}✓ Clippy passed${NC}"
else
    echo -e "${RED}✗ Clippy failed${NC}"
    FAILED_TESTS+=("Clippy")
    EXIT_CODE=1
fi
echo ""

# Run format check
print_status "Running format check..."
if cargo fmt --all -- --check 2>&1 | tee "${TEST_RESULTS_DIR}/fmt.log"; then
    echo -e "${GREEN}✓ Format check passed${NC}"
else
    echo -e "${RED}✗ Format check failed${NC}"
    FAILED_TESTS+=("Format")
    EXIT_CODE=1
fi
echo ""

# Run unit tests
print_status "Running unit tests..."
if cargo nextest run \
    --profile "${NEXTEST_PROFILE}" \
    --workspace \
    --lib \
    --all-features \
    --no-fail-fast \
    --test-threads "${TEST_THREADS}" 2>&1 | tee "${TEST_RESULTS_DIR}/unit-tests.log"; then
    echo -e "${GREEN}✓ Unit tests passed${NC}"
else
    echo -e "${RED}✗ Unit tests failed${NC}"
    FAILED_TESTS+=("Unit tests")
    EXIT_CODE=1
fi
echo ""

# Run integration tests
print_status "Running integration tests..."
if cargo nextest run \
    --profile "${NEXTEST_PROFILE}" \
    --workspace \
    --test '*' \
    --all-features \
    --no-fail-fast \
    --test-threads "${TEST_THREADS}" 2>&1 | tee "${TEST_RESULTS_DIR}/integration-tests.log"; then
    echo -e "${GREEN}✓ Integration tests passed${NC}"
else
    echo -e "${RED}✗ Integration tests failed${NC}"
    FAILED_TESTS+=("Integration tests")
    EXIT_CODE=1
fi
echo ""

# Run doc tests
print_status "Running documentation tests..."
if cargo test --workspace --doc --all-features 2>&1 | tee "${TEST_RESULTS_DIR}/doc-tests.log"; then
    echo -e "${GREEN}✓ Doc tests passed${NC}"
else
    echo -e "${RED}✗ Doc tests failed${NC}"
    FAILED_TESTS+=("Doc tests")
    EXIT_CODE=1
fi
echo ""

# Build documentation
print_status "Building documentation..."
if cargo doc --workspace --all-features --no-deps 2>&1 | tee "${TEST_RESULTS_DIR}/doc-build.log"; then
    echo -e "${GREEN}✓ Documentation built successfully${NC}"
else
    echo -e "${RED}✗ Documentation build failed${NC}"
    FAILED_TESTS+=("Documentation")
    EXIT_CODE=1
fi
echo ""

# Security audit
if command -v cargo-audit &> /dev/null; then
    print_status "Running security audit..."
    if cargo audit --json > "${TEST_RESULTS_DIR}/audit.json" 2>&1; then
        echo -e "${GREEN}✓ Security audit passed${NC}"
    else
        echo -e "${YELLOW}⚠ Security audit found issues${NC}"
        FAILED_TESTS+=("Security audit")
    fi
    echo ""
fi

# Generate test summary
print_status "Generating test summary..."

cat > "${TEST_RESULTS_DIR}/summary.txt" << EOF
================================================================================
                    LLM Observatory Test Summary
================================================================================
Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Profile: ${NEXTEST_PROFILE}
Threads: ${TEST_THREADS}
Rust Version: $(rustc --version)
Cargo Version: $(cargo --version)

Test Results:
EOF

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    cat >> "${TEST_RESULTS_DIR}/summary.txt" << EOF

✓ All tests passed!

EOF
else
    cat >> "${TEST_RESULTS_DIR}/summary.txt" << EOF

✗ Some tests failed:
$(printf '  - %s\n' "${FAILED_TESTS[@]}")

EOF
fi

cat >> "${TEST_RESULTS_DIR}/summary.txt" << EOF
================================================================================
EOF

cat "${TEST_RESULTS_DIR}/summary.txt"

# Export test results in JUnit format for CI
if command -v cargo-nextest &> /dev/null; then
    print_status "Exporting test results in JUnit format..."
    cargo nextest run \
        --profile "${NEXTEST_PROFILE}" \
        --workspace \
        --all-features \
        --message-format libtest-json \
        > "${TEST_RESULTS_DIR}/results.json" 2>&1 || true
fi

# Generate HTML report if available
if [ -f "${TEST_RESULTS_DIR}/results.json" ]; then
    print_status "Test results saved to ${TEST_RESULTS_DIR}/results.json"
fi

echo ""
if [ ${EXIT_CODE} -eq 0 ]; then
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}                    ALL TESTS PASSED ✓${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
else
    echo -e "${RED}==============================================================================${NC}"
    echo -e "${RED}                    SOME TESTS FAILED ✗${NC}"
    echo -e "${RED}==============================================================================${NC}"
    echo -e "${RED}Failed tests: ${#FAILED_TESTS[@]}${NC}"
fi

exit ${EXIT_CODE}

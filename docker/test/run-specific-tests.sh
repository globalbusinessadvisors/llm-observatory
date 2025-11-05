#!/bin/bash
# Run specific test suites or individual tests
# Usage: ./run-specific-tests.sh [OPTIONS] [TEST_PATTERN]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
TEST_RESULTS_DIR="${WORKSPACE_DIR}/test-results"
NEXTEST_PROFILE="${NEXTEST_PROFILE:-default}"

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_PATTERN]

Run specific tests or test suites in the LLM Observatory project.

OPTIONS:
    -h, --help              Show this help message
    -p, --package PKG       Run tests only in the specified package
    -t, --test-type TYPE    Run specific test type: unit, integration, doc
    -f, --filter FILTER     Run tests matching the filter pattern
    -e, --exact             Use exact matching for test names
    -i, --ignored           Run only ignored tests
    --no-capture            Don't capture test output
    --nocapture             Alias for --no-capture
    -v, --verbose           Verbose output
    --list                  List all available tests
    --features FEATURES     Run with specific features enabled

TEST_PATTERN:
    Optional test name pattern to match (regex supported)

EXAMPLES:
    # Run all tests in the 'core' package
    $0 --package llm-observatory-core

    # Run all unit tests
    $0 --test-type unit

    # Run tests matching 'database'
    $0 --filter database

    # Run a specific test
    $0 --exact test_connection

    # List all available tests
    $0 --list

    # Run integration tests with verbose output
    $0 --test-type integration --verbose

    # Run tests in storage package with specific features
    $0 --package llm-observatory-storage --features timescaledb

AVAILABLE PACKAGES:
    llm-observatory-core
    llm-observatory-collector
    llm-observatory-storage
    llm-observatory-api
    llm-observatory-sdk
    llm-observatory-providers
    llm-observatory-cli
EOF
}

print_status() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Parse arguments
PACKAGE=""
TEST_TYPE=""
FILTER=""
EXACT=false
IGNORED=false
NO_CAPTURE=false
VERBOSE=false
LIST_TESTS=false
FEATURES=""
TEST_PATTERN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -p|--package)
            PACKAGE="$2"
            shift 2
            ;;
        -t|--test-type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -f|--filter)
            FILTER="$2"
            shift 2
            ;;
        -e|--exact)
            EXACT=true
            shift
            ;;
        -i|--ignored)
            IGNORED=true
            shift
            ;;
        --no-capture|--nocapture)
            NO_CAPTURE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --list)
            LIST_TESTS=true
            shift
            ;;
        --features)
            FEATURES="$2"
            shift 2
            ;;
        -*)
            print_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            TEST_PATTERN="$1"
            shift
            ;;
    esac
done

# Build cargo nextest command
CARGO_CMD="cargo nextest run"
CARGO_ARGS=()

# Add profile
CARGO_ARGS+=("--profile" "${NEXTEST_PROFILE}")

# Add package filter
if [ -n "${PACKAGE}" ]; then
    CARGO_ARGS+=("--package" "${PACKAGE}")
else
    CARGO_ARGS+=("--workspace")
fi

# Add test type filter
case "${TEST_TYPE}" in
    unit)
        CARGO_ARGS+=("--lib")
        ;;
    integration)
        CARGO_ARGS+=("--test" "*")
        ;;
    doc)
        CARGO_CMD="cargo test"
        CARGO_ARGS=("--doc")
        if [ -n "${PACKAGE}" ]; then
            CARGO_ARGS+=("--package" "${PACKAGE}")
        else
            CARGO_ARGS+=("--workspace")
        fi
        ;;
    "")
        # Run all tests
        ;;
    *)
        print_error "Invalid test type: ${TEST_TYPE}"
        print_usage
        exit 1
        ;;
esac

# Add features
if [ -n "${FEATURES}" ]; then
    CARGO_ARGS+=("--features" "${FEATURES}")
else
    CARGO_ARGS+=("--all-features")
fi

# Add filter or test pattern
if [ -n "${FILTER}" ]; then
    CARGO_ARGS+=("--filter" "${FILTER}")
elif [ -n "${TEST_PATTERN}" ]; then
    if [ "${EXACT}" = true ]; then
        CARGO_ARGS+=("--exact" "${TEST_PATTERN}")
    else
        CARGO_ARGS+=("${TEST_PATTERN}")
    fi
fi

# Add flags
if [ "${IGNORED}" = true ]; then
    CARGO_ARGS+=("--run-ignored" "ignored-only")
fi

if [ "${NO_CAPTURE}" = true ]; then
    CARGO_ARGS+=("--no-capture")
fi

if [ "${VERBOSE}" = true ]; then
    CARGO_ARGS+=("--verbose")
fi

# List tests if requested
if [ "${LIST_TESTS}" = true ]; then
    print_status "Listing available tests..."
    echo ""

    if [ "${TEST_TYPE}" = "doc" ]; then
        cargo test --workspace --doc --all-features -- --list
    else
        cargo nextest list --workspace --all-features
    fi

    exit 0
fi

# Create results directory
mkdir -p "${TEST_RESULTS_DIR}"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                  LLM Observatory - Specific Tests${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

print_status "Test configuration:"
echo "  Package: ${PACKAGE:-all}"
echo "  Test type: ${TEST_TYPE:-all}"
echo "  Filter: ${FILTER:-${TEST_PATTERN:-none}}"
echo "  Features: ${FEATURES:-all}"
echo ""

print_status "Running command:"
echo "  ${CARGO_CMD} ${CARGO_ARGS[*]}"
echo ""

# Execute tests
print_status "Starting test execution..."
echo ""

${CARGO_CMD} "${CARGO_ARGS[@]}"
EXIT_CODE=$?

echo ""

if [ ${EXIT_CODE} -eq 0 ]; then
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}                       TESTS PASSED ✓${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
else
    echo -e "${RED}==============================================================================${NC}"
    echo -e "${RED}                       TESTS FAILED ✗${NC}"
    echo -e "${RED}==============================================================================${NC}"
fi

exit ${EXIT_CODE}

#!/bin/bash
# Generate code coverage reports using cargo-tarpaulin
# Supports multiple output formats: HTML, LCOV, JSON, XML

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
COVERAGE_DIR="${COVERAGE_OUTPUT_DIR:-${WORKSPACE_DIR}/coverage}"
COVERAGE_FORMAT="${COVERAGE_FORMAT:-html,lcov}"
TARPAULIN_TIMEOUT="${TARPAULIN_TIMEOUT:-600}"
MIN_COVERAGE="${MIN_COVERAGE:-70}"

# Create coverage directory
mkdir -p "${COVERAGE_DIR}"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                  LLM Observatory - Coverage Report${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

print_status() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if tarpaulin is installed
if ! command -v cargo-tarpaulin &> /dev/null; then
    print_error "cargo-tarpaulin not found"
    print_status "Installing cargo-tarpaulin..."
    cargo install cargo-tarpaulin --locked
fi

# Parse coverage formats
IFS=',' read -ra FORMATS <<< "${COVERAGE_FORMAT}"
TARPAULIN_ARGS=()

for format in "${FORMATS[@]}"; do
    format=$(echo "$format" | tr '[:lower:]' '[:upper:]' | xargs)
    TARPAULIN_ARGS+=("--out" "${format}")
done

print_status "Coverage configuration:"
echo "  Output directory: ${COVERAGE_DIR}"
echo "  Formats: ${COVERAGE_FORMAT}"
echo "  Timeout: ${TARPAULIN_TIMEOUT}s"
echo "  Minimum coverage: ${MIN_COVERAGE}%"
echo ""

# Wait for database if needed
if [ -n "${DATABASE_URL}" ]; then
    print_status "Waiting for database..."
    DB_HOST=$(echo "${DATABASE_URL}" | sed -n 's/.*@\(.*\):.*/\1/p')
    DB_PORT=$(echo "${DATABASE_URL}" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')

    max_attempts=30
    attempt=1
    while ! nc -z "${DB_HOST}" "${DB_PORT}" 2>/dev/null; do
        if [ ${attempt} -eq ${max_attempts} ]; then
            print_error "Database not available"
            exit 1
        fi
        echo -n "."
        sleep 1
        ((attempt++))
    done
    echo ""
    print_status "Database ready!"
fi

# Run migrations if available
if [ -n "${DATABASE_URL}" ] && command -v sqlx &> /dev/null; then
    if [ -d "${WORKSPACE_DIR}/migrations" ]; then
        print_status "Running database migrations..."
        sqlx migrate run --source "${WORKSPACE_DIR}/migrations" || {
            print_warning "Migration failed, continuing..."
        }
    fi
fi

print_status "Starting coverage analysis..."
echo ""

# Run tarpaulin with configured options
cargo tarpaulin \
    --workspace \
    --all-features \
    --engine llvm \
    "${TARPAULIN_ARGS[@]}" \
    --output-dir "${COVERAGE_DIR}" \
    --timeout "${TARPAULIN_TIMEOUT}" \
    --follow-exec \
    --locked \
    --verbose \
    --skip-clean \
    --exclude-files "target/*" \
    --exclude-files "tests/*" \
    --exclude-files "*/tests/*" \
    2>&1 | tee "${COVERAGE_DIR}/coverage.log"

EXIT_CODE=$?

echo ""

if [ ${EXIT_CODE} -eq 0 ]; then
    print_status "Coverage analysis completed successfully!"

    # Extract coverage percentage from lcov file if available
    if [ -f "${COVERAGE_DIR}/lcov.info" ]; then
        # Calculate coverage percentage
        LINES_FOUND=$(grep -E "^LF:" "${COVERAGE_DIR}/lcov.info" | cut -d: -f2 | awk '{s+=$1} END {print s}')
        LINES_HIT=$(grep -E "^LH:" "${COVERAGE_DIR}/lcov.info" | cut -d: -f2 | awk '{s+=$1} END {print s}')

        if [ -n "${LINES_FOUND}" ] && [ "${LINES_FOUND}" -gt 0 ]; then
            COVERAGE=$(awk "BEGIN {printf \"%.2f\", (${LINES_HIT}/${LINES_FOUND})*100}")

            echo ""
            echo -e "${BLUE}==============================================================================${NC}"
            echo -e "${BLUE}                       Coverage Summary${NC}"
            echo -e "${BLUE}==============================================================================${NC}"
            echo "  Total lines: ${LINES_FOUND}"
            echo "  Covered lines: ${LINES_HIT}"
            echo -e "  Coverage: ${GREEN}${COVERAGE}%${NC}"
            echo -e "${BLUE}==============================================================================${NC}"
            echo ""

            # Check minimum coverage threshold
            if [ "$(echo "${COVERAGE} < ${MIN_COVERAGE}" | bc -l)" -eq 1 ]; then
                print_warning "Coverage ${COVERAGE}% is below minimum threshold of ${MIN_COVERAGE}%"
                EXIT_CODE=1
            else
                print_status "Coverage meets minimum threshold!"
            fi

            # Save coverage summary
            cat > "${COVERAGE_DIR}/summary.json" << EOF
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "total_lines": ${LINES_FOUND},
  "covered_lines": ${LINES_HIT},
  "coverage_percentage": ${COVERAGE},
  "minimum_threshold": ${MIN_COVERAGE},
  "threshold_met": $([ "$(echo "${COVERAGE} >= ${MIN_COVERAGE}" | bc -l)" -eq 1 ] && echo "true" || echo "false")
}
EOF
        fi
    fi

    # List generated reports
    print_status "Generated reports:"
    ls -lh "${COVERAGE_DIR}" | grep -v "^total" | grep -v "^d" | awk '{print "  - " $9 " (" $5 ")"}'

    if [ -f "${COVERAGE_DIR}/index.html" ]; then
        echo ""
        print_status "HTML report: ${COVERAGE_DIR}/index.html"
    fi

else
    print_error "Coverage analysis failed with exit code ${EXIT_CODE}"
fi

echo ""
exit ${EXIT_CODE}

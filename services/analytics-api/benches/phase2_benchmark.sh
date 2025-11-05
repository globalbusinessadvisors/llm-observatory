#!/bin/bash
#
# Phase 2 Performance Benchmark Script
# Tests Phase 2 advanced search and filtering endpoints
#
# Requirements:
# - Running Analytics API (localhost:8080)
# - Valid JWT token
# - Apache Bench (ab) or wrk installed
# - jq for JSON processing
#
# Usage: ./benches/phase2_benchmark.sh [base_url] [jwt_token]

set -e

# Configuration
BASE_URL="${1:-http://localhost:8080}"
JWT_TOKEN="${2:-$(cat ~/.llm-observatory-jwt 2>/dev/null || echo 'test_token')}"
RESULTS_DIR="./benches/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$RESULTS_DIR"

echo "======================================================================"
echo "Phase 2 Performance Benchmark"
echo "======================================================================"
echo "Base URL: $BASE_URL"
echo "Results: $RESULTS_DIR/benchmark_${TIMESTAMP}.json"
echo ""

# Function to run benchmark
run_benchmark() {
    local name="$1"
    local url="$2"
    local method="$3"
    local data="$4"
    local concurrency="${5:-10}"
    local requests="${6:-1000}"

    echo -e "${YELLOW}Testing: $name${NC}"
    echo "  Concurrency: $concurrency"
    echo "  Requests: $requests"

    if command -v wrk &> /dev/null; then
        # Use wrk if available (better for POST requests)
        if [ "$method" == "POST" ]; then
            local temp_script=$(mktemp)
            cat > "$temp_script" <<EOF
wrk.method = "POST"
wrk.body = '$data'
wrk.headers["Content-Type"] = "application/json"
wrk.headers["Authorization"] = "Bearer $JWT_TOKEN"
EOF
            wrk -t4 -c"$concurrency" -d30s --latency -s "$temp_script" "$url" | tee "$RESULTS_DIR/${name}_${TIMESTAMP}.txt"
            rm "$temp_script"
        else
            wrk -t4 -c"$concurrency" -d30s --latency -H "Authorization: Bearer $JWT_TOKEN" "$url" | tee "$RESULTS_DIR/${name}_${TIMESTAMP}.txt"
        fi
    elif command -v ab &> /dev/null; then
        # Fallback to Apache Bench
        if [ "$method" == "POST" ]; then
            echo "$data" > /tmp/post_data.json
            ab -n "$requests" -c "$concurrency" -T "application/json" \
                -H "Authorization: Bearer $JWT_TOKEN" \
                -p /tmp/post_data.json \
                "$url" | tee "$RESULTS_DIR/${name}_${TIMESTAMP}.txt"
            rm /tmp/post_data.json
        else
            ab -n "$requests" -c "$concurrency" \
                -H "Authorization: Bearer $JWT_TOKEN" \
                "$url" | tee "$RESULTS_DIR/${name}_${TIMESTAMP}.txt"
        fi
    else
        echo -e "${RED}Error: Neither wrk nor ab found. Please install one of them.${NC}"
        exit 1
    fi

    echo ""
}

# Function to test simple query performance
test_simple_query() {
    local data=$(cat <<EOF
{
  "filter": {
    "field": "provider",
    "operator": "eq",
    "value": "openai"
  },
  "limit": 50
}
EOF
)
    run_benchmark "simple_eq_filter" "${BASE_URL}/api/v1/traces/search" "POST" "$data" 50 2000
}

# Function to test comparison operators
test_comparison_operators() {
    local data=$(cat <<EOF
{
  "filter": {
    "field": "duration_ms",
    "operator": "gte",
    "value": 1000
  },
  "limit": 50
}
EOF
)
    run_benchmark "comparison_gte" "${BASE_URL}/api/v1/traces/search" "POST" "$data" 50 2000
}

# Function to test IN operator
test_in_operator() {
    local data=$(cat <<EOF
{
  "filter": {
    "field": "provider",
    "operator": "in",
    "value": ["openai", "anthropic", "google"]
  },
  "limit": 50
}
EOF
)
    run_benchmark "in_operator" "${BASE_URL}/api/v1/traces/search" "POST" "$data" 50 2000
}

# Function to test full-text search
test_fulltext_search() {
    local data=$(cat <<EOF
{
  "filter": {
    "field": "input_text",
    "operator": "search",
    "value": "authentication error"
  },
  "limit": 50
}
EOF
)
    run_benchmark "fulltext_search" "${BASE_URL}/api/v1/traces/search" "POST" "$data" 30 1000
}

# Function to test complex nested filters
test_complex_nested() {
    local data=$(cat <<EOF
{
  "filter": {
    "operator": "AND",
    "filters": [
      {
        "field": "provider",
        "operator": "eq",
        "value": "openai"
      },
      {
        "operator": "OR",
        "filters": [
          {
            "field": "duration_ms",
            "operator": "gt",
            "value": 1000
          },
          {
            "field": "total_cost_usd",
            "operator": "gt",
            "value": 0.01
          }
        ]
      }
    ]
  },
  "limit": 50
}
EOF
)
    run_benchmark "complex_nested_3_levels" "${BASE_URL}/api/v1/traces/search" "POST" "$data" 30 1000
}

# Function to test combined search and filters
test_combined_search_filters() {
    local data=$(cat <<EOF
{
  "filter": {
    "operator": "AND",
    "filters": [
      {
        "field": "provider",
        "operator": "eq",
        "value": "openai"
      },
      {
        "field": "input_text",
        "operator": "search",
        "value": "generate code"
      },
      {
        "field": "duration_ms",
        "operator": "gte",
        "value": 500
      }
    ]
  },
  "sort_by": "ts",
  "sort_desc": true,
  "limit": 50
}
EOF
)
    run_benchmark "combined_search_filters" "${BASE_URL}/api/v1/traces/search" "POST" "$data" 30 1000
}

# Function to test large result sets
test_large_result_set() {
    local data=$(cat <<EOF
{
  "filter": {
    "field": "status_code",
    "operator": "eq",
    "value": "SUCCESS"
  },
  "limit": 1000
}
EOF
)
    run_benchmark "large_result_set_1000" "${BASE_URL}/api/v1/traces/search" "POST" "$data" 10 500
}

# Function to test cache performance
test_cache_performance() {
    echo -e "${YELLOW}Testing cache performance (repeat same query)${NC}"

    local data=$(cat <<EOF
{
  "filter": {
    "field": "provider",
    "operator": "eq",
    "value": "openai"
  },
  "limit": 50
}
EOF
)

    # First request (cache miss)
    echo "First request (cache miss):"
    run_benchmark "cache_miss" "${BASE_URL}/api/v1/traces/search" "POST" "$data" 1 10

    # Second request (cache hit)
    echo "Second request (cache hit):"
    run_benchmark "cache_hit" "${BASE_URL}/api/v1/traces/search" "POST" "$data" 100 2000
}

# Function to run all benchmarks
run_all_benchmarks() {
    echo -e "${GREEN}Starting all Phase 2 benchmarks...${NC}"
    echo ""

    test_simple_query
    test_comparison_operators
    test_in_operator
    test_fulltext_search
    test_complex_nested
    test_combined_search_filters
    test_large_result_set
    test_cache_performance

    echo ""
    echo -e "${GREEN}All benchmarks complete!${NC}"
    echo "Results saved to: $RESULTS_DIR"
}

# Function to generate summary report
generate_summary() {
    echo ""
    echo "======================================================================"
    echo "Performance Summary"
    echo "======================================================================"
    echo ""

    # Parse results and show summary
    # This is a placeholder - real implementation would parse the actual results
    cat <<EOF
Target Performance Metrics (Phase 2):
  - Simple filters:        P95 < 50ms,  Throughput > 5000 req/s
  - Complex nested:        P95 < 150ms, Throughput > 1000 req/s
  - Full-text search:      P95 < 100ms, Throughput > 1500 req/s
  - Combined filters:      P95 < 200ms, Throughput > 800 req/s

Review detailed results in: $RESULTS_DIR

Optimization Checklist:
  ✓ GIN indexes created for full-text search
  ✓ B-tree indexes on common filter fields
  ✓ Redis caching enabled
  ✓ Cursor-based pagination
  ✓ Connection pooling configured
  □ Query plan analysis (run EXPLAIN ANALYZE)
  □ Index usage verification
  □ Cache hit rate monitoring

Next Steps:
  1. Analyze slow queries with: EXPLAIN ANALYZE
  2. Check index usage:  SELECT * FROM pg_stat_user_indexes;
  3. Monitor cache hits: Check Redis stats
  4. Review query patterns in logs
  5. Optimize slow queries based on results
EOF
}

# Main execution
case "${1:-all}" in
    simple)
        test_simple_query
        ;;
    comparison)
        test_comparison_operators
        ;;
    in)
        test_in_operator
        ;;
    search)
        test_fulltext_search
        ;;
    nested)
        test_complex_nested
        ;;
    combined)
        test_combined_search_filters
        ;;
    large)
        test_large_result_set
        ;;
    cache)
        test_cache_performance
        ;;
    all)
        run_all_benchmarks
        generate_summary
        ;;
    *)
        echo "Usage: $0 [simple|comparison|in|search|nested|combined|large|cache|all] [base_url] [jwt_token]"
        exit 1
        ;;
esac

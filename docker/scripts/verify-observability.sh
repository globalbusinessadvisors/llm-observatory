#!/bin/bash
# Verify LLM Observatory Observability Stack
# This script checks if all monitoring services are healthy

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Service health check endpoints
declare -A SERVICES=(
  ["Prometheus"]="http://localhost:9090/-/healthy"
  ["Alertmanager"]="http://localhost:9093/-/healthy"
  ["Grafana"]="http://localhost:3000/api/health"
  ["Jaeger"]="http://localhost:14269/"
  ["Loki"]="http://localhost:3100/ready"
  ["PostgreSQL Exporter"]="http://localhost:9187/metrics"
  ["Redis Exporter"]="http://localhost:9121/metrics"
  ["Node Exporter"]="http://localhost:9100/metrics"
)

echo "=========================================="
echo "LLM Observatory - Observability Stack"
echo "Health Check"
echo "=========================================="
echo ""

# Function to check service health
check_service() {
  local name=$1
  local url=$2

  printf "Checking %-25s ... " "$name"

  if curl -sf "$url" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
    return 0
  else
    echo -e "${RED}✗ FAILED${NC}"
    return 1
  fi
}

# Check all services
FAILED=0
for service in "${!SERVICES[@]}"; do
  if ! check_service "$service" "${SERVICES[$service]}"; then
    ((FAILED++))
  fi
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="

TOTAL=${#SERVICES[@]}
PASSED=$((TOTAL - FAILED))

echo "Total services: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

echo ""
echo "=========================================="
echo "Service URLs"
echo "=========================================="
echo ""
echo "Grafana:      http://localhost:3000 (admin/admin)"
echo "Prometheus:   http://localhost:9090"
echo "Alertmanager: http://localhost:9093"
echo "Jaeger UI:    http://localhost:16686"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All services are healthy!${NC}"
  exit 0
else
  echo -e "${RED}Some services are not healthy. Check docker-compose logs.${NC}"
  echo ""
  echo "To view logs:"
  echo "  docker-compose logs prometheus"
  echo "  docker-compose logs jaeger"
  echo "  docker-compose logs loki"
  echo "  docker-compose logs grafana"
  exit 1
fi

#!/bin/bash

# Run integration tests for customer support platform
# Usage: ./scripts/run-integration-tests.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
TEST_TYPE="all"
VERBOSE=false
COVERAGE=false
PARALLEL=true
DOCKER=false
STOP_CONTAINERS=true

# Configuration
TEST_DIR="tests"
PYTHON_VERSION="3.11"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --type)
      TEST_TYPE="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --coverage)
      COVERAGE=true
      shift
      ;;
    --no-parallel)
      PARALLEL=false
      shift
      ;;
    --docker)
      DOCKER=true
      shift
      ;;
    --keep-containers)
      STOP_CONTAINERS=false
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --type TYPE              Test type to run (all, chat, kb, analytics, observatory, e2e, load)"
      echo "  --verbose                Enable verbose output"
      echo "  --coverage               Enable coverage report"
      echo "  --no-parallel            Run tests sequentially"
      echo "  --docker                 Use Docker for testing"
      echo "  --keep-containers        Keep containers running after tests"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Print header
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Customer Support Platform - Integration Tests${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if [ "$DOCKER" = true ]; then
  # Check Docker
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed${NC}"
    exit 1
  fi

  # Check Docker Compose
  if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed${NC}"
    exit 1
  fi

  echo -e "${GREEN}Docker and Docker Compose found${NC}"

  # Start test environment
  echo ""
  echo -e "${YELLOW}Starting test environment...${NC}"
  docker-compose -f docker/compose/docker-compose.test.yml up -d

  # Wait for services
  echo -e "${YELLOW}Waiting for services to be ready...${NC}"
  sleep 10

  # Check service health
  max_retries=30
  retry=0
  while [ $retry -lt $max_retries ]; do
    if curl -f http://localhost:8001/health > /dev/null 2>&1 && \
       curl -f http://localhost:8002/health > /dev/null 2>&1 && \
       curl -f http://localhost:8003/health > /dev/null 2>&1; then
      echo -e "${GREEN}All services are ready${NC}"
      break
    fi
    echo "Waiting for services... ($((retry+1))/$max_retries)"
    sleep 1
    retry=$((retry+1))
  done

  if [ $retry -eq $max_retries ]; then
    echo -e "${RED}Services did not start in time${NC}"
    exit 1
  fi
else
  # Check Python
  if ! command -v python${PYTHON_VERSION} &> /dev/null && ! command -v python &> /dev/null; then
    echo -e "${RED}Python is not installed${NC}"
    exit 1
  fi

  echo -e "${GREEN}Python found${NC}"

  # Check pip
  if ! command -v pip &> /dev/null; then
    echo -e "${RED}pip is not installed${NC}"
    exit 1
  fi

  echo -e "${GREEN}pip found${NC}"

  # Install test dependencies
  echo ""
  echo -e "${YELLOW}Installing test dependencies...${NC}"
  pip install -q pytest pytest-asyncio httpx

  if [ "$COVERAGE" = true ]; then
    pip install -q pytest-cov
  fi
fi

echo ""

# Run tests based on type
case $TEST_TYPE in
  all)
    echo -e "${YELLOW}Running all integration tests...${NC}"

    if [ "$PARALLEL" = true ]; then
      PYTEST_ARGS="-n auto"
    else
      PYTEST_ARGS=""
    fi

    if [ "$VERBOSE" = true ]; then
      PYTEST_ARGS="$PYTEST_ARGS -v -s"
    else
      PYTEST_ARGS="$PYTEST_ARGS -q"
    fi

    if [ "$COVERAGE" = true ]; then
      PYTEST_ARGS="$PYTEST_ARGS --cov=$TEST_DIR --cov-report=html --cov-report=term"
    fi

    if [ "$DOCKER" = true ]; then
      docker-compose -f docker/compose/docker-compose.test.yml exec -T test-runner \
        python -m pytest $TEST_DIR/integration $PYTEST_ARGS
    else
      python -m pytest $TEST_DIR/integration $PYTEST_ARGS
    fi
    ;;

  chat)
    echo -e "${YELLOW}Running chat API integration tests...${NC}"
    if [ "$DOCKER" = true ]; then
      docker-compose -f docker/compose/docker-compose.test.yml exec -T test-runner \
        python -m pytest $TEST_DIR/integration/test_chat_e2e.py -v
    else
      python -m pytest $TEST_DIR/integration/test_chat_e2e.py -v
    fi
    ;;

  kb)
    echo -e "${YELLOW}Running KB API integration tests...${NC}"
    if [ "$DOCKER" = true ]; then
      docker-compose -f docker/compose/docker-compose.test.yml exec -T test-runner \
        python -m pytest $TEST_DIR/integration/test_kb_integration.py -v
    else
      python -m pytest $TEST_DIR/integration/test_kb_integration.py -v
    fi
    ;;

  analytics)
    echo -e "${YELLOW}Running analytics API integration tests...${NC}"
    if [ "$DOCKER" = true ]; then
      docker-compose -f docker/compose/docker-compose.test.yml exec -T test-runner \
        python -m pytest $TEST_DIR/integration/test_analytics.py -v
    else
      python -m pytest $TEST_DIR/integration/test_analytics.py -v
    fi
    ;;

  observatory)
    echo -e "${YELLOW}Running Observatory integration tests...${NC}"
    if [ "$DOCKER" = true ]; then
      docker-compose -f docker/compose/docker-compose.test.yml exec -T test-runner \
        python -m pytest $TEST_DIR/integration/test_observatory_integration.py -v
    else
      python -m pytest $TEST_DIR/integration/test_observatory_integration.py -v
    fi
    ;;

  e2e)
    echo -e "${YELLOW}Running E2E tests...${NC}"

    if ! command -v npx &> /dev/null; then
      echo -e "${RED}Node.js/npm is not installed${NC}"
      exit 1
    fi

    if [ "$DOCKER" = true ]; then
      docker-compose -f docker/compose/docker-compose.test.yml exec -T playwright-runner \
        npx playwright test
    else
      npx playwright install
      npx playwright test
    fi
    ;;

  load)
    echo -e "${YELLOW}Running load tests...${NC}"

    if ! command -v k6 &> /dev/null; then
      echo -e "${RED}k6 is not installed${NC}"
      exit 1
    fi

    echo "Running chat API load test..."
    k6 run $TEST_DIR/load/chat-api.js

    echo ""
    echo "Running KB API load test..."
    k6 run $TEST_DIR/load/kb-api.js

    echo ""
    echo "Running analytics API load test..."
    k6 run $TEST_DIR/load/analytics-api.js
    ;;

  *)
    echo -e "${RED}Unknown test type: $TEST_TYPE${NC}"
    exit 1
    ;;
esac

TEST_RESULT=$?

echo ""
echo -e "${YELLOW}========================================${NC}"

if [ $TEST_RESULT -eq 0 ]; then
  echo -e "${GREEN}Tests completed successfully!${NC}"
else
  echo -e "${RED}Tests failed with exit code: $TEST_RESULT${NC}"
fi

# Cleanup
if [ "$DOCKER" = true ] && [ "$STOP_CONTAINERS" = true ]; then
  echo ""
  echo -e "${YELLOW}Stopping test environment...${NC}"
  docker-compose -f docker/compose/docker-compose.test.yml down -v
  echo -e "${GREEN}Test environment stopped${NC}"
fi

echo -e "${YELLOW}========================================${NC}"
echo ""

exit $TEST_RESULT

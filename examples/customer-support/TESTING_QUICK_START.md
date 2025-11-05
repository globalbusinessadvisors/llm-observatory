# Testing Quick Start Guide

## Overview

The customer support platform includes comprehensive tests across three categories:
- **Integration Tests** (Python/pytest): 82+ test cases validating all APIs
- **End-to-End Tests** (Playwright): 46+ test scenarios validating UI
- **Load Tests** (k6): Performance testing with realistic load profiles

## Prerequisites

```bash
# Install Python dependencies
pip install -r tests/requirements.txt

# Install Playwright browsers
npx playwright install

# Install k6 (if not already installed)
# macOS: brew install k6
# Linux: apt install k6
# Windows: choco install k6
```

## Running Tests - Quick Commands

### Option 1: Using Test Runner Script (Recommended)

```bash
# Make script executable (first time only)
chmod +x scripts/run-integration-tests.sh

# Run all integration tests
./scripts/run-integration-tests.sh

# Run specific test category
./scripts/run-integration-tests.sh --type chat
./scripts/run-integration-tests.sh --type kb
./scripts/run-integration-tests.sh --type analytics
./scripts/run-integration-tests.sh --type observatory

# Run E2E tests
./scripts/run-integration-tests.sh --type e2e

# Run load tests
./scripts/run-integration-tests.sh --type load

# Run with additional options
./scripts/run-integration-tests.sh --coverage --verbose
./scripts/run-integration-tests.sh --docker  # Use Docker containers
```

### Option 2: Direct Commands

**Integration Tests:**
```bash
# All integration tests
python -m pytest tests/integration -v

# Specific test file
python -m pytest tests/integration/test_chat_e2e.py -v
python -m pytest tests/integration/test_kb_integration.py -v
python -m pytest tests/integration/test_analytics.py -v
python -m pytest tests/integration/test_observatory_integration.py -v

# Specific test class
python -m pytest tests/integration/test_chat_e2e.py::TestChatAPIBasic -v

# With coverage report
python -m pytest tests/integration --cov=tests --cov-report=html
```

**E2E Tests:**
```bash
# All E2E tests
npx playwright test

# Specific test file
npx playwright test tests/e2e/chat.spec.ts

# Headed mode (see browser)
npx playwright test --headed

# Debug mode
npx playwright test --debug

# Specific test by name
npx playwright test -g "should send a message"
```

**Load Tests:**
```bash
# Chat API load test
k6 run tests/load/chat-api.js

# KB API load test
k6 run tests/load/kb-api.js

# Analytics API load test
k6 run tests/load/analytics-api.js

# All load tests
for test in tests/load/*.js; do k6 run "$test"; done
```

## Test Structure

```
tests/
├── integration/           # API integration tests
│   ├── test_chat_e2e.py          # Chat API: 20 tests
│   ├── test_kb_integration.py    # KB API: 20 tests
│   ├── test_analytics.py         # Analytics: 25 tests
│   └── test_observatory_integration.py  # Observatory: 17 tests
├── e2e/                   # UI/E2E tests (Playwright)
│   ├── chat.spec.ts              # Chat UI: 18 tests
│   ├── analytics.spec.ts         # Analytics UI: 17 tests
│   └── knowledge-base.spec.ts    # KB UI: 16 tests
├── load/                  # Load tests (k6)
│   ├── chat-api.js               # Chat API load test
│   ├── kb-api.js                 # KB API load test
│   └── analytics-api.js          # Analytics API load test
├── utils/
│   └── test_helpers.py   # Reusable test utilities
├── conftest.py           # Pytest configuration and fixtures
├── pytest.ini            # Pytest settings
└── README.md            # Detailed documentation
```

## Test Coverage by Component

| API | Tests | E2E | Load | Status |
|-----|-------|-----|------|--------|
| Chat | 20 | 18 | ✓ | Complete |
| Knowledge Base | 20 | 16 | ✓ | Complete |
| Analytics | 25 | 17 | ✓ | Complete |
| Observatory | 17 | - | - | Complete |

## Common Workflows

### Develop and Test Locally

```bash
# 1. Start services
docker-compose up -d

# 2. Run integration tests
pytest tests/integration -v

# 3. Check specific functionality
pytest tests/integration/test_chat_e2e.py::TestChatAPIBasic::test_send_chat_message -v

# 4. Run E2E tests
npx playwright test

# 5. Monitor performance
k6 run tests/load/chat-api.js
```

### Pre-Commit Testing

```bash
# Quick validation before committing
./scripts/run-integration-tests.sh --type all --no-parallel

# With coverage
./scripts/run-integration-tests.sh --coverage
```

### CI/CD Pipeline

```bash
# Run all tests for pull request validation
./scripts/run-integration-tests.sh --docker

# Generate reports
pytest tests/integration --cov --cov-report=xml
npx playwright test --reporter=json
k6 run tests/load/chat-api.js --out json=results.json
```

### Performance Regression Testing

```bash
# Baseline performance
k6 run tests/load/chat-api.js --summary-export=baseline.json

# After changes
k6 run tests/load/chat-api.js --summary-export=current.json

# Compare (use external tools to diff JSON)
```

## Expected Results

### Integration Tests
- **Expected**: All tests should pass
- **Duration**: 2-5 minutes
- **Output**: Green checkmarks, passing counts

### E2E Tests
- **Expected**: All tests should pass
- **Duration**: 5-15 minutes (depending on browser)
- **Output**: HTML report in playwright-report/

### Load Tests
- **Expected**: All thresholds met
- **Duration**: 5-6 minutes per test
- **Output**: Summary with metrics and pass/fail

## Debugging Failed Tests

### Integration Test Failures

```bash
# Run with verbose output
pytest tests/integration/test_chat_e2e.py -vv -s

# Run with pdb debugger
pytest tests/integration/test_chat_e2e.py --pdb

# Run single test
pytest tests/integration/test_chat_e2e.py::TestChatAPIBasic::test_health_check -v
```

### E2E Test Failures

```bash
# Run with browser visible
npx playwright test --headed

# Run in debug mode (opens inspector)
npx playwright test --debug

# View recorded video/trace
npx playwright show-report
```

### Load Test Failures

```bash
# Run with detailed output
k6 run tests/load/chat-api.js -v

# Export results for analysis
k6 run tests/load/chat-api.js --out json=results.json

# Reduce load to debug
# Edit load test file and reduce VU count
```

## Test Markers

Run tests with markers for selective execution:

```bash
# Chat API tests only
pytest -m chat

# KB API tests only
pytest -m kb

# Analytics tests
pytest -m analytics

# Observatory integration tests
pytest -m observatory

# All integration tests
pytest -m integration

# Exclude slow tests
pytest -m "not slow"
```

## Docker-Based Testing

For isolated, reproducible testing:

```bash
# Start test environment
docker-compose -f docker-compose.test.yml up -d

# Run tests in containers
docker-compose -f docker-compose.test.yml exec test-runner \
  python -m pytest tests/integration -v

# Run E2E tests
docker-compose -f docker-compose.test.yml exec playwright-runner \
  npx playwright test

# Run load tests
docker-compose -f docker-compose.test.yml exec k6-runner \
  k6 run tests/load/chat-api.js

# Stop test environment
docker-compose -f docker-compose.test.yml down -v
```

## Troubleshooting

### Connection Errors

```bash
# Verify services are running
curl http://localhost:8000/health  # Chat API
curl http://localhost:8001/health  # KB API
curl http://localhost:8002/health  # Analytics API

# If not running:
docker-compose up -d
```

### Playwright Tests Timeout

```bash
# Increase timeout in playwright.config.ts
timeout: 60 * 1000  # 60 seconds
```

### Load Test Thresholds Fail

```bash
# Reduce load (edit test file)
stages: [
  { duration: '30s', target: 5 },   # Reduced VUs
  { duration: '1m', target: 10 },
]
```

### Module Import Errors

```bash
# Reinstall dependencies
pip install -r tests/requirements.txt --upgrade
npx playwright install
```

## Performance Benchmarks

Expected performance (baseline):

| Component | Metric | Target |
|-----------|--------|--------|
| Chat API | p95 response | < 500ms |
| Chat API | error rate | < 1% |
| KB API | p95 response | < 800ms |
| KB API | error rate | < 1% |
| Analytics API | p95 response | < 1000ms |
| Analytics API | error rate | < 1% |

## Next Steps

1. **Read full documentation**: `tests/README.md`
2. **Review test examples**: Look at specific test files
3. **Run tests**: Start with `pytest tests/integration -v`
4. **Set up CI/CD**: Integrate with your pipeline
5. **Monitor performance**: Track test results over time

## Quick Help

```bash
# Show this help
./scripts/run-integration-tests.sh --help

# List all pytest markers
pytest --markers

# List all tests without running
pytest tests/ --collect-only

# Run tests and stop on first failure
pytest tests/integration -x

# Run last failed tests
pytest tests/integration --lf
```

## Tips & Best Practices

1. **Run tests early and often**: Before committing changes
2. **Use Docker**: For reproducible, isolated test runs
3. **Review test reports**: Check HTML reports and logs
4. **Monitor performance**: Track load test results
5. **Maintain test data**: Keep sample data fresh and relevant
6. **Document failures**: Record patterns and solutions

## Support & Resources

- **Full Documentation**: `tests/README.md`
- **Test Summary**: `TESTS_SUMMARY.md`
- **Pytest Docs**: https://docs.pytest.org/
- **Playwright Docs**: https://playwright.dev/
- **k6 Docs**: https://k6.io/docs/

---

**Last Updated**: November 2024
**Version**: 1.0.0

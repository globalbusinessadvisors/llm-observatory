# Customer Support Platform - Comprehensive Test Suite

This directory contains comprehensive integration, end-to-end, and load tests for the entire customer support platform.

## Test Structure

```
tests/
├── integration/           # API integration tests
│   ├── test_chat_e2e.py  # Chat API tests
│   ├── test_kb_integration.py  # Knowledge Base API tests
│   ├── test_analytics.py  # Analytics API tests
│   └── test_observatory_integration.py  # Observatory integration tests
├── e2e/                   # End-to-end UI tests (Playwright)
│   ├── chat.spec.ts      # Chat interface tests
│   ├── analytics.spec.ts  # Analytics dashboard tests
│   └── knowledge-base.spec.ts  # Knowledge base UI tests
├── load/                  # Load and performance tests (k6)
│   ├── chat-api.js       # Chat API load test
│   ├── kb-api.js         # KB API load test
│   └── analytics-api.js  # Analytics API load test
├── utils/                 # Test utilities
│   ├── test_helpers.py   # Helper functions
│   └── __init__.py
├── conftest.py           # Pytest configuration and fixtures
├── pytest.ini            # Pytest settings
├── playwright.config.ts  # Playwright configuration
└── requirements.txt      # Python test dependencies
```

## Quick Start

### Prerequisites

- Docker & Docker Compose (v2.0+) - for containerized testing
- Python 3.11+ - for integration tests
- Node.js 18+ - for E2E tests
- k6 - for load tests
- At least one LLM provider API key

### Installation

#### 1. Install Python dependencies

```bash
pip install -r tests/requirements.txt
```

#### 2. Install Playwright browsers

```bash
npx playwright install
```

#### 3. Install k6

**macOS:**
```bash
brew install k6
```

**Linux:**
```bash
apt install k6
```

**Windows:**
```bash
choco install k6
```

Or download from: https://k6.io/docs/getting-started/installation/

## Running Tests

### Integration Tests (Python)

Run all integration tests:
```bash
python -m pytest tests/integration -v
```

Run specific test category:
```bash
# Chat API tests
python -m pytest tests/integration/test_chat_e2e.py -v

# Knowledge Base tests
python -m pytest tests/integration/test_kb_integration.py -v

# Analytics tests
python -m pytest tests/integration/test_analytics.py -v

# Observatory integration tests
python -m pytest tests/integration/test_observatory_integration.py -v
```

Run with coverage:
```bash
python -m pytest tests/integration --cov=tests --cov-report=html --cov-report=term
```

Run specific test:
```bash
python -m pytest tests/integration/test_chat_e2e.py::TestChatAPIBasic::test_health_check -v
```

### E2E Tests (Playwright)

Install Playwright:
```bash
npx playwright install
```

Run all E2E tests:
```bash
npx playwright test
```

Run specific test file:
```bash
npx playwright test tests/e2e/chat.spec.ts
```

Run in headed mode (see browser):
```bash
npx playwright test --headed
```

Run in debug mode:
```bash
npx playwright test --debug
```

Run specific test:
```bash
npx playwright test -g "should send a message and receive a response"
```

Generate test report:
```bash
npx playwright test
npx playwright show-report
```

### Load Tests (k6)

Run chat API load test:
```bash
k6 run tests/load/chat-api.js
```

Run with custom options:
```bash
k6 run tests/load/chat-api.js \
  --vus 20 \
  --duration 2m \
  --out json=results.json
```

Run all load tests:
```bash
k6 run tests/load/chat-api.js
k6 run tests/load/kb-api.js
k6 run tests/load/analytics-api.js
```

### Using the Test Runner Script

The provided shell script simplifies test execution:

```bash
chmod +x scripts/run-integration-tests.sh

# Run all tests
./scripts/run-integration-tests.sh

# Run specific test type
./scripts/run-integration-tests.sh --type chat
./scripts/run-integration-tests.sh --type kb
./scripts/run-integration-tests.sh --type analytics
./scripts/run-integration-tests.sh --type observatory
./scripts/run-integration-tests.sh --type e2e
./scripts/run-integration-tests.sh --type load

# Enable coverage report
./scripts/run-integration-tests.sh --coverage

# Run with Docker
./scripts/run-integration-tests.sh --docker

# Verbose output
./scripts/run-integration-tests.sh --verbose
```

## Docker-based Testing

For isolated testing with all dependencies:

```bash
# Start test environment
docker-compose -f docker/compose/docker-compose.test.yml up -d

# Run integration tests
docker-compose -f docker/compose/docker-compose.test.yml exec test-runner \
  python -m pytest tests/integration -v

# Run E2E tests
docker-compose -f docker/compose/docker-compose.test.yml exec playwright-runner \
  npx playwright test

# Run load tests
docker-compose -f docker/compose/docker-compose.test.yml exec k6-runner \
  k6 run tests/load/chat-api.js

# Stop test environment
docker-compose -f docker/compose/docker-compose.test.yml down -v
```

## Test Coverage

### Integration Tests

#### Chat API Tests (test_chat_e2e.py)
- **Basic Operations**: Health check, conversation creation, message sending
- **Advanced Features**: Streaming responses, multi-provider fallback, rate limiting
- **Error Handling**: Invalid inputs, message size limits, missing fields
- **Coverage**: 15+ test cases

#### Knowledge Base Tests (test_kb_integration.py)
- **Document Operations**: Upload, list, retrieve, delete documents
- **Search Functionality**: Semantic search, hybrid search, filtering
- **Document Management**: Versioning, metadata editing, batch operations
- **Error Handling**: Invalid queries, unsupported files, large uploads
- **Coverage**: 20+ test cases

#### Analytics Tests (test_analytics.py)
- **Metrics Collection**: Summary, conversation metrics, cost analysis
- **Performance Metrics**: Latency, throughput, error rates
- **Time-series Data**: Aggregations by time period, user, endpoint
- **Data Filtering**: Date ranges, custom filters, comparisons
- **Coverage**: 25+ test cases

#### Observatory Integration Tests (test_observatory_integration.py)
- **Request Tracking**: Metadata preservation, cost tracking, token usage
- **Multi-provider**: Provider fallback, cost comparison, performance comparison
- **Reporting**: Data exports, historical access, consistency validation
- **Coverage**: 15+ test cases

### E2E Tests

#### Chat Interface Tests (chat.spec.ts)
- **UI Interaction**: Message sending, conversation creation, history navigation
- **Real-time Features**: Streaming responses, loading states, error handling
- **Advanced Features**: Dark mode, provider selection, keyboard shortcuts
- **Coverage**: 15+ test cases

#### Analytics Dashboard Tests (analytics.spec.ts)
- **Dashboard Display**: Metrics rendering, charts, filtering
- **Data Interaction**: Drill-down, custom filters, comparisons
- **Export**: Data export functionality
- **Coverage**: 12+ test cases

#### Knowledge Base UI Tests (knowledge-base.spec.ts)
- **Document Management**: Upload, search, delete, view details
- **Search Features**: Relevance scoring, filtering, sorting
- **Document Operations**: Metadata editing, versioning, batch operations
- **Coverage**: 15+ test cases

### Load Tests

#### Chat API Load Test (chat-api.js)
- **Endpoints Tested**:
  - Health check
  - Conversation creation
  - Message sending
  - Conversation listing

- **Load Profile**:
  - Ramp up to 50 VUs over 2 minutes
  - Sustained load for 2 minutes
  - Ramp down

- **Thresholds**:
  - 95th percentile response time < 500ms
  - Error rate < 10%

#### KB API Load Test (kb-api.js)
- **Endpoints Tested**:
  - Health check
  - Semantic search
  - Hybrid search
  - Document listing

- **Load Profile**:
  - Ramp up to 30 VUs
  - Sustained load
  - Ramp down

- **Thresholds**:
  - Search response time < 1000ms
  - Error rate < 10%

#### Analytics API Load Test (analytics-api.js)
- **Endpoints Tested**:
  - Metrics summary
  - Conversation metrics
  - Cost metrics
  - Performance metrics

- **Load Profile**:
  - Ramp up to 20 VUs
  - Sustained load
  - Ramp down

- **Thresholds**:
  - Metrics response time < 1500ms
  - Error rate < 10%

## Test Fixtures and Helpers

The test suite includes helpful utilities in `utils/test_helpers.py`:

```python
# Create test conversation
conv = await create_test_conversation(
    client,
    title="Test",
    metadata={"user_id": "test"}
)

# Send test message
response = await send_test_message(
    client,
    conversation_id=conv["id"],
    message="Hello"
)

# Search knowledge base
results = await search_knowledge_base(
    client,
    query="test",
    top_k=5
)

# Get conversation history
history = await get_conversation_history(
    client,
    conversation_id=conv["id"]
)

# Create test document
doc = await create_test_document(
    client,
    filename="test.txt",
    content="Test content"
)

# Context manager for cleanup
async with TestContextManager(client) as ctx:
    conv = await ctx.create_conversation()
    doc = await ctx.create_document()
    # Resources are automatically cleaned up
```

## Test Markers

Use pytest markers to run specific test categories:

```bash
# Run only chat API tests
pytest -m chat

# Run only KB tests
pytest -m kb

# Run only analytics tests
pytest -m analytics

# Run only observatory tests
pytest -m observatory

# Run integration tests
pytest -m integration

# Run slow tests
pytest -m slow

# Skip slow tests
pytest -m "not slow"
```

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/test.yml`:

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
      redis:
        image: redis:7
      qdrant:
        image: qdrant/qdrant
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: pip install -r tests/requirements.txt
      - name: Run tests
        run: ./scripts/run-integration-tests.sh --type all

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install Playwright
        run: npx playwright install --with-deps
      - name: Run E2E tests
        run: npx playwright test

  load-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install k6
        run: apt-get update && apt-get install -y k6
      - name: Run load tests
        run: ./scripts/run-integration-tests.sh --type load
```

## Debugging Tests

### Integration Tests

Enable verbose logging:
```bash
python -m pytest tests/integration -vv -s
```

Run with pdb on failure:
```bash
python -m pytest tests/integration --pdb
```

### E2E Tests

Debug specific test:
```bash
npx playwright test --debug -g "test name"
```

View traces:
```bash
npx playwright show-trace trace.zip
```

### Load Tests

Output detailed metrics:
```bash
k6 run tests/load/chat-api.js --summary-export=summary.json
```

## Performance Baselines

Expected performance metrics (from baseline measurements):

| Metric | Target | Current |
|--------|--------|---------|
| Chat API p95 response | < 500ms | - |
| KB API search p95 | < 1000ms | - |
| Analytics API p95 | < 1500ms | - |
| Error rate | < 1% | - |
| Chat API throughput | > 100 req/s | - |
| KB API throughput | > 50 req/s | - |

## Troubleshooting

### Tests fail with connection errors

Ensure all services are running:
```bash
# Check service health
curl http://localhost:8000/health  # Chat API
curl http://localhost:8001/health  # KB API
curl http://localhost:8002/health  # Analytics API
```

### Playwright tests timeout

Increase timeout in `playwright.config.ts`:
```typescript
timeout: 60 * 1000,  // 60 seconds
```

### Load test thresholds failing

Reduce load in load test files:
```javascript
stages: [
  { duration: '30s', target: 5 },   // Reduced from 10
  { duration: '1m', target: 10 },   // Reduced from 50
]
```

### Docker containers fail to start

Check logs:
```bash
docker-compose -f docker/compose/docker-compose.test.yml logs -f
```

Clean up and restart:
```bash
docker-compose -f docker/compose/docker-compose.test.yml down -v
docker-compose -f docker/compose/docker-compose.test.yml up -d
```

## Contributing

When adding new tests:

1. Follow existing test structure and naming conventions
2. Use appropriate markers (@pytest.mark.chat, etc.)
3. Add docstrings explaining test purpose
4. Use fixtures for common setup
5. Clean up resources (use TestContextManager)
6. Update this README with new test categories

## Resources

- [Pytest Documentation](https://docs.pytest.org/)
- [Playwright Documentation](https://playwright.dev/)
- [k6 Documentation](https://k6.io/docs/)
- [httpx Documentation](https://www.python-httpx.org/)

## License

MIT License - see [LICENSE](../../LICENSE) file for details

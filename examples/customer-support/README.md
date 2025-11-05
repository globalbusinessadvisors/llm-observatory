# AI Customer Support Platform

A production-ready, enterprise-grade AI-powered customer support system built with modern microservices architecture. This platform demonstrates real-world LLM application patterns with comprehensive observability through LLM Observatory.

## Overview

This example application showcases:
- **Multi-service architecture** with Python (FastAPI), Node.js (Express), and Rust (Axum)
- **Real-time chat** with context-aware AI responses
- **Knowledge base** with semantic search and RAG capabilities
- **Analytics & monitoring** with real-time metrics
- **Multi-provider LLM support** (OpenAI, Anthropic, Azure OpenAI)
- **Production observability** with LLM Observatory integration

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend (React)                         │
│                    WebSocket + REST API                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┬──────────────┐
                │                           │              │
┌───────────────▼────────────┐  ┌──────────▼──────────┐  │
│    Chat API (FastAPI)      │  │  KB API (Express)   │  │
│  - Conversation management │  │  - Document ingest  │  │
│  - Multi-provider LLM      │  │  - Semantic search  │  │
│  - Streaming responses     │  │  - RAG pipeline     │  │
└────────────────────────────┘  └─────────────────────┘  │
                                                          │
                              ┌───────────────────────────▼────────┐
                              │   Analytics API (Axum/Rust)        │
                              │   - Real-time metrics              │
                              │   - Performance analytics          │
                              │   - Cost tracking                  │
                              └────────────────────────────────────┘
                                            │
                      ┌─────────────────────┴─────────────────────┐
                      │                                           │
         ┌────────────▼──────────┐              ┌────────────────▼────────┐
         │   LLM Observatory     │              │   Infrastructure        │
         │   - Request tracking  │              │   - PostgreSQL          │
         │   - Performance       │              │   - Qdrant (vectors)    │
         │   - Cost analysis     │              │   - Redis (cache)       │
         └───────────────────────┘              └─────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose (v2.0+)
- At least one LLM provider API key (OpenAI, Anthropic, or Azure OpenAI)
- 8GB+ RAM available
- 10GB+ disk space

### 1. Clone and Setup

```bash
# Clone the repository
cd examples/customer-support

# Copy environment template
cp .env.example .env

# Edit .env and add your API keys
nano .env  # or use your preferred editor
```

**Required configuration:**
```bash
# At minimum, set one of these:
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
# or
AZURE_OPENAI_API_KEY=...
AZURE_OPENAI_ENDPOINT=...
```

### 2. Start the Platform

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service health
docker-compose ps
```

### 3. Initialize Database

```bash
# Run migrations
docker-compose exec chat-api python -m alembic upgrade head
docker-compose exec kb-api npm run migrate

# Seed sample data (optional)
docker-compose exec chat-api python scripts/seed.py
docker-compose exec kb-api npm run seed
```

### 4. Access the Application

- **Frontend**: http://localhost:3000
- **Chat API**: http://localhost:8000/docs (Swagger UI)
- **KB API**: http://localhost:8001/docs (OpenAPI)
- **Analytics API**: http://localhost:8002/docs
- **LLM Observatory**: http://localhost:3001 (if enabled)

## Development Setup

### Local Development (without Docker)

#### Chat API (Python/FastAPI)

```bash
cd services/chat-api

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -e ".[dev]"

# Run migrations
alembic upgrade head

# Start development server
uvicorn app.main:app --reload --port 8000
```

#### KB API (Node.js/Express)

```bash
cd services/kb-api

# Install dependencies
npm install

# Run migrations
npm run migrate

# Start development server
npm run dev
```

#### Analytics API (Rust/Axum)

```bash
cd services/analytics-api

# Build and run
cargo run

# Or with hot reload
cargo watch -x run
```

#### Frontend (React/Vite)

```bash
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev
```

## Service Details

### Chat API (Python/FastAPI)

**Purpose**: Core conversational AI service with multi-provider LLM support.

**Key Features**:
- WebSocket-based real-time chat
- Conversation history management
- Multi-provider abstraction (OpenAI, Anthropic, Azure)
- Streaming responses
- Context injection from knowledge base
- Rate limiting and request queuing

**Endpoints**:
- `POST /v1/chat/completions` - Create chat completion
- `GET /v1/conversations` - List conversations
- `GET /v1/conversations/{id}` - Get conversation details
- `WS /ws` - WebSocket chat stream

**Tech Stack**: Python 3.11+, FastAPI, SQLAlchemy, Redis, LangChain

### KB API (Node.js/Express)

**Purpose**: Knowledge base management with semantic search and RAG.

**Key Features**:
- Document ingestion (PDF, TXT, MD, DOCX)
- Automatic chunking and embedding
- Vector similarity search
- RAG pipeline integration
- Document versioning
- Metadata filtering

**Endpoints**:
- `POST /v1/documents` - Upload document
- `GET /v1/documents` - List documents
- `POST /v1/search` - Semantic search
- `DELETE /v1/documents/{id}` - Delete document

**Tech Stack**: Node.js 20+, Express, TypeScript, Qdrant, OpenAI Embeddings

### Analytics API (Rust/Axum)

**Purpose**: High-performance analytics and metrics aggregation.

**Key Features**:
- Real-time metrics processing
- Cost tracking and analysis
- Performance monitoring
- Custom metric aggregations
- Time-series data queries
- Efficient caching layer

**Endpoints**:
- `GET /v1/metrics/summary` - Get metrics summary
- `GET /v1/metrics/conversations` - Conversation metrics
- `GET /v1/metrics/costs` - Cost analysis
- `GET /v1/metrics/performance` - Performance stats

**Tech Stack**: Rust 1.75+, Axum, Tokio, SQLx, Redis

### Frontend (React)

**Purpose**: Modern, responsive web interface.

**Key Features**:
- Real-time chat interface
- Conversation history
- Knowledge base management
- Analytics dashboard
- Dark/light mode
- Responsive design

**Tech Stack**: React 18, TypeScript, Vite, Tailwind CSS, Zustand

## SDKs

Pre-built SDKs for integrating the platform into your applications:

### Python SDK

```python
from customer_support_sdk import CustomerSupportClient

client = CustomerSupportClient(
    chat_api_url="http://localhost:8000",
    kb_api_url="http://localhost:8001",
    analytics_api_url="http://localhost:8002"
)

# Send a chat message
response = client.chat.send_message(
    message="How do I reset my password?",
    conversation_id="conv_123"
)

# Search knowledge base
results = client.kb.search(
    query="password reset",
    top_k=5
)
```

### Node.js SDK

```javascript
import { CustomerSupportClient } from '@customer-support/sdk';

const client = new CustomerSupportClient({
  chatApiUrl: 'http://localhost:8000',
  kbApiUrl: 'http://localhost:8001',
  analyticsApiUrl: 'http://localhost:8002',
});

// Send a chat message
const response = await client.chat.sendMessage({
  message: 'How do I reset my password?',
  conversationId: 'conv_123',
});

// Search knowledge base
const results = await client.kb.search({
  query: 'password reset',
  topK: 5,
});
```

### Rust SDK

```rust
use customer_support_sdk::CustomerSupportClient;

#[tokio::main]
async fn main() {
    let client = CustomerSupportClient::new(
        "http://localhost:8000",
        "http://localhost:8001",
        "http://localhost:8002",
    );

    // Send a chat message
    let response = client.chat()
        .send_message("How do I reset my password?")
        .conversation_id("conv_123")
        .await?;

    // Search knowledge base
    let results = client.kb()
        .search("password reset")
        .top_k(5)
        .await?;
}
```

## LLM Observatory Integration

This platform integrates with LLM Observatory for comprehensive observability:

### What's Tracked

- **Request/Response**: All LLM interactions with full context
- **Performance**: Latency, throughput, token usage
- **Costs**: Per-request and aggregated costs
- **Quality**: Response quality metrics
- **Errors**: Failed requests and error patterns

### Viewing Metrics

1. Enable LLM Observatory in `.env`:
   ```bash
   LLM_OBSERVATORY_ENABLED=true
   LLM_OBSERVATORY_URL=http://llm-observatory-api:3000
   ```

2. Access the UI at http://localhost:3001

3. View dashboards for:
   - Real-time request monitoring
   - Cost analysis and forecasting
   - Performance trends
   - Error rates and patterns

## Configuration

### Environment Variables

See `.env.example` for all available configuration options.

**Critical Settings**:

```bash
# LLM Provider (choose one or more)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...

# Database
POSTGRES_PASSWORD=secure_password_here
REDIS_PASSWORD=secure_password_here

# Services
CHAT_API_WORKERS=4
MAX_CONVERSATION_HISTORY=20
CHUNK_SIZE=1000
TOP_K_RESULTS=5

# Security
JWT_SECRET=your-secret-key
RATE_LIMIT_MAX_REQUESTS=100
```

### Scaling Configuration

**Horizontal Scaling**:

```yaml
# docker-compose.override.yml
services:
  chat-api:
    deploy:
      replicas: 3

  kb-api:
    deploy:
      replicas: 2
```

**Resource Limits**:

```yaml
services:
  chat-api:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

## Testing

### Run All Tests

```bash
# Chat API
cd services/chat-api
pytest --cov=app tests/

# KB API
cd services/kb-api
npm test

# Analytics API
cd services/analytics-api
cargo test

# Frontend
cd frontend
npm test

# Integration tests
./scripts/run-integration-tests.sh
```

### Load Testing

```bash
# Install k6
brew install k6  # macOS
# or
choco install k6  # Windows
# or
apt install k6  # Linux

# Run load tests
k6 run tests/load/chat-api.js
k6 run tests/load/kb-api.js
```

## Deployment

### Production Checklist

- [ ] Update all secrets in `.env`
- [ ] Set `ENVIRONMENT=production`
- [ ] Configure external PostgreSQL
- [ ] Set up Redis persistence
- [ ] Enable SSL/TLS
- [ ] Configure rate limits
- [ ] Set up monitoring alerts
- [ ] Enable backup strategy
- [ ] Configure log aggregation
- [ ] Test disaster recovery

### Kubernetes Deployment

```bash
# Apply configurations
kubectl apply -f k8s/

# Verify deployments
kubectl get pods -n customer-support
kubectl get services -n customer-support

# Check logs
kubectl logs -f deployment/chat-api -n customer-support
```

See `k8s/README.md` for detailed Kubernetes deployment instructions.

### Cloud Deployment

**AWS ECS**:
```bash
./scripts/deploy-aws.sh
```

**Google Cloud Run**:
```bash
./scripts/deploy-gcp.sh
```

**Azure Container Apps**:
```bash
./scripts/deploy-azure.sh
```

## Monitoring & Observability

### Metrics

- **Application Metrics**: via LLM Observatory
- **Infrastructure Metrics**: via Prometheus + Grafana
- **Logs**: Centralized via ELK/Loki
- **Traces**: via OpenTelemetry

### Health Checks

```bash
# Check all services
curl http://localhost:8000/health
curl http://localhost:8001/health
curl http://localhost:8002/health

# Detailed health
curl http://localhost:8000/health/detailed
```

### Alerts

Configure alerts in `monitoring/alerts.yml`:

- High error rate (>5%)
- High latency (p95 >2s)
- Cost threshold exceeded
- Service downtime

## Troubleshooting

### Common Issues

**Services won't start**:
```bash
# Check logs
docker-compose logs

# Restart services
docker-compose restart

# Rebuild containers
docker-compose up --build -d
```

**Database connection errors**:
```bash
# Check PostgreSQL
docker-compose exec postgres pg_isready

# Reset database
docker-compose down -v
docker-compose up -d postgres
```

**Vector search not working**:
```bash
# Check Qdrant
curl http://localhost:6333/health

# Recreate collection
docker-compose exec kb-api npm run recreate-collection
```

**High memory usage**:
```bash
# Check resource usage
docker stats

# Reduce workers/replicas in .env
CHAT_API_WORKERS=2
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

### Development Workflow

1. Create feature branch
2. Make changes
3. Run tests
4. Submit PR
5. Code review
6. Merge to main

### Code Standards

- **Python**: Black, isort, mypy, pylint
- **Node.js**: ESLint, Prettier, TypeScript strict
- **Rust**: rustfmt, clippy
- **Commits**: Conventional Commits

## Documentation

- [API Documentation](docs/api/)
- [Architecture Guide](docs/architecture.md)
- [Deployment Guide](docs/deployment.md)
- [Development Guide](docs/development.md)
- [Troubleshooting](docs/troubleshooting.md)

## License

MIT License - see [LICENSE](LICENSE) file for details

## Support

- **Issues**: [GitHub Issues](https://github.com/your-org/customer-support/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/customer-support/discussions)
- **Slack**: [Join our community](https://slack.your-org.com)

## Acknowledgments

Built with:
- [FastAPI](https://fastapi.tiangolo.com/)
- [Express.js](https://expressjs.com/)
- [Axum](https://github.com/tokio-rs/axum)
- [React](https://react.dev/)
- [Qdrant](https://qdrant.tech/)
- [LLM Observatory](https://github.com/your-org/llm-observatory)

---

**Built with LLM Observatory** - Comprehensive observability for LLM applications

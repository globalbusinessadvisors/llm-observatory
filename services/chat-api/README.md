# LLM Observatory Chat API

A production-ready FastAPI service for managing LLM-powered conversations with comprehensive observability, cost tracking, and multi-provider support.

## Features

- **Multi-Provider Support**: OpenAI, Anthropic, Azure OpenAI
- **Real-time Streaming**: Server-Sent Events (SSE) for streaming responses
- **Cost Tracking**: Automatic cost calculation per conversation/message
- **Conversation Management**: Full CRUD operations for conversations and messages
- **Feedback System**: Collect user feedback (thumbs up/down, ratings, comments)
- **Type-Safe**: Full type hints with Pydantic validation
- **Async/Await**: Built on asyncio for high performance
- **Production-Ready**: Comprehensive error handling, logging, and monitoring
- **Database**: PostgreSQL with SQLAlchemy async ORM
- **Testing**: 70%+ test coverage with pytest

## Quick Start

### Prerequisites

- Python 3.11+
- PostgreSQL 14+
- Redis 7+
- OpenAI API key (or Anthropic/Azure OpenAI)

### Installation

1. Clone the repository:
```bash
cd services/chat-api
```

2. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Configure environment:
```bash
cp .env.example .env
# Edit .env and add your API keys
```

5. Run database migrations:
```bash
# Tables are auto-created on first run
```

6. Start the server:
```bash
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`

### Docker Setup

1. Build the image:
```bash
docker build -t llm-observatory-chat-api .
```

2. Run with docker-compose:
```bash
docker-compose up -d
```

## API Documentation

Once running, access the interactive API documentation:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI JSON**: http://localhost:8000/openapi.json

## API Endpoints

### Conversations

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/conversations` | Create a new conversation |
| GET | `/api/v1/conversations` | List conversations |
| GET | `/api/v1/conversations/{id}` | Get conversation with messages |
| PATCH | `/api/v1/conversations/{id}` | Update conversation |
| DELETE | `/api/v1/conversations/{id}` | Delete conversation |
| POST | `/api/v1/conversations/{id}/feedback` | Submit feedback |

### Messages

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/conversations/{id}/messages` | Send message and get response |
| GET | `/api/v1/conversations/{id}/messages` | Get conversation messages |
| GET | `/api/v1/conversations/{id}/stream` | Stream LLM response (SSE) |

### Health & Status

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Root endpoint with service info |
| GET | `/health` | Health check |
| GET | `/ready` | Readiness check |

## Usage Examples

### Create a Conversation

```bash
curl -X POST http://localhost:8000/api/v1/conversations \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_123",
    "title": "Customer Support Chat",
    "metadata": {"source": "web"}
  }'
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "user_123",
  "title": "Customer Support Chat",
  "metadata": {"source": "web"},
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

### Send a Message

```bash
curl -X POST http://localhost:8000/api/v1/conversations/{conversation_id}/messages \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is the weather like today?",
    "provider": "openai",
    "model": "gpt-4",
    "temperature": 0.7,
    "max_tokens": 150
  }'
```

Response:
```json
{
  "message": {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "conversation_id": "550e8400-e29b-41d4-a716-446655440000",
    "role": "assistant",
    "content": "I don't have access to real-time weather data...",
    "provider": "openai",
    "model": "gpt-4",
    "prompt_tokens": 25,
    "completion_tokens": 50,
    "total_tokens": 75,
    "cost_usd": 0.00315,
    "latency_ms": 1234,
    "created_at": "2024-01-15T10:30:05Z"
  },
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000",
  "usage": {
    "prompt_tokens": 25,
    "completion_tokens": 50,
    "total_tokens": 75
  },
  "cost_usd": 0.00315
}
```

### Stream a Response (SSE)

```bash
curl -N http://localhost:8000/api/v1/conversations/{conversation_id}/stream?message=Hello
```

Response (Server-Sent Events):
```
data: {"content": "Hello", "done": false}

data: {"content": "!", "done": false}

data: {"content": " How", "done": false}

data: {"content": "", "done": true, "message_id": "..."}
```

### Get Conversation with Messages

```bash
curl http://localhost:8000/api/v1/conversations/{conversation_id}
```

### Submit Feedback

```bash
curl -X POST http://localhost:8000/api/v1/conversations/{conversation_id}/feedback \
  -H "Content-Type: application/json" \
  -d '{
    "message_id": "660e8400-e29b-41d4-a716-446655440001",
    "feedback_type": "thumbs_up",
    "rating": 5,
    "comment": "Very helpful response!"
  }'
```

## Configuration

All configuration is done via environment variables. See `.env.example` for all available options.

### Key Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | - |
| `REDIS_URL` | Redis connection string | - |
| `OPENAI_API_KEY` | OpenAI API key | - |
| `ANTHROPIC_API_KEY` | Anthropic API key | - |
| `DEFAULT_PROVIDER` | Default LLM provider | `openai` |
| `OPENAI_DEFAULT_MODEL` | Default OpenAI model | `gpt-4` |
| `MAX_TOKENS` | Max tokens per response | `4096` |
| `TEMPERATURE` | Default temperature | `0.7` |
| `LOG_LEVEL` | Logging level | `INFO` |

## Cost Tracking

The API automatically tracks and calculates costs for all LLM API calls:

- **Supported Models**: GPT-4, GPT-3.5-turbo, Claude 3 (Opus, Sonnet, Haiku), and more
- **Accurate Pricing**: Up-to-date pricing per 1K tokens
- **Per-Message Cost**: Each message includes `cost_usd` field
- **Conversation Total**: Sum costs across all messages

### Current Pricing (per 1K tokens)

| Model | Input | Output |
|-------|-------|--------|
| GPT-4 | $0.03 | $0.06 |
| GPT-3.5-turbo | $0.0015 | $0.002 |
| Claude 3 Opus | $0.015 | $0.075 |
| Claude 3 Sonnet | $0.003 | $0.015 |

## Database Schema

### Conversations Table

```sql
CREATE TABLE conversations (
    id UUID PRIMARY KEY,
    user_id VARCHAR(255),
    title VARCHAR(500),
    metadata JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);
```

### Messages Table

```sql
CREATE TABLE messages (
    id UUID PRIMARY KEY,
    conversation_id UUID REFERENCES conversations(id),
    role VARCHAR(20),  -- system, user, assistant, function
    content TEXT,
    provider VARCHAR(50),
    model VARCHAR(100),
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    total_tokens INTEGER,
    cost_usd FLOAT,
    latency_ms INTEGER,
    time_to_first_token_ms INTEGER,
    trace_id VARCHAR(255),
    span_id VARCHAR(255),
    metadata JSONB,
    error TEXT,
    created_at TIMESTAMPTZ
);
```

### Feedback Table

```sql
CREATE TABLE feedback (
    id UUID PRIMARY KEY,
    conversation_id UUID REFERENCES conversations(id),
    message_id UUID REFERENCES messages(id),
    user_id VARCHAR(255),
    feedback_type VARCHAR(20),  -- thumbs_up, thumbs_down, flag
    rating INTEGER,  -- 1-5
    comment TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ
);
```

## Testing

Run tests with pytest:

```bash
# All tests
pytest

# Unit tests only
pytest tests/unit

# Integration tests only
pytest tests/integration

# With coverage report
pytest --cov=app --cov-report=html

# Specific test file
pytest tests/unit/test_cost_tracker.py
```

## Development

### Code Quality

```bash
# Format code
black app/ tests/

# Sort imports
isort app/ tests/

# Lint
flake8 app/ tests/
pylint app/

# Type checking
mypy app/
```

### Pre-commit Hooks

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

## Deployment

### Production Checklist

- [ ] Set `ENVIRONMENT=production`
- [ ] Use strong `SECRET_KEY` and `JWT_SECRET`
- [ ] Configure production database
- [ ] Set up Redis for caching
- [ ] Configure CORS origins
- [ ] Enable SSL/TLS
- [ ] Set up monitoring and logging
- [ ] Configure rate limiting
- [ ] Review PII redaction settings
- [ ] Set up backup strategy

### Docker Deployment

```bash
docker build -t llm-observatory-chat-api:latest .
docker run -p 8000:8000 \
  -e DATABASE_URL=... \
  -e OPENAI_API_KEY=... \
  llm-observatory-chat-api:latest
```

### Kubernetes Deployment

See `k8s/` directory for Kubernetes manifests.

## Monitoring & Observability

The API includes built-in support for:

- **Structured Logging**: JSON logs with correlation IDs
- **OpenTelemetry**: Traces sent to OTLP collector
- **Health Checks**: `/health` and `/ready` endpoints
- **Metrics**: Prometheus-compatible metrics (optional)

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│    FastAPI App          │
│  ┌─────────────────┐   │
│  │   API Routes    │   │
│  └────────┬────────┘   │
│           │             │
│  ┌────────▼────────┐   │
│  │  LLM Service    │   │
│  │  - OpenAI       │   │
│  │  - Anthropic    │   │
│  │  - Azure OpenAI │   │
│  └────────┬────────┘   │
│           │             │
│  ┌────────▼────────┐   │
│  │ Cost Tracker    │   │
│  └─────────────────┘   │
└─────────┬───────────────┘
          │
     ┌────┴────┐
     ▼         ▼
┌──────────┐ ┌────────┐
│PostgreSQL│ │ Redis  │
└──────────┘ └────────┘
```

## Performance

- **Async/Await**: Non-blocking I/O for high concurrency
- **Connection Pooling**: Efficient database connection management
- **Caching**: Redis caching for frequently accessed data
- **Streaming**: Reduced latency with SSE streaming
- **Batching**: Efficient database operations

## Security

- **Input Validation**: Pydantic models validate all input
- **SQL Injection**: Protected by SQLAlchemy ORM
- **PII Detection**: Optional PII redaction (configurable)
- **Rate Limiting**: Configurable rate limiting
- **CORS**: Configurable CORS policies
- **API Keys**: Secure storage of LLM provider keys

## Troubleshooting

### Database Connection Issues

```bash
# Check database is running
psql -h localhost -U postgres -d llm_observatory

# Check connection string
echo $DATABASE_URL
```

### LLM API Errors

```bash
# Verify API key
echo $OPENAI_API_KEY

# Check logs
tail -f logs/app.log
```

### Performance Issues

- Enable database query logging: `DB_ECHO=true`
- Monitor with observability tools
- Check connection pool settings

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run linting and tests
6. Submit a pull request

## License

Apache 2.0

## Support

For issues and questions:
- GitHub Issues: [llm-observatory/llm-observatory](https://github.com/llm-observatory/llm-observatory/issues)
- Documentation: [docs/](./docs/)

## Roadmap

- [ ] GraphQL API
- [ ] Webhook support
- [ ] Advanced caching strategies
- [ ] Multi-tenancy support
- [ ] Rate limiting per user
- [ ] Custom model support
- [ ] Function calling/tools
- [ ] RAG integration
- [ ] A/B testing framework

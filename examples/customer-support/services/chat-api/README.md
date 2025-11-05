# Chat API Service

FastAPI-based chat service with multi-provider LLM support and real-time streaming.

## Features

- Multi-provider LLM support (OpenAI, Anthropic, Azure OpenAI)
- WebSocket-based real-time chat
- Conversation history management
- Context injection from knowledge base
- Rate limiting and request queuing
- LLM Observatory integration

## Development

```bash
# Install dependencies
poetry install

# Run migrations
alembic upgrade head

# Start development server
poetry run uvicorn app.main:app --reload --port 8000
```

## Testing

```bash
# Run tests
poetry run pytest

# Run with coverage
poetry run pytest --cov=app --cov-report=html
```

## API Documentation

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

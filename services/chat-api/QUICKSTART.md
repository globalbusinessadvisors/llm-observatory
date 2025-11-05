# Chat API Quick Start Guide

Get the LLM Observatory Chat API running in 5 minutes!

## Option 1: Docker Compose (Recommended)

### Prerequisites
- Docker and Docker Compose installed
- OpenAI API key (or Anthropic/Azure OpenAI)

### Steps

1. **Navigate to the service directory**
```bash
cd services/chat-api
```

2. **Configure environment**
```bash
cp .env.example .env
```

Edit `.env` and add your API key:
```bash
OPENAI_API_KEY=sk-your-api-key-here
```

3. **Start all services**
```bash
docker-compose up -d
```

This starts:
- Chat API (port 8000)
- PostgreSQL/TimescaleDB (port 5432)
- Redis (port 6379)

4. **Verify it's running**
```bash
curl http://localhost:8000/health
```

You should see:
```json
{
  "status": "healthy",
  "service": "LLM Observatory Chat API",
  "version": "1.0.0"
}
```

5. **View API documentation**

Open in your browser:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Option 2: Local Development

### Prerequisites
- Python 3.11+
- PostgreSQL 14+ running locally
- Redis 7+ running locally
- OpenAI API key

### Steps

1. **Create virtual environment**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. **Install dependencies**
```bash
pip install -r requirements.txt
```

3. **Configure environment**
```bash
cp .env.example .env
```

Edit `.env`:
```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/llm_observatory
REDIS_URL=redis://:redis_password@localhost:6379/0
OPENAI_API_KEY=sk-your-api-key-here
```

4. **Start the server**
```bash
uvicorn app.main:app --reload
```

Or use the Makefile:
```bash
make dev
```

5. **Access the API**
- API: http://localhost:8000
- Docs: http://localhost:8000/docs

## Quick Test

### 1. Create a conversation

```bash
curl -X POST http://localhost:8000/api/v1/conversations \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user",
    "title": "My First Chat"
  }'
```

Copy the `id` from the response.

### 2. Send a message

```bash
curl -X POST http://localhost:8000/api/v1/conversations/{conversation_id}/messages \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello! Tell me a joke.",
    "provider": "openai",
    "model": "gpt-3.5-turbo"
  }'
```

You'll get a response with:
- The AI's response
- Token usage
- Cost in USD
- Latency metrics

### 3. Stream a response

```bash
curl -N "http://localhost:8000/api/v1/conversations/{conversation_id}/stream?message=Tell%20me%20a%20story"
```

You'll see the response streamed in real-time!

### 4. Get conversation history

```bash
curl http://localhost:8000/api/v1/conversations/{conversation_id}
```

## Testing Different Providers

### OpenAI (GPT-4)
```bash
curl -X POST http://localhost:8000/api/v1/conversations/{id}/messages \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Explain quantum computing",
    "provider": "openai",
    "model": "gpt-4"
  }'
```

### Anthropic (Claude)
```bash
# First, add ANTHROPIC_API_KEY to .env

curl -X POST http://localhost:8000/api/v1/conversations/{id}/messages \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Explain quantum computing",
    "provider": "anthropic",
    "model": "claude-3-sonnet-20240229"
  }'
```

## Running Tests

```bash
# All tests
pytest

# With coverage
pytest --cov=app --cov-report=html

# Open coverage report
open htmlcov/index.html
```

## Useful Commands

### Docker Compose

```bash
# View logs
docker-compose logs -f chat-api

# Restart service
docker-compose restart chat-api

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Makefile Shortcuts

```bash
# Install dependencies
make install

# Run dev server
make dev

# Run tests with coverage
make test-cov

# Format code
make format

# Build Docker image
make docker-build

# View logs
make docker-logs
```

## Database Access

### PostgreSQL Shell
```bash
# Via Docker
docker-compose exec timescaledb psql -U postgres -d llm_observatory

# Or use Makefile
make db-shell
```

### Redis CLI
```bash
# Via Docker
docker-compose exec redis redis-cli -a redis_password

# Or use Makefile
make redis-cli
```

## Troubleshooting

### Issue: "Database connection failed"

**Solution**: Ensure PostgreSQL is running and credentials are correct.

```bash
# Check PostgreSQL is running
docker-compose ps timescaledb

# Check logs
docker-compose logs timescaledb
```

### Issue: "OpenAI API key not found"

**Solution**: Add your API key to `.env`:

```bash
OPENAI_API_KEY=sk-your-actual-key-here
```

Then restart:
```bash
docker-compose restart chat-api
```

### Issue: "Port 8000 already in use"

**Solution**: Change the port in `.env`:

```bash
CHAT_API_PORT=8001
```

Or stop the conflicting service.

### Issue: Tests failing

**Solution**: Ensure test database exists:

```bash
# Create test database
docker-compose exec timescaledb psql -U postgres -c "CREATE DATABASE llm_observatory_test;"

# Run tests
pytest
```

## Next Steps

1. **Explore the API**: Check out http://localhost:8000/docs
2. **Read the README**: See `README.md` for detailed documentation
3. **Check the examples**: Look at `examples/` directory
4. **Integrate with frontend**: Use the API in your application
5. **Monitor costs**: Check message costs in the response
6. **Add feedback**: Submit user feedback via the API

## Production Deployment

For production deployment instructions, see:
- `README.md` - Deployment section
- `docker/` - Production Docker configurations
- `k8s/` - Kubernetes manifests (if available)

## Support

- **Documentation**: `README.md`
- **API Docs**: http://localhost:8000/docs
- **Issues**: GitHub Issues
- **Examples**: `examples/` directory

## Example Python Client

```python
import httpx

# Create conversation
response = httpx.post(
    "http://localhost:8000/api/v1/conversations",
    json={"user_id": "user_123", "title": "Test Chat"}
)
conversation_id = response.json()["id"]

# Send message
response = httpx.post(
    f"http://localhost:8000/api/v1/conversations/{conversation_id}/messages",
    json={
        "message": "Hello!",
        "provider": "openai",
        "model": "gpt-3.5-turbo"
    }
)

print(response.json())
```

Happy coding! 🚀

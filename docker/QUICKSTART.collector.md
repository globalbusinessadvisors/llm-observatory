# Collector Service - Quick Start Guide

## 5-Minute Setup

### Prerequisites

- Docker 20.10+ with Docker Compose
- 2GB RAM minimum
- Ports 4327, 4328, 9091, 8082 available

### Step 1: Copy Environment File

```bash
cp .env.example .env
```

### Step 2: Start Infrastructure

```bash
# Start database and cache
docker compose up -d timescaledb redis
```

### Step 3: Start Collector

```bash
# Production mode
docker compose -f docker-compose.yml -f docker-compose.app.yml up -d collector

# OR Development mode (with hot reload)
docker compose -f docker-compose.yml -f docker-compose.app.yml --profile dev up -d collector-dev
```

### Step 4: Verify

```bash
# Check health
curl http://localhost:8082/health

# Check metrics
curl http://localhost:9091/metrics
```

## Send Your First Trace

### Using cURL (HTTP)

```bash
curl -X POST http://localhost:4328/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "scopeSpans": [{
        "spans": [{
          "traceId": "0102030405060708090a0b0c0d0e0f10",
          "spanId": "0102030405060708",
          "name": "my-first-llm-call",
          "kind": 1,
          "startTimeUnixNano": "1234567890000000000",
          "endTimeUnixNano": "1234567891000000000",
          "attributes": [{
            "key": "llm.provider",
            "value": {"stringValue": "openai"}
          }, {
            "key": "llm.model",
            "value": {"stringValue": "gpt-4"}
          }, {
            "key": "llm.request.type",
            "value": {"stringValue": "completion"}
          }]
        }]
      }]
    }]
  }'
```

### Using OpenTelemetry SDK (Python)

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configure
exporter = OTLPSpanExporter(endpoint="http://localhost:4327", insecure=True)
provider = TracerProvider()
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

# Use
tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("llm-call") as span:
    span.set_attribute("llm.provider", "openai")
    span.set_attribute("llm.model", "gpt-4")
    # Your LLM call here
```

## Common Commands

### Production

```bash
# Start
make -f docker/Makefile.collector up

# View logs
make -f docker/Makefile.collector logs

# Check health
make -f docker/Makefile.collector health

# Stop
make -f docker/Makefile.collector down
```

### Development

```bash
# Start with hot reload
make -f docker/Makefile.collector up-dev

# View logs
make -f docker/Makefile.collector logs-dev

# Restart after config changes
make -f docker/Makefile.collector restart-dev
```

## Access Points

| Service | URL | Description |
|---------|-----|-------------|
| OTLP gRPC | `localhost:4327` | OpenTelemetry gRPC endpoint |
| OTLP HTTP | `localhost:4328` | OpenTelemetry HTTP endpoint |
| Metrics | `http://localhost:9091/metrics` | Prometheus metrics |
| Health | `http://localhost:8082/health` | Health check |

## Configuration

Edit `/workspaces/llm-observatory/.env`:

```bash
# Basic settings
COLLECTOR_LOG_LEVEL=info
COLLECTOR_BATCH_SIZE=500

# LLM features
COLLECTOR_LLM_ENRICHMENT_ENABLED=true
COLLECTOR_TOKEN_COUNTING_ENABLED=true
COLLECTOR_COST_CALCULATION_ENABLED=true
```

Restart after changes:
```bash
docker compose -f docker-compose.app.yml restart collector
```

## Troubleshooting

### Port Already in Use

```bash
# Check what's using the port
sudo lsof -i :4327

# Use different ports
export COLLECTOR_OTLP_GRPC_PORT=4427
docker compose -f docker-compose.app.yml up -d collector
```

### Container Won't Start

```bash
# Check logs
docker compose -f docker-compose.app.yml logs collector

# Check dependencies
docker compose ps timescaledb redis
```

### No Data Received

```bash
# Verify collector is listening
curl http://localhost:8082/health

# Check logs for errors
docker compose -f docker-compose.app.yml logs collector | grep -i error

# Send test trace
make -f docker/Makefile.collector test-http
```

## Next Steps

1. [Configure LLM-specific processing](COLLECTOR_README.md#llm-specific-processing)
2. [Set up monitoring dashboards](../docs/monitoring.md)
3. [Integrate with your application](../docs/integration.md)
4. [Optimize for production](../docs/production.md)

## Need Help?

- Full documentation: [COLLECTOR_README.md](COLLECTOR_README.md)
- GitHub Issues: https://github.com/llm-observatory/llm-observatory/issues
- Discord: https://discord.gg/llm-observatory

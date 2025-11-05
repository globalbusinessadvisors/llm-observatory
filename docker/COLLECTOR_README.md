# LLM Observatory Collector Service - Docker Configuration

## Overview

The Collector Service is an OpenTelemetry-compatible OTLP receiver with LLM-specific processing capabilities. It receives telemetry data (traces, metrics, logs) via OTLP protocol and enriches it with LLM-specific metadata before storing it.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Collector Service                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐     ┌──────────────┐     ┌────────────────┐  │
│  │   OTLP      │────▶│  Processors  │────▶│   Exporters    │  │
│  │  Receivers  │     │              │     │                │  │
│  │             │     │ • Enrichment │     │ • Storage      │  │
│  │ • gRPC      │     │ • Tokens     │     │ • Database     │  │
│  │ • HTTP      │     │ • Cost       │     │ • Prometheus   │  │
│  │             │     │ • PII        │     │                │  │
│  └─────────────┘     └──────────────┘     └────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Features

### LLM-Specific Processing

1. **Enrichment**: Extracts and normalizes LLM model information
2. **Token Counting**: Calculates accurate token counts for prompts/completions
3. **Cost Calculation**: Computes costs based on usage and provider pricing
4. **PII Redaction**: Optional removal of sensitive information

### OpenTelemetry Standards

- Full OTLP/gRPC support (port 4327)
- Full OTLP/HTTP support (port 4328)
- Prometheus metrics endpoint (port 9091)
- Health check endpoint (port 8082)

## Docker Images

### Production Image

**File**: `docker/Dockerfile.collector`

- Multi-stage build for minimal size
- Based on Debian Bookworm Slim
- Non-root user for security
- Optimized with release builds
- ~50MB final image size

**Build**:
```bash
docker build -f docker/Dockerfile.collector -t llm-observatory/collector:latest .
```

### Development Image

**File**: `docker/Dockerfile.collector.dev`

- Based on rust:1.75-slim
- Includes cargo-watch for hot reload
- Debug symbols included
- Fast incremental builds

**Build**:
```bash
docker build -f docker/Dockerfile.collector.dev -t llm-observatory/collector:dev .
```

## Docker Compose Usage

### Production Deployment

```bash
# Start all services including collector
docker compose -f docker-compose.yml -f docker/compose/docker-compose.app.yml up -d

# Start only collector and dependencies
docker compose -f docker-compose.yml -f docker/compose/docker-compose.app.yml up -d collector

# View logs
docker compose -f docker-compose.yml -f docker/compose/docker-compose.app.yml logs -f collector
```

### Development Mode

```bash
# Start with hot reload enabled
docker compose -f docker-compose.yml -f docker/compose/docker-compose.app.yml --profile dev up -d collector-dev

# View logs with detailed output
docker compose -f docker-compose.yml -f docker/compose/docker-compose.app.yml logs -f collector-dev
```

## Port Configuration

### Default Ports

| Service | Port | Purpose |
|---------|------|---------|
| OTLP gRPC | 4327 | OpenTelemetry gRPC receiver |
| OTLP HTTP | 4328 | OpenTelemetry HTTP receiver |
| Metrics | 9091 | Prometheus metrics |
| Health | 8082 | Health check endpoint |

**Note**: These ports differ from Jaeger (4317/4318) to avoid conflicts.

### Development Ports

| Service | Port | Purpose |
|---------|------|---------|
| OTLP gRPC | 4337 | Development gRPC receiver |
| OTLP HTTP | 4338 | Development HTTP receiver |
| Metrics | 9191 | Development metrics |
| Health | 8182 | Development health check |

## Environment Variables

### Core Configuration

```bash
# Endpoints
COLLECTOR_OTLP_GRPC_ENDPOINT=0.0.0.0:4327
COLLECTOR_OTLP_HTTP_ENDPOINT=0.0.0.0:4328
COLLECTOR_METRICS_ENDPOINT=0.0.0.0:9091
COLLECTOR_HEALTH_ENDPOINT=0.0.0.0:8082

# Database connection
DATABASE_URL=postgresql://user:pass@timescaledb:5432/llm_observatory

# Redis connection
REDIS_URL=redis://:password@redis:6379/0

# Storage service
STORAGE_SERVICE_URL=http://storage:8081
```

### Batch Processing

```bash
COLLECTOR_BATCH_SIZE=500              # Items per batch
COLLECTOR_BATCH_TIMEOUT=10            # Seconds before flush
COLLECTOR_MAX_QUEUE_SIZE=10000        # Max queued items
COLLECTOR_NUM_WORKERS=4               # Worker threads
```

### LLM Features

```bash
COLLECTOR_LLM_ENRICHMENT_ENABLED=true
COLLECTOR_TOKEN_COUNTING_ENABLED=true
COLLECTOR_COST_CALCULATION_ENABLED=true
COLLECTOR_PII_REDACTION_ENABLED=false
```

### Logging

```bash
COLLECTOR_LOG_LEVEL=info              # debug, info, warn, error
COLLECTOR_LOG_FORMAT=json             # json, pretty
RUST_LOG=info                         # Rust logging filter
RUST_BACKTRACE=1                      # Enable backtraces
```

### OpenTelemetry Protocol

```bash
OTLP_COMPRESSION=gzip                 # gzip, none
OTLP_TIMEOUT=30                       # Seconds
OTLP_MAX_MESSAGE_SIZE=4194304         # 4MB default
```

## Configuration File

The collector uses `/app/config/collector.yaml` for detailed configuration. Key sections:

### Receivers
```yaml
receivers:
  otlp_grpc:
    endpoint: "0.0.0.0:4327"
  otlp_http:
    endpoint: "0.0.0.0:4328"
```

### Processors
```yaml
processors:
  llm_enrichment:
    enabled: true
  token_counting:
    enabled: true
  cost_calculation:
    enabled: true
  pii_redaction:
    enabled: false
```

### Exporters
```yaml
exporters:
  storage:
    endpoint: "http://storage:8081"
  database:
    connection_url: "${DATABASE_URL}"
  prometheus:
    endpoint: "0.0.0.0:9091"
```

## Health Checks

### HTTP Endpoint

```bash
# Basic health check
curl http://localhost:8082/health

# Response (healthy)
{
  "status": "healthy",
  "version": "0.1.0",
  "uptime": "3h 24m 15s"
}
```

### Docker Health Check

```bash
# Check container health
docker compose -f docker/compose/docker-compose.app.yml ps collector

# Manually trigger health check
docker compose -f docker/compose/docker-compose.app.yml exec collector /usr/local/bin/collector health-check
```

## Metrics

### Prometheus Endpoint

Access metrics at: `http://localhost:9091/metrics`

### Key Metrics

```
# Received spans
llm_observatory_collector_spans_received_total

# Processed spans
llm_observatory_collector_spans_processed_total

# Failed spans
llm_observatory_collector_spans_failed_total

# Queue size
llm_observatory_collector_queue_size

# Processing latency
llm_observatory_collector_processing_duration_seconds
```

## Testing

### Send Test Data (gRPC)

```bash
# Using grpcurl
grpcurl -plaintext \
  -import-path ./proto \
  -proto opentelemetry/proto/collector/trace/v1/trace_service.proto \
  -d @ \
  localhost:4327 \
  opentelemetry.proto.collector.trace.v1.TraceService/Export < test_data.json
```

### Send Test Data (HTTP)

```bash
# Using curl
curl -X POST http://localhost:4328/v1/traces \
  -H "Content-Type: application/json" \
  -d @test_trace.json
```

### Verify Processing

```bash
# Check logs
docker compose -f docker/compose/docker-compose.app.yml logs collector | grep "processed"

# Check metrics
curl -s http://localhost:9091/metrics | grep spans_processed
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose -f docker/compose/docker-compose.app.yml logs collector

# Common issues:
# 1. Database not ready - wait for health check
# 2. Port conflicts - check COLLECTOR_*_PORT variables
# 3. Invalid config - verify collector.yaml syntax
```

### High Memory Usage

```bash
# Adjust memory limiter in config
# Edit docker/config/collector.yaml:
memory_limiter:
  limit_mib: 512
  spike_limit_mib: 128

# Reduce batch size
COLLECTOR_BATCH_SIZE=100
COLLECTOR_MAX_QUEUE_SIZE=1000
```

### Slow Processing

```bash
# Increase workers
COLLECTOR_NUM_WORKERS=8

# Increase batch size
COLLECTOR_BATCH_SIZE=1000

# Check database connection pool
DB_POOL_MAX_SIZE=50
```

### Connection Refused

```bash
# Verify network
docker compose -f docker/compose/docker-compose.app.yml exec collector ping storage
docker compose -f docker/compose/docker-compose.app.yml exec collector ping timescaledb

# Check service dependencies
docker compose -f docker/compose/docker-compose.app.yml ps
```

## Security Best Practices

### Production Checklist

- [ ] Enable TLS for OTLP receivers
- [ ] Use non-default ports
- [ ] Enable PII redaction
- [ ] Restrict CORS origins
- [ ] Use secrets management for credentials
- [ ] Enable authentication/authorization
- [ ] Set resource limits
- [ ] Configure network policies
- [ ] Regular security updates

### TLS Configuration

```yaml
# In collector.yaml
receivers:
  otlp_grpc:
    tls:
      enabled: true
      cert_file: /etc/collector/certs/server.crt
      key_file: /etc/collector/certs/server.key
```

## Performance Tuning

### High Throughput

```bash
# Increase workers and batch size
COLLECTOR_NUM_WORKERS=16
COLLECTOR_BATCH_SIZE=2000
COLLECTOR_MAX_QUEUE_SIZE=50000

# Increase connection pool
DB_POOL_MAX_SIZE=100

# Use larger message size
OTLP_MAX_MESSAGE_SIZE=8388608  # 8MB
```

### Low Latency

```bash
# Reduce batch timeout
COLLECTOR_BATCH_TIMEOUT=1

# Increase workers
COLLECTOR_NUM_WORKERS=8

# Disable compression
OTLP_COMPRESSION=none
```

## Monitoring

### Grafana Dashboard

Import the collector dashboard from `docker/grafana/dashboards/collector.json`

Key panels:
- Ingestion rate (spans/sec)
- Processing latency (p50, p95, p99)
- Queue size
- Error rate
- Resource usage (CPU, memory)

### Alerts

Configure alerts in `docker/prometheus/alerts/collector_alerts.yml`

- High error rate
- Queue near capacity
- High processing latency
- Service down

## Development

### Hot Reload

```bash
# Start dev container
docker compose -f docker/compose/docker-compose.app.yml --profile dev up collector-dev

# Changes to source files trigger automatic rebuild
# View rebuild logs
docker compose -f docker/compose/docker-compose.app.yml logs -f collector-dev
```

### Debugging

```bash
# Enable debug logging
COLLECTOR_LOG_LEVEL=debug
RUST_LOG=debug
RUST_BACKTRACE=full

# Use pretty format for readability
COLLECTOR_LOG_FORMAT=pretty
```

## Integration Examples

### Python Application

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configure exporter
exporter = OTLPSpanExporter(
    endpoint="http://localhost:4327",
    insecure=True
)

# Setup tracing
provider = TracerProvider()
processor = BatchSpanProcessor(exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

# Use tracer
tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("llm-call"):
    # Your LLM call here
    pass
```

### JavaScript/Node.js Application

```javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');

// Configure exporter
const exporter = new OTLPTraceExporter({
  url: 'http://localhost:4328/v1/traces',
});

// Setup provider
const provider = new NodeTracerProvider();
provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register();
```

## Additional Resources

- [OpenTelemetry Protocol Specification](https://opentelemetry.io/docs/specs/otlp/)
- [Collector Configuration Reference](../docs/collector-configuration.md)
- [LLM Processing Guide](../docs/llm-processing.md)
- [Troubleshooting Guide](../docs/troubleshooting.md)

## Support

For issues and questions:
- GitHub Issues: https://github.com/llm-observatory/llm-observatory/issues
- Documentation: https://docs.llm-observatory.io
- Discord: https://discord.gg/llm-observatory

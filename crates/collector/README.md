# llm-observatory-collector

OpenTelemetry collector with LLM-specific processors for LLM Observatory.

## Overview

High-performance telemetry collector designed specifically for LLM applications:

- **OTLP Receiver**: gRPC and HTTP endpoints for OpenTelemetry data
- **LLM-Aware Processing**: Token counting, cost calculation, PII redaction
- **Intelligent Sampling**: Head and tail sampling strategies
- **Context Propagation**: Distributed tracing support
- **Metric Enrichment**: Automatic LLM-specific metadata

## Features

- **100k+ spans/sec**: High-throughput processing
- **PII Redaction**: Optional privacy-preserving transformations
- **Cost Calculation**: Real-time LLM cost tracking
- **Multiple Backends**: TimescaleDB, Tempo, Loki support

## Usage

```bash
# Run collector
llm-observatory-collector --config config.yaml
```

Configuration:

```yaml
receivers:
  otlp:
    grpc:
      endpoint: 0.0.0.0:4317
    http:
      endpoint: 0.0.0.0:4318

processors:
  llm_enrichment:
    enable_cost: true
    enable_pii_redaction: false

exporters:
  timescaledb:
    connection_string: postgres://...
```

## Documentation

See the [collector documentation](https://docs.llm-observatory.io/collector) for detailed configuration.

## License

Apache-2.0

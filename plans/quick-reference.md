# LLM Observatory: Quick Reference Guide

**Last Updated:** 2025-11-05

---

## Architecture at a Glance

```
Applications → SDK → Collector → Storage → Visualization
             (Rust)   (OTel)    (Multi-tier)  (Grafana)
```

---

## Technology Stack

### Core
- **Language:** Rust (stable)
- **Async:** Tokio
- **Telemetry:** OpenTelemetry

### Storage
- **Metrics:** TimescaleDB
- **Traces:** Grafana Tempo
- **Logs:** Grafana Loki

### Dependencies
```toml
[dependencies]
# OpenTelemetry
opentelemetry = { version = "0.24", features = ["trace", "metrics"] }
opentelemetry_sdk = { version = "0.24", features = ["rt-tokio"] }
opentelemetry-otlp = { version = "0.17", features = ["tokio"] }

# Tracing
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
tracing-opentelemetry = "0.24"

# Async
tokio = { version = "1", features = ["full"] }
tokio-metrics = "0.3"

# Performance
bytes = "1"
simd-json = "0.13"

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

---

## Key Patterns

### 1. Instrumenting LLM Calls

```rust
use tracing::{info, instrument};
use opentelemetry::trace::{Span, Tracer};

#[instrument(
    name = "llm.chat_completion",
    skip(prompt),
    fields(
        gen_ai.system = %provider,
        gen_ai.request.model = %model,
        prompt_length = prompt.len()
    )
)]
async fn call_llm(
    provider: &str,
    model: &str,
    prompt: &str,
) -> Result<Response> {
    let start = Instant::now();

    let response = llm_client.complete(model, prompt).await?;

    // Record metrics
    let span = Span::current();
    span.set_attribute("gen_ai.usage.prompt_tokens", response.usage.prompt_tokens);
    span.set_attribute("gen_ai.usage.completion_tokens", response.usage.completion_tokens);
    span.set_attribute("llm.cost.total_usd", response.cost);
    span.set_attribute("llm.duration_ms", start.elapsed().as_millis());

    info!(
        tokens = response.usage.total_tokens,
        cost_usd = response.cost,
        "LLM request completed"
    );

    Ok(response)
}
```

### 2. Context Propagation

```rust
use opentelemetry::{global, Context};

async fn rag_pipeline(query: &str) -> Result<String> {
    let tracer = global::tracer("llm-observatory");

    // Parent span
    let span = tracer
        .span_builder("rag.query")
        .start(&tracer);

    let cx = Context::current_with_span(span);

    // Child spans inherit context automatically
    let docs = cx.with_context(|cx| {
        retrieve_documents(query, cx)
    }).await?;

    let response = cx.with_context(|cx| {
        call_llm_with_context(query, &docs, cx)
    }).await?;

    Ok(response)
}
```

### 3. Sampling Configuration

```rust
// Priority sampler: always sample errors and slow requests
let sampler = LLMSampler::PrioritySampler {
    base_rate: 0.01,        // 1% of normal requests
    error_rate: 1.0,        // 100% of errors
    slow_threshold_ms: 5000, // > 5s
};

let trace_config = trace::Config::default()
    .with_sampler(sampler);
```

### 4. Batch Processing

```rust
let batch_config = BatchConfig {
    max_queue_size: 2048,
    scheduled_delay: Duration::from_secs(10),
    max_export_batch_size: 512,
    max_export_timeout: Duration::from_secs(30),
};
```

---

## Database Schemas

### Metrics (TimescaleDB)

```sql
-- Query: Cost by model (last 24h)
SELECT
    model_name,
    COUNT(*) as requests,
    SUM(total_cost_usd) as cost_usd,
    AVG(duration_ms) as avg_latency_ms
FROM llm_metrics
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY model_name
ORDER BY cost_usd DESC;

-- Query: P95 latency trend
SELECT
    time_bucket('1 hour', ts) as hour,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_ms
FROM llm_metrics
WHERE ts > NOW() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour;
```

### Traces (Tempo)

```rust
// Query by trace ID
let trace = tempo_client.get_trace(trace_id).await?;

// Search with TraceQL
let traces = tempo_client.search_traces(
    r#"{ span.llm.model = "gpt-4" && duration > 5s }"#
).await?;
```

### Logs (Loki)

```logql
# Find errors
{service_name="llm-gateway", level="error"}
| json
| line_format "{{.timestamp}} {{.error.message}}"

# Find slow requests
{service_name="llm-gateway"}
| json
| performance_duration_ms > 5000

# Aggregate error rate
sum(rate({service_name="llm-gateway", level="error"}[5m]))
/
sum(rate({service_name="llm-gateway"}[5m]))
```

---

## OpenTelemetry Semantic Conventions

### Required Attributes

```rust
// GenAI semantic conventions
span.set_attribute("gen_ai.system", "openai");
span.set_attribute("gen_ai.request.model", "gpt-4-turbo");
```

### Optional Attributes

```rust
// Request parameters
span.set_attribute("gen_ai.request.temperature", 0.7);
span.set_attribute("gen_ai.request.max_tokens", 1000);
span.set_attribute("gen_ai.request.top_p", 0.9);

// Usage metrics
span.set_attribute("gen_ai.usage.prompt_tokens", 100);
span.set_attribute("gen_ai.usage.completion_tokens", 200);
```

### Custom Attributes (Extensions)

```rust
// Cost tracking
span.set_attribute("llm.cost.prompt_usd", 0.001);
span.set_attribute("llm.cost.completion_usd", 0.002);
span.set_attribute("llm.cost.total_usd", 0.003);

// Performance
span.set_attribute("llm.ttft_ms", 456);  // Time to first token
span.set_attribute("llm.tokens_per_second", 12.5);

// Context
span.set_attribute("llm.user_id", "user_123");
span.set_attribute("llm.application_id", "app_456");
```

---

## Configuration Examples

### SDK Configuration

```rust
use opentelemetry_sdk::{runtime, trace as sdktrace, Resource};
use opentelemetry_semantic_conventions as semcov;

// Initialize trace provider
let tracer = opentelemetry_otlp::new_pipeline()
    .tracing()
    .with_exporter(
        opentelemetry_otlp::new_exporter()
            .tonic()
            .with_endpoint("http://localhost:4317")
    )
    .with_trace_config(
        sdktrace::Config::default()
            .with_sampler(sampler)
            .with_resource(Resource::new(vec![
                KeyValue::new(semcov::SERVICE_NAME, "llm-app"),
                KeyValue::new(semcov::SERVICE_VERSION, "1.0.0"),
            ]))
    )
    .install_batch(runtime::Tokio)?;
```

### Collector Configuration

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors
        type: status_code
        status_code: { status_codes: [ERROR] }
      - name: slow
        type: latency
        latency: { threshold_ms: 5000 }

exporters:
  otlp/tempo:
    endpoint: tempo:4317

  prometheusremotewrite:
    endpoint: http://timescaledb:9201/write

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, tail_sampling]
      exporters: [otlp/tempo]

    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheusremotewrite]
```

---

## Performance Optimization

### Zero-Copy Parsing

```rust
use bytes::{Bytes, BytesMut};

pub struct ZeroCopyResponse<'a> {
    #[serde(borrow)]
    pub model: &'a str,
    #[serde(borrow)]
    pub text: &'a str,
    pub tokens: u32,
}

// Parse without copying
let response: ZeroCopyResponse = simd_json::from_slice(&buf)?;
```

### Memory Pooling

```rust
pub struct TelemetryBuffer {
    buffer: BytesMut,
}

impl TelemetryBuffer {
    pub fn write_span(&mut self, span: &Span) -> Result<Bytes> {
        self.buffer.clear();  // Reuse buffer
        bincode::serialize_into(&mut self.buffer, span)?;
        Ok(self.buffer.split().freeze())
    }
}
```

### Async Batching

```rust
pub async fn flush_worker(mut rx: mpsc::Receiver<Span>) {
    let mut batch = Vec::with_capacity(100);

    while let Some(span) = rx.recv().await {
        batch.push(span);

        if batch.len() >= 100 {
            export_batch(&batch).await;
            batch.clear();
        }
    }
}
```

---

## Common Queries

### 1. Find Expensive Requests

```sql
-- TimescaleDB
SELECT trace_id, model_name, total_cost_usd, duration_ms
FROM llm_metrics
WHERE total_cost_usd > 0.1
ORDER BY ts DESC
LIMIT 100;
```

### 2. Error Analysis

```logql
# Loki
{service_name="llm-gateway", level="error"}
| json
| line_format "{{.trace_id}}: {{.error.type}} - {{.error.message}}"
```

### 3. Model Comparison

```sql
-- TimescaleDB
SELECT
    model_name,
    COUNT(*) as requests,
    AVG(duration_ms) as avg_latency_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_ms,
    SUM(total_cost_usd) as total_cost_usd
FROM llm_metrics
WHERE ts > NOW() - INTERVAL '7 days'
GROUP BY model_name
ORDER BY requests DESC;
```

### 4. User Activity

```sql
-- TimescaleDB
SELECT
    user_id,
    COUNT(*) as requests,
    SUM(total_tokens) as tokens,
    SUM(total_cost_usd) as cost_usd
FROM llm_metrics
WHERE ts > NOW() - INTERVAL '30 days'
GROUP BY user_id
ORDER BY cost_usd DESC
LIMIT 50;
```

---

## Debugging

### Enable Debug Logging

```bash
# Environment variable
export RUST_LOG=llm_observatory=debug,opentelemetry=debug

# Or in code
tracing_subscriber::fmt()
    .with_env_filter("llm_observatory=debug")
    .init();
```

### Disable Batching (Local Dev)

```rust
// For immediate trace visibility
let tracer = opentelemetry_otlp::new_pipeline()
    .tracing()
    .with_exporter(/* ... */)
    .install_simple()?;  // No batching
```

### Inspect Traces Locally

```bash
# View traces in Grafana
open http://localhost:3000/explore

# Query Tempo directly
curl http://localhost:3200/api/traces/<trace_id>
```

---

## Deployment

### Docker Compose (Development)

```yaml
# docker-compose.yml
version: '3.8'

services:
  timescaledb:
    image: timescale/timescaledb:latest-pg16
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: password

  tempo:
    image: grafana/tempo:latest
    ports:
      - "3200:3200"
      - "4317:4317"
    volumes:
      - ./tempo-config.yaml:/etc/tempo.yaml

  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"

  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"
      - "4318:4318"
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
```

### Kubernetes (Production)

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
spec:
  replicas: 3
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:latest
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
```

---

## Monitoring the Monitoring

### Key Metrics

```promql
# Collector throughput
rate(otelcol_receiver_accepted_spans[5m])

# Export errors
rate(otelcol_exporter_send_failed_spans[5m])

# Queue size
otelcol_exporter_queue_size

# Memory usage
process_resident_memory_bytes{job="otel-collector"}
```

### Alerts

```yaml
# alerting-rules.yaml
groups:
  - name: otel-collector
    rules:
      - alert: HighErrorRate
        expr: rate(otelcol_exporter_send_failed_spans[5m]) > 100
        for: 5m
        annotations:
          summary: "High span export error rate"

      - alert: QueueFull
        expr: otelcol_exporter_queue_size > 2000
        for: 2m
        annotations:
          summary: "Export queue nearly full"
```

---

## Cost Optimization

### 1. Aggressive Sampling

```rust
// Sample only 0.1% of normal traffic
let sampler = LLMSampler::PrioritySampler {
    base_rate: 0.001,  // 0.1%
    error_rate: 1.0,   // 100% errors
    slow_threshold_ms: 10000,  // > 10s
};
```

### 2. Shorter Retention

```sql
-- Reduce hot tier from 7 to 3 days
SELECT add_retention_policy('llm_metrics', INTERVAL '3 days');
```

### 3. Compression

```sql
-- Enable compression after 1 day (vs 7 days)
SELECT add_compression_policy('llm_metrics', INTERVAL '1 day');
```

---

## Security

### PII Scrubbing

```rust
pub fn scrub_pii(span: &mut Span) {
    // Remove prompts/responses
    span.attributes.remove("gen_ai.prompt");
    span.attributes.remove("gen_ai.completion");

    // Keep hashes for debugging
    if let Some(prompt) = span.attributes.get("gen_ai.prompt") {
        let hash = blake3::hash(prompt.as_bytes());
        span.attributes.insert("gen_ai.prompt_hash", hash.to_hex());
    }
}
```

### Encryption

```yaml
# TLS for OTLP
exporters:
  otlp:
    endpoint: collector:4317
    tls:
      cert_file: /certs/cert.pem
      key_file: /certs/key.pem
      ca_file: /certs/ca.pem
```

---

## Resources

- **Full Architecture:** `/workspaces/llm-observatory/plans/architecture-analysis.md`
- **Executive Summary:** `/workspaces/llm-observatory/plans/executive-summary.md`
- **OpenTelemetry Docs:** https://opentelemetry.io/docs/
- **Rust Tracing:** https://docs.rs/tracing/
- **Grafana Tempo:** https://grafana.com/docs/tempo/
- **TimescaleDB:** https://docs.timescale.com/

---

**Last Updated:** 2025-11-05

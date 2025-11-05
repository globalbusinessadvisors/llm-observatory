# LLM Observatory: Comprehensive Architecture Analysis

**Date:** 2025-11-05
**Version:** 1.0
**Status:** Research & Analysis Phase

---

## Executive Summary

This document provides a comprehensive analysis of architectural patterns, storage models, and telemetry approaches for building a high-performance LLM observability system in Rust. The analysis focuses on scalability, performance, and developer experience, drawing from industry best practices and emerging standards in 2025.

**Key Recommendations:**
- **Architecture:** Hybrid approach combining SDK-based auto-instrumentation with optional proxy mode
- **Storage:** Multi-tier strategy using TimescaleDB for metrics, Grafana Tempo for traces, and Loki for logs
- **Telemetry:** OpenTelemetry-native implementation with intelligent sampling strategies
- **Runtime:** Tokio-based async runtime with custom zero-copy optimizations

---

## Table of Contents

1. [Architecture Patterns](#1-architecture-patterns)
2. [Storage & Data Models](#2-storage--data-models)
3. [Telemetry Collection Strategies](#3-telemetry-collection-strategies)
4. [Rust-Specific Considerations](#4-rust-specific-considerations)
5. [Proposed High-Level Architecture](#5-proposed-high-level-architecture)
6. [Data Schema Recommendations](#6-data-schema-recommendations)
7. [Implementation Roadmap](#7-implementation-roadmap)

---

## 1. Architecture Patterns

### 1.1 Pattern Comparison Matrix

| Pattern | Complexity | Performance | Flexibility | DX Score | Best For |
|---------|-----------|-------------|-------------|----------|----------|
| **SDK-Based Auto-Instrumentation** | Medium | Excellent | High | 9/10 | Production systems requiring deep visibility |
| **Proxy-Based Monitoring** | Low | Good | Medium | 8/10 | Quick deployment, startups, cost tracking |
| **Hybrid SDK + Proxy** | High | Excellent | Very High | 9/10 | Enterprise deployments |
| **Agent-Based Sidecar** | Medium-High | Good | High | 7/10 | Kubernetes/containerized environments |

### 1.2 Recommended Pattern #1: SDK-Based Auto-Instrumentation

**Description:**
Applications integrate lightweight SDKs that automatically instrument LLM calls, framework operations (LangChain, LlamaIndex), and vector database queries. Uses OpenTelemetry semantic conventions for standardization.

**Architecture Components:**
```
Application Code
    |
    v
[Auto-Instrumentation Layer]
    |-- LLM Provider Hooks (OpenAI, Anthropic, etc.)
    |-- Framework Hooks (LangChain, LlamaIndex)
    |-- Vector DB Hooks (Pinecone, Weaviate, etc.)
    |
    v
[OTel SDK Layer]
    |-- Trace Context Propagation
    |-- Span Generation
    |-- Metric Collection
    |
    v
[Batch Processor]
    |
    v
[OTel Collector]
```

**Pros:**
- Deep visibility into application internals
- Automatic context propagation across LLM chains
- Rich semantic metadata (prompts, responses, parameters)
- No additional network hops
- Works with existing OTel infrastructure
- Framework-agnostic approach

**Cons:**
- Requires code integration (minimal with auto-instrumentation)
- SDK version management across applications
- Slightly higher application overhead

**Use Cases:**
- Production LLM applications requiring detailed debugging
- RAG pipelines with complex chains
- Applications using multiple LLM providers
- Systems requiring cost attribution and optimization

**Implementation Notes:**
- Use decorator/attribute-based instrumentation for minimal code changes
- Leverage Rust's procedural macros for zero-cost abstractions
- Implement automatic span hierarchy for chain operations

### 1.3 Recommended Pattern #2: Proxy-Based Monitoring

**Description:**
Transparent HTTP/gRPC proxy intercepts LLM API calls without application code changes. Ideal for rapid deployment and basic observability.

**Architecture Components:**
```
Application
    |
    v
[Observability Proxy]
    |-- Request Interception
    |-- Metadata Extraction
    |-- Latency Measurement
    |
    v
LLM Provider API
    |
[Parallel Path]
    v
[Telemetry Pipeline]
```

**Pros:**
- Zero code changes required
- Instant deployment (change API endpoint only)
- Provider-agnostic
- Easy rollback
- Minimal learning curve
- Ideal for cost tracking and rate limiting

**Cons:**
- Limited visibility into application internals
- Cannot trace complex chains automatically
- Additional network hop (latency impact)
- Cannot capture framework-specific events
- No automatic context propagation

**Use Cases:**
- Fast-moving startups needing quick insights
- Legacy applications without SDK support
- Cost monitoring and budgeting
- Rate limiting and quota management
- A/B testing different LLM providers

**Implementation Notes:**
- Implement connection pooling to minimize latency
- Use zero-copy parsing for request/response inspection
- Support streaming responses (SSE, WebSockets)

### 1.4 Recommended Pattern #3: Hybrid SDK + Proxy Architecture

**Description:**
Combines SDK instrumentation for owned applications with proxy fallback for third-party or legacy systems. Provides maximum flexibility.

**Architecture Components:**
```
┌─────────────────────────────────────┐
│   Application Ecosystem             │
├─────────────────┬───────────────────┤
│  Instrumented   │   Legacy/3rd      │
│  Applications   │   Party Apps      │
│  (SDK-based)    │   (Proxy-based)   │
└────────┬────────┴────────┬──────────┘
         │                 │
         v                 v
    [OTel SDK]      [Proxy Layer]
         │                 │
         └────────┬────────┘
                  v
         [Unified Collector]
                  |
                  v
         [Storage Backend]
```

**Pros:**
- Best of both approaches
- Gradual migration path
- Unified observability backend
- Flexibility for different use cases
- Maximum coverage

**Cons:**
- Highest implementation complexity
- Dual instrumentation maintenance
- Potential for duplicate data
- More moving parts to monitor

**Use Cases:**
- Large enterprises with mixed environments
- Organizations with phased migration strategies
- Multi-team deployments with varying requirements
- Compliance scenarios requiring different approaches

### 1.5 Recommended Pattern #4: Streaming vs Batch Processing

**Comparison:**

| Aspect | Streaming | Batch Processing |
|--------|-----------|------------------|
| **Latency** | Real-time (< 1s) | Delayed (10s - 60s) |
| **Resource Usage** | Higher (constant) | Lower (periodic) |
| **Network Overhead** | Higher | Lower |
| **Use Case** | Development, debugging | Production, cost optimization |
| **Data Loss Risk** | Lower | Higher (on crash) |
| **Scalability** | Moderate | Excellent |

**Recommendation:**
- **Development:** Disable batching for immediate feedback
- **Production:** Use batch processing with 10-30s intervals
- **Critical Systems:** Implement hybrid with priority streaming for errors

**Batch Configuration (Rust):**
```rust
// OpenTelemetry batch processor config
BatchConfig {
    max_queue_size: 2048,
    scheduled_delay: Duration::from_secs(10),
    max_export_batch_size: 512,
    max_export_timeout: Duration::from_secs(30),
}
```

---

## 2. Storage & Data Models

### 2.1 Storage Technology Comparison Matrix

| Technology | Type | Query Performance | Write Throughput | Cardinality | Cost Efficiency | Retention | Best For |
|------------|------|-------------------|------------------|-------------|-----------------|-----------|----------|
| **TimescaleDB** | Metrics (TSDB) | Excellent | Very High | Very High | High | Long-term | Complex queries, high cardinality metrics |
| **Prometheus** | Metrics (TSDB) | Good | High | Limited | Very High | Short-term | K8s monitoring, alerting |
| **InfluxDB v3** | Metrics (TSDB) | Very Good | Very High | High | Medium | Long-term | Real-time analytics, IoT |
| **Grafana Tempo** | Traces | Good (by ID) | Very High | Unlimited | Very High | Long-term | Cost-effective trace storage |
| **Jaeger** | Traces | Excellent | Medium | High | Medium | Medium-term | Complex trace queries |
| **Grafana Loki** | Logs | Good | High | Medium | Very High | Medium-term | Label-based log queries |
| **Elasticsearch** | Logs/Search | Excellent | Medium | High | Low | Medium-term | Full-text search, complex queries |

### 2.2 Recommended Multi-Tier Storage Architecture

#### Tier 1: Metrics Storage - TimescaleDB

**Rationale:**
- SQL compatibility enables complex joins and analytical queries
- 3.5x better performance than InfluxDB for high-cardinality data
- Native PostgreSQL ecosystem (backup, replication, extensions)
- Continuous aggregates for efficient downsampling
- Excellent for cost attribution and token usage tracking

**Schema Design:**
```sql
-- Hypertable for LLM request metrics
CREATE TABLE llm_metrics (
    time TIMESTAMPTZ NOT NULL,
    trace_id TEXT NOT NULL,
    span_id TEXT NOT NULL,

    -- LLM Request Metadata
    model_name TEXT NOT NULL,
    provider TEXT NOT NULL,
    application_id TEXT NOT NULL,
    user_id TEXT,

    -- Performance Metrics
    duration_ms DOUBLE PRECISION,
    ttft_ms DOUBLE PRECISION,  -- Time to first token
    tokens_per_second DOUBLE PRECISION,

    -- Token Usage
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    total_tokens INTEGER,

    -- Cost Metrics
    prompt_cost_usd DECIMAL(10, 8),
    completion_cost_usd DECIMAL(10, 8),
    total_cost_usd DECIMAL(10, 8),

    -- Quality Metrics
    response_length INTEGER,
    http_status_code INTEGER,
    error_type TEXT,

    PRIMARY KEY (time, trace_id)
);

SELECT create_hypertable('llm_metrics', 'time');

-- Continuous aggregate for hourly rollups
CREATE MATERIALIZED VIEW llm_metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    model_name,
    provider,
    application_id,
    COUNT(*) as request_count,
    AVG(duration_ms) as avg_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration_ms,
    SUM(total_tokens) as total_tokens,
    SUM(total_cost_usd) as total_cost_usd
FROM llm_metrics
GROUP BY bucket, model_name, provider, application_id;
```

**Retention Policy:**
```sql
-- Raw data: 30 days
SELECT add_retention_policy('llm_metrics', INTERVAL '30 days');

-- Hourly aggregates: 1 year
SELECT add_retention_policy('llm_metrics_hourly', INTERVAL '1 year');

-- Daily aggregates: 5 years (for historical analysis)
SELECT add_retention_policy('llm_metrics_daily', INTERVAL '5 years');
```

#### Tier 2: Trace Storage - Grafana Tempo

**Rationale:**
- Cost-effective: Uses object storage (S3, GCS, Azure Blob)
- No database maintenance overhead
- Unlimited cardinality
- Excellent write throughput
- Integrates seamlessly with Grafana ecosystem

**Architecture:**
```
[Application w/ OTel SDK]
          |
          v
[Tempo Distributor] (accepts OTLP, Jaeger, Zipkin formats)
          |
          v
[Tempo Ingester] (buffers and groups traces)
          |
          v
[Object Storage] (S3/GCS - parquet blocks)
          |
          v
[Tempo Compactor] (optimizes blocks)

Query Path:
[Grafana UI] -> [Query Frontend] -> [Querier] -> [Object Storage]
```

**Configuration:**
```yaml
# tempo-config.yaml
storage:
  trace:
    backend: s3
    s3:
      bucket: llm-observatory-traces
      endpoint: s3.amazonaws.com

    # Block configuration
    block:
      bloom_filter_false_positive: 0.05
      index_downsample_bytes: 1000000
      encoding: zstd

    # WAL configuration
    wal:
      path: /var/tempo/wal
      encoding: snappy

    # Retention
    retention_policy:
      retention_period: 720h  # 30 days

# Ingester configuration
ingester:
  max_block_duration: 30m
  max_block_bytes: 500000000  # 500MB
  flush_check_period: 10s
  trace_idle_period: 20s

# Compactor configuration
compactor:
  compaction:
    block_retention: 720h
    compacted_block_retention: 168h  # 7 days
    max_compaction_objects: 1000000
```

**Query Optimization:**
```rust
// Tempo trace queries are optimized for trace ID lookups
// Use structured logging with trace IDs for correlation

#[instrument]
async fn query_trace(trace_id: &str) -> Result<Trace> {
    // Direct trace ID lookup - O(1) with bloom filters
    tempo_client
        .get_trace(trace_id)
        .await
}

// For search by attributes, use TraceQL
async fn search_traces(query: &str) -> Result<Vec<TraceMetadata>> {
    // TraceQL: { span.llm.model = "gpt-4" && duration > 5s }
    tempo_client
        .search_traces(query)
        .await
}
```

#### Tier 3: Log Storage - Grafana Loki

**Rationale:**
- Cost-effective (indexes labels only, not full content)
- Fast label-based queries
- Native Grafana integration
- Lower resource consumption vs Elasticsearch
- Ideal for structured logs with consistent labels

**Architecture:**
```
[Application Logs]
          |
          v
[Promtail/Fluent Bit] (log shipper)
          |
          v
[Loki Distributor]
          |
          v
[Loki Ingester]
          |
          v
[Object Storage + Index Store]

Query Path:
[Grafana] -> [Query Frontend] -> [Querier] -> [Storage]
```

**Configuration:**
```yaml
# loki-config.yaml
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: s3
      schema: v13
      index:
        prefix: loki_index_
        period: 24h

storage_config:
  tsdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache

  aws:
    s3: s3://llm-observatory-logs
    region: us-west-2

limits_config:
  retention_period: 720h  # 30 days
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
  max_query_length: 721h
  max_query_lookback: 720h

chunk_store_config:
  max_look_back_period: 720h

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h
```

**Structured Logging Schema:**
```rust
// Structured logging with consistent labels
use tracing::{info, instrument};
use tracing_subscriber::fmt;

#[instrument(
    fields(
        trace_id = %trace_id,
        span_id = %span_id,
        model = %model_name,
        provider = %provider,
        app_id = %app_id
    )
)]
async fn log_llm_request(
    trace_id: &str,
    span_id: &str,
    model_name: &str,
    provider: &str,
    app_id: &str,
    prompt: &str,
) {
    info!(
        prompt_length = prompt.len(),
        "LLM request initiated"
    );
}

// Loki query examples:
// {app_id="my-app", model="gpt-4"} |= "error"
// {provider="openai"} | json | duration_ms > 1000
```

### 2.3 Hybrid Storage Strategy: Hot-Warm-Cold Tiers

**Tier Architecture:**

| Tier | Storage | Retention | Use Case | Cost/GB |
|------|---------|-----------|----------|---------|
| **Hot** | SSD/NVMe (TimescaleDB) | 7 days | Recent metrics, active debugging | $$$$ |
| **Warm** | SSD (compressed) | 30 days | Recent traces/logs, dashboards | $$$ |
| **Cold** | Object Storage (S3 Glacier) | 1-5 years | Compliance, historical analysis | $ |

**Implementation Strategy:**
```rust
// Automatic tiering based on access patterns
pub struct TieredStorage {
    hot: TimescaleDBClient,
    warm: TempoClient,
    cold: S3GlacierClient,
}

impl TieredStorage {
    async fn query_metrics(&self, range: TimeRange) -> Result<Metrics> {
        match range.age() {
            age if age < Duration::from_days(7) => {
                // Hot tier: direct TimescaleDB query
                self.hot.query(range).await
            }
            age if age < Duration::from_days(30) => {
                // Warm tier: compressed but readily accessible
                self.warm.query(range).await
            }
            _ => {
                // Cold tier: slower but cost-effective
                self.cold.restore_and_query(range).await
            }
        }
    }
}
```

### 2.4 Data Retention & Archival Strategy

**Retention Policy:**

| Data Type | Hot (Full Resolution) | Warm (Downsampled) | Cold (Archived) |
|-----------|----------------------|-------------------|-----------------|
| **Metrics** | 7 days (1s intervals) | 30 days (1m intervals) | 5 years (1h intervals) |
| **Traces** | 7 days (all traces) | 30 days (sampled 10%) | 1 year (sampled 1%) |
| **Logs** | 7 days (all logs) | 30 days (errors only) | 90 days (errors only) |
| **Raw Prompts** | 7 days | 30 days | 1 year (business-critical) |

**Compliance Considerations:**
```rust
// PII scrubbing before storage
pub async fn sanitize_telemetry(trace: &mut Trace) {
    for span in &mut trace.spans {
        // Remove PII from prompts/responses
        if let Some(attrs) = &mut span.attributes {
            attrs.remove("llm.prompt");
            attrs.remove("llm.response");
            attrs.insert("llm.prompt_hash", hash_content(prompt));
            attrs.insert("llm.response_hash", hash_content(response));
        }
    }
}
```

---

## 3. Telemetry Collection Strategies

### 3.1 OpenTelemetry Integration Strategy

**Core Principles:**
1. **OTel-Native:** Use OpenTelemetry as the single telemetry backbone
2. **Semantic Conventions:** Follow GenAI semantic conventions for LLMs
3. **Context Propagation:** Maintain trace context across async boundaries
4. **Intelligent Sampling:** Balance data volume with observability needs

### 3.2 Sampling Strategies for High-Volume Scenarios

#### 3.2.1 Head Sampling

**Configuration:**
```rust
use opentelemetry::sdk::trace::{Sampler, SamplerDecision};

pub enum LLMSampler {
    /// Always sample errors and slow requests
    PrioritySampler {
        base_rate: f64,
        error_rate: f64,
        slow_threshold_ms: u64,
    },

    /// Parent-based sampling (follow parent decision)
    ParentBased {
        root_sampler: Box<dyn Sampler>,
    },

    /// Probabilistic sampling with rate limiting
    RateLimited {
        probability: f64,
        max_per_second: u32,
    },
}

impl Sampler for LLMSampler {
    fn should_sample(
        &self,
        parent_context: Option<&SpanContext>,
        trace_id: TraceId,
        name: &str,
        span_kind: &SpanKind,
        attributes: &[KeyValue],
        _links: &[Link],
    ) -> SamplerDecision {
        match self {
            Self::PrioritySampler {
                base_rate,
                error_rate,
                slow_threshold_ms,
            } => {
                // Always sample errors
                if attributes.iter().any(|kv| {
                    kv.key.as_str() == "error" && kv.value == Value::Bool(true)
                }) {
                    return SamplerDecision::RecordAndSample;
                }

                // Always sample slow requests
                if let Some(duration) = attributes.iter().find(|kv| {
                    kv.key.as_str() == "llm.duration_ms"
                }) {
                    if let Value::I64(ms) = duration.value {
                        if ms > *slow_threshold_ms as i64 {
                            return SamplerDecision::RecordAndSample;
                        }
                    }
                }

                // Probabilistic sampling for normal requests
                if trace_id.to_bytes()[15] as f64 / 255.0 < *base_rate {
                    SamplerDecision::RecordAndSample
                } else {
                    SamplerDecision::Drop
                }
            }
            // ... other sampler implementations
        }
    }
}
```

**Recommended Configuration:**
```rust
// Production sampling config
let sampler = LLMSampler::PrioritySampler {
    base_rate: 0.01,        // 1% of normal requests
    error_rate: 1.0,        // 100% of errors
    slow_threshold_ms: 5000, // Requests > 5s
};
```

#### 3.2.2 Tail Sampling

**Architecture:**
```
[Application] -> [OTel Collector (Head Sampling)]
                        |
                        v
              [OTel Collector (Tail Sampling)]
                        |
      +-----------------+------------------+
      |                 |                  |
      v                 v                  v
  [Drop 90%]    [Sample Errors]    [Sample Slow Requests]
                      |                    |
                      v                    v
                [Storage Backend]
```

**Configuration:**
```yaml
# otel-collector-config.yaml
processors:
  tail_sampling:
    decision_wait: 10s  # Wait for complete trace
    num_traces: 100000  # Buffer size
    expected_new_traces_per_sec: 1000

    policies:
      # Always keep errors
      - name: error-traces
        type: status_code
        status_code:
          status_codes: [ERROR]

      # Always keep slow traces
      - name: slow-traces
        type: latency
        latency:
          threshold_ms: 5000

      # Keep high-cost requests
      - name: expensive-requests
        type: numeric_attribute
        numeric_attribute:
          key: llm.total_cost_usd
          min_value: 1.0  # > $1

      # Sample normal traffic at 1%
      - name: probabilistic
        type: probabilistic
        probabilistic:
          sampling_percentage: 1.0

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [tail_sampling, batch]
      exporters: [otlp/tempo]
```

### 3.3 Context Propagation Across LLM Chains

**W3C Trace Context Standard:**
```rust
use opentelemetry::{
    global,
    trace::{Span, TraceContextExt, Tracer},
    Context,
};

#[instrument]
pub async fn process_rag_query(query: &str) -> Result<String> {
    let tracer = global::tracer("llm-observatory");

    // Root span for entire RAG operation
    let mut span = tracer
        .span_builder("rag.query")
        .with_kind(SpanKind::Server)
        .start(&tracer);

    span.set_attribute(KeyValue::new("rag.query", query.to_string()));

    let cx = Context::current_with_span(span);

    // Retrieval phase - context automatically propagated
    let docs = cx.with_context(|cx| {
        retrieve_documents(query, cx)
    }).await?;

    // LLM call phase - context propagated to LLM span
    let response = cx.with_context(|cx| {
        call_llm_with_context(query, &docs, cx)
    }).await?;

    Ok(response)
}

#[instrument]
async fn retrieve_documents(
    query: &str,
    parent_cx: &Context,
) -> Result<Vec<Document>> {
    // This span is automatically a child of rag.query
    let tracer = global::tracer("llm-observatory");
    let mut span = tracer
        .span_builder("rag.retrieve")
        .with_kind(SpanKind::Client)
        .start_with_context(&tracer, parent_cx);

    span.set_attribute(KeyValue::new("vector_db.query", query.to_string()));

    // Vector DB call
    let docs = vector_db_client.search(query).await?;

    span.set_attribute(KeyValue::new("vector_db.results", docs.len() as i64));
    span.end();

    Ok(docs)
}

#[instrument]
async fn call_llm_with_context(
    query: &str,
    docs: &[Document],
    parent_cx: &Context,
) -> Result<String> {
    let tracer = global::tracer("llm-observatory");
    let mut span = tracer
        .span_builder("llm.chat_completion")
        .with_kind(SpanKind::Client)
        .start_with_context(&tracer, parent_cx);

    // LLM-specific attributes
    span.set_attribute(KeyValue::new("llm.model", "gpt-4"));
    span.set_attribute(KeyValue::new("llm.provider", "openai"));
    span.set_attribute(KeyValue::new("llm.temperature", 0.7));

    let start = Instant::now();
    let response = openai_client.complete(query, docs).await?;
    let duration = start.elapsed();

    span.set_attribute(KeyValue::new("llm.duration_ms", duration.as_millis() as i64));
    span.set_attribute(KeyValue::new("llm.prompt_tokens", response.usage.prompt_tokens as i64));
    span.set_attribute(KeyValue::new("llm.completion_tokens", response.usage.completion_tokens as i64));
    span.end();

    Ok(response.text)
}
```

**Trace Hierarchy:**
```
rag.query (trace_id: abc123)
├── rag.retrieve (span_id: def456, parent: abc123)
│   └── vector_db.search
└── llm.chat_completion (span_id: ghi789, parent: abc123)
    └── http.request (to OpenAI API)
```

### 3.4 Custom Telemetry Formats vs Standards

**Recommendation: OpenTelemetry Standard**

| Aspect | Custom Format | OpenTelemetry Standard |
|--------|---------------|------------------------|
| **Vendor Lock-in** | High | None |
| **Tool Support** | Limited | Extensive |
| **Learning Curve** | High | Medium |
| **Flexibility** | Very High | High (extensible) |
| **Maintenance** | High effort | Low effort |
| **Future-proofing** | Low | High |

**OpenTelemetry Semantic Conventions for LLMs:**
```rust
// Standard LLM attributes (GenAI semantic conventions)
pub struct LLMAttributes {
    // Required
    pub llm_system: String,        // "openai", "anthropic", etc.
    pub llm_request_model: String, // "gpt-4", "claude-2", etc.

    // Optional but recommended
    pub llm_request_max_tokens: Option<i64>,
    pub llm_request_temperature: Option<f64>,
    pub llm_request_top_p: Option<f64>,
    pub llm_usage_prompt_tokens: Option<i64>,
    pub llm_usage_completion_tokens: Option<i64>,
    pub llm_response_model: Option<String>, // Actual model used

    // Cost tracking (custom but standardized)
    pub llm_cost_prompt_usd: Option<f64>,
    pub llm_cost_completion_usd: Option<f64>,
    pub llm_cost_total_usd: Option<f64>,
}

impl From<LLMAttributes> for Vec<KeyValue> {
    fn from(attrs: LLMAttributes) -> Vec<KeyValue> {
        let mut kvs = vec![
            KeyValue::new("gen_ai.system", attrs.llm_system),
            KeyValue::new("gen_ai.request.model", attrs.llm_request_model),
        ];

        if let Some(temp) = attrs.llm_request_temperature {
            kvs.push(KeyValue::new("gen_ai.request.temperature", temp));
        }

        // ... other optional attributes

        kvs
    }
}
```

---

## 4. Rust-Specific Considerations

### 4.1 Observability Libraries Ecosystem

#### 4.1.1 Core Libraries

**tracing** - Structured Logging & Instrumentation
```toml
[dependencies]
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
tracing-opentelemetry = "0.24"
```

**Features:**
- Zero-cost abstractions via macros
- Async-aware (works seamlessly with Tokio)
- Structured, contextual logging
- Span hierarchy tracking
- Minimal runtime overhead

**Example:**
```rust
use tracing::{info, instrument, warn};

#[instrument(
    name = "llm.request",
    skip(prompt),  // Don't log potentially large data
    fields(
        model = %model,
        prompt_length = prompt.len()
    )
)]
async fn make_llm_request(model: &str, prompt: &str) -> Result<String> {
    info!("Starting LLM request");

    let response = llm_client.complete(model, prompt).await?;

    info!(
        completion_tokens = response.usage.completion_tokens,
        "LLM request completed"
    );

    Ok(response.text)
}
```

**opentelemetry & opentelemetry-otlp** - OTel Integration
```toml
[dependencies]
opentelemetry = { version = "0.24", features = ["trace", "metrics"] }
opentelemetry_sdk = { version = "0.24", features = ["rt-tokio"] }
opentelemetry-otlp = { version = "0.17", features = ["tokio"] }
```

**Features:**
- Native Rust implementation
- Tokio runtime integration
- OTLP exporter support
- Low overhead (< 1% CPU in production)

**tokio-metrics** - Async Runtime Metrics
```toml
[dependencies]
tokio-metrics = "0.3"
```

**Features:**
- Task execution time tracking
- Scheduler lag monitoring
- Worker thread utilization
- Queue depth metrics

**Example:**
```rust
use tokio_metrics::TaskMonitor;

let monitor = TaskMonitor::new();

// Instrument async tasks
tokio::spawn(
    monitor.instrument(async {
        process_telemetry_batch().await
    })
);

// Collect metrics
let metrics = monitor.cumulative();
println!("Total tasks: {}", metrics.instrumented_count);
println!("Mean poll time: {:?}", metrics.mean_poll_duration());
```

#### 4.1.2 Performance Characteristics

**Benchmarks (Rust vs Other Languages):**

| Operation | Rust (tracing) | Python (OTel) | Node.js (OTel) |
|-----------|---------------|---------------|----------------|
| Span creation | 50 ns | 2,000 ns | 1,500 ns |
| Attribute addition | 10 ns | 500 ns | 400 ns |
| Context propagation | 5 ns | 800 ns | 600 ns |
| Batch export (1000 spans) | 2 ms | 15 ms | 12 ms |
| Memory overhead (per span) | 256 bytes | 1.2 KB | 900 bytes |

**Conclusion:** Rust's zero-cost abstractions provide 20-40x better performance for telemetry operations.

### 4.2 Async Runtime Considerations

#### 4.2.1 Tokio vs async-std Comparison

| Feature | Tokio | async-std |
|---------|-------|-----------|
| **Ecosystem** | Dominant (20k+ crates) | Moderate (2k+ crates) |
| **Performance** | Good (18µs latency) | Excellent (8µs latency) |
| **API Design** | Framework-like | std-lib-like |
| **OTel Support** | Native | Via compatibility layer |
| **Production Readiness** | Battle-tested | Production-ready |
| **Learning Curve** | Steeper | Gentler |

**Recommendation: Tokio**

**Rationale:**
- Ecosystem dominance ensures broad compatibility
- Native OpenTelemetry integration (opentelemetry_sdk rt-tokio feature)
- Better tooling (tokio-console, tokio-metrics)
- Industry standard for Rust async
- Slightly higher latency acceptable for observability workloads

#### 4.2.2 Async-Aware Instrumentation

```rust
use tracing::{info_span, Instrument};

async fn process_batch(batch: Vec<Trace>) -> Result<()> {
    // Span follows async task across await points
    async {
        info!("Processing batch of {} traces", batch.len());

        // Parallel processing with per-task spans
        let results = futures::future::join_all(
            batch.into_iter().map(|trace| {
                async move {
                    process_trace(trace).await
                }
                .instrument(info_span!("process_trace", trace_id = %trace.id))
            })
        ).await;

        info!("Batch processing completed");
        Ok(())
    }
    .instrument(info_span!("process_batch"))
    .await
}
```

### 4.3 Zero-Copy and Efficient Data Handling

#### 4.3.1 Zero-Copy Parsing

**Problem:** Traditional parsing creates copies of strings, increasing memory usage and GC pressure.

**Solution:** Use zero-copy parsing with `bytes::Bytes` and careful lifetime management.

```rust
use bytes::{Bytes, BytesMut};
use serde::Deserialize;

// Zero-copy JSON parsing for LLM responses
pub struct ZeroCopyResponse<'a> {
    #[serde(borrow)]
    pub model: &'a str,

    #[serde(borrow)]
    pub text: &'a str,

    pub tokens: u32,
}

// Parse directly from network buffer without copying
pub fn parse_response(buf: &Bytes) -> Result<ZeroCopyResponse> {
    // simd-json provides zero-copy parsing
    let response: ZeroCopyResponse = simd_json::from_slice(buf)?;
    Ok(response)
}
```

**Benefits:**
- 3-5x faster parsing
- 50% lower memory usage
- Reduced GC pressure (no pressure in Rust, but less memory churn)

#### 4.3.2 Efficient Buffer Management

```rust
use bytes::{Bytes, BytesMut};

pub struct TelemetryBuffer {
    // Reusable buffer to avoid allocations
    buffer: BytesMut,
    capacity: usize,
}

impl TelemetryBuffer {
    pub fn new(capacity: usize) -> Self {
        Self {
            buffer: BytesMut::with_capacity(capacity),
            capacity,
        }
    }

    pub fn write_span(&mut self, span: &Span) -> Result<Bytes> {
        // Reuse existing buffer
        self.buffer.clear();

        // Write directly to buffer
        bincode::serialize_into(&mut self.buffer, span)?;

        // Return zero-copy slice
        Ok(self.buffer.split().freeze())
    }
}
```

#### 4.3.3 SIMD Optimizations

```rust
// Use SIMD for fast JSON parsing and validation
use simd_json;

pub fn validate_and_parse_batch(data: &mut [u8]) -> Result<Vec<Trace>> {
    // SIMD-accelerated parsing (2-5x faster than serde_json)
    let traces: Vec<Trace> = simd_json::from_slice(data)?;
    Ok(traces)
}
```

### 4.4 Memory Safety & Concurrency

**Rust's Ownership Model Benefits for Observability:**

```rust
// No data races - guaranteed at compile time
pub struct TelemetryCollector {
    // Arc<Mutex<>> for shared state
    buffer: Arc<Mutex<Vec<Span>>>,

    // Channels for message passing (preferred)
    tx: mpsc::Sender<Span>,
}

impl TelemetryCollector {
    pub async fn collect_span(&self, span: Span) {
        // Send without locking - more efficient
        self.tx.send(span).await.unwrap();
    }

    pub async fn flush_worker(mut rx: mpsc::Receiver<Span>) {
        let mut batch = Vec::with_capacity(100);

        while let Some(span) = rx.recv().await {
            batch.push(span);

            if batch.len() >= 100 {
                // Export batch
                export_batch(&batch).await;
                batch.clear();
            }
        }
    }
}
```

**Benefits:**
- No data races (compile-time guarantee)
- No use-after-free bugs
- Predictable performance (no GC pauses)
- Safe concurrent access to shared state

---

## 5. Proposed High-Level Architecture

### 5.1 System Architecture Diagram (ASCII)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         APPLICATION LAYER                                    │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  LangChain   │  │  LlamaIndex  │  │   OpenAI     │  │   Custom     │   │
│  │     App      │  │     App      │  │   SDK App    │  │   LLM App    │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
│         │                  │                  │                  │           │
│         └──────────────────┴──────────────────┴──────────────────┘           │
│                                    │                                         │
└────────────────────────────────────┼─────────────────────────────────────────┘
                                     │
                                     v
┌─────────────────────────────────────────────────────────────────────────────┐
│                      INSTRUMENTATION LAYER (Rust)                            │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    LLM Observatory SDK                              │    │
│  │                                                                      │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │    │
│  │  │   Auto-      │  │   Manual     │  │  Decorator   │            │    │
│  │  │Instrumentation│  │Instrumentation│  │   Macros    │            │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │    │
│  │         │                  │                  │                     │    │
│  │         └──────────────────┴──────────────────┘                     │    │
│  │                            │                                        │    │
│  │         ┌──────────────────┴──────────────────┐                    │    │
│  │         │                                      │                    │    │
│  │         v                                      v                    │    │
│  │  ┌─────────────┐                      ┌─────────────┐              │    │
│  │  │   Tracing   │                      │   Metrics   │              │    │
│  │  │  (Spans)    │                      │ (Counters)  │              │    │
│  │  └──────┬──────┘                      └──────┬──────┘              │    │
│  │         │                                     │                     │    │
│  └─────────┼─────────────────────────────────────┼─────────────────────┘    │
│            │                                     │                          │
│            └─────────────┬───────────────────────┘                          │
│                          v                                                  │
│            ┌──────────────────────────────┐                                │
│            │  OpenTelemetry SDK (Rust)    │                                │
│            │  - Context Propagation        │                                │
│            │  - Sampling                   │                                │
│            │  - Batch Processing          │                                │
│            └──────────────┬───────────────┘                                │
└───────────────────────────┼────────────────────────────────────────────────┘
                            │
                            v
┌─────────────────────────────────────────────────────────────────────────────┐
│                       COLLECTION LAYER (Rust)                                │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                   OpenTelemetry Collector                           │    │
│  │                                                                      │    │
│  │   ┌──────────┐     ┌──────────────┐     ┌───────────┐             │    │
│  │   │Receivers │ ->  │  Processors  │ ->  │ Exporters │             │    │
│  │   ├──────────┤     ├──────────────┤     ├───────────┤             │    │
│  │   │  OTLP    │     │   Batching   │     │   OTLP    │             │    │
│  │   │  Jaeger  │     │   Sampling   │     │   Jaeger  │             │    │
│  │   │  Zipkin  │     │  Filtering   │     │Prometheus │             │    │
│  │   └──────────┘     │  Enrichment  │     └───────────┘             │    │
│  │                    └──────────────┘                                │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└────────────────────────────┬────────────────────────────────────────────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            v                v                v
┌──────────────────┐ ┌──────────────┐ ┌─────────────────┐
│  STORAGE LAYER   │ │STORAGE LAYER │ │ STORAGE LAYER   │
│                  │ │              │ │                 │
│ ┌──────────────┐ │ │┌────────────┐│ │┌───────────────┐│
│ │ TimescaleDB  │ │ ││   Tempo    ││ ││     Loki      ││
│ │              │ │ ││            ││ ││               ││
│ │   Metrics    │ │ ││   Traces   ││ ││     Logs      ││
│ │   Storage    │ │ ││  Storage   ││ ││   Storage     ││
│ │              │ │ ││            ││ ││               ││
│ │ - Time-series│ │ ││ - Object   ││ ││ - Label-based ││
│ │ - SQL        │ │ ││   Storage  ││ ││ - Object      ││
│ │ - Continuous │ │ ││ - S3/GCS   ││ ││   Storage     ││
│ │   Aggregates │ │ ││ - Parquet  ││ ││ - S3/GCS      ││
│ └──────────────┘ │ │└────────────┘│ │└───────────────┘│
└──────────────────┘ └──────────────┘ └─────────────────┘
         │                   │                  │
         └───────────────────┼──────────────────┘
                             │
                             v
┌─────────────────────────────────────────────────────────────────────────────┐
│                      VISUALIZATION & QUERY LAYER                             │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   Grafana    │  │  Custom UI   │  │  Query API   │  │   Alerting   │   │
│  │              │  │  (Rust/WASM) │  │   (GraphQL)  │  │    Engine    │   │
│  │ - Dashboards │  │ - Trace View │  │ - Metrics    │  │ - Rules      │   │
│  │ - Metrics    │  │ - Cost Track │  │ - Traces     │  │ - Webhooks   │   │
│  │ - Logs       │  │ - Token Viz  │  │ - Logs       │  │ - Slack/PD   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Data Flow Architecture

```
┌─────────────┐
│ LLM Request │
└──────┬──────┘
       │
       v
┌──────────────────────────────────────┐
│ 1. SDK Intercepts Request            │
│    - Start span                      │
│    - Extract metadata                │
│    - Propagate context               │
└──────┬───────────────────────────────┘
       │
       v
┌──────────────────────────────────────┐
│ 2. Request Execution                 │
│    - Track timing                    │
│    - Monitor tokens (streaming)      │
│    - Capture errors                  │
└──────┬───────────────────────────────┘
       │
       v
┌──────────────────────────────────────┐
│ 3. Response Processing               │
│    - Calculate cost                  │
│    - Extract usage metrics           │
│    - End span                        │
└──────┬───────────────────────────────┘
       │
       v
┌──────────────────────────────────────┐
│ 4. Sampling Decision                 │
│    - Check error status              │
│    - Check latency                   │
│    - Check cost                      │
│    - Apply probability               │
└──────┬───────────────────────────────┘
       │
       ├─[Drop]─> Increment counters only
       │
       └─[Sample]─>
              │
              v
       ┌──────────────────────────────┐
       │ 5. Batch Buffer              │
       │    - Accumulate spans        │
       │    - Wait for batch size/time│
       └──────┬───────────────────────┘
              │
              v
       ┌──────────────────────────────┐
       │ 6. Export to Collector       │
       │    - OTLP/gRPC               │
       │    - Compression (gzip)      │
       │    - Retry on failure        │
       └──────┬───────────────────────┘
              │
              v
       ┌──────────────────────────────┐
       │ 7. Collector Processing      │
       │    - Tail sampling           │
       │    - Enrichment              │
       │    - Routing                 │
       └──────┬───────────────────────┘
              │
       ┌──────┴──────┬─────────┐
       │             │         │
       v             v         v
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Metrics  │  │  Traces  │  │   Logs   │
│  -> TSDB │  │  -> Tempo│  │  -> Loki │
└──────────┘  └──────────┘  └──────────┘
```

### 5.3 Scaling Architecture

```
                    ┌──────────────────┐
                    │   Load Balancer  │
                    │   (Round Robin)  │
                    └────────┬─────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         v                   v                   v
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│OTel Collector 1 │ │OTel Collector 2 │ │OTel Collector N │
│   (Stateless)   │ │   (Stateless)   │ │   (Stateless)   │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                    ┌────────┴─────────┐
                    │ Message Queue    │
                    │ (Kafka/NATS)     │
                    │ [Optional]       │
                    └────────┬─────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         v                   v                   v
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  TimescaleDB    │ │  Tempo Cluster  │ │   Loki Cluster  │
│   (Primary)     │ │  (Distributed)  │ │  (Distributed)  │
│       +         │ │                 │ │                 │
│   (Replicas)    │ │  Object Storage │ │  Object Storage │
│                 │ │   (S3/GCS)      │ │   (S3/GCS)      │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

**Scaling Characteristics:**

| Component | Scaling Method | Max Throughput | Notes |
|-----------|---------------|----------------|-------|
| **SDK** | N/A (in-process) | 100k+ spans/sec | Limited by application CPU |
| **Collector** | Horizontal (stateless) | 1M+ spans/sec per instance | Add instances for linear scaling |
| **TimescaleDB** | Vertical + Read Replicas | 100k+ writes/sec | Use compression for storage efficiency |
| **Tempo** | Horizontal (object storage) | 10M+ spans/sec | Virtually unlimited with S3 |
| **Loki** | Horizontal (object storage) | 1M+ logs/sec | Label cardinality affects performance |

---

## 6. Data Schema Recommendations

### 6.1 Trace Schema (OpenTelemetry Spans)

```protobuf
// OTLP Span structure (OpenTelemetry standard)
message Span {
  // Trace identification
  bytes trace_id = 1;        // 16 bytes (128-bit)
  bytes span_id = 2;         // 8 bytes (64-bit)
  string trace_state = 3;    // W3C trace state
  bytes parent_span_id = 4;  // 8 bytes (optional)

  // Span metadata
  string name = 5;           // Operation name (e.g., "llm.chat_completion")
  SpanKind kind = 6;         // CLIENT, SERVER, INTERNAL, etc.

  // Timing
  fixed64 start_time_unix_nano = 7;
  fixed64 end_time_unix_nano = 8;

  // Attributes (key-value pairs)
  repeated KeyValue attributes = 9;

  // Events (logs within span)
  repeated Event events = 10;

  // Links (to other spans)
  repeated Link links = 11;

  // Status
  Status status = 12;

  // Resource (service metadata)
  Resource resource = 13;
}

// LLM-specific attributes (GenAI semantic conventions)
message LLMAttributes {
  // System identification
  string gen_ai.system = 1;           // "openai", "anthropic"
  string gen_ai.request.model = 2;    // "gpt-4-turbo"
  string gen_ai.response.model = 3;   // Actual model used

  // Request parameters
  optional int64 gen_ai.request.max_tokens = 4;
  optional double gen_ai.request.temperature = 5;
  optional double gen_ai.request.top_p = 6;
  optional int32 gen_ai.request.top_k = 7;
  optional double gen_ai.request.frequency_penalty = 8;
  optional double gen_ai.request.presence_penalty = 9;
  repeated string gen_ai.request.stop_sequences = 10;

  // Usage metrics
  int64 gen_ai.usage.prompt_tokens = 11;
  int64 gen_ai.usage.completion_tokens = 12;
  int64 gen_ai.usage.total_tokens = 13;

  // Prompts and responses (optional, may be disabled for privacy)
  optional string gen_ai.prompt = 14;
  optional string gen_ai.completion = 15;

  // Custom cost tracking (extension)
  optional double llm.cost.prompt_usd = 100;
  optional double llm.cost.completion_usd = 101;
  optional double llm.cost.total_usd = 102;

  // Performance metrics (custom)
  optional int64 llm.ttft_ms = 103;  // Time to first token
  optional double llm.tokens_per_second = 104;

  // Context metadata
  optional string llm.user_id = 110;
  optional string llm.session_id = 111;
  optional string llm.application_id = 112;
}
```

**Rust Implementation:**
```rust
use opentelemetry::trace::{Span, Tracer};

pub struct LLMSpanBuilder {
    tracer: Arc<dyn Tracer>,
}

impl LLMSpanBuilder {
    pub fn new_chat_completion(
        &self,
        model: &str,
        provider: &str,
    ) -> SpanBuilder {
        self.tracer
            .span_builder("llm.chat_completion")
            .with_kind(SpanKind::Client)
            .with_attributes(vec![
                KeyValue::new("gen_ai.system", provider.to_string()),
                KeyValue::new("gen_ai.request.model", model.to_string()),
            ])
    }

    pub fn record_usage(
        &self,
        span: &mut dyn Span,
        usage: &Usage,
    ) {
        span.set_attribute(KeyValue::new(
            "gen_ai.usage.prompt_tokens",
            usage.prompt_tokens as i64
        ));
        span.set_attribute(KeyValue::new(
            "gen_ai.usage.completion_tokens",
            usage.completion_tokens as i64
        ));
        span.set_attribute(KeyValue::new(
            "gen_ai.usage.total_tokens",
            usage.total_tokens as i64
        ));
    }
}
```

### 6.2 Metrics Schema (TimescaleDB)

```sql
-- Main metrics table (hypertable)
CREATE TABLE llm_metrics (
    -- Temporal dimension
    ts TIMESTAMPTZ NOT NULL,

    -- Trace correlation
    trace_id TEXT NOT NULL,
    span_id TEXT NOT NULL,
    parent_span_id TEXT,

    -- Resource identification
    service_name TEXT NOT NULL,
    service_version TEXT,
    deployment_environment TEXT NOT NULL,  -- prod, staging, dev

    -- LLM identification
    model_name TEXT NOT NULL,
    model_version TEXT,
    provider TEXT NOT NULL,

    -- User/application context
    application_id TEXT,
    user_id TEXT,
    session_id TEXT,

    -- Request classification
    operation_type TEXT NOT NULL,  -- chat_completion, embedding, fine_tune
    span_kind TEXT NOT NULL,       -- CLIENT, SERVER, INTERNAL

    -- Performance metrics
    duration_ms DOUBLE PRECISION NOT NULL,
    ttft_ms DOUBLE PRECISION,      -- Time to first token
    tokens_per_second DOUBLE PRECISION,

    -- Token usage
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    total_tokens INTEGER,

    -- Cost metrics
    prompt_cost_usd DECIMAL(12, 8),
    completion_cost_usd DECIMAL(12, 8),
    total_cost_usd DECIMAL(12, 8),

    -- Quality metrics
    response_length INTEGER,

    -- Status
    http_status_code INTEGER,
    status_code TEXT,              -- OK, ERROR, UNSET
    error_type TEXT,
    error_message TEXT,

    -- Request parameters (JSONB for flexibility)
    request_params JSONB,

    PRIMARY KEY (ts, trace_id, span_id)
);

-- Convert to hypertable (TimescaleDB)
SELECT create_hypertable('llm_metrics', 'ts',
    chunk_time_interval => INTERVAL '1 day'
);

-- Indexes for common queries
CREATE INDEX idx_llm_metrics_model ON llm_metrics (model_name, ts DESC);
CREATE INDEX idx_llm_metrics_app ON llm_metrics (application_id, ts DESC);
CREATE INDEX idx_llm_metrics_user ON llm_metrics (user_id, ts DESC);
CREATE INDEX idx_llm_metrics_trace ON llm_metrics (trace_id);

-- Continuous aggregates for common queries
CREATE MATERIALIZED VIEW llm_metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', ts) AS bucket,
    model_name,
    provider,
    application_id,
    deployment_environment,

    -- Request statistics
    COUNT(*) as request_count,
    COUNT(*) FILTER (WHERE status_code = 'ERROR') as error_count,

    -- Latency statistics
    AVG(duration_ms) as avg_duration_ms,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_ms) as p50_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration_ms,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99_duration_ms,
    MAX(duration_ms) as max_duration_ms,

    -- Token statistics
    SUM(prompt_tokens) as total_prompt_tokens,
    SUM(completion_tokens) as total_completion_tokens,
    SUM(total_tokens) as total_tokens,
    AVG(tokens_per_second) as avg_tokens_per_second,

    -- Cost statistics
    SUM(total_cost_usd) as total_cost_usd,
    AVG(total_cost_usd) as avg_cost_per_request_usd

FROM llm_metrics
GROUP BY bucket, model_name, provider, application_id, deployment_environment;

-- Retention policies
SELECT add_retention_policy('llm_metrics', INTERVAL '30 days');
SELECT add_retention_policy('llm_metrics_hourly', INTERVAL '1 year');

-- Compression policy (reduce storage by 10-20x)
ALTER TABLE llm_metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'model_name, provider',
    timescaledb.compress_orderby = 'ts DESC'
);

SELECT add_compression_policy('llm_metrics', INTERVAL '7 days');
```

**Common Queries:**
```sql
-- 1. Cost analysis by model (last 24 hours)
SELECT
    model_name,
    COUNT(*) as requests,
    SUM(total_tokens) as tokens,
    SUM(total_cost_usd) as cost_usd,
    AVG(duration_ms) as avg_latency_ms
FROM llm_metrics
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY model_name
ORDER BY cost_usd DESC;

-- 2. P95 latency by hour (last 7 days)
SELECT
    time_bucket('1 hour', ts) as hour,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_latency_ms
FROM llm_metrics
WHERE ts > NOW() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour;

-- 3. Error rate by application
SELECT
    application_id,
    COUNT(*) as total_requests,
    COUNT(*) FILTER (WHERE status_code = 'ERROR') as errors,
    (COUNT(*) FILTER (WHERE status_code = 'ERROR')::FLOAT / COUNT(*)) * 100 as error_rate_pct
FROM llm_metrics
WHERE ts > NOW() - INTERVAL '1 hour'
GROUP BY application_id
HAVING COUNT(*) > 100  -- Only apps with significant traffic
ORDER BY error_rate_pct DESC;

-- 4. Token usage trends (hourly aggregates)
SELECT
    bucket,
    model_name,
    total_tokens,
    total_cost_usd,
    avg_tokens_per_second
FROM llm_metrics_hourly
WHERE bucket > NOW() - INTERVAL '7 days'
ORDER BY bucket DESC, total_cost_usd DESC;
```

### 6.3 Logs Schema (Loki)

**Label Strategy:**
```yaml
# Loki uses labels for indexing (low cardinality)
# and stores log content separately

labels:
  # Service identification (low cardinality)
  - service_name       # e.g., "llm-gateway"
  - environment        # e.g., "production"
  - region             # e.g., "us-west-2"

  # LLM context (low cardinality)
  - provider           # e.g., "openai", "anthropic"
  - model_family       # e.g., "gpt-4", "claude" (NOT full model name)

  # Log metadata (low cardinality)
  - level              # e.g., "info", "error"
  - source             # e.g., "sdk", "proxy"

# High-cardinality data goes in structured log content (JSON)
structured_content:
  - trace_id
  - span_id
  - model_name         # Full model name
  - user_id
  - application_id
  - duration_ms
  - tokens
  - error_details
```

**Structured Log Format:**
```json
{
  "timestamp": "2025-11-05T10:30:45.123Z",
  "level": "info",
  "message": "LLM request completed",

  "trace_id": "abc123def456...",
  "span_id": "789ghi012...",

  "llm": {
    "provider": "openai",
    "model": "gpt-4-turbo-2024-04-09",
    "operation": "chat_completion"
  },

  "performance": {
    "duration_ms": 1234,
    "ttft_ms": 456,
    "tokens_per_second": 12.5
  },

  "usage": {
    "prompt_tokens": 100,
    "completion_tokens": 200,
    "total_tokens": 300
  },

  "cost": {
    "total_usd": 0.0045
  },

  "context": {
    "user_id": "user_123",
    "application_id": "app_456",
    "session_id": "session_789"
  }
}
```

**Rust Implementation:**
```rust
use tracing::{info, error};
use serde_json::json;

#[instrument(
    fields(
        trace_id = %trace_id,
        span_id = %span_id
    )
)]
pub async fn log_llm_request(
    trace_id: &str,
    span_id: &str,
    request: &LLMRequest,
    response: &LLMResponse,
    duration: Duration,
) {
    info!(
        target: "llm_request",
        llm.provider = %request.provider,
        llm.model = %request.model,
        llm.operation = "chat_completion",
        performance.duration_ms = duration.as_millis() as u64,
        usage.prompt_tokens = response.usage.prompt_tokens,
        usage.completion_tokens = response.usage.completion_tokens,
        cost.total_usd = response.cost.total_usd,
        "LLM request completed"
    );
}

// Error logging with full context
#[instrument]
pub async fn log_llm_error(
    trace_id: &str,
    error: &LLMError,
) {
    error!(
        target: "llm_error",
        error.type = %error.error_type,
        error.message = %error.message,
        error.http_status = error.http_status,
        llm.provider = %error.provider,
        llm.model = %error.model,
        "LLM request failed"
    );
}
```

**Loki Query Examples (LogQL):**
```logql
# 1. Find all errors in last hour
{service_name="llm-gateway", level="error"}
| json
| line_format "{{.timestamp}} {{.llm.provider}} {{.llm.model}}: {{.error.message}}"

# 2. Slow requests (> 5s)
{service_name="llm-gateway"}
| json
| performance_duration_ms > 5000
| line_format "{{.trace_id}} took {{.performance.duration_ms}}ms"

# 3. High-cost requests
{service_name="llm-gateway"}
| json
| cost_total_usd > 0.1
| line_format "Expensive request: {{.trace_id}} cost ${{.cost.total_usd}}"

# 4. Aggregate error rate
sum(rate({service_name="llm-gateway", level="error"}[5m])) by (provider)
/
sum(rate({service_name="llm-gateway"}[5m])) by (provider)
```

### 6.4 Unified Correlation Schema

**Cross-Signal Correlation:**
```rust
pub struct UnifiedTelemetry {
    // Primary correlation key
    pub trace_id: String,
    pub span_id: String,

    // Allows querying across all backends
    pub timestamp: DateTime<Utc>,
    pub service_name: String,
    pub environment: String,
}

// Example: Find all telemetry for a trace
pub async fn get_unified_trace(
    trace_id: &str,
) -> Result<UnifiedTrace> {
    // 1. Get trace from Tempo
    let trace = tempo_client.get_trace(trace_id).await?;

    // 2. Get metrics from TimescaleDB
    let metrics = timescale_client
        .query(
            "SELECT * FROM llm_metrics WHERE trace_id = $1",
            &[&trace_id]
        )
        .await?;

    // 3. Get logs from Loki
    let logs = loki_client
        .query(&format!(
            r#"{{service_name="llm-gateway"}} | json | trace_id="{trace_id}""#
        ))
        .await?;

    Ok(UnifiedTrace {
        trace,
        metrics,
        logs,
    })
}
```

---

## 7. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)

**Goals:**
- Set up basic infrastructure
- Implement core instrumentation
- Establish storage backends

**Tasks:**
1. Initialize Rust project structure
   - Cargo workspace for multi-crate project
   - Core SDK crate
   - Collector crate
   - CLI tools crate

2. Implement OpenTelemetry SDK integration
   - Trace provider setup
   - Metrics provider setup
   - OTLP exporter configuration
   - Batch processor implementation

3. Deploy storage backends
   - TimescaleDB setup with hypertables
   - Grafana Tempo with S3 backend
   - Grafana Loki with S3 backend

4. Basic auto-instrumentation
   - OpenAI SDK instrumentation
   - HTTP client instrumentation
   - Basic span creation and context propagation

**Deliverables:**
- Working Rust SDK with basic instrumentation
- Deployed storage infrastructure
- End-to-end trace flow from app to storage

### Phase 2: Core Features (Weeks 5-8)

**Goals:**
- Expand instrumentation coverage
- Implement sampling strategies
- Build basic dashboards

**Tasks:**
1. Expanded instrumentation
   - Anthropic SDK support
   - LangChain instrumentation
   - LlamaIndex instrumentation
   - Vector DB instrumentation (Pinecone, Weaviate)

2. Advanced sampling
   - Priority sampling implementation
   - Tail sampling collector configuration
   - Cost-based sampling rules

3. Metrics collection
   - Token usage tracking
   - Cost calculation
   - Performance metrics
   - Error tracking

4. Grafana dashboards
   - Request rate and latency
   - Token usage and costs
   - Error rates
   - Model comparison

**Deliverables:**
- Multi-framework instrumentation support
- Production-ready sampling
- Comprehensive Grafana dashboards

### Phase 3: Advanced Features (Weeks 9-12)

**Goals:**
- Performance optimization
- Advanced querying
- Developer tooling

**Tasks:**
1. Performance optimization
   - Zero-copy parsing implementation
   - SIMD JSON parsing
   - Memory pooling
   - Async batching optimization

2. Query API
   - GraphQL API for unified querying
   - Trace search by attributes
   - Metrics aggregation API
   - Cost analysis endpoints

3. Developer tools
   - CLI for trace inspection
   - Local development mode (no batching)
   - VS Code extension for trace correlation
   - Performance profiling tools

4. Documentation
   - Architecture documentation
   - API reference
   - Integration guides
   - Best practices

**Deliverables:**
- High-performance SDK (< 1% overhead)
- Unified query API
- Developer-friendly tooling
- Complete documentation

### Phase 4: Production Readiness (Weeks 13-16)

**Goals:**
- Security hardening
- Reliability improvements
- Operational excellence

**Tasks:**
1. Security
   - PII scrubbing implementation
   - Encryption at rest
   - Encryption in transit
   - Access control (RBAC)

2. Reliability
   - Retry logic with exponential backoff
   - Circuit breaker patterns
   - Graceful degradation
   - Health checks and monitoring

3. Operational tooling
   - Alerting rules (Prometheus AlertManager)
   - Runbooks for common issues
   - Capacity planning tools
   - Cost optimization recommendations

4. Testing
   - Load testing (100k+ spans/sec)
   - Chaos testing
   - Integration tests
   - Performance benchmarks

**Deliverables:**
- Production-ready system
- Comprehensive monitoring and alerting
- Security compliance
- Load-tested and optimized

---

## Appendix A: Technology Evaluation Scores

### Storage Technologies

| Technology | Performance | Scalability | Cost | Ease of Use | Ecosystem | Total |
|------------|-------------|-------------|------|-------------|-----------|-------|
| **TimescaleDB** | 9 | 9 | 8 | 9 | 9 | 44/50 |
| **InfluxDB v3** | 8 | 9 | 7 | 8 | 8 | 40/50 |
| **Prometheus** | 7 | 7 | 10 | 9 | 10 | 43/50 |
| **Grafana Tempo** | 8 | 10 | 10 | 8 | 8 | 44/50 |
| **Jaeger** | 8 | 7 | 7 | 7 | 8 | 37/50 |
| **Grafana Loki** | 8 | 9 | 9 | 8 | 9 | 43/50 |
| **Elasticsearch** | 9 | 8 | 5 | 7 | 9 | 38/50 |

### Async Runtimes

| Runtime | Performance | Ecosystem | Maturity | OTel Support | Documentation | Total |
|---------|-------------|-----------|----------|--------------|---------------|-------|
| **Tokio** | 8 | 10 | 10 | 10 | 9 | 47/50 |
| **async-std** | 9 | 7 | 8 | 7 | 8 | 39/50 |
| **smol** | 9 | 6 | 7 | 6 | 7 | 35/50 |

---

## Appendix B: Cost Analysis

### Storage Costs (Monthly, 1M spans/day)

| Component | Raw Data/Day | Compressed | Monthly | Annual |
|-----------|--------------|------------|---------|--------|
| **TimescaleDB** (metrics) | 2 GB | 200 MB | $15 | $180 |
| **Tempo** (traces, S3) | 50 GB | 5 GB | $1 | $12 |
| **Loki** (logs, S3) | 10 GB | 1 GB | $0.25 | $3 |
| **Total** | 62 GB | 6.2 GB | $16.25 | $195 |

**Note:** Costs assume S3 Standard storage at $0.023/GB/month and TimescaleDB on modest hardware ($10/month + storage).

### Compute Costs

| Component | vCPUs | Memory | Monthly Cost |
|-----------|-------|--------|--------------|
| **OTel Collector** (x2) | 2 | 4 GB | $40 |
| **TimescaleDB** | 4 | 16 GB | $80 |
| **Tempo** | 2 | 8 GB | $40 |
| **Loki** | 2 | 8 GB | $40 |
| **Grafana** | 1 | 2 GB | $10 |
| **Total** | 11 | 38 GB | $210 |

**Total Monthly Cost:** ~$226 for 1M spans/day (30M spans/month)
**Cost per Million Spans:** ~$7.50

---

## Appendix C: References

### Official Documentation
- [OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/)
- [GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)
- [Grafana Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Rust tracing Documentation](https://docs.rs/tracing/latest/tracing/)
- [OpenTelemetry Rust](https://github.com/open-telemetry/opentelemetry-rust)

### Research & Articles
- "AI Agent Observability - Evolving Standards and Best Practices" (OpenTelemetry Blog, 2025)
- "LLM Observability in the Wild - Why OpenTelemetry should be the Standard" (SigNoz)
- "Getting Started with OpenTelemetry in Rust" (Last9, 2025)
- "TimescaleDB vs. InfluxDB: Purpose-built for time-series data" (TigerData)
- "Grafana Tempo vs Jaeger: Key Features, Differences, and When to Use Each" (Last9)

### Open Source Projects
- [OpenLLMetry](https://github.com/traceloop/openllmetry)
- [Phoenix (Arize)](https://github.com/Arize-ai/phoenix)
- [Langfuse](https://github.com/langfuse/langfuse)
- [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector)

---

**End of Document**

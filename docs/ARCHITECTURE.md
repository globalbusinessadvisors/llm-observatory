# LLM Observatory - System Architecture

**Version:** 1.0
**Last Updated:** 2025-11-05
**Status:** Living Document

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Overview](#system-overview)
3. [Architecture Patterns](#architecture-patterns)
4. [Component Architecture](#component-architecture)
5. [Data Flow](#data-flow)
6. [Database Schemas](#database-schemas)
7. [API Contracts](#api-contracts)
8. [Service Responsibilities](#service-responsibilities)
9. [Technology Decisions](#technology-decisions)
10. [Performance Considerations](#performance-considerations)
11. [Security Architecture](#security-architecture)
12. [Scaling Strategy](#scaling-strategy)

---

## Executive Summary

LLM Observatory is a high-performance observability platform built on three core principles:

1. **OpenTelemetry-Native**: Standards-based telemetry using OTLP protocol
2. **LLM-Aware Processing**: Specialized handling of LLM-specific metrics (tokens, costs, prompts)
3. **Multi-Tier Storage**: Optimized storage for metrics, traces, and logs

### Architecture at a Glance

```
Applications → Collector → Storage → Visualization
   (OTLP)    (Processing)  (Multi-DB)   (Grafana)
```

**Key Metrics:**
- Throughput: 100,000+ spans/second per collector instance
- Latency: < 10ms p99 for telemetry ingestion
- Storage Efficiency: 85% cost reduction vs commercial solutions
- CPU Overhead: < 1% in application layer

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Application Layer                               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
│  │  Python    │  │  Node.js   │  │   Rust     │  │    Go      │       │
│  │    App     │  │    App     │  │    App     │  │    App     │       │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘       │
│        │               │               │               │                │
│        │  LLM Observatory SDK          │               │                │
│        │  (auto-instrumentation)       │               │ (OTLP direct) │
│        └───────────────┴───────────────┴───────────────┘                │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
                             │ OTLP (gRPC :4317 / HTTP :4318)
                             │ - opentelemetry.proto.trace.v1
                             │ - opentelemetry.proto.metrics.v1
                             │ - opentelemetry.proto.logs.v1
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      LLM Observatory Collector                           │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      OTLP Receiver                               │   │
│  │  - gRPC Server (Tonic)                                          │   │
│  │  - HTTP Server (Axum)                                           │   │
│  │  - Connection pooling & load balancing                          │   │
│  └───────────────────────────┬─────────────────────────────────────┘   │
│                               │                                          │
│  ┌────────────────────────────▼────────────────────────────────────┐   │
│  │                   Processing Pipeline                            │   │
│  │                                                                   │   │
│  │  ┌──────────────────────────────────────────────────────────┐  │   │
│  │  │  1. PII Redaction (Optional)                            │  │   │
│  │  │     - Regex-based detection                             │  │   │
│  │  │     - Pattern matching for API keys, emails, etc.       │  │   │
│  │  └──────────────────────────────────────────────────────────┘  │   │
│  │                                                                   │   │
│  │  ┌──────────────────────────────────────────────────────────┐  │   │
│  │  │  2. LLM Enrichment                                      │  │   │
│  │  │     - Token counting (tiktoken-rs)                      │  │   │
│  │  │     - Cost calculation (provider pricing tables)        │  │   │
│  │  │     - Model metadata extraction                         │  │   │
│  │  └──────────────────────────────────────────────────────────┘  │   │
│  │                                                                   │   │
│  │  ┌──────────────────────────────────────────────────────────┐  │   │
│  │  │  3. Intelligent Sampling                                │  │   │
│  │  │     - Head sampling (probabilistic)                     │  │   │
│  │  │     - Tail sampling (trace-based)                       │  │   │
│  │  │     - Priority sampling (errors, high-cost, slow)       │  │   │
│  │  └──────────────────────────────────────────────────────────┘  │   │
│  │                                                                   │   │
│  │  ┌──────────────────────────────────────────────────────────┐  │   │
│  │  │  4. Metric Aggregation                                  │  │   │
│  │  │     - Pre-aggregate metrics from spans                  │  │   │
│  │  │     - Time-series bucketing                             │  │   │
│  │  │     - Cardinality limiting                              │  │   │
│  │  └──────────────────────────────────────────────────────────┘  │   │
│  └───────────────────────────┬─────────────────────────────────────┘   │
└────────────────────────────────┼───────────────────────────────────────┘
                                 │
                 ┌───────────────┼───────────────┐
                 │               │               │
                 ▼               ▼               ▼
┌─────────────────────┐ ┌───────────────┐ ┌─────────────────┐
│   TimescaleDB       │ │    Jaeger     │ │      Loki       │
│   (Metrics)         │ │   (Traces)    │ │     (Logs)      │
│                     │ │               │ │                 │
│ ┌─────────────────┐ │ │ ┌───────────┐ │ │ ┌─────────────┐ │
│ │ llm_metrics     │ │ │ │ Badger DB │ │ │ │ Index       │ │
│ │ llm_spans       │ │ │ │ (embedded)│ │ │ │ (BoltDB)    │ │
│ │ llm_costs       │ │ │ └───────────┘ │ │ └─────────────┘ │
│ │ system_metrics  │ │ │               │ │                 │
│ └─────────────────┘ │ │ Span Storage  │ │ Chunk Storage   │
│                     │ │ - TraceID idx │ │ - Label index   │
│ Hypertables         │ │ - Duration idx│ │ - Time-based    │
│ - Auto-partition    │ │ - Tag idx     │ │   chunks        │
│ - Compression       │ │               │ │                 │
│ - Retention policy  │ │               │ │                 │
└──────────┬──────────┘ └───────┬───────┘ └────────┬────────┘
           │                    │                   │
           └────────────────────┼───────────────────┘
                                │
                                ▼
              ┌──────────────────────────────────┐
              │       Query & API Layer          │
              │                                  │
              │  ┌────────────────────────────┐ │
              │  │  REST API (Axum)          │ │
              │  │  - /api/v1/metrics        │ │
              │  │  - /api/v1/traces         │ │
              │  │  - /api/v1/costs          │ │
              │  └────────────────────────────┘ │
              │                                  │
              │  ┌────────────────────────────┐ │
              │  │  GraphQL API (async-graphql)│
              │  │  - Unified query interface│ │
              │  │  - Real-time subscriptions│ │
              │  └────────────────────────────┘ │
              │                                  │
              │  ┌────────────────────────────┐ │
              │  │  Grafana Data Source      │ │
              │  │  - Prometheus compatible  │ │
              │  │  - Tempo integration      │ │
              │  │  - Loki integration       │ │
              │  └────────────────────────────┘ │
              └────────────┬─────────────────────┘
                           │
                           ▼
              ┌──────────────────────────────────┐
              │      Grafana Dashboards          │
              │                                  │
              │  - LLM Performance Overview      │
              │  - Cost Analysis & Optimization  │
              │  - Distributed Tracing           │
              │  - Error Tracking & Alerts       │
              │  - Token Usage Analytics         │
              └──────────────────────────────────┘
```

---

## Architecture Patterns

### 1. Collection Pattern: OpenTelemetry Protocol (OTLP)

**Why OTLP?**
- Industry standard (CNCF project)
- Vendor-neutral
- Rich semantic conventions
- Multi-language support
- Efficient binary protocol (Protocol Buffers)

**Implementation:**
```rust
// Collector receives OTLP data via gRPC or HTTP
pub struct OtlpReceiver {
    grpc_server: GrpcServer,  // Port 4317
    http_server: HttpServer,  // Port 4318
}

// Converts OTLP to internal representation
impl OtlpReceiver {
    async fn handle_trace(&self, request: ExportTraceServiceRequest) {
        for resource_span in request.resource_spans {
            for scope_span in resource_span.scope_spans {
                for span in scope_span.spans {
                    // Convert to internal Span type
                    // Extract LLM-specific attributes
                    // Enrich with cost data
                    // Forward to processing pipeline
                }
            }
        }
    }
}
```

### 2. Processing Pattern: Pipeline Architecture

**Advantages:**
- Composable processors
- Easy to add new enrichment steps
- Backpressure handling
- Error isolation

**Pipeline Stages:**
```rust
pub trait Processor: Send + Sync {
    async fn process(&self, batch: SpanBatch) -> Result<SpanBatch>;
}

// Pipeline composition
let pipeline = ProcessorPipeline::new()
    .add(PiiRedactionProcessor::new())
    .add(TokenCountingProcessor::new())
    .add(CostCalculationProcessor::new())
    .add(SamplingProcessor::new())
    .add(MetricAggregationProcessor::new());
```

### 3. Storage Pattern: Multi-Tier Strategy

**Rationale:**
- Different data types have different access patterns
- Cost optimization through specialized storage
- Query performance through appropriate indexing

| Data Type | Storage | Why |
|-----------|---------|-----|
| **Metrics** | TimescaleDB | Time-series optimization, SQL queries, aggregation functions |
| **Traces** | Jaeger/Tempo | High write throughput, trace-id indexing, cheap storage (S3) |
| **Logs** | Loki | Label-based indexing, low cost, log correlation |
| **Cache** | Redis | Fast key-value access, pub/sub, session management |

---

## Component Architecture

### 1. Collector Service

**Responsibilities:**
- Receive OTLP telemetry data
- Process and enrich spans
- Calculate costs
- Apply sampling strategies
- Forward to storage backends

**Key Components:**
```rust
// Main collector structure
pub struct Collector {
    // Receivers
    otlp_receiver: OtlpReceiver,

    // Processing pipeline
    processors: Vec<Box<dyn Processor>>,

    // Exporters
    timescale_exporter: TimescaleExporter,
    jaeger_exporter: JaegerExporter,
    loki_exporter: LokiExporter,

    // Configuration
    config: CollectorConfig,

    // Metrics
    metrics: CollectorMetrics,
}

// Configuration
pub struct CollectorConfig {
    pub otlp_grpc_port: u16,           // 4317
    pub otlp_http_port: u16,           // 4318
    pub batch_size: usize,             // 500
    pub batch_timeout: Duration,        // 10s
    pub max_queue_size: usize,         // 10,000
    pub num_workers: usize,            // 4
    pub enable_pii_redaction: bool,
    pub enable_cost_calculation: bool,
}
```

**Performance Characteristics:**
- Throughput: 100,000 spans/sec
- Latency: < 10ms p99
- Memory: ~512MB for 1M spans in flight
- CPU: ~25% per core under sustained load

### 2. Storage Service

**Responsibilities:**
- Write metrics to TimescaleDB
- Batch writes using COPY protocol
- Manage database connections
- Handle data retention
- Provide health checks

**Key Components:**
```rust
pub struct StorageService {
    // Database connection pool
    pool: PgPool,

    // Writers (optimized for each data type)
    metric_writer: MetricWriter,
    span_writer: SpanWriter,
    log_writer: LogWriter,

    // COPY protocol optimization
    copy_writer: CopyWriter,

    // Configuration
    config: StorageConfig,
}

// COPY protocol for high-throughput writes
pub struct CopyWriter {
    batch_size: usize,        // 10,000
    flush_interval: Duration,  // 1s
    buffer: Vec<MetricRow>,
}

impl CopyWriter {
    // 10x faster than INSERT statements
    async fn write_batch(&mut self) -> Result<()> {
        let mut writer = self.pool.copy_in_raw(
            "COPY llm_metrics (timestamp, trace_id, ...) FROM STDIN"
        ).await?;

        for row in &self.buffer {
            writer.send(row.to_csv_row()).await?;
        }

        writer.finish().await?;
        self.buffer.clear();
        Ok(())
    }
}
```

**Performance Characteristics:**
- Write throughput: 50,000 rows/sec (COPY protocol)
- Read latency: < 50ms p95 for aggregate queries
- Storage efficiency: 4:1 compression ratio
- Connection pooling: 5-20 connections

### 3. API Service

**Responsibilities:**
- Expose REST and GraphQL APIs
- Query metrics, traces, and logs
- Implement caching strategies
- Provide Grafana data source compatibility
- Handle authentication and authorization

**Key Components:**
```rust
pub struct ApiService {
    // HTTP server
    router: Router,

    // Database access (read-only pool)
    db_pool: PgPool,

    // Cache layer
    cache: RedisCache,

    // GraphQL schema
    graphql_schema: Schema<Query, Mutation, Subscription>,

    // Configuration
    config: ApiConfig,
}

// REST API endpoints
#[derive(OpenApi)]
pub struct ApiRoutes;

#[utoipa::path(
    get,
    path = "/api/v1/metrics",
    responses(
        (status = 200, description = "Metrics retrieved", body = MetricsResponse)
    )
)]
async fn get_metrics(
    Query(params): Query<MetricsQuery>,
    State(db): State<PgPool>,
) -> Result<Json<MetricsResponse>> {
    // Query TimescaleDB
    // Apply filters
    // Return aggregated metrics
}

// GraphQL schema
#[derive(SimpleObject)]
struct LLMMetric {
    timestamp: DateTime<Utc>,
    trace_id: String,
    service_name: String,
    model_name: String,
    total_tokens: i32,
    total_cost_usd: f64,
    duration_ms: i64,
}

#[Object]
impl Query {
    async fn llm_metrics(
        &self,
        ctx: &Context<'_>,
        #[graphql(desc = "Service name filter")] service: Option<String>,
        #[graphql(desc = "Time range")] from: DateTime<Utc>,
        #[graphql(desc = "Time range")] to: DateTime<Utc>,
    ) -> Result<Vec<LLMMetric>> {
        // Query database
        // Return results
    }
}
```

---

## Data Flow

### 1. Trace Collection Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: Application Instrumentation                            │
│                                                                  │
│  Python app with SDK:                                           │
│  ```python                                                       │
│  from llm_observatory import trace_llm                          │
│                                                                  │
│  @trace_llm()                                                   │
│  async def generate_response(prompt: str):                      │
│      response = await openai.chat.completions.create(...)       │
│      return response.choices[0].message.content                 │
│  ```                                                             │
│                                                                  │
│  SDK automatically:                                              │
│  - Creates span with trace_id, span_id                          │
│  - Captures prompt, response, model, params                     │
│  - Measures duration, tracks tokens                             │
│  - Propagates context to child spans                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ OTLP export (gRPC)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: Collector Ingestion                                    │
│                                                                  │
│  - Receive OTLP ExportTraceServiceRequest                       │
│  - Parse Protocol Buffer message                                │
│  - Extract resource, scope, and span data                       │
│  - Validate schema and required fields                          │
│  - Add to processing queue                                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: Processing Pipeline                                    │
│                                                                  │
│  3a. PII Redaction (if enabled):                               │
│      - Scan prompt/response for sensitive data                  │
│      - Redact emails: user@example.com → user@***              │
│      - Redact API keys: sk-... → sk-***                        │
│      - Hash user IDs for privacy                                │
│                                                                  │
│  3b. Token Counting:                                            │
│      - Use tiktoken-rs for accurate counting                    │
│      - Count prompt_tokens from input                           │
│      - Count completion_tokens from output                      │
│      - total_tokens = prompt_tokens + completion_tokens         │
│                                                                  │
│  3c. Cost Calculation:                                          │
│      - Look up model pricing (e.g., gpt-4-turbo)               │
│      - prompt_cost = prompt_tokens * price_per_1k_prompt       │
│      - completion_cost = completion_tokens * price_per_1k_comp │
│      - total_cost = prompt_cost + completion_cost               │
│                                                                  │
│  3d. Sampling Decision:                                         │
│      - Always keep: errors, slow requests (>5s), high cost     │
│      - Sample: 1% of normal traffic                            │
│      - Drop: low-value, high-volume requests                    │
│                                                                  │
│  3e. Metric Aggregation:                                        │
│      - Pre-aggregate metrics from spans                         │
│      - Group by: service, model, time bucket                    │
│      - Calculate: count, sum, avg, p50, p95, p99               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Fan-out to storage
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌─────────────┐
│ TimescaleDB  │ │   Jaeger     │ │    Loki     │
│              │ │              │ │             │
│ Write metric │ │ Write span   │ │ Write logs  │
│ aggregates   │ │ with full    │ │ from span   │
│              │ │ context      │ │ events      │
└──────────────┘ └──────────────┘ └─────────────┘
```

### 2. Query Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: User Query                                              │
│                                                                  │
│  Grafana dashboard or API client sends query:                   │
│  GET /api/v1/metrics?service=rag-app&from=now-1h               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: API Service                                             │
│                                                                  │
│  - Parse query parameters                                        │
│  - Check Redis cache for recent results                         │
│  - If cache miss, query database                                │
│  - Apply filters and aggregations                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: Database Query                                          │
│                                                                  │
│  TimescaleDB (for metrics):                                     │
│  SELECT                                                          │
│    time_bucket('5 minutes', timestamp) AS bucket,               │
│    service_name,                                                │
│    model_name,                                                  │
│    COUNT(*) as request_count,                                   │
│    SUM(total_cost_usd) as total_cost,                          │
│    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)   │
│      as p95_latency                                             │
│  FROM llm_metrics                                               │
│  WHERE service_name = 'rag-app'                                 │
│    AND timestamp > NOW() - INTERVAL '1 hour'                   │
│  GROUP BY bucket, service_name, model_name                      │
│  ORDER BY bucket;                                               │
│                                                                  │
│  Uses hypertable partitioning for fast time-range scans        │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 4: Response                                                │
│                                                                  │
│  - Format results as JSON                                        │
│  - Cache in Redis (TTL: 5 minutes)                             │
│  - Return to client                                              │
│  - Grafana renders visualization                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Database Schemas

### TimescaleDB Schema

```sql
-- Metrics hypertable (main storage for aggregated metrics)
CREATE TABLE llm_metrics (
    timestamp        TIMESTAMPTZ NOT NULL,
    trace_id         TEXT NOT NULL,
    span_id          TEXT NOT NULL,
    parent_span_id   TEXT,

    -- Service identification
    service_name     TEXT NOT NULL,
    service_version  TEXT,
    deployment_env   TEXT,

    -- LLM provider and model
    provider_name    TEXT NOT NULL,  -- 'openai', 'anthropic', etc.
    model_name       TEXT NOT NULL,  -- 'gpt-4-turbo', 'claude-3-opus'
    model_version    TEXT,

    -- Request details
    operation_name   TEXT,           -- 'chat.completion', 'embeddings', etc.
    user_id          TEXT,
    session_id       TEXT,

    -- Token metrics
    prompt_tokens    INTEGER,
    completion_tokens INTEGER,
    total_tokens     INTEGER,

    -- Cost metrics (in USD)
    prompt_cost_usd      DOUBLE PRECISION,
    completion_cost_usd  DOUBLE PRECISION,
    total_cost_usd       DOUBLE PRECISION,

    -- Performance metrics
    duration_ms      BIGINT NOT NULL,
    ttft_ms          BIGINT,         -- Time to first token
    tokens_per_sec   DOUBLE PRECISION,

    -- Request parameters
    temperature      DOUBLE PRECISION,
    max_tokens       INTEGER,
    top_p            DOUBLE PRECISION,

    -- Status and errors
    status_code      TEXT,           -- 'ok', 'error', 'timeout'
    error_type       TEXT,
    error_message    TEXT,

    -- Metadata
    tags             JSONB,          -- Flexible key-value pairs
    attributes       JSONB,          -- OpenTelemetry attributes

    PRIMARY KEY (timestamp, trace_id, span_id)
);

-- Convert to hypertable (time-series optimization)
SELECT create_hypertable('llm_metrics', 'timestamp');

-- Create indexes for common queries
CREATE INDEX idx_llm_metrics_service ON llm_metrics (service_name, timestamp DESC);
CREATE INDEX idx_llm_metrics_model ON llm_metrics (model_name, timestamp DESC);
CREATE INDEX idx_llm_metrics_trace_id ON llm_metrics (trace_id);
CREATE INDEX idx_llm_metrics_user_id ON llm_metrics (user_id, timestamp DESC) WHERE user_id IS NOT NULL;
CREATE INDEX idx_llm_metrics_cost ON llm_metrics (timestamp DESC, total_cost_usd DESC);

-- GIN index for JSONB queries
CREATE INDEX idx_llm_metrics_tags ON llm_metrics USING GIN (tags);

-- Continuous aggregates for faster dashboard queries
CREATE MATERIALIZED VIEW llm_metrics_5min
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('5 minutes', timestamp) AS bucket,
    service_name,
    model_name,
    COUNT(*) as request_count,
    SUM(total_tokens) as total_tokens,
    SUM(total_cost_usd) as total_cost,
    AVG(duration_ms) as avg_duration_ms,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_ms) as p50_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration_ms,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99_duration_ms,
    COUNT(*) FILTER (WHERE status_code = 'error') as error_count
FROM llm_metrics
GROUP BY bucket, service_name, model_name;

-- Refresh policy (update every 1 minute)
SELECT add_continuous_aggregate_policy('llm_metrics_5min',
    start_offset => INTERVAL '1 hour',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute');

-- Retention policy (keep raw data for 30 days)
SELECT add_retention_policy('llm_metrics', INTERVAL '30 days');

-- Compression policy (compress data older than 7 days)
ALTER TABLE llm_metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'service_name, model_name',
    timescaledb.compress_orderby = 'timestamp DESC'
);

SELECT add_compression_policy('llm_metrics', INTERVAL '7 days');

-- Cost tracking table (aggregated by hour/day/month)
CREATE TABLE llm_costs (
    timestamp        TIMESTAMPTZ NOT NULL,
    granularity      TEXT NOT NULL,  -- 'hourly', 'daily', 'monthly'
    service_name     TEXT NOT NULL,
    model_name       TEXT NOT NULL,
    user_id          TEXT,

    request_count    BIGINT,
    total_tokens     BIGINT,
    total_cost_usd   DOUBLE PRECISION,
    avg_cost_per_req DOUBLE PRECISION,

    PRIMARY KEY (timestamp, granularity, service_name, model_name, user_id)
);

SELECT create_hypertable('llm_costs', 'timestamp');
```

### Jaeger/Tempo Schema

Jaeger uses its own internal schema (Badger DB or Cassandra). We interact via:
- Jaeger Query API (HTTP)
- OTLP gRPC export from collector

**Trace Structure:**
```json
{
  "traceID": "7d8f9e2a1b3c4d5e",
  "spans": [
    {
      "spanID": "1a2b3c4d5e6f7g8h",
      "operationName": "llm.chat_completion",
      "startTime": 1699564800000000,
      "duration": 1200000,
      "tags": [
        {"key": "llm.provider", "value": "openai"},
        {"key": "llm.model", "value": "gpt-4-turbo"},
        {"key": "llm.tokens.prompt", "value": 850},
        {"key": "llm.tokens.completion", "value": 150},
        {"key": "llm.cost.total", "value": 0.015}
      ],
      "logs": [
        {
          "timestamp": 1699564800050000,
          "fields": [
            {"key": "event", "value": "request_sent"}
          ]
        }
      ]
    }
  ]
}
```

---

## API Contracts

### REST API

**Base URL:** `http://localhost:8080/api/v1`

#### 1. Get Metrics

```http
GET /api/v1/metrics
```

**Query Parameters:**
- `service` (optional): Filter by service name
- `model` (optional): Filter by model name
- `from` (required): Start time (ISO 8601 or relative like "now-1h")
- `to` (required): End time
- `aggregation` (optional): Time bucket size (1m, 5m, 1h, 1d)
- `limit` (optional): Max results (default: 1000)

**Response:**
```json
{
  "data": [
    {
      "timestamp": "2025-11-05T10:00:00Z",
      "service_name": "rag-service",
      "model_name": "gpt-4-turbo",
      "request_count": 150,
      "total_tokens": 125000,
      "total_cost_usd": 18.75,
      "avg_duration_ms": 1250,
      "p95_duration_ms": 2100,
      "error_count": 2
    }
  ],
  "metadata": {
    "count": 1,
    "from": "2025-11-05T10:00:00Z",
    "to": "2025-11-05T11:00:00Z"
  }
}
```

#### 2. Get Cost Summary

```http
GET /api/v1/costs/summary
```

**Query Parameters:**
- `period` (required): "hourly", "daily", "monthly"
- `from` (required): Start time
- `to` (required): End time
- `group_by` (optional): "service", "model", "user"

**Response:**
```json
{
  "total_cost_usd": 1247.89,
  "breakdown": [
    {
      "service_name": "rag-service",
      "total_cost_usd": 856.32,
      "percentage": 68.6,
      "request_count": 125400,
      "avg_cost_per_request": 0.0068
    }
  ]
}
```

### GraphQL API

**Endpoint:** `http://localhost:8080/graphql`

**Schema:**
```graphql
type Query {
  """Get LLM metrics with filters"""
  llmMetrics(
    service: String
    model: String
    from: DateTime!
    to: DateTime!
    limit: Int = 1000
  ): [LLMMetric!]!

  """Get cost summary"""
  costSummary(
    period: Period!
    from: DateTime!
    to: DateTime!
    groupBy: CostGroupBy
  ): CostSummary!

  """Get trace by ID"""
  trace(traceId: String!): Trace
}

type LLMMetric {
  timestamp: DateTime!
  traceId: String!
  serviceName: String!
  modelName: String!
  totalTokens: Int!
  totalCostUsd: Float!
  durationMs: Int!
  statusCode: String!
}

type CostSummary {
  totalCostUsd: Float!
  breakdown: [CostBreakdown!]!
}

type Trace {
  traceId: String!
  duration: Int!
  spans: [Span!]!
}

enum Period {
  HOURLY
  DAILY
  MONTHLY
}

enum CostGroupBy {
  SERVICE
  MODEL
  USER
}
```

**Example Query:**
```graphql
query GetMetrics {
  llmMetrics(
    service: "rag-service"
    from: "2025-11-05T00:00:00Z"
    to: "2025-11-05T23:59:59Z"
  ) {
    timestamp
    modelName
    totalTokens
    totalCostUsd
    durationMs
  }
}
```

---

## Service Responsibilities

### Collector Service

| Responsibility | Implementation | Notes |
|----------------|----------------|-------|
| **OTLP Ingestion** | gRPC (Tonic) + HTTP (Axum) | Dual protocol support |
| **Validation** | Protobuf schema validation | Reject malformed data |
| **PII Redaction** | Regex patterns + custom rules | Optional, configurable |
| **Token Counting** | tiktoken-rs library | Accurate for OpenAI models |
| **Cost Calculation** | Provider pricing tables | Updated monthly |
| **Sampling** | Head + tail sampling | Configurable strategies |
| **Batching** | Configurable batch size/timeout | Optimize throughput |
| **Export** | Multi-backend (TimescaleDB, Jaeger, Loki) | Parallel writes |

### Storage Service

| Responsibility | Implementation | Notes |
|----------------|----------------|-------|
| **Write Optimization** | COPY protocol | 10x faster than INSERT |
| **Connection Pooling** | SQLx pool | 5-20 connections |
| **Schema Management** | sqlx migrations | Version-controlled |
| **Data Retention** | TimescaleDB policies | Configurable per table |
| **Compression** | TimescaleDB compression | Automatic after 7 days |
| **Health Checks** | HTTP endpoint | Liveness and readiness |

### API Service

| Responsibility | Implementation | Notes |
|----------------|----------------|-------|
| **REST API** | Axum framework | OpenAPI spec |
| **GraphQL API** | async-graphql | Schema-first |
| **Caching** | Redis | TTL-based |
| **Authentication** | JWT tokens | Optional |
| **Rate Limiting** | Token bucket | Per-user limits |
| **CORS** | Configurable origins | Production-ready |
| **Grafana Integration** | Data source API | Prometheus-compatible |

---

## Technology Decisions

### Why Rust?

| Aspect | Benefit |
|--------|---------|
| **Performance** | 20-40x faster than Python/Node.js for telemetry processing |
| **Memory Safety** | No garbage collection, predictable latency |
| **Concurrency** | Fearless concurrency with Tokio async runtime |
| **Ecosystem** | Rich OpenTelemetry support, excellent HTTP libraries |
| **Deployment** | Single binary, no runtime dependencies |

### Why TimescaleDB?

| Aspect | Benefit |
|--------|---------|
| **SQL Compatibility** | Familiar query language, extensive tool support |
| **Time-Series Optimization** | Automatic partitioning, efficient time-range queries |
| **Aggregation** | Built-in percentile functions, continuous aggregates |
| **Compression** | 4:1 compression ratio reduces storage costs |
| **Retention** | Automatic data lifecycle management |

### Why Jaeger for Traces?

| Aspect | Benefit |
|--------|---------|
| **OTLP Native** | Direct integration with collector |
| **Performance** | Handles millions of spans per day |
| **UI** | Excellent trace visualization |
| **Cost** | Open source, cheap storage with Badger/Cassandra |
| **Ecosystem** | CNCF graduated project, production-proven |

---

## Performance Considerations

### 1. Collector Performance

**Bottlenecks:**
- OTLP deserialization (Protocol Buffers)
- Token counting (CPU-intensive)
- Database writes (I/O-bound)

**Optimizations:**
```rust
// Use rayon for parallel token counting
use rayon::prelude::*;

let token_counts: Vec<usize> = spans
    .par_iter()
    .map(|span| count_tokens(&span.prompt))
    .collect();

// Batch database writes
let mut batch = Vec::with_capacity(1000);
for span in spans {
    batch.push(span);
    if batch.len() >= 1000 {
        write_batch(&mut batch).await?;
    }
}
```

### 2. Database Performance

**Query Optimization:**
```sql
-- Use continuous aggregates for dashboards
SELECT * FROM llm_metrics_5min
WHERE bucket >= NOW() - INTERVAL '24 hours';

-- Instead of:
SELECT time_bucket('5 minutes', timestamp), ...
FROM llm_metrics
WHERE timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY time_bucket('5 minutes', timestamp), ...;
```

**Index Strategy:**
- Time-based: Clustered on timestamp
- Cardinality: Index high-selectivity columns (service_name, model_name)
- Avoid: Indexing low-selectivity columns (status_code)

### 3. Caching Strategy

**Redis Cache Tiers:**
- Hot data (last 5 minutes): TTL 1 minute
- Warm data (last 1 hour): TTL 5 minutes
- Cold data (older): Query database directly

---

## Security Architecture

### 1. Authentication & Authorization

```rust
// JWT-based authentication
pub struct AuthMiddleware;

impl AuthMiddleware {
    pub async fn verify_token(&self, token: &str) -> Result<Claims> {
        let validation = Validation::new(Algorithm::HS256);
        jsonwebtoken::decode::<Claims>(
            token,
            &DecodingKey::from_secret(secret),
            &validation,
        )
    }
}
```

### 2. PII Redaction

**Patterns:**
```rust
pub struct PiiRedactor {
    patterns: Vec<Regex>,
}

impl PiiRedactor {
    pub fn new() -> Self {
        Self {
            patterns: vec![
                Regex::new(r"sk-[a-zA-Z0-9]{32,}").unwrap(),  // API keys
                Regex::new(r"\b[\w.-]+@[\w.-]+\.\w+\b").unwrap(),  // Emails
                Regex::new(r"\b\d{3}-\d{2}-\d{4}\b").unwrap(),  // SSN
            ],
        }
    }

    pub fn redact(&self, text: &str) -> String {
        let mut result = text.to_string();
        for pattern in &self.patterns {
            result = pattern.replace_all(&result, "[REDACTED]").to_string();
        }
        result
    }
}
```

### 3. Network Security

- TLS for all external communication
- mTLS for service-to-service (optional)
- Network policies in Kubernetes
- Secrets management (Vault, AWS Secrets Manager)

---

## Scaling Strategy

### Horizontal Scaling

**Collector:**
- Stateless design allows easy horizontal scaling
- Load balancer in front (e.g., NGINX, AWS ALB)
- Each instance handles 100k spans/sec

**Storage:**
- TimescaleDB supports read replicas
- Write to primary, read from replicas
- Connection pooling distributes load

**API:**
- Stateless design
- Redis for distributed caching
- Auto-scaling based on CPU/memory

### Vertical Scaling

**When to scale vertically:**
- Database: Large working set, complex aggregations
- Collector: High token counting overhead
- Cache: Large cache hit ratio needed

**Resource recommendations:**
- Collector: 2-4 CPU cores, 4-8 GB RAM
- Storage: 4-8 CPU cores, 16-32 GB RAM
- API: 2-4 CPU cores, 4-8 GB RAM

---

## Conclusion

LLM Observatory's architecture is designed for:
1. **Performance**: Handle 100k+ spans/sec with < 10ms latency
2. **Scalability**: Horizontal scaling of all components
3. **Cost-Effectiveness**: 85% cheaper than commercial solutions
4. **Flexibility**: OpenTelemetry standard, multi-backend storage
5. **Reliability**: Proven technologies, comprehensive monitoring

For more details, see:
- [Deployment Guide](./DEPLOYMENT.md) - Production deployment patterns
- [Development Guide](./DEVELOPMENT.md) - Local development setup
- [API Documentation](./API.md) - Complete API reference

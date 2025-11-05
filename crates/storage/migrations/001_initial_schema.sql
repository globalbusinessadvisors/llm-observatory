-- Migration: 001_initial_schema.sql
-- Description: Create initial tables for LLM Observatory (llm_traces, llm_metrics, llm_logs)
-- Date: 2025-11-05
-- Author: LLM Observatory Core Team

BEGIN;

-- ============================================================================
-- Core Traces Table (Section 2.1)
-- ============================================================================
-- Purpose: Store raw LLM trace data (OpenTelemetry spans)
-- Will be converted to hypertable in 002_add_hypertables.sql

CREATE TABLE IF NOT EXISTS llm_traces (
    -- Primary identifiers
    ts                      TIMESTAMPTZ NOT NULL,           -- Time dimension (partition key)
    trace_id                TEXT NOT NULL,                  -- OpenTelemetry trace ID
    span_id                 TEXT NOT NULL,                  -- OpenTelemetry span ID
    parent_span_id          TEXT,                           -- Parent span (for chains)

    -- Span metadata
    span_name               TEXT NOT NULL,                  -- Operation name (e.g., "llm.chat.completion")
    span_kind               TEXT NOT NULL DEFAULT 'internal', -- internal, client, server, producer, consumer

    -- LLM-specific attributes
    provider                TEXT NOT NULL,                  -- openai, anthropic, google, etc.
    model                   TEXT NOT NULL,                  -- gpt-4, claude-3-opus, etc.

    -- Input/Output (redacted)
    input_type              TEXT NOT NULL,                  -- text, chat, multimodal
    input_text              TEXT,                           -- For text inputs
    input_messages          JSONB,                          -- For chat inputs (array of messages)
    output_text             TEXT,                           -- Generated response
    finish_reason           TEXT,                           -- stop, length, content_filter, etc.

    -- Token usage
    prompt_tokens           INTEGER,
    completion_tokens       INTEGER,
    total_tokens            INTEGER,

    -- Cost tracking
    prompt_cost_usd         DECIMAL(12, 8),                -- Prompt cost
    completion_cost_usd     DECIMAL(12, 8),                -- Completion cost
    total_cost_usd          DECIMAL(12, 8),                -- Total cost

    -- Latency metrics
    duration_ms             INTEGER NOT NULL,               -- Total duration
    ttft_ms                 INTEGER,                        -- Time to first token

    -- Status
    status_code             TEXT NOT NULL,                  -- OK, ERROR, UNSET
    error_message           TEXT,                           -- Error details if failed

    -- Metadata & tags
    user_id                 TEXT,                           -- User identifier
    session_id              TEXT,                           -- Session identifier
    environment             TEXT,                           -- production, staging, development
    tags                    TEXT[],                         -- Custom tags (array)
    attributes              JSONB,                          -- Additional attributes

    -- Sampling
    sampled                 BOOLEAN NOT NULL DEFAULT true,  -- Whether this span was sampled
    sample_rate             REAL,                           -- Sampling rate applied

    -- OpenTelemetry compliance
    resource_attributes     JSONB,                          -- Resource attributes
    events                  JSONB,                          -- Span events
    links                   JSONB,                          -- Span links

    -- Constraints
    PRIMARY KEY (ts, trace_id, span_id)
);

-- Add comments for documentation
COMMENT ON TABLE llm_traces IS 'LLM trace data following OpenTelemetry semantic conventions';
COMMENT ON COLUMN llm_traces.ts IS 'Timestamp when the span started';
COMMENT ON COLUMN llm_traces.trace_id IS 'OpenTelemetry trace ID for correlation';
COMMENT ON COLUMN llm_traces.span_id IS 'Unique span identifier';
COMMENT ON COLUMN llm_traces.parent_span_id IS 'Parent span ID for nested traces (chains, RAG pipelines)';
COMMENT ON COLUMN llm_traces.duration_ms IS 'Total span duration in milliseconds';
COMMENT ON COLUMN llm_traces.ttft_ms IS 'Time to first token in milliseconds (streaming)';
COMMENT ON COLUMN llm_traces.total_cost_usd IS 'Total cost in USD (prompt + completion)';
COMMENT ON COLUMN llm_traces.sampled IS 'Whether this span was sampled for storage';
COMMENT ON COLUMN llm_traces.tags IS 'Custom tags as array for filtering';
COMMENT ON COLUMN llm_traces.attributes IS 'Additional structured attributes as JSONB';

-- ============================================================================
-- Metrics Table (Section 2.2)
-- ============================================================================
-- Purpose: Store aggregated metrics (counters, gauges, histograms)

CREATE TABLE IF NOT EXISTS llm_metrics (
    -- Time dimension
    ts                      TIMESTAMPTZ NOT NULL,

    -- Metric identity
    metric_name             TEXT NOT NULL,                  -- request_count, token_count, etc.
    metric_type             TEXT NOT NULL,                  -- counter, gauge, histogram

    -- Dimensions (high cardinality)
    provider                TEXT NOT NULL,
    model                   TEXT NOT NULL,
    environment             TEXT,
    user_id                 TEXT,

    -- Metric values
    value                   DOUBLE PRECISION NOT NULL,      -- Metric value
    count                   BIGINT,                         -- For histograms
    sum                     DOUBLE PRECISION,               -- For histograms
    min                     DOUBLE PRECISION,               -- For histograms
    max                     DOUBLE PRECISION,               -- For histograms

    -- Additional dimensions
    tags                    JSONB,                          -- Additional tags

    PRIMARY KEY (ts, metric_name, provider, model)
);

COMMENT ON TABLE llm_metrics IS 'Aggregated LLM metrics (counters, gauges, histograms)';
COMMENT ON COLUMN llm_metrics.metric_name IS 'Name of the metric (e.g., request_count, token_count)';
COMMENT ON COLUMN llm_metrics.metric_type IS 'Type of metric: counter, gauge, or histogram';
COMMENT ON COLUMN llm_metrics.value IS 'Primary metric value';

-- ============================================================================
-- Logs Table (Section 2.3)
-- ============================================================================
-- Purpose: Store structured logs from LLM operations

CREATE TABLE IF NOT EXISTS llm_logs (
    -- Time dimension
    ts                      TIMESTAMPTZ NOT NULL,

    -- Correlation
    trace_id                TEXT,                           -- Link to trace
    span_id                 TEXT,                           -- Link to span

    -- Log metadata
    log_level               TEXT NOT NULL,                  -- DEBUG, INFO, WARN, ERROR
    message                 TEXT NOT NULL,                  -- Log message

    -- Source
    provider                TEXT,
    model                   TEXT,
    environment             TEXT,

    -- Structured data
    attributes              JSONB,                          -- Structured attributes

    PRIMARY KEY (ts, trace_id, span_id)
);

COMMENT ON TABLE llm_logs IS 'Structured logs from LLM operations';
COMMENT ON COLUMN llm_logs.log_level IS 'Log severity level (DEBUG, INFO, WARN, ERROR)';
COMMENT ON COLUMN llm_logs.trace_id IS 'Link to parent trace for correlation';
COMMENT ON COLUMN llm_logs.span_id IS 'Link to parent span for correlation';

COMMIT;

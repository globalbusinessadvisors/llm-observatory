-- Development seed data for LLM Observatory
-- This file provides sample data for testing and development
-- Run with: psql -h localhost -U postgres -d llm_observatory < seed.sql

\c llm_observatory

-- Set timezone for consistent timestamps
SET timezone = 'UTC';

BEGIN;

-- Create sample LLM trace data
-- Note: Actual table schemas will be created by migrations
-- These are example inserts based on common observability patterns

-- Create tables for development (will be replaced by proper migrations)
CREATE TABLE IF NOT EXISTS traces (
    trace_id UUID PRIMARY KEY,
    span_id UUID NOT NULL,
    parent_span_id UUID,
    trace_name VARCHAR(255) NOT NULL,
    service_name VARCHAR(100) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    duration_ms BIGINT NOT NULL,
    status_code VARCHAR(20) NOT NULL,
    attributes JSONB,
    events JSONB,
    links JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Convert to hypertable for time-series optimization
SELECT create_hypertable('traces', 'start_time',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_traces_service_name ON traces(service_name, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_traces_trace_name ON traces(trace_name, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_traces_status_code ON traces(status_code, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_traces_attributes ON traces USING gin(attributes);

-- LLM-specific attributes table
CREATE TABLE IF NOT EXISTS llm_attributes (
    id BIGSERIAL PRIMARY KEY,
    trace_id UUID NOT NULL REFERENCES traces(trace_id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL,
    model VARCHAR(100) NOT NULL,
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    total_tokens INTEGER,
    temperature REAL,
    max_tokens INTEGER,
    top_p REAL,
    frequency_penalty REAL,
    presence_penalty REAL,
    response_format VARCHAR(50),
    tool_calls JSONB,
    finish_reason VARCHAR(50),
    cost_usd DECIMAL(10, 6),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_llm_attributes_trace_id ON llm_attributes(trace_id);
CREATE INDEX IF NOT EXISTS idx_llm_attributes_provider ON llm_attributes(provider, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_llm_attributes_model ON llm_attributes(model, created_at DESC);

-- Metrics aggregation table
CREATE TABLE IF NOT EXISTS metrics (
    time TIMESTAMPTZ NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    service_name VARCHAR(100) NOT NULL,
    tags JSONB,
    value DOUBLE PRECISION NOT NULL,
    count BIGINT NOT NULL DEFAULT 1
);

SELECT create_hypertable('metrics', 'time',
    chunk_time_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_metrics_name_service ON metrics(metric_name, service_name, time DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_tags ON metrics USING gin(tags);

-- ============================================================================
-- Seed sample data
-- ============================================================================

-- Insert sample traces for different LLM providers
INSERT INTO traces (trace_id, span_id, parent_span_id, trace_name, service_name, start_time, end_time, duration_ms, status_code, attributes, events, links)
VALUES
    -- OpenAI GPT-4 request
    (
        '550e8400-e29b-41d4-a716-446655440001',
        '550e8400-e29b-41d4-a716-446655440011',
        NULL,
        'chat.completions.create',
        'llm-app',
        NOW() - INTERVAL '5 minutes',
        NOW() - INTERVAL '4 minutes 57 seconds',
        3000,
        'ok',
        '{"http.method": "POST", "http.url": "https://api.openai.com/v1/chat/completions", "llm.provider": "openai"}'::jsonb,
        '[]'::jsonb,
        '[]'::jsonb
    ),
    -- Anthropic Claude request
    (
        '550e8400-e29b-41d4-a716-446655440002',
        '550e8400-e29b-41d4-a716-446655440012',
        NULL,
        'messages.create',
        'llm-app',
        NOW() - INTERVAL '4 minutes',
        NOW() - INTERVAL '3 minutes 55 seconds',
        5000,
        'ok',
        '{"http.method": "POST", "http.url": "https://api.anthropic.com/v1/messages", "llm.provider": "anthropic"}'::jsonb,
        '[]'::jsonb,
        '[]'::jsonb
    ),
    -- Azure OpenAI request
    (
        '550e8400-e29b-41d4-a716-446655440003',
        '550e8400-e29b-41d4-a716-446655440013',
        NULL,
        'chat.completions.create',
        'llm-app',
        NOW() - INTERVAL '3 minutes',
        NOW() - INTERVAL '2 minutes 58 seconds',
        2000,
        'ok',
        '{"http.method": "POST", "http.url": "https://myapp.openai.azure.com/openai/deployments/gpt-4/chat/completions", "llm.provider": "azure_openai"}'::jsonb,
        '[]'::jsonb,
        '[]'::jsonb
    ),
    -- Failed request example
    (
        '550e8400-e29b-41d4-a716-446655440004',
        '550e8400-e29b-41d4-a716-446655440014',
        NULL,
        'chat.completions.create',
        'llm-app',
        NOW() - INTERVAL '2 minutes',
        NOW() - INTERVAL '1 minute 59 seconds',
        1000,
        'error',
        '{"http.method": "POST", "http.url": "https://api.openai.com/v1/chat/completions", "llm.provider": "openai", "error.type": "rate_limit_exceeded"}'::jsonb,
        '[{"name": "exception", "timestamp": "' || (NOW() - INTERVAL '2 minutes')::text || '", "attributes": {"exception.type": "RateLimitError", "exception.message": "Rate limit exceeded"}}]'::jsonb,
        '[]'::jsonb
    ),
    -- Long-running request
    (
        '550e8400-e29b-41d4-a716-446655440005',
        '550e8400-e29b-41d4-a716-446655440015',
        NULL,
        'chat.completions.create',
        'llm-app',
        NOW() - INTERVAL '1 minute',
        NOW() - INTERVAL '45 seconds',
        15000,
        'ok',
        '{"http.method": "POST", "http.url": "https://api.openai.com/v1/chat/completions", "llm.provider": "openai", "llm.streaming": true}'::jsonb,
        '[]'::jsonb,
        '[]'::jsonb
    )
ON CONFLICT (trace_id) DO NOTHING;

-- Insert corresponding LLM attributes
INSERT INTO llm_attributes (trace_id, provider, model, prompt_tokens, completion_tokens, total_tokens, temperature, max_tokens, top_p, finish_reason, cost_usd)
VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'openai', 'gpt-4-0125-preview', 150, 350, 500, 0.7, 1000, 1.0, 'stop', 0.025),
    ('550e8400-e29b-41d4-a716-446655440002', 'anthropic', 'claude-3-opus-20240229', 200, 450, 650, 0.8, 2000, 1.0, 'end_turn', 0.049),
    ('550e8400-e29b-41d4-a716-446655440003', 'azure_openai', 'gpt-4', 100, 200, 300, 0.5, 500, 0.95, 'stop', 0.015),
    ('550e8400-e29b-41d4-a716-446655440005', 'openai', 'gpt-4-0125-preview', 500, 1500, 2000, 0.7, 2000, 1.0, 'stop', 0.100)
ON CONFLICT DO NOTHING;

-- Insert sample metrics
INSERT INTO metrics (time, metric_name, service_name, tags, value, count)
SELECT
    time_bucket,
    metric_name,
    'llm-app',
    tags,
    value,
    1
FROM (
    VALUES
        (NOW() - INTERVAL '5 minutes', 'llm.request.duration', '{"provider": "openai", "model": "gpt-4"}'::jsonb, 3000.0),
        (NOW() - INTERVAL '4 minutes', 'llm.request.duration', '{"provider": "anthropic", "model": "claude-3-opus"}'::jsonb, 5000.0),
        (NOW() - INTERVAL '3 minutes', 'llm.request.duration', '{"provider": "azure_openai", "model": "gpt-4"}'::jsonb, 2000.0),
        (NOW() - INTERVAL '2 minutes', 'llm.request.duration', '{"provider": "openai", "model": "gpt-4"}'::jsonb, 1000.0),
        (NOW() - INTERVAL '1 minute', 'llm.request.duration', '{"provider": "openai", "model": "gpt-4"}'::jsonb, 15000.0),
        (NOW() - INTERVAL '5 minutes', 'llm.tokens.total', '{"provider": "openai", "model": "gpt-4"}'::jsonb, 500.0),
        (NOW() - INTERVAL '4 minutes', 'llm.tokens.total', '{"provider": "anthropic", "model": "claude-3-opus"}'::jsonb, 650.0),
        (NOW() - INTERVAL '3 minutes', 'llm.tokens.total', '{"provider": "azure_openai", "model": "gpt-4"}'::jsonb, 300.0),
        (NOW() - INTERVAL '1 minute', 'llm.tokens.total', '{"provider": "openai", "model": "gpt-4"}'::jsonb, 2000.0),
        (NOW() - INTERVAL '5 minutes', 'llm.cost.usd', '{"provider": "openai", "model": "gpt-4"}'::jsonb, 0.025),
        (NOW() - INTERVAL '4 minutes', 'llm.cost.usd', '{"provider": "anthropic", "model": "claude-3-opus"}'::jsonb, 0.049),
        (NOW() - INTERVAL '3 minutes', 'llm.cost.usd', '{"provider": "azure_openai", "model": "gpt-4"}'::jsonb, 0.015),
        (NOW() - INTERVAL '1 minute', 'llm.cost.usd', '{"provider": "openai", "model": "gpt-4"}'::jsonb, 0.100)
) AS t(time_bucket, metric_name, tags, value)
ON CONFLICT DO NOTHING;

-- Create continuous aggregate for hourly metrics
CREATE MATERIALIZED VIEW IF NOT EXISTS metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    metric_name,
    service_name,
    tags,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    SUM(value) AS sum_value,
    SUM(count) AS total_count
FROM metrics
GROUP BY bucket, metric_name, service_name, tags
WITH NO DATA;

-- Refresh the continuous aggregate
CALL refresh_continuous_aggregate('metrics_hourly', NOW() - INTERVAL '1 day', NOW());

-- Create retention policy to drop old data
SELECT add_retention_policy('traces', INTERVAL '7 days', if_not_exists => TRUE);
SELECT add_retention_policy('metrics', INTERVAL '30 days', if_not_exists => TRUE);

-- Create compression policy for older data
SELECT add_compression_policy('traces', INTERVAL '1 day', if_not_exists => TRUE);
SELECT add_compression_policy('metrics', INTERVAL '3 days', if_not_exists => TRUE);

COMMIT;

-- Display summary
DO $$
DECLARE
    trace_count INTEGER;
    llm_attr_count INTEGER;
    metric_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO trace_count FROM traces;
    SELECT COUNT(*) INTO llm_attr_count FROM llm_attributes;
    SELECT COUNT(*) INTO metric_count FROM metrics;

    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Development seed data loaded successfully!';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Traces: %', trace_count;
    RAISE NOTICE 'LLM Attributes: %', llm_attr_count;
    RAISE NOTICE 'Metrics: %', metric_count;
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Sample queries:';
    RAISE NOTICE '  - SELECT * FROM traces ORDER BY start_time DESC LIMIT 10;';
    RAISE NOTICE '  - SELECT * FROM llm_attributes ORDER BY created_at DESC;';
    RAISE NOTICE '  - SELECT * FROM metrics ORDER BY time DESC LIMIT 20;';
    RAISE NOTICE '  - SELECT * FROM metrics_hourly;';
    RAISE NOTICE '==============================================';
END
$$;

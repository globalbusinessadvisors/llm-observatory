-- Test database schema initialization
-- Creates the necessary tables and extensions for LLM Observatory testing

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "timescaledb";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- ============================================================================
-- USERS AND AUTHENTICATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_admin BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);

-- ============================================================================
-- PROJECTS AND API KEYS
-- ============================================================================

CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(owner_id, name)
);

CREATE INDEX idx_projects_owner ON projects(owner_id);
CREATE INDEX idx_projects_name ON projects(name);

CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key_hash VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    permissions JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    UNIQUE(project_id, name)
);

CREATE INDEX idx_api_keys_project ON api_keys(project_id);
CREATE INDEX idx_api_keys_hash ON api_keys(key_hash);

-- ============================================================================
-- LLM TRACES AND SPANS
-- ============================================================================

CREATE TABLE IF NOT EXISTS llm_traces (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    trace_id VARCHAR(255) UNIQUE NOT NULL,
    model VARCHAR(255),
    provider VARCHAR(100),
    user_id VARCHAR(255),
    session_id VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_traces_project ON llm_traces(project_id);
CREATE INDEX idx_traces_trace_id ON llm_traces(trace_id);
CREATE INDEX idx_traces_model ON llm_traces(model);
CREATE INDEX idx_traces_provider ON llm_traces(provider);
CREATE INDEX idx_traces_created_at ON llm_traces(created_at DESC);

-- Convert to hypertable for time-series data
SELECT create_hypertable('llm_traces', 'created_at',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

CREATE TABLE IF NOT EXISTS llm_spans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trace_id UUID NOT NULL REFERENCES llm_traces(id) ON DELETE CASCADE,
    span_id VARCHAR(255) NOT NULL,
    parent_span_id VARCHAR(255),
    name VARCHAR(255) NOT NULL,
    kind VARCHAR(50),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_ms INTEGER GENERATED ALWAYS AS (
        EXTRACT(MILLISECONDS FROM (end_time - start_time))
    ) STORED,
    status VARCHAR(50),
    attributes JSONB DEFAULT '{}',
    UNIQUE(trace_id, span_id)
);

CREATE INDEX idx_spans_trace ON llm_spans(trace_id);
CREATE INDEX idx_spans_span_id ON llm_spans(span_id);
CREATE INDEX idx_spans_parent ON llm_spans(parent_span_id);
CREATE INDEX idx_spans_start_time ON llm_spans(start_time DESC);
CREATE INDEX idx_spans_name ON llm_spans(name);

-- ============================================================================
-- EVENTS AND LOGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS llm_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    span_id UUID NOT NULL REFERENCES llm_spans(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    name VARCHAR(255),
    data JSONB DEFAULT '{}',
    severity VARCHAR(20) DEFAULT 'info'
);

CREATE INDEX idx_events_span ON llm_events(span_id);
CREATE INDEX idx_events_type ON llm_events(event_type);
CREATE INDEX idx_events_timestamp ON llm_events(timestamp DESC);

-- Convert to hypertable
SELECT create_hypertable('llm_events', 'timestamp',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- ============================================================================
-- METRICS
-- ============================================================================

CREATE TABLE IF NOT EXISTS metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    metric_name VARCHAR(255) NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    labels JSONB DEFAULT '{}'
);

CREATE INDEX idx_metrics_project ON metrics(project_id);
CREATE INDEX idx_metrics_name ON metrics(metric_name);
CREATE INDEX idx_metrics_timestamp ON metrics(timestamp DESC);

-- Convert to hypertable
SELECT create_hypertable('metrics', 'timestamp',
    chunk_time_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

-- ============================================================================
-- TOKEN USAGE AND COSTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS token_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    span_id UUID NOT NULL REFERENCES llm_spans(id) ON DELETE CASCADE,
    prompt_tokens INTEGER DEFAULT 0,
    completion_tokens INTEGER DEFAULT 0,
    total_tokens INTEGER GENERATED ALWAYS AS (prompt_tokens + completion_tokens) STORED,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_token_usage_span ON token_usage(span_id);
CREATE INDEX idx_token_usage_timestamp ON token_usage(timestamp DESC);

-- Convert to hypertable
SELECT create_hypertable('token_usage', 'timestamp',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

CREATE TABLE IF NOT EXISTS costs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    span_id UUID NOT NULL REFERENCES llm_spans(id) ON DELETE CASCADE,
    cost_usd DECIMAL(10, 6) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    breakdown JSONB DEFAULT '{}'
);

CREATE INDEX idx_costs_span ON costs(span_id);
CREATE INDEX idx_costs_timestamp ON costs(timestamp DESC);

-- Convert to hypertable
SELECT create_hypertable('costs', 'timestamp',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- ============================================================================
-- CONTINUOUS AGGREGATES FOR PERFORMANCE
-- ============================================================================

-- Hourly metrics rollup
CREATE MATERIALIZED VIEW IF NOT EXISTS metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
    project_id,
    metric_name,
    time_bucket('1 hour', timestamp) AS hour,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    COUNT(*) AS count
FROM metrics
GROUP BY project_id, metric_name, hour
WITH NO DATA;

SELECT add_continuous_aggregate_policy('metrics_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

-- Daily token usage rollup
CREATE MATERIALIZED VIEW IF NOT EXISTS token_usage_daily
WITH (timescaledb.continuous) AS
SELECT
    s.trace_id,
    t.project_id,
    time_bucket('1 day', tu.timestamp) AS day,
    SUM(tu.prompt_tokens) AS total_prompt_tokens,
    SUM(tu.completion_tokens) AS total_completion_tokens,
    SUM(tu.total_tokens) AS total_tokens,
    COUNT(*) AS request_count
FROM token_usage tu
JOIN llm_spans s ON tu.span_id = s.id
JOIN llm_traces t ON s.trace_id = t.id
GROUP BY s.trace_id, t.project_id, day
WITH NO DATA;

SELECT add_continuous_aggregate_policy('token_usage_daily',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to clean up old test data
CREATE OR REPLACE FUNCTION cleanup_old_test_data(retention_days INTEGER DEFAULT 7)
RETURNS TABLE(table_name TEXT, rows_deleted BIGINT) AS $$
BEGIN
    -- Clean up old traces
    DELETE FROM llm_traces WHERE created_at < NOW() - (retention_days || ' days')::INTERVAL;
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    table_name := 'llm_traces';
    RETURN NEXT;

    -- Clean up old events
    DELETE FROM llm_events WHERE timestamp < NOW() - (retention_days || ' days')::INTERVAL;
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    table_name := 'llm_events';
    RETURN NEXT;

    -- Clean up old metrics
    DELETE FROM metrics WHERE timestamp < NOW() - (retention_days || ' days')::INTERVAL;
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    table_name := 'metrics';
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions for test user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO test_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO test_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO test_user;

-- Create read-only user for certain tests
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'test_readonly') THEN
        CREATE USER test_readonly WITH PASSWORD 'readonly_password';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE llm_observatory_test TO test_readonly;
GRANT USAGE ON SCHEMA public TO test_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO test_readonly;

-- Log schema creation
DO $$
BEGIN
    RAISE NOTICE 'Test schema initialized successfully';
    RAISE NOTICE 'Tables created: users, projects, api_keys, llm_traces, llm_spans, llm_events, metrics, token_usage, costs';
    RAISE NOTICE 'Continuous aggregates created: metrics_hourly, token_usage_daily';
END
$$;

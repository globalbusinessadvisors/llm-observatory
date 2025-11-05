-- Migration: 003_create_indexes.sql
-- Description: Create all indexes for optimal query performance
-- Date: 2025-11-05
-- Author: LLM Observatory Core Team
-- Sections: 4.1 (Primary), 4.2 (Composite), 4.3 (Partial)

BEGIN;

-- ============================================================================
-- Section 4.1: Primary Indexes for llm_traces
-- ============================================================================

-- Trace ID lookup (find all spans in a trace)
CREATE INDEX IF NOT EXISTS idx_traces_trace_id
ON llm_traces (trace_id, ts DESC);

-- Provider and model filtering (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_traces_provider_model
ON llm_traces (provider, model, ts DESC);

-- User ID filtering (cost tracking per user)
-- Partial index: only index rows where user_id is not NULL
CREATE INDEX IF NOT EXISTS idx_traces_user_id
ON llm_traces (user_id, ts DESC)
WHERE user_id IS NOT NULL;

-- Session ID filtering (conversation tracking)
-- Partial index: only index rows where session_id is not NULL
CREATE INDEX IF NOT EXISTS idx_traces_session_id
ON llm_traces (session_id, ts DESC)
WHERE session_id IS NOT NULL;

-- Status code filtering (error analysis)
CREATE INDEX IF NOT EXISTS idx_traces_status
ON llm_traces (status_code, ts DESC);

-- Cost analysis (expensive requests)
-- Partial index: only index rows with cost data
CREATE INDEX IF NOT EXISTS idx_traces_cost
ON llm_traces (total_cost_usd DESC, ts DESC)
WHERE total_cost_usd > 0;

-- BRIN index for time-range queries (very efficient for time-series)
-- Much smaller than B-tree, ideal for timestamp queries
CREATE INDEX IF NOT EXISTS idx_traces_ts_brin
ON llm_traces USING BRIN (ts)
WITH (pages_per_range = 128);

-- GIN index for JSONB attributes (complex queries on metadata)
CREATE INDEX IF NOT EXISTS idx_traces_attributes
ON llm_traces USING GIN (attributes);

-- GIN index for array tags (tag-based filtering)
CREATE INDEX IF NOT EXISTS idx_traces_tags
ON llm_traces USING GIN (tags);

-- ============================================================================
-- Section 4.2: Composite Indexes for Common Query Patterns
-- ============================================================================

-- Provider and status combination (error rates by provider)
CREATE INDEX IF NOT EXISTS idx_traces_provider_status
ON llm_traces (provider, status_code, ts DESC);

-- Model and duration (latency analysis by model)
CREATE INDEX IF NOT EXISTS idx_traces_model_duration
ON llm_traces (model, duration_ms DESC, ts DESC);

-- Cost analysis queries (provider, model, cost)
-- Partial index: only rows with cost data
CREATE INDEX IF NOT EXISTS idx_traces_cost_analysis
ON llm_traces (provider, model, total_cost_usd DESC, ts DESC)
WHERE total_cost_usd IS NOT NULL;

-- ============================================================================
-- Section 4.3: Partial Indexes for Specific Scenarios
-- ============================================================================

-- Errors only (much smaller index, faster error queries)
CREATE INDEX IF NOT EXISTS idx_traces_errors
ON llm_traces (ts DESC, provider, model)
WHERE status_code = 'ERROR';

-- Expensive requests only (>$1.00 per request)
CREATE INDEX IF NOT EXISTS idx_traces_expensive
ON llm_traces (ts DESC, total_cost_usd DESC)
WHERE total_cost_usd > 1.0;

-- Slow requests only (>5 seconds)
CREATE INDEX IF NOT EXISTS idx_traces_slow
ON llm_traces (ts DESC, duration_ms DESC)
WHERE duration_ms > 5000;

-- ============================================================================
-- Indexes for llm_metrics (minimal - continuous aggregates preferred)
-- ============================================================================

-- Metric name and provider lookup
CREATE INDEX IF NOT EXISTS idx_metrics_name_provider
ON llm_metrics (metric_name, provider, model, ts DESC);

-- Environment filtering
CREATE INDEX IF NOT EXISTS idx_metrics_environment
ON llm_metrics (environment, ts DESC)
WHERE environment IS NOT NULL;

-- ============================================================================
-- Indexes for llm_logs
-- ============================================================================

-- Trace correlation (find logs for a trace)
CREATE INDEX IF NOT EXISTS idx_logs_trace_id
ON llm_logs (trace_id, ts DESC)
WHERE trace_id IS NOT NULL;

-- Log level filtering (error logs)
CREATE INDEX IF NOT EXISTS idx_logs_level
ON llm_logs (log_level, ts DESC);

-- Provider filtering
CREATE INDEX IF NOT EXISTS idx_logs_provider
ON llm_logs (provider, ts DESC)
WHERE provider IS NOT NULL;

-- Full-text search on log messages (if needed)
-- Uncomment if you need text search on log messages
-- CREATE INDEX IF NOT EXISTS idx_logs_message_fts
-- ON llm_logs USING GIN (to_tsvector('english', message));

COMMIT;

-- ============================================================================
-- Index Statistics and Verification
-- ============================================================================
-- Run these queries to verify index creation and estimate sizes:
--
-- SELECT
--     schemaname,
--     tablename,
--     indexname,
--     pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--     AND tablename IN ('llm_traces', 'llm_metrics', 'llm_logs')
-- ORDER BY pg_relation_size(indexname::regclass) DESC;

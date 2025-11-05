-- Migration: 002_add_hypertables.sql
-- Description: Convert tables to TimescaleDB hypertables with optimized chunk intervals
-- Date: 2025-11-05
-- Author: LLM Observatory Core Team
-- Prerequisites: Requires TimescaleDB extension enabled

BEGIN;

-- ============================================================================
-- Enable TimescaleDB Extension
-- ============================================================================
-- Create extension if not already enabled
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- ============================================================================
-- Convert llm_traces to Hypertable (Section 3.1)
-- ============================================================================
-- Chunk interval: 1 day (optimal for 7-day hot retention)
-- This partitions data into daily chunks for efficient querying and retention

SELECT create_hypertable(
    'llm_traces',
    'ts',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

COMMENT ON TABLE llm_traces IS 'LLM trace data - Hypertable partitioned by timestamp (1-day chunks)';

-- ============================================================================
-- Convert llm_metrics to Hypertable (Section 3.1)
-- ============================================================================
-- Chunk interval: 1 hour (higher write frequency for metrics)
-- Smaller chunks allow for more granular compression and retention

SELECT create_hypertable(
    'llm_metrics',
    'ts',
    chunk_time_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

COMMENT ON TABLE llm_metrics IS 'LLM metrics - Hypertable partitioned by timestamp (1-hour chunks)';

-- ============================================================================
-- Convert llm_logs to Hypertable (Section 3.1)
-- ============================================================================
-- Chunk interval: 1 day (similar to traces)

SELECT create_hypertable(
    'llm_logs',
    'ts',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

COMMENT ON TABLE llm_logs IS 'LLM logs - Hypertable partitioned by timestamp (1-day chunks)';

-- ============================================================================
-- Optional: Space Partitioning (Section 3.2)
-- ============================================================================
-- Uncomment the following if you need multi-dimensional partitioning
-- for very high scale (>50M traces/day)
--
-- This partitions data by provider in addition to time, enabling
-- parallel query execution across providers

-- SELECT add_dimension(
--     'llm_traces',
--     'provider',
--     number_partitions => 4,  -- openai, anthropic, google, others
--     if_not_exists => TRUE
-- );

COMMIT;

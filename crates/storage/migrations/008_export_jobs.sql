-- Migration 008: Export Jobs
--
-- This migration creates the infrastructure for export job management including:
-- - Export jobs table for tracking async export operations
-- - Indexes for efficient job queries
-- - Cleanup function for expired jobs

-- ============================================================================
-- Export Jobs Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS export_jobs (
    -- Primary identifier
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Organization ownership
    org_id TEXT NOT NULL,

    -- Job status
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled', 'expired')),

    -- Export configuration
    format TEXT NOT NULL CHECK (format IN ('csv', 'json', 'jsonl')),
    compression TEXT NOT NULL DEFAULT 'none' CHECK (compression IN ('none', 'gzip')),

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,

    -- Results
    trace_count BIGINT,
    file_size_bytes BIGINT,
    file_path TEXT,
    error_message TEXT,
    progress_percent INTEGER CHECK (progress_percent >= 0 AND progress_percent <= 100),

    -- Filter parameters (used for the export query)
    filter_start_time TIMESTAMPTZ,
    filter_end_time TIMESTAMPTZ,
    filter_provider TEXT,
    filter_model TEXT,
    filter_environment TEXT,
    filter_user_id TEXT,
    filter_status_code TEXT,
    filter_limit INTEGER NOT NULL DEFAULT 100000 CHECK (filter_limit > 0 AND filter_limit <= 1000000)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_export_jobs_org_id ON export_jobs(org_id);
CREATE INDEX IF NOT EXISTS idx_export_jobs_status ON export_jobs(status);
CREATE INDEX IF NOT EXISTS idx_export_jobs_created_at ON export_jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_export_jobs_org_status_created ON export_jobs(org_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_export_jobs_expires_at ON export_jobs(expires_at) WHERE expires_at IS NOT NULL;

-- Compound index for common queries
CREATE INDEX IF NOT EXISTS idx_export_jobs_lookup ON export_jobs(org_id, job_id)
WHERE status IN ('pending', 'processing', 'completed');

-- ============================================================================
-- Cleanup Function
-- ============================================================================

-- Function to mark expired jobs
CREATE OR REPLACE FUNCTION mark_expired_export_jobs()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    -- Mark jobs as expired if their expiration time has passed
    UPDATE export_jobs
    SET status = 'expired'
    WHERE status = 'completed'
      AND expires_at IS NOT NULL
      AND expires_at < NOW()
      AND status != 'expired';

    GET DIAGNOSTICS updated_count = ROW_COUNT;

    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Function to delete old expired jobs
CREATE OR REPLACE FUNCTION cleanup_expired_export_jobs(retention_days INTEGER DEFAULT 7)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete expired jobs older than retention period
    DELETE FROM export_jobs
    WHERE status = 'expired'
      AND created_at < NOW() - (retention_days || ' days')::INTERVAL;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Function to get export job statistics
CREATE OR REPLACE FUNCTION get_export_job_statistics(p_org_id TEXT, p_days INTEGER DEFAULT 30)
RETURNS TABLE (
    total_jobs BIGINT,
    pending_jobs BIGINT,
    processing_jobs BIGINT,
    completed_jobs BIGINT,
    failed_jobs BIGINT,
    cancelled_jobs BIGINT,
    expired_jobs BIGINT,
    total_traces_exported BIGINT,
    total_bytes_exported BIGINT,
    avg_export_time_seconds NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT AS total_jobs,
        COUNT(*) FILTER (WHERE status = 'pending')::BIGINT AS pending_jobs,
        COUNT(*) FILTER (WHERE status = 'processing')::BIGINT AS processing_jobs,
        COUNT(*) FILTER (WHERE status = 'completed')::BIGINT AS completed_jobs,
        COUNT(*) FILTER (WHERE status = 'failed')::BIGINT AS failed_jobs,
        COUNT(*) FILTER (WHERE status = 'cancelled')::BIGINT AS cancelled_jobs,
        COUNT(*) FILTER (WHERE status = 'expired')::BIGINT AS expired_jobs,
        COALESCE(SUM(trace_count), 0)::BIGINT AS total_traces_exported,
        COALESCE(SUM(file_size_bytes), 0)::BIGINT AS total_bytes_exported,
        AVG(EXTRACT(EPOCH FROM (completed_at - started_at)))::NUMERIC AS avg_export_time_seconds
    FROM export_jobs
    WHERE org_id = p_org_id
      AND created_at >= NOW() - (p_days || ' days')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON TABLE export_jobs IS 'Tracks async export jobs for trace data exports';
COMMENT ON COLUMN export_jobs.job_id IS 'Unique identifier for the export job';
COMMENT ON COLUMN export_jobs.org_id IS 'Organization that owns this export job';
COMMENT ON COLUMN export_jobs.status IS 'Current status of the export job';
COMMENT ON COLUMN export_jobs.format IS 'Export format (csv, json, jsonl)';
COMMENT ON COLUMN export_jobs.compression IS 'Compression format applied to export';
COMMENT ON COLUMN export_jobs.created_at IS 'When the export job was created';
COMMENT ON COLUMN export_jobs.started_at IS 'When the export job started processing';
COMMENT ON COLUMN export_jobs.completed_at IS 'When the export job finished';
COMMENT ON COLUMN export_jobs.expires_at IS 'When the download link expires';
COMMENT ON COLUMN export_jobs.trace_count IS 'Number of traces exported';
COMMENT ON COLUMN export_jobs.file_size_bytes IS 'Size of the exported file in bytes';
COMMENT ON COLUMN export_jobs.file_path IS 'Path to the exported file (for internal use)';
COMMENT ON COLUMN export_jobs.error_message IS 'Error message if the job failed';
COMMENT ON COLUMN export_jobs.progress_percent IS 'Progress percentage (0-100)';
COMMENT ON COLUMN export_jobs.filter_start_time IS 'Filter parameter: start time';
COMMENT ON COLUMN export_jobs.filter_end_time IS 'Filter parameter: end time';
COMMENT ON COLUMN export_jobs.filter_provider IS 'Filter parameter: provider';
COMMENT ON COLUMN export_jobs.filter_model IS 'Filter parameter: model';
COMMENT ON COLUMN export_jobs.filter_environment IS 'Filter parameter: environment';
COMMENT ON COLUMN export_jobs.filter_user_id IS 'Filter parameter: user ID';
COMMENT ON COLUMN export_jobs.filter_status_code IS 'Filter parameter: status code';
COMMENT ON COLUMN export_jobs.filter_limit IS 'Maximum number of traces to export';

COMMENT ON FUNCTION mark_expired_export_jobs() IS 'Marks completed export jobs as expired when their expiration time has passed';
COMMENT ON FUNCTION cleanup_expired_export_jobs(INTEGER) IS 'Deletes expired export jobs older than the specified retention period';
COMMENT ON FUNCTION get_export_job_statistics(TEXT, INTEGER) IS 'Returns statistics about export jobs for an organization';

-- ============================================================================
-- Example Usage
-- ============================================================================

-- Mark expired jobs (should be run periodically, e.g., every hour)
-- SELECT mark_expired_export_jobs();

-- Cleanup old expired jobs (keep last 7 days)
-- SELECT cleanup_expired_export_jobs(7);

-- Get export statistics for an organization
-- SELECT * FROM get_export_job_statistics('org_123', 30);

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- Verify table was created successfully
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_name = 'export_jobs'
    ) THEN
        RAISE NOTICE 'Migration 008: Export jobs table created successfully';
    ELSE
        RAISE EXCEPTION 'Migration 008: Failed to create export_jobs table';
    END IF;
END $$;

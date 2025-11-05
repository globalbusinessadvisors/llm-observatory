-- Migration: 007_fulltext_search.sql
-- Description: Add full-text search capabilities with GIN indexes for trace content
-- Date: 2025-11-05
-- Author: LLM Observatory Core Team - Phase 2
-- Purpose: Enable fast full-text search on input_text and output_text fields
--          using PostgreSQL's native FTS with tsvector and GIN indexing

BEGIN;

-- ============================================================================
-- Section 7.1: Add tsvector columns for full-text search
-- ============================================================================

-- Add tsvector column for input text search
-- This stores the pre-computed full-text search vector for input_text
ALTER TABLE llm_traces
ADD COLUMN IF NOT EXISTS input_text_search tsvector;

-- Add tsvector column for output text search
-- This stores the pre-computed full-text search vector for output_text
ALTER TABLE llm_traces
ADD COLUMN IF NOT EXISTS output_text_search tsvector;

-- Add combined tsvector column for searching both input and output
-- This allows searching across both fields in a single query
ALTER TABLE llm_traces
ADD COLUMN IF NOT EXISTS content_search tsvector;

-- ============================================================================
-- Section 7.2: Populate tsvector columns with existing data
-- ============================================================================

-- Populate input_text_search for existing rows
-- Using 'english' dictionary for stemming and stop word removal
-- COALESCE handles NULL values by providing empty string
UPDATE llm_traces
SET input_text_search = to_tsvector('english', COALESCE(input_text, ''))
WHERE input_text_search IS NULL AND input_text IS NOT NULL;

-- Populate output_text_search for existing rows
UPDATE llm_traces
SET output_text_search = to_tsvector('english', COALESCE(output_text, ''))
WHERE output_text_search IS NULL AND output_text IS NOT NULL;

-- Populate combined content_search for existing rows
-- Concatenates input and output with space separator
-- Weight 'A' for input (higher importance) and 'B' for output
UPDATE llm_traces
SET content_search =
    setweight(to_tsvector('english', COALESCE(input_text, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(output_text, '')), 'B')
WHERE content_search IS NULL;

-- ============================================================================
-- Section 7.3: Create GIN indexes for fast full-text search
-- ============================================================================

-- GIN index for input text search
-- This enables fast full-text queries on input_text
-- Typical query: WHERE input_text_search @@ to_tsquery('search terms')
CREATE INDEX IF NOT EXISTS idx_traces_input_text_fts
ON llm_traces USING GIN (input_text_search);

-- GIN index for output text search
-- This enables fast full-text queries on output_text
-- Typical query: WHERE output_text_search @@ to_tsquery('search terms')
CREATE INDEX IF NOT EXISTS idx_traces_output_text_fts
ON llm_traces USING GIN (output_text_search);

-- GIN index for combined content search (most commonly used)
-- This enables searching across both input and output in a single query
-- Typical query: WHERE content_search @@ to_tsquery('search terms')
CREATE INDEX IF NOT EXISTS idx_traces_content_fts
ON llm_traces USING GIN (content_search);

-- ============================================================================
-- Section 7.4: Create triggers to auto-update tsvector columns
-- ============================================================================

-- Trigger function to automatically update tsvector columns on INSERT/UPDATE
-- This ensures the search vectors stay in sync with the text content
CREATE OR REPLACE FUNCTION llm_traces_search_vector_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Update input_text_search
    NEW.input_text_search := to_tsvector('english', COALESCE(NEW.input_text, ''));

    -- Update output_text_search
    NEW.output_text_search := to_tsvector('english', COALESCE(NEW.output_text, ''));

    -- Update combined content_search with weights
    NEW.content_search :=
        setweight(to_tsvector('english', COALESCE(NEW.input_text, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.output_text, '')), 'B');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on INSERT/UPDATE
-- BEFORE trigger ensures tsvector is computed before row is written
DROP TRIGGER IF EXISTS trig_traces_search_vector_update ON llm_traces;
CREATE TRIGGER trig_traces_search_vector_update
    BEFORE INSERT OR UPDATE OF input_text, output_text
    ON llm_traces
    FOR EACH ROW
    EXECUTE FUNCTION llm_traces_search_vector_update();

-- ============================================================================
-- Section 7.5: Create helper functions for full-text search
-- ============================================================================

-- Function to search traces with ranking
-- Returns traces that match the search query, sorted by relevance
CREATE OR REPLACE FUNCTION search_traces(
    search_query text,
    max_results integer DEFAULT 100
)
RETURNS TABLE (
    ts timestamptz,
    trace_id text,
    span_id text,
    provider text,
    model text,
    input_text text,
    output_text text,
    rank real
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.ts,
        t.trace_id,
        t.span_id,
        t.provider,
        t.model,
        t.input_text,
        t.output_text,
        ts_rank(t.content_search, query) AS rank
    FROM
        llm_traces t,
        plainto_tsquery('english', search_query) query
    WHERE
        t.content_search @@ query
    ORDER BY
        rank DESC,
        t.ts DESC
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to search with phrase query (exact phrase matching)
CREATE OR REPLACE FUNCTION search_traces_phrase(
    search_phrase text,
    max_results integer DEFAULT 100
)
RETURNS TABLE (
    ts timestamptz,
    trace_id text,
    span_id text,
    provider text,
    model text,
    input_text text,
    output_text text,
    rank real
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.ts,
        t.trace_id,
        t.span_id,
        t.provider,
        t.model,
        t.input_text,
        t.output_text,
        ts_rank(t.content_search, query) AS rank
    FROM
        llm_traces t,
        phraseto_tsquery('english', search_phrase) query
    WHERE
        t.content_search @@ query
    ORDER BY
        rank DESC,
        t.ts DESC
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get search statistics
CREATE OR REPLACE FUNCTION get_search_index_stats()
RETURNS TABLE (
    table_name text,
    index_name text,
    index_size text,
    rows_with_search_vector bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        'llm_traces'::text,
        'idx_traces_content_fts'::text,
        pg_size_pretty(pg_relation_size('idx_traces_content_fts')) AS index_size,
        COUNT(*) AS rows_with_search_vector
    FROM llm_traces
    WHERE content_search IS NOT NULL;
END;
$$ LANGUAGE plpgsql STABLE;

COMMIT;

-- ============================================================================
-- Usage Examples and Performance Notes
-- ============================================================================

-- Example 1: Basic full-text search (most common)
-- SELECT * FROM llm_traces
-- WHERE content_search @@ plainto_tsquery('english', 'error authentication failed')
-- ORDER BY ts DESC
-- LIMIT 100;

-- Example 2: Search with ranking (best relevance first)
-- SELECT
--     ts, trace_id, provider, model,
--     ts_rank(content_search, query) AS rank
-- FROM llm_traces, plainto_tsquery('english', 'user login') query
-- WHERE content_search @@ query
-- ORDER BY rank DESC, ts DESC
-- LIMIT 50;

-- Example 3: Search only in input text
-- SELECT * FROM llm_traces
-- WHERE input_text_search @@ to_tsquery('english', 'prompt & generation')
-- ORDER BY ts DESC;

-- Example 4: Search only in output text
-- SELECT * FROM llm_traces
-- WHERE output_text_search @@ to_tsquery('english', 'error | failure')
-- ORDER BY ts DESC;

-- Example 5: Phrase search (exact phrase)
-- SELECT * FROM llm_traces
-- WHERE content_search @@ phraseto_tsquery('english', 'internal server error')
-- ORDER BY ts DESC;

-- Example 6: Combined with other filters
-- SELECT * FROM llm_traces
-- WHERE provider = 'openai'
--   AND model = 'gpt-4'
--   AND content_search @@ plainto_tsquery('english', 'authentication')
--   AND ts > NOW() - INTERVAL '7 days'
-- ORDER BY ts DESC;

-- Example 7: Use the helper function
-- SELECT * FROM search_traces('authentication error', 50);

-- Example 8: Get index statistics
-- SELECT * FROM get_search_index_stats();

-- ============================================================================
-- Performance Notes
-- ============================================================================

-- 1. GIN indexes are larger than B-tree but much faster for full-text search
-- 2. The tsvector columns add ~20-30% storage overhead
-- 3. The trigger adds minimal overhead to INSERT/UPDATE operations
-- 4. Use plainto_tsquery() for simple queries, to_tsquery() for advanced
-- 5. phraseto_tsquery() for exact phrase matching
-- 6. ts_rank() adds some CPU cost but provides relevance sorting
-- 7. Consider using ts_rank_cd() for more accurate ranking with document length
-- 8. The 'english' dictionary provides stemming (run/running/ran -> run)
-- 9. For multilingual support, create additional tsvector columns with different dictionaries
-- 10. Monitor index size with: SELECT pg_size_pretty(pg_relation_size('idx_traces_content_fts'));

-- ============================================================================
-- Index Maintenance
-- ============================================================================

-- Rebuild indexes if they become bloated (after large DELETE operations)
-- REINDEX INDEX CONCURRENTLY idx_traces_content_fts;
-- REINDEX INDEX CONCURRENTLY idx_traces_input_text_fts;
-- REINDEX INDEX CONCURRENTLY idx_traces_output_text_fts;

-- Analyze table after migration to update statistics
-- ANALYZE llm_traces;

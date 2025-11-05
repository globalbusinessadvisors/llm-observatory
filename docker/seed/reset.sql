-- Reset development database to clean state
-- WARNING: This will delete ALL data!
-- Run with: psql -h localhost -U postgres -d llm_observatory < reset.sql

\c llm_observatory

BEGIN;

-- Drop continuous aggregates first (depends on metrics table)
DROP MATERIALIZED VIEW IF EXISTS metrics_hourly CASCADE;

-- Drop tables in reverse order of dependencies
DROP TABLE IF EXISTS llm_attributes CASCADE;
DROP TABLE IF EXISTS metrics CASCADE;
DROP TABLE IF EXISTS traces CASCADE;

-- Drop any other development tables
-- Add more DROP statements here as needed

COMMIT;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Database reset completed successfully!';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'All tables and data have been removed.';
    RAISE NOTICE 'Run seed.sql to repopulate with sample data.';
    RAISE NOTICE '==============================================';
END
$$;

-- Initialize TimescaleDB for LLM Observatory
-- This script runs automatically when the database container starts

-- Create the main database if it doesn't exist
-- Note: This script runs in the postgres database context
SELECT 'CREATE DATABASE llm_observatory'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'llm_observatory')\gexec

-- Connect to the llm_observatory database
\c llm_observatory

-- Install TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Verify TimescaleDB installation
SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';

-- Create roles for different access levels
DO $$
BEGIN
    -- Application user with read/write access
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'llm_observatory_app') THEN
        CREATE ROLE llm_observatory_app WITH LOGIN PASSWORD 'change_me_in_production';
    END IF;

    -- Read-only user for analytics/reporting
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'llm_observatory_readonly') THEN
        CREATE ROLE llm_observatory_readonly WITH LOGIN PASSWORD 'change_me_readonly';
    END IF;
END
$$;

-- Grant database connection privileges
GRANT CONNECT ON DATABASE llm_observatory TO llm_observatory_app;
GRANT CONNECT ON DATABASE llm_observatory TO llm_observatory_readonly;

-- Grant schema usage (this will need to be extended once schemas are created)
GRANT USAGE ON SCHEMA public TO llm_observatory_app;
GRANT USAGE ON SCHEMA public TO llm_observatory_readonly;

-- Grant default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO llm_observatory_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO llm_observatory_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO llm_observatory_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO llm_observatory_readonly;

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- For UUID generation
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";  -- For query performance monitoring

-- Set optimal TimescaleDB settings for development
-- These can be adjusted based on workload
ALTER DATABASE llm_observatory SET timescaledb.max_background_workers = 8;

-- Log successful initialization
DO $$
BEGIN
    RAISE NOTICE 'TimescaleDB initialization completed successfully';
    RAISE NOTICE 'Database: llm_observatory';
    RAISE NOTICE 'TimescaleDB version: %', (SELECT extversion FROM pg_extension WHERE extname = 'timescaledb');
END
$$;

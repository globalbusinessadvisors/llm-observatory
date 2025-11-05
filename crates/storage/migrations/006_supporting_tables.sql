-- Migration: 006_supporting_tables.sql
-- Description: Create supporting tables for pricing, authentication, and organization
-- Date: 2025-11-05
-- Author: LLM Observatory Core Team
-- Sections: 2.4.1 (Pricing), 2.4.2 (API Keys), 2.4.3 (Projects/Users)

BEGIN;

-- ============================================================================
-- Section 2.4.1: Model Pricing History
-- ============================================================================
-- Purpose: Track pricing changes over time for accurate cost calculation
-- Used by cost calculator to apply historical pricing

CREATE TABLE IF NOT EXISTS model_pricing (
    id                      SERIAL PRIMARY KEY,
    effective_date          TIMESTAMPTZ NOT NULL,
    provider                TEXT NOT NULL,
    model                   TEXT NOT NULL,
    prompt_cost_per_1k      DECIMAL(12, 8) NOT NULL,        -- Cost per 1K prompt tokens
    completion_cost_per_1k  DECIMAL(12, 8) NOT NULL,        -- Cost per 1K completion tokens
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure unique pricing per provider/model/date
    UNIQUE (provider, model, effective_date)
);

-- Index for fast pricing lookups
CREATE INDEX IF NOT EXISTS idx_pricing_lookup
ON model_pricing (provider, model, effective_date DESC);

COMMENT ON TABLE model_pricing IS 'Historical pricing data for LLM models';
COMMENT ON COLUMN model_pricing.effective_date IS 'Date when this pricing becomes effective';
COMMENT ON COLUMN model_pricing.prompt_cost_per_1k IS 'Cost per 1,000 prompt tokens in USD';
COMMENT ON COLUMN model_pricing.completion_cost_per_1k IS 'Cost per 1,000 completion tokens in USD';

-- ============================================================================
-- Section 2.4.2: API Keys & Authentication
-- ============================================================================
-- Purpose: Manage API keys for accessing LLM Observatory API
-- Security: Stores SHA-256 hash, never plain text

CREATE TABLE IF NOT EXISTS api_keys (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key_hash                TEXT NOT NULL UNIQUE,           -- SHA-256 hash of API key
    key_prefix              TEXT NOT NULL,                  -- First 8 chars (for identification)
    name                    TEXT NOT NULL,                  -- Human-readable name
    user_id                 TEXT,                           -- Owner (links to users table)
    scopes                  TEXT[],                         -- read, write, admin
    rate_limit_rpm          INTEGER DEFAULT 60,             -- Requests per minute
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at              TIMESTAMPTZ,                    -- Optional expiration
    last_used_at            TIMESTAMPTZ,                    -- Track usage
    is_active               BOOLEAN NOT NULL DEFAULT true
);

-- Index for authentication lookups (primary use case)
CREATE INDEX IF NOT EXISTS idx_api_keys_hash
ON api_keys (key_hash)
WHERE is_active = true;

-- Index for user management
CREATE INDEX IF NOT EXISTS idx_api_keys_user
ON api_keys (user_id)
WHERE is_active = true;

-- Index for expiration cleanup
CREATE INDEX IF NOT EXISTS idx_api_keys_expires
ON api_keys (expires_at)
WHERE expires_at IS NOT NULL AND is_active = true;

COMMENT ON TABLE api_keys IS 'API key management for authentication and authorization';
COMMENT ON COLUMN api_keys.key_hash IS 'SHA-256 hash of the API key (never store plain text)';
COMMENT ON COLUMN api_keys.key_prefix IS 'First 8 characters for display (e.g., "llm_obs_")';
COMMENT ON COLUMN api_keys.scopes IS 'Array of permissions: read, write, admin';
COMMENT ON COLUMN api_keys.rate_limit_rpm IS 'Rate limit in requests per minute';

-- ============================================================================
-- Section 2.4.3: Users Table
-- ============================================================================
-- Purpose: Store user account information
-- Links to: api_keys, projects (ownership)

CREATE TABLE IF NOT EXISTS users (
    id                      TEXT PRIMARY KEY,               -- External user ID (from auth provider)
    email                   TEXT UNIQUE,
    name                    TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata                JSONB                           -- Additional user metadata
);

-- Index for email lookups
CREATE INDEX IF NOT EXISTS idx_users_email
ON users (email)
WHERE email IS NOT NULL;

COMMENT ON TABLE users IS 'User accounts for LLM Observatory';
COMMENT ON COLUMN users.id IS 'External user ID from authentication provider';
COMMENT ON COLUMN users.metadata IS 'Additional user metadata as JSONB';

-- ============================================================================
-- Section 2.4.3: Projects Table
-- ============================================================================
-- Purpose: Organize traces into projects/workspaces
-- Multi-tenancy: Each project has isolated data

CREATE TABLE IF NOT EXISTS projects (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                    TEXT NOT NULL,
    slug                    TEXT NOT NULL UNIQUE,           -- URL-friendly identifier
    owner_id                TEXT NOT NULL,                  -- References users(id)
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settings                JSONB                           -- Project settings (sampling, retention, etc.)
);

-- Index for owner lookups
CREATE INDEX IF NOT EXISTS idx_projects_owner
ON projects (owner_id);

-- Index for slug lookups (common in URLs)
CREATE INDEX IF NOT EXISTS idx_projects_slug
ON projects (slug);

COMMENT ON TABLE projects IS 'Project/workspace organization for multi-tenancy';
COMMENT ON COLUMN projects.slug IS 'URL-friendly identifier (e.g., "my-app-prod")';
COMMENT ON COLUMN projects.owner_id IS 'User who owns this project (references users.id)';
COMMENT ON COLUMN projects.settings IS 'Project-specific settings as JSONB';

-- ============================================================================
-- Foreign Key Constraints
-- ============================================================================
-- Add foreign key constraints for referential integrity

-- API keys reference users
ALTER TABLE api_keys
ADD CONSTRAINT fk_api_keys_user
FOREIGN KEY (user_id)
REFERENCES users(id)
ON DELETE CASCADE;

-- Projects reference users
ALTER TABLE projects
ADD CONSTRAINT fk_projects_owner
FOREIGN KEY (owner_id)
REFERENCES users(id)
ON DELETE CASCADE;

COMMIT;

-- ============================================================================
-- Seed Data (Optional)
-- ============================================================================
-- Uncomment to insert sample pricing data for common models
--
-- INSERT INTO model_pricing (effective_date, provider, model, prompt_cost_per_1k, completion_cost_per_1k)
-- VALUES
--     -- OpenAI GPT-4 (as of 2025-11)
--     ('2025-11-01', 'openai', 'gpt-4', 0.03, 0.06),
--     ('2025-11-01', 'openai', 'gpt-4-32k', 0.06, 0.12),
--     ('2025-11-01', 'openai', 'gpt-4-turbo', 0.01, 0.03),
--     ('2025-11-01', 'openai', 'gpt-3.5-turbo', 0.0015, 0.002),
--
--     -- Anthropic Claude (as of 2025-11)
--     ('2025-11-01', 'anthropic', 'claude-3-opus', 0.015, 0.075),
--     ('2025-11-01', 'anthropic', 'claude-3-sonnet', 0.003, 0.015),
--     ('2025-11-01', 'anthropic', 'claude-3-haiku', 0.00025, 0.00125),
--
--     -- Google (as of 2025-11)
--     ('2025-11-01', 'google', 'gemini-pro', 0.00025, 0.0005),
--     ('2025-11-01', 'google', 'gemini-pro-vision', 0.00025, 0.0005)
-- ON CONFLICT (provider, model, effective_date) DO NOTHING;

-- ============================================================================
-- Verification Queries
-- ============================================================================
-- Run these queries to verify table creation:
--
-- -- List all tables
-- SELECT tablename
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;
--
-- -- Verify foreign keys
-- SELECT
--     conname AS constraint_name,
--     conrelid::regclass AS table_name,
--     confrelid::regclass AS referenced_table
-- FROM pg_constraint
-- WHERE contype = 'f'
--     AND connamespace = 'public'::regnamespace;
--
-- -- Check indexes
-- SELECT
--     tablename,
--     indexname,
--     indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--     AND tablename IN ('model_pricing', 'api_keys', 'users', 'projects')
-- ORDER BY tablename, indexname;

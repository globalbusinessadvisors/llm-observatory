# Test Data Seeds

This directory contains seed scripts and data for populating the test database with various datasets.

## Overview

Test seeds are organized by data size and use case:

- **minimal**: Bare minimum data for basic functionality tests (1-10 records per table)
- **small**: Small dataset for integration tests (100s of records)
- **medium**: Medium dataset for performance testing (1000s of records)
- **large**: Large dataset for scale testing (10000s of records)

## Usage

### Using Docker Compose

```bash
# Seed with default (small) dataset
docker compose -f docker-compose.test.yml run --rm test-seeder

# Seed with specific size
SEED_DATA_SIZE=medium docker compose -f docker-compose.test.yml run --rm test-seeder

# Seed with large dataset
SEED_DATA_SIZE=large docker compose -f docker-compose.test.yml run --rm test-seeder
```

### Manual Seeding

```bash
# Set environment variables
export DATABASE_URL="postgres://test_user:test_password@localhost:5432/llm_observatory_test"
export REDIS_URL="redis://localhost:6379"
export SEED_DATA_SIZE="small"

# Run seed script
./docker/test/seed-test-data.sh
```

## Seed Data Structure

### Base Fixtures (All Sizes)

Always loaded regardless of size:

- **Users**: 5 test users with different roles
  - `admin@test.local` - Admin user
  - `user1@test.local` - Regular user
  - `user2@test.local` - Second user
  - `inactive@test.local` - Inactive user
  - `developer@test.local` - Developer user

- **Projects**: 4 test projects
  - Test Project 1 (admin)
  - Test Project 2 (user1)
  - Production Simulation (admin)
  - Development (developer)

- **API Keys**: 6 API keys with various permissions
  - Active keys with read/write/admin permissions
  - Read-only key
  - Expired key (for testing)
  - Inactive key (for testing)

### Size-Specific Data

#### Minimal (minimal)
- 10 LLM traces
- 50 spans
- 100 events
- 50 metrics
- Best for: Unit tests, quick validation

#### Small (small) - Default
- 100 LLM traces
- 500 spans
- 1,000 events
- 500 metrics
- Best for: Integration tests, standard CI/CD

#### Medium (medium)
- 1,000 LLM traces
- 5,000 spans
- 10,000 events
- 5,000 metrics
- Best for: Performance tests, load testing

#### Large (large)
- 10,000 LLM traces
- 50,000 spans
- 100,000 events
- 50,000 metrics
- Best for: Scale testing, stress testing

## Data Characteristics

### Realistic Distribution

Seeded data follows realistic patterns:

- **Models**: Distributed across popular LLM models
  - GPT-4, GPT-3.5-turbo (OpenAI)
  - Claude-3-opus, Claude-3-sonnet (Anthropic)
  - Gemini-pro (Google)

- **Response Times**: Random latencies between 100ms - 5000ms

- **Token Usage**: Realistic token counts
  - Prompt tokens: 10-1000
  - Completion tokens: 10-2000

- **Error Rates**: ~5% error rate for realistic testing

- **Time Distribution**: Data spread across last 7 days

### Relationships

Data maintains proper relationships:

- Traces → Spans (1:N)
- Spans → Events (1:N)
- Spans → Token Usage (1:1)
- Spans → Costs (1:1)
- Projects → Traces (1:N)
- Users → Projects (1:N)

## Fixtures Files

### users.json
Test user accounts with different roles and permissions.

### projects.json
Test projects with various configurations.

### api_keys.json
API keys for authentication testing.

### llm_models.json
LLM model configurations with pricing information.

### sample_traces.json
Sample trace data with spans, events, and metrics.

## Custom Seed Scripts

You can create custom seed scripts in this directory:

```bash
#!/bin/bash
# custom-seed.sh
set -e

# Your custom seeding logic
psql << EOF
INSERT INTO your_table (columns) VALUES (values);
EOF
```

Make it executable:
```bash
chmod +x docker/test/seeds/custom-seed.sh
```

## Cleaning Test Data

To clean old test data:

```sql
-- Clean data older than 7 days
SELECT * FROM cleanup_old_test_data(7);

-- Truncate all tables (reset database)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END $$;
```

## Environment Variables

- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `SEED_DATA_SIZE`: Size of dataset (minimal, small, medium, large)
- `FIXTURES_DIR`: Path to fixtures directory

## Verification

After seeding, verify data was loaded:

```sql
-- Check record counts
SELECT
    'Users: ' || COUNT(*) FROM users
UNION ALL
SELECT
    'Projects: ' || COUNT(*) FROM projects
UNION ALL
SELECT
    'Traces: ' || COUNT(*) FROM llm_traces
UNION ALL
SELECT
    'Spans: ' || COUNT(*) FROM llm_spans;
```

## Troubleshooting

### Database Connection Issues

```bash
# Check if database is ready
pg_isready -h localhost -p 5432 -U test_user

# Test connection
psql "postgres://test_user:test_password@localhost:5432/llm_observatory_test" -c "SELECT 1"
```

### Seed Script Fails

1. Ensure database schema is initialized
2. Check database permissions
3. Verify environment variables are set
4. Check logs for specific errors

### Performance Issues

For large datasets:
- Use tmpfs for test database (see docker-compose.test.yml)
- Disable fsync and synchronous commits
- Increase shared_buffers and work_mem
- Run ANALYZE after seeding

## Notes

- All passwords in test fixtures are hashed with Argon2
- Test data is generated with random but deterministic values
- Seeding is idempotent - can be run multiple times
- Data includes edge cases for comprehensive testing
- Timestamps are relative to current time for consistency

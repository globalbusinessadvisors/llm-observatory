# Database Seed Data

This directory contains SQL scripts for seeding the development database with sample data.

## Files

- **seed.sql** - Populates the database with sample traces, LLM attributes, and metrics
- **reset.sql** - Drops all tables and data to start fresh

## Usage

### Seeding the Database

From the host machine:
```bash
psql -h localhost -U postgres -d llm_observatory < docker/seed/seed.sql
```

From within the dev-utils container:
```bash
docker-compose -f docker-compose.yml -f docker/compose/docker-compose.dev.yml run --rm dev-utils sh -c "psql < /seed-data/seed.sql"
```

### Resetting the Database

From the host machine:
```bash
psql -h localhost -U postgres -d llm_observatory < docker/seed/reset.sql
```

From within the dev-utils container:
```bash
docker-compose -f docker-compose.yml -f docker/compose/docker-compose.dev.yml run --rm dev-utils sh -c "psql < /seed-data/reset.sql"
```

### Reset and Reseed

To completely reset and repopulate:
```bash
# From host
psql -h localhost -U postgres -d llm_observatory < docker/seed/reset.sql
psql -h localhost -U postgres -d llm_observatory < docker/seed/seed.sql

# From container
docker-compose -f docker-compose.yml -f docker/compose/docker-compose.dev.yml run --rm dev-utils sh -c "psql < /seed-data/reset.sql && psql < /seed-data/seed.sql"
```

## Sample Data

The seed script creates:

- **5 sample traces** from different LLM providers (OpenAI, Anthropic, Azure OpenAI)
- **4 LLM attribute records** with token counts, costs, and parameters
- **13 metrics** for request duration, token usage, and costs
- **Continuous aggregate** for hourly metrics rollups
- **Retention policies** to automatically drop old data
- **Compression policies** for efficient storage

## Tables Created

- `traces` - Main trace/span data (TimescaleDB hypertable)
- `llm_attributes` - LLM-specific metadata (tokens, costs, model parameters)
- `metrics` - Time-series metrics (TimescaleDB hypertable)
- `metrics_hourly` - Continuous aggregate for hourly rollups

## Sample Queries

After seeding, try these queries:

```sql
-- View all traces
SELECT * FROM traces ORDER BY start_time DESC;

-- View LLM attributes with costs
SELECT provider, model, total_tokens, cost_usd
FROM llm_attributes
ORDER BY created_at DESC;

-- View recent metrics
SELECT time, metric_name, tags->>'provider' as provider, value
FROM metrics
ORDER BY time DESC
LIMIT 20;

-- View hourly aggregates
SELECT * FROM metrics_hourly;

-- Average duration by provider
SELECT
    attributes->>'llm.provider' as provider,
    AVG(duration_ms) as avg_duration_ms,
    COUNT(*) as request_count
FROM traces
GROUP BY attributes->>'llm.provider';

-- Total tokens and cost by model
SELECT
    model,
    SUM(total_tokens) as total_tokens,
    SUM(cost_usd) as total_cost_usd,
    COUNT(*) as request_count
FROM llm_attributes
GROUP BY model
ORDER BY total_cost_usd DESC;
```

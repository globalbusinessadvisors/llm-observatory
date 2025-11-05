#!/bin/bash
# Seed test database with fixture data
# Supports multiple data sizes: minimal, small, medium, large

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
FIXTURES_DIR="${FIXTURES_DIR:-${WORKSPACE_DIR}/docker/test/fixtures}"
SEED_DATA_SIZE="${SEED_DATA_SIZE:-small}"
DATABASE_URL="${DATABASE_URL:-}"
REDIS_URL="${REDIS_URL:-}"

print_status() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                  LLM Observatory - Test Data Seeder${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# Validate configuration
if [ -z "${DATABASE_URL}" ]; then
    print_error "DATABASE_URL not set"
    exit 1
fi

print_status "Seed configuration:"
echo "  Data size: ${SEED_DATA_SIZE}"
echo "  Database: ${DATABASE_URL%%\?*}"
echo "  Fixtures: ${FIXTURES_DIR}"
echo ""

# Wait for database
print_status "Waiting for database..."
DB_HOST=$(echo "${DATABASE_URL}" | sed -n 's/.*@\(.*\):.*/\1/p')
DB_PORT=$(echo "${DATABASE_URL}" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')

max_attempts=30
attempt=1
while ! nc -z "${DB_HOST}" "${DB_PORT}" 2>/dev/null; do
    if [ ${attempt} -eq ${max_attempts} ]; then
        print_error "Database not available"
        exit 1
    fi
    echo -n "."
    sleep 1
    ((attempt++))
done
echo ""
print_status "Database ready!"

# Extract database connection details
DB_NAME=$(echo "${DATABASE_URL}" | sed -n 's/.*\/\([^?]*\).*/\1/p')
DB_USER=$(echo "${DATABASE_URL}" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
DB_PASS=$(echo "${DATABASE_URL}" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')

export PGHOST="${DB_HOST}"
export PGPORT="${DB_PORT}"
export PGDATABASE="${DB_NAME}"
export PGUSER="${DB_USER}"
export PGPASSWORD="${DB_PASS}"

# Run migrations first
if [ -d "${WORKSPACE_DIR}/migrations" ] && command -v sqlx &> /dev/null; then
    print_status "Running database migrations..."
    sqlx migrate run --source "${WORKSPACE_DIR}/migrations" || {
        print_error "Migration failed"
        exit 1
    }
fi

# Clear existing test data
print_status "Clearing existing test data..."
psql << EOF
-- Disable foreign key checks temporarily
SET session_replication_role = replica;

-- Clear test data from all tables
DO \$\$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END \$\$;

-- Re-enable foreign key checks
SET session_replication_role = DEFAULT;
EOF

print_status "Database cleared!"

# Load base fixtures
print_status "Loading base fixtures..."

# Users and authentication
print_status "  - Loading users..."
psql << 'EOF'
INSERT INTO users (id, email, username, password_hash, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'admin@test.local', 'admin', '$argon2id$v=19$m=19456,t=2,p=1$testtest$hash', NOW(), NOW()),
    ('00000000-0000-0000-0000-000000000002', 'user1@test.local', 'user1', '$argon2id$v=19$m=19456,t=2,p=1$testtest$hash', NOW(), NOW()),
    ('00000000-0000-0000-0000-000000000003', 'user2@test.local', 'user2', '$argon2id$v=19$m=19456,t=2,p=1$testtest$hash', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;
EOF

# Projects
print_status "  - Loading projects..."
psql << 'EOF'
INSERT INTO projects (id, name, description, owner_id, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000101', 'Test Project 1', 'Test project for integration tests', '00000000-0000-0000-0000-000000000001', NOW(), NOW()),
    ('00000000-0000-0000-0000-000000000102', 'Test Project 2', 'Another test project', '00000000-0000-0000-0000-000000000002', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;
EOF

# API Keys
print_status "  - Loading API keys..."
psql << 'EOF'
INSERT INTO api_keys (id, key_hash, name, project_id, created_at, expires_at)
VALUES
    ('00000000-0000-0000-0000-000000000201', 'test_key_hash_1', 'Test Key 1', '00000000-0000-0000-0000-000000000101', NOW(), NOW() + INTERVAL '1 year'),
    ('00000000-0000-0000-0000-000000000202', 'test_key_hash_2', 'Test Key 2', '00000000-0000-0000-0000-000000000102', NOW(), NOW() + INTERVAL '1 year')
ON CONFLICT (id) DO NOTHING;
EOF

# Load size-specific data
case "${SEED_DATA_SIZE}" in
    minimal)
        print_status "Loading minimal dataset (1-10 records per table)..."
        TRACE_COUNT=10
        SPAN_COUNT=50
        EVENT_COUNT=100
        ;;
    small)
        print_status "Loading small dataset (100s of records)..."
        TRACE_COUNT=100
        SPAN_COUNT=500
        EVENT_COUNT=1000
        ;;
    medium)
        print_status "Loading medium dataset (1000s of records)..."
        TRACE_COUNT=1000
        SPAN_COUNT=5000
        EVENT_COUNT=10000
        ;;
    large)
        print_status "Loading large dataset (10000s of records)..."
        TRACE_COUNT=10000
        SPAN_COUNT=50000
        EVENT_COUNT=100000
        ;;
    *)
        print_error "Invalid data size: ${SEED_DATA_SIZE}"
        exit 1
        ;;
esac

# Generate LLM traces
print_status "  - Generating ${TRACE_COUNT} LLM traces..."
psql << EOF
INSERT INTO llm_traces (id, project_id, trace_id, model, provider, created_at)
SELECT
    gen_random_uuid(),
    (ARRAY['00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000102'])[floor(random() * 2 + 1)],
    'trace_' || generate_series || '_' || extract(epoch from NOW())::text,
    (ARRAY['gpt-4', 'gpt-3.5-turbo', 'claude-3-opus', 'claude-3-sonnet'])[floor(random() * 4 + 1)],
    (ARRAY['openai', 'anthropic'])[floor(random() * 2 + 1)],
    NOW() - (random() * INTERVAL '7 days')
FROM generate_series(1, ${TRACE_COUNT});
EOF

# Generate spans
print_status "  - Generating ${SPAN_COUNT} spans..."
psql << EOF
INSERT INTO llm_spans (id, trace_id, span_id, parent_span_id, name, start_time, end_time, attributes)
SELECT
    gen_random_uuid(),
    (SELECT id FROM llm_traces ORDER BY random() LIMIT 1),
    'span_' || generate_series,
    CASE WHEN random() > 0.3 THEN 'span_' || floor(random() * generate_series)::text ELSE NULL END,
    (ARRAY['completion', 'embedding', 'chat', 'completion_stream'])[floor(random() * 4 + 1)],
    NOW() - (random() * INTERVAL '7 days'),
    NOW() - (random() * INTERVAL '7 days') + (random() * INTERVAL '1 hour'),
    jsonb_build_object(
        'temperature', random(),
        'max_tokens', floor(random() * 2000 + 100),
        'top_p', random()
    )
FROM generate_series(1, ${SPAN_COUNT});
EOF

# Generate events
print_status "  - Generating ${EVENT_COUNT} events..."
psql << EOF
INSERT INTO llm_events (id, span_id, event_type, timestamp, data)
SELECT
    gen_random_uuid(),
    (SELECT id FROM llm_spans ORDER BY random() LIMIT 1),
    (ARRAY['request', 'response', 'error', 'metric'])[floor(random() * 4 + 1)],
    NOW() - (random() * INTERVAL '7 days'),
    jsonb_build_object(
        'tokens', floor(random() * 1000),
        'latency_ms', floor(random() * 5000),
        'cost_usd', (random() * 0.5)::numeric(10,6)
    )
FROM generate_series(1, ${EVENT_COUNT});
EOF

# Generate metrics
print_status "  - Generating metrics..."
psql << EOF
INSERT INTO metrics (id, project_id, metric_name, value, timestamp, labels)
SELECT
    gen_random_uuid(),
    (ARRAY['00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000102'])[floor(random() * 2 + 1)],
    (ARRAY['request_count', 'error_rate', 'latency_p95', 'token_usage', 'cost'])[floor(random() * 5 + 1)],
    random() * 1000,
    NOW() - (random() * INTERVAL '7 days'),
    jsonb_build_object(
        'model', (ARRAY['gpt-4', 'claude-3-opus'])[floor(random() * 2 + 1)],
        'environment', (ARRAY['production', 'staging', 'development'])[floor(random() * 3 + 1)]
    )
FROM generate_series(1, ${TRACE_COUNT} * 5);
EOF

# Seed Redis cache if available
if [ -n "${REDIS_URL}" ]; then
    print_status "Seeding Redis cache..."

    REDIS_HOST=$(echo "${REDIS_URL}" | sed -n 's/.*@\(.*\):.*/\1/p')
    REDIS_PORT=$(echo "${REDIS_URL}" | sed -n 's/.*:\([0-9]*\).*/\1/p')
    REDIS_PASS=$(echo "${REDIS_URL}" | sed -n 's/.*:\/\/:\([^@]*\)@.*/\1/p')

    # Set some cache entries
    for i in {1..50}; do
        redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASS}" SET "test:cache:$i" "value_$i" EX 3600 > /dev/null 2>&1 || true
    done

    print_status "Redis seeded with 50 cache entries"
fi

# Verify data
print_status "Verifying seeded data..."
echo ""

psql -t << 'EOF'
SELECT
    'Users: ' || COUNT(*) FROM users
UNION ALL
SELECT
    'Projects: ' || COUNT(*) FROM projects
UNION ALL
SELECT
    'API Keys: ' || COUNT(*) FROM api_keys
UNION ALL
SELECT
    'Traces: ' || COUNT(*) FROM llm_traces
UNION ALL
SELECT
    'Spans: ' || COUNT(*) FROM llm_spans
UNION ALL
SELECT
    'Events: ' || COUNT(*) FROM llm_events
UNION ALL
SELECT
    'Metrics: ' || COUNT(*) FROM metrics;
EOF

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}                    Test Data Seeded Successfully ✓${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
print_status "Database is ready for testing!"

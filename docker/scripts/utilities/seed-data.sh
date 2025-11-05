#!/usr/bin/env bash
#
# Seed Database with Initial Data
# Purpose: Populate database with initial/test data
# Usage: ./seed-data.sh [--env production|development|test]
#

set -euo pipefail

# Source environment variables
if [ -f /app/.env ]; then
    # shellcheck disable=SC1091
    source /app/.env
fi

# Configuration
readonly DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@timescaledb:5432/llm_observatory}"
readonly DATA_DIR="${DATA_DIR:-/app/data}"
readonly ENVIRONMENT="${ENVIRONMENT:-development}"

# Colors
readonly COLOR_RESET="\033[0m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_BLUE="\033[0;34m"
readonly COLOR_YELLOW="\033[0;33m"
readonly COLOR_RED="\033[0;31m"

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"
}

# Parse arguments
ENV_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--env production|development|test]"
            exit 1
            ;;
    esac
done

# Use override if provided
TARGET_ENV="${ENV_OVERRIDE:-${ENVIRONMENT}}"

# Check if database is ready
check_database() {
    log_info "Checking database connection..."
    if psql "${DATABASE_URL}" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Database connection verified"
        return 0
    else
        log_error "Failed to connect to database"
        return 1
    fi
}

# Insert sample projects
seed_projects() {
    log_info "Seeding projects..."

    psql "${DATABASE_URL}" <<EOF
-- Insert sample projects
INSERT INTO projects (name, description, api_key_hash, is_active, metadata)
VALUES
    ('Sample Web Application', 'A sample web application for demonstration',
     '\$argon2id\$v=19\$m=19456,t=2,p=1\$sample_key_1', true,
     '{"tier": "free", "quota": 1000}'),
    ('Mobile App', 'Mobile application project',
     '\$argon2id\$v=19\$m=19456,t=2,p=1\$sample_key_2', true,
     '{"tier": "premium", "quota": 10000}'),
    ('Chatbot Service', 'AI chatbot backend service',
     '\$argon2id\$v=19\$m=19456,t=2,p=1\$sample_key_3', true,
     '{"tier": "enterprise", "quota": 100000}')
ON CONFLICT (name) DO NOTHING;
EOF

    log_success "Projects seeded"
}

# Insert sample models
seed_models() {
    log_info "Seeding models..."

    psql "${DATABASE_URL}" <<EOF
-- Insert sample models
INSERT INTO models (provider, model_name, model_version, capabilities, pricing_info, is_active, metadata)
VALUES
    ('openai', 'gpt-4', '0613',
     '{"chat": true, "completion": true, "functions": true}',
     '{"input_cost_per_1k": 0.03, "output_cost_per_1k": 0.06}', true,
     '{"max_tokens": 8192, "training_cutoff": "2023-04"}'),
    ('openai', 'gpt-3.5-turbo', '0125',
     '{"chat": true, "completion": true, "functions": true}',
     '{"input_cost_per_1k": 0.0005, "output_cost_per_1k": 0.0015}', true,
     '{"max_tokens": 4096, "training_cutoff": "2023-09"}'),
    ('anthropic', 'claude-3-opus', '20240229',
     '{"chat": true, "vision": true, "functions": true}',
     '{"input_cost_per_1k": 0.015, "output_cost_per_1k": 0.075}', true,
     '{"max_tokens": 200000, "training_cutoff": "2023-08"}'),
    ('anthropic', 'claude-3-sonnet', '20240229',
     '{"chat": true, "vision": true, "functions": true}',
     '{"input_cost_per_1k": 0.003, "output_cost_per_1k": 0.015}', true,
     '{"max_tokens": 200000, "training_cutoff": "2023-08"}'),
    ('google', 'gemini-pro', '1.0',
     '{"chat": true, "vision": true, "multimodal": true}',
     '{"input_cost_per_1k": 0.00025, "output_cost_per_1k": 0.0005}', true,
     '{"max_tokens": 32000}')
ON CONFLICT (provider, model_name, model_version) DO NOTHING;
EOF

    log_success "Models seeded"
}

# Insert sample configurations
seed_configurations() {
    log_info "Seeding configurations..."

    psql "${DATABASE_URL}" <<EOF
-- Insert sample configurations
INSERT INTO configurations (key, value, description, is_encrypted, metadata)
VALUES
    ('default_model', '"gpt-3.5-turbo"', 'Default model for new requests', false,
     '{"category": "models", "editable": true}'),
    ('max_tokens_per_request', '4096', 'Maximum tokens per request', false,
     '{"category": "limits", "editable": true}'),
    ('rate_limit_per_minute', '60', 'Rate limit per minute per project', false,
     '{"category": "limits", "editable": true}'),
    ('enable_caching', 'true', 'Enable response caching', false,
     '{"category": "performance", "editable": true}'),
    ('cache_ttl_seconds', '3600', 'Cache TTL in seconds', false,
     '{"category": "performance", "editable": true}'),
    ('log_retention_days', '90', 'Number of days to retain logs', false,
     '{"category": "retention", "editable": true}')
ON CONFLICT (key) DO NOTHING;
EOF

    log_success "Configurations seeded"
}

# Insert sample test data (for development/test only)
seed_test_data() {
    if [ "${TARGET_ENV}" = "production" ]; then
        log_warning "Skipping test data in production environment"
        return 0
    fi

    log_info "Seeding test data..."

    # Get sample project IDs
    local project_ids
    project_ids=$(psql "${DATABASE_URL}" -t -c "SELECT id FROM projects LIMIT 3;")

    local model_ids
    model_ids=$(psql "${DATABASE_URL}" -t -c "SELECT id FROM models LIMIT 3;")

    if [ -z "${project_ids}" ] || [ -z "${model_ids}" ]; then
        log_warning "No projects or models found, skipping test data"
        return 0
    fi

    # This would insert sample traces, spans, etc.
    # For now, just a placeholder
    log_info "Test data seeding is not fully implemented yet"
    log_info "You can add sample traces/spans/metrics here for testing"

    log_success "Test data seeded"
}

# Main execution
main() {
    log_info "Starting database seeding"
    log_info "Environment: ${TARGET_ENV}"
    log_info "Database: ${DB_NAME:-llm_observatory}"

    # Check database connection
    check_database || exit 1

    # Seed data in order
    seed_projects
    seed_models
    seed_configurations

    # Seed test data if not production
    if [ "${TARGET_ENV}" != "production" ]; then
        seed_test_data
    fi

    # Verify seeding
    log_info "Verifying seeded data..."

    local project_count
    project_count=$(psql "${DATABASE_URL}" -t -c "SELECT COUNT(*) FROM projects;")
    log_info "Projects: ${project_count}"

    local model_count
    model_count=$(psql "${DATABASE_URL}" -t -c "SELECT COUNT(*) FROM models;")
    log_info "Models: ${model_count}"

    local config_count
    config_count=$(psql "${DATABASE_URL}" -t -c "SELECT COUNT(*) FROM configurations;")
    log_info "Configurations: ${config_count}"

    log_success "Database seeding completed successfully"
}

main "$@"

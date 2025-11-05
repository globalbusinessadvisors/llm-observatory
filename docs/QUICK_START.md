# LLM Observatory - Quick Start Guide

Get up and running with LLM Observatory in just 5 minutes! This guide will walk you through the essential steps to deploy the infrastructure and start monitoring your LLM applications.

## Table of Contents

- [Prerequisites](#prerequisites)
- [5-Minute Setup](#5-minute-setup)
- [First API Call](#first-api-call)
- [View Dashboards](#view-dashboards)
- [Next Steps](#next-steps)

---

## Prerequisites

Before you begin, ensure you have:

- **Docker** (20.10+) and **Docker Compose** (2.0+)
- **4GB RAM** available
- **10GB disk space**
- Ports **5432**, **6379**, and **3000** available

**Quick check**:
```bash
docker --version && docker compose version
```

---

## 5-Minute Setup

### Step 1: Clone and Configure (1 minute)

```bash
# Clone the repository
git clone https://github.com/llm-observatory/llm-observatory.git
cd llm-observatory

# Copy environment template
cp .env.example .env

# Generate secure passwords (optional but recommended)
echo "DB_PASSWORD=$(openssl rand -hex 16)" >> .env
echo "REDIS_PASSWORD=$(openssl rand -hex 16)" >> .env
echo "SECRET_KEY=$(openssl rand -hex 32)" >> .env
```

### Step 2: Start Infrastructure (2 minutes)

```bash
# Start all core services
docker compose up -d

# Wait for services to be healthy (30-60 seconds)
watch -n 2 'docker compose ps'
# Press Ctrl+C when all services show "(healthy)"
```

Expected output after services are ready:
```
NAME                      IMAGE                            STATUS
llm-observatory-db        timescale/timescaledb:2.14.2     Up (healthy)
llm-observatory-grafana   grafana/grafana:10.4.1           Up (healthy)
llm-observatory-redis     redis:7.2-alpine                 Up (healthy)
```

### Step 3: Verify Installation (1 minute)

```bash
# Check database
docker compose exec timescaledb psql -U postgres -d llm_observatory \
  -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"

# Output: extversion | 2.14.2

# Check Redis
docker compose exec redis redis-cli -a redis_password ping
# Output: PONG

# Check Grafana
curl -s http://localhost:3000/api/health | jq .
# Output: {"database": "ok", "version": "10.4.1"}
```

### Step 4: Access Grafana (30 seconds)

1. Open http://localhost:3000 in your browser
2. Login with:
   - Username: `admin`
   - Password: `admin`
3. Change password when prompted (or skip for development)

**That's it!** Your LLM Observatory infrastructure is ready.

---

## First API Call

### Option 1: Using the REST API (Coming Soon)

Once the API service is deployed, you can send LLM spans:

```bash
# Example: Create a span for an OpenAI completion
curl -X POST http://localhost:8080/api/v1/spans \
  -H "Content-Type: application/json" \
  -d '{
    "trace_id": "abc123",
    "span_id": "span456",
    "name": "openai.chat.completion",
    "start_time": "2024-01-15T10:00:00Z",
    "end_time": "2024-01-15T10:00:02Z",
    "attributes": {
      "llm.provider": "openai",
      "llm.model": "gpt-4",
      "llm.request.type": "chat",
      "llm.usage.prompt_tokens": 50,
      "llm.usage.completion_tokens": 200,
      "llm.usage.total_tokens": 250
    }
  }'
```

### Option 2: Using the Rust SDK (Coming Soon)

```rust
use llm_observatory::prelude::*;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize the observatory
    let _guard = Observatory::init()
        .with_service_name("my-llm-app")
        .with_otlp_endpoint("http://localhost:4317")
        .start()
        .await?;

    // Your LLM calls are automatically traced
    let response = call_openai("What is Rust?").await?;

    println!("Response: {}", response);
    Ok(())
}
```

### Option 3: Manual Database Insert (Testing)

For quick testing, insert sample data directly:

```bash
docker compose exec timescaledb psql -U postgres -d llm_observatory <<EOF
-- Create sample metrics table (temporary for testing)
CREATE TABLE IF NOT EXISTS llm_test_metrics (
    ts TIMESTAMPTZ NOT NULL,
    trace_id TEXT,
    span_id TEXT,
    model_name TEXT,
    duration_ms INTEGER,
    total_tokens INTEGER,
    cost_usd NUMERIC(10, 6)
);

-- Insert sample data
INSERT INTO llm_test_metrics VALUES
    (NOW() - INTERVAL '1 hour', 'trace1', 'span1', 'gpt-4', 2000, 250, 0.005),
    (NOW() - INTERVAL '2 hours', 'trace2', 'span2', 'gpt-3.5-turbo', 800, 150, 0.001),
    (NOW() - INTERVAL '3 hours', 'trace3', 'span3', 'claude-3-opus', 3000, 400, 0.012),
    (NOW() - INTERVAL '4 hours', 'trace4', 'span4', 'gpt-4', 1500, 200, 0.004);

-- Query the data
SELECT
    model_name,
    COUNT(*) as requests,
    AVG(duration_ms) as avg_duration,
    SUM(total_tokens) as total_tokens,
    SUM(cost_usd) as total_cost
FROM llm_test_metrics
GROUP BY model_name
ORDER BY total_cost DESC;
EOF
```

---

## View Dashboards

### Access Grafana Dashboards

1. **Open Grafana**: http://localhost:3000
2. **Login**: `admin` / `admin` (change on first login)
3. **Navigate to Dashboards** (left sidebar, grid icon)

### Create Your First Dashboard

Since the project is in development, let's create a simple dashboard:

#### Step 1: Add Data Source

1. In Grafana, go to **Connections** > **Data sources**
2. Click **Add data source**
3. Select **PostgreSQL**
4. Configure:
   - **Host**: `timescaledb:5432`
   - **Database**: `llm_observatory`
   - **User**: `postgres`
   - **Password**: `postgres` (from your `.env`)
   - **TLS/SSL Mode**: `disable`
5. Click **Save & Test**

#### Step 2: Create Dashboard

1. Click **Dashboards** > **New** > **New Dashboard**
2. Click **Add visualization**
3. Select **PostgreSQL** data source
4. Use this query:

```sql
SELECT
    time_bucket('1 hour', ts) AS time,
    model_name,
    COUNT(*) as requests,
    AVG(duration_ms) as avg_duration_ms,
    SUM(cost_usd) as total_cost_usd
FROM llm_test_metrics
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY time, model_name
ORDER BY time
```

5. Set visualization to **Time series**
6. In the panel editor:
   - **Title**: "LLM Requests by Model"
   - **Legend**: Enable, show values
7. Click **Apply**

#### Step 3: Add More Panels

Add panels for:

1. **Total Cost Over Time**:
```sql
SELECT
    time_bucket('1 hour', ts) AS time,
    SUM(cost_usd) as total_cost
FROM llm_test_metrics
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY time
ORDER BY time
```

2. **Latency Distribution**:
```sql
SELECT
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_ms) as p50,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99
FROM llm_test_metrics
WHERE ts > NOW() - INTERVAL '1 hour'
```

3. **Token Usage by Model**:
```sql
SELECT
    model_name,
    SUM(total_tokens) as total_tokens
FROM llm_test_metrics
WHERE ts > NOW() - INTERVAL '24 hours'
GROUP BY model_name
ORDER BY total_tokens DESC
```

#### Step 4: Save Dashboard

1. Click **Save dashboard** (disk icon, top right)
2. Name: "LLM Observatory - Overview"
3. Click **Save**

### Explore Data with Table View

Create a table to see raw requests:

1. Add new panel
2. Use query:
```sql
SELECT
    ts,
    trace_id,
    model_name,
    duration_ms,
    total_tokens,
    cost_usd
FROM llm_test_metrics
ORDER BY ts DESC
LIMIT 100
```
3. Set visualization to **Table**
4. Enable sorting and filtering

---

## Next Steps

Congratulations! You now have a working LLM Observatory environment. Here's what to do next:

### 1. Explore Database (5 minutes)

Connect to the database and explore:

```bash
# Connect to database
docker compose exec timescaledb psql -U postgres -d llm_observatory

# List tables
\dt

# List extensions
\dx

# Exit
\q
```

### 2. Deploy Application (When Available)

Once the Rust application is ready:

```bash
# Build the application
cargo build --release

# Run the collector
./target/release/llm-observatory-collector

# Run the API
./target/release/llm-observatory-api
```

### 3. Instrument Your LLM Application

Add the LLM Observatory SDK to your application:

```toml
# Cargo.toml
[dependencies]
llm-observatory = "0.1"
opentelemetry = "0.24"
```

```rust
// main.rs
use llm_observatory::prelude::*;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize observability
    let _guard = Observatory::init()
        .with_service_name("my-app")
        .with_otlp_endpoint("http://localhost:4317")
        .start()
        .await?;

    // Your code here - LLM calls are automatically traced
    Ok(())
}
```

### 4. Set Up Monitoring (15 minutes)

Configure Prometheus and alerts:

```bash
# Start monitoring stack
docker compose -f docker/monitoring-stack.yml up -d

# Access Prometheus: http://localhost:9091
# Configure alerts for:
# - High cost per hour
# - Slow response times
# - Error rates
```

See [Monitoring Setup Guide](/workspaces/llm-observatory/docs/MONITORING_SETUP.md) for details.

### 5. Optimize for Production (30 minutes)

Review and implement:

1. **Security**:
   - Change all default passwords
   - Enable TLS for database connections
   - Configure firewall rules
   - Review [Security Best Practices](#)

2. **Performance**:
   - Tune database parameters in `.env`
   - Set up connection pooling
   - Configure Redis cache size
   - Review [Performance Tuning Guide](#)

3. **Reliability**:
   - Set up automated backups
   - Configure retention policies
   - Test disaster recovery
   - Review [Backup Infrastructure](/workspaces/llm-observatory/docs/BACKUP_INFRASTRUCTURE.md)

### 6. Learn More

Explore detailed documentation:

- [Docker Workflows](/workspaces/llm-observatory/docs/DOCKER_WORKFLOWS.md) - Development patterns
- [Architecture Guide](/workspaces/llm-observatory/docs/ARCHITECTURE_DOCKER.md) - System design
- [Troubleshooting](/workspaces/llm-observatory/docs/TROUBLESHOOTING_DOCKER.md) - Common issues
- [Operations Manual](/workspaces/llm-observatory/docs/OPERATIONS_MANUAL.md) - Day-to-day operations

---

## Quick Reference

### Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | `admin` / `admin` |
| PgAdmin | http://localhost:5050 | `admin@llm-observatory.local` / `admin` |
| Prometheus | http://localhost:9091 | (if monitoring stack deployed) |

### Database Connections

```bash
# PostgreSQL (from host)
psql postgresql://postgres:postgres@localhost:5432/llm_observatory

# PostgreSQL (from container)
psql postgresql://postgres:postgres@timescaledb:5432/llm_observatory

# Redis (from host)
redis-cli -h localhost -p 6379 -a redis_password
```

### Essential Commands

```bash
# View status
docker compose ps

# View logs
docker compose logs -f

# Restart service
docker compose restart timescaledb

# Stop all
docker compose down

# Start with admin tools
docker compose --profile admin up -d

# Backup database
docker compose exec timescaledb pg_dump -U postgres llm_observatory > backup.sql

# Restore database
cat backup.sql | docker compose exec -T timescaledb psql -U postgres llm_observatory
```

### Troubleshooting Quick Fixes

**Service won't start**:
```bash
docker compose down -v
docker compose up -d
```

**Port conflict**:
```bash
# Edit .env and change ports
DB_PORT=15432
GRAFANA_PORT=13000
REDIS_PORT=16379

# Restart
docker compose down && docker compose up -d
```

**Check health**:
```bash
docker compose ps
docker compose logs [service_name]
```

---

## Getting Help

- **Documentation**: [/docs](/workspaces/llm-observatory/docs/)
- **Issues**: [GitHub Issues](https://github.com/llm-observatory/llm-observatory/issues)
- **Discussions**: [GitHub Discussions](https://github.com/llm-observatory/llm-observatory/discussions)

When asking for help, include:
- Output of `docker compose ps`
- Relevant logs: `docker compose logs [service]`
- Docker version: `docker --version`
- OS and version

---

## What You've Accomplished

In just 5 minutes, you've:

- Deployed a production-grade observability stack
- Started TimescaleDB with time-series extensions
- Configured Grafana for visualization
- Set up Redis for caching
- Created your first dashboard
- Inserted and queried sample LLM metrics

You're now ready to start monitoring your LLM applications!

---

## Project Status

**Current Phase**: Foundation - Development

**Available Now**:
- Docker infrastructure
- Database initialization
- Grafana dashboards
- Manual data insertion

**Coming Soon**:
- Rust SDK for automatic instrumentation
- REST API for span ingestion
- OTLP collector with sampling
- Pre-built dashboards for common use cases
- CLI tools for management

**Stay Updated**:
- Watch the [GitHub repository](https://github.com/llm-observatory/llm-observatory)
- Star the project to show support
- Join discussions for updates

---

**Built with ❤️ for the LLM community**

Ready to dive deeper? Check out the [full documentation](/workspaces/llm-observatory/README.md) or explore [Docker workflows](/workspaces/llm-observatory/docs/DOCKER_WORKFLOWS.md).

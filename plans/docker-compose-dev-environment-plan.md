# Docker Compose Development Environment - Implementation Plan

**Document Version:** 1.0
**Date:** 2025-11-05
**Status:** Planning Phase
**Target Completion:** 1-2 weeks

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Assessment](#current-state-assessment)
3. [Objectives & Requirements](#objectives--requirements)
4. [Architecture Design](#architecture-design)
5. [Implementation Phases](#implementation-phases)
6. [Detailed Component Specifications](#detailed-component-specifications)
7. [Developer Workflows](#developer-workflows)
8. [Testing Strategy](#testing-strategy)
9. [Documentation Requirements](#documentation-requirements)
10. [Success Criteria](#success-criteria)

---

## Executive Summary

### Purpose

Create a comprehensive Docker Compose-based development environment for the LLM Observatory project that enables:
- **One-command setup** for new developers
- **Hot-reload development** for all Rust services
- **Integrated debugging** capabilities
- **Consistent environments** across team members
- **Production parity** for accurate testing

### Current Status

**Infrastructure Services (Complete):**
- ✅ TimescaleDB 2.14.2 with proper initialization
- ✅ Redis 7.2 for caching
- ✅ Grafana 10.4.1 for visualization
- ✅ PgAdmin (optional) for database administration
- ✅ Backup service configuration

**Application Services (Missing):**
- ❌ Collector service (OTLP receiver)
- ❌ Storage service (database layer)
- ❌ API service (REST/GraphQL endpoints)
- ❌ CLI tools container
- ❌ SDK examples/playground

**Development Tooling (Missing):**
- ❌ Hot reload configuration
- ❌ Debugging setup (VSCode, RustRover)
- ❌ Testing containers
- ❌ Development utilities (migrations, seed data)

### Target State

A complete Docker Compose environment with:
- **5 application services** fully containerized
- **Development mode** with cargo-watch for hot reload
- **Production mode** for deployment testing
- **Testing mode** for CI/CD integration
- **Debugging support** for popular IDEs
- **Comprehensive documentation** for all workflows

---

## Current State Assessment

### What We Have ✅

#### 1. Infrastructure Layer (docker-compose.yml)

**TimescaleDB Service:**
```yaml
✅ PostgreSQL 16 with TimescaleDB 2.14.2
✅ Health checks configured
✅ Persistent volumes
✅ Initialization scripts
✅ Performance tuning parameters
✅ Connection pooling settings
```

**Redis Service:**
```yaml
✅ Redis 7.2 with authentication
✅ LRU eviction policy
✅ AOF persistence
✅ Health checks
```

**Monitoring Services:**
```yaml
✅ Grafana with PostgreSQL backend
✅ PgAdmin (profile-based)
✅ Health check endpoints
```

**Backup Service:**
```yaml
✅ Automated backup container
✅ S3 integration support
✅ Profile-based execution
```

#### 2. Configuration Management

**Environment Variables (.env.example):**
```
✅ Database configuration (primary, app, readonly users)
✅ Redis configuration
✅ Grafana settings
✅ Security settings (JWT, CORS, secrets)
✅ Monitoring configuration
✅ Backup settings
✅ Provider API keys (placeholders)
```

#### 3. Database Initialization

**Init Script (01-init-timescaledb.sql):**
```sql
✅ Database creation
✅ TimescaleDB extension installation
✅ User role creation (app, readonly)
✅ Privilege management
✅ Extension installation (uuid-ossp, pg_stat_statements)
```

### What We Need ❌

#### 1. Application Services

**Missing Services:**
- Collector Service (OTLP receiver for traces/metrics/logs)
- Storage Service (database layer with batch writers)
- API Service (REST/GraphQL endpoints)
- CLI Tools (migrations, data seeding, admin tasks)
- SDK Playground (development/testing environment)

#### 2. Development Configuration

**Missing Features:**
- Hot reload setup with cargo-watch
- Development Dockerfiles optimized for fast rebuilds
- Volume mounts for source code
- Debug symbol preservation
- IDE integration (launch.json, run configurations)

#### 3. Service Orchestration

**Missing Configuration:**
- Service dependencies and startup order
- Health check integration between services
- Service discovery configuration
- Network isolation for testing
- Resource limits for development

#### 4. Development Tooling

**Missing Tools:**
- Migration runner container
- Test runner with isolated database
- Data seeding utilities
- Log aggregation/viewing
- Performance profiling tools

#### 5. Documentation

**Missing Guides:**
- Quick start guide (0-5 minutes to running system)
- Development workflows
- Debugging setup
- Common tasks reference
- Troubleshooting guide

---

## Objectives & Requirements

### Primary Objectives

#### 1. Developer Experience
- **One-Command Setup:** `docker-compose up` starts entire stack
- **Fast Iteration:** Code changes reflected within 2-3 seconds
- **Easy Debugging:** Attach debugger with one click
- **Clear Logs:** Structured logging with easy filtering

#### 2. Production Parity
- **Same Services:** Development matches production architecture
- **Same Data:** Realistic test data and schemas
- **Same Configuration:** Environment-based config management
- **Same Networking:** Service discovery and communication patterns

#### 3. Team Collaboration
- **Consistent Environments:** Works identically on all machines
- **Version Controlled:** All configuration in Git
- **Documented:** Clear setup and usage instructions
- **Maintainable:** Easy to update and extend

### Functional Requirements

#### FR1: Multi-Service Orchestration
- All services start in correct dependency order
- Health checks gate service startup
- Graceful shutdown handling
- Service restart on failure (configurable)

#### FR2: Development Mode
- Hot reload for all Rust services
- Source code mounted as volumes
- Debug symbols included in builds
- Verbose logging enabled
- Test data auto-seeded

#### FR3: Production Mode
- Optimized release builds
- Minimal container sizes
- Production logging configuration
- Security hardening applied
- Resource limits enforced

#### FR4: Testing Mode
- Isolated test databases
- Parallel test execution support
- Test data cleanup between runs
- Integration test support
- Performance test support

#### FR5: Developer Tools
- Database migration runner
- Data seeding utilities
- Log aggregation viewer
- Health check dashboard
- Metrics visualization

### Non-Functional Requirements

#### NFR1: Performance
- Initial setup: < 5 minutes (cold start with downloads)
- Warm restart: < 30 seconds
- Hot reload: < 3 seconds for code changes
- Resource usage: < 4GB RAM for full stack

#### NFR2: Reliability
- Services recover from crashes automatically
- Data persisted across restarts
- Network failures handled gracefully
- Clear error messages for common issues

#### NFR3: Security
- Default credentials for development only
- Secrets loaded from environment
- Network isolation between services
- No privileged containers required

#### NFR4: Maintainability
- Clear separation of concerns
- Minimal custom scripting
- Standard Docker patterns
- Well-documented configurations

---

## Architecture Design

### Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Compose Stack                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │   Collector  │  │     API      │  │     CLI      │        │
│  │   (OTLP)     │  │  (REST/GQL)  │  │   (Tools)    │        │
│  │   :4317/18   │  │    :8080     │  │              │        │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘        │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                │
│                            │                                    │
│                   ┌────────▼────────┐                          │
│                   │    Storage      │                          │
│                   │  (DB Layer)     │                          │
│                   └────────┬────────┘                          │
│                            │                                    │
│  ┌─────────────────────────┼─────────────────────────┐        │
│  │                         │                         │        │
│  │  ┌──────────────┐  ┌───▼──────────┐  ┌──────────▼──┐     │
│  │  │   Grafana    │  │ TimescaleDB  │  │    Redis    │     │
│  │  │   :3000      │  │    :5432     │  │    :6379    │     │
│  │  └──────────────┘  └──────────────┘  └─────────────┘     │
│  │                                                            │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  │   PgAdmin    │  │  Prometheus  │  │  Jaeger UI   │   │
│  │  │   :5050      │  │    :9090     │  │    :16686    │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │
│  │                                                            │
│  └────────────────────────────────────────────────────────────┘
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Network Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    llm-observatory-network                     │
│                        (bridge driver)                         │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Frontend Network (exposed to host)                           │
│  ├─ collector:4317/4318  (OTLP gRPC/HTTP)                    │
│  ├─ api:8080             (REST/GraphQL API)                   │
│  ├─ grafana:3000         (Dashboards)                        │
│  ├─ prometheus:9090      (Metrics)                           │
│  ├─ jaeger:16686         (Tracing UI)                        │
│  └─ pgadmin:5050         (DB Admin)                          │
│                                                                │
│  Backend Network (internal only)                              │
│  ├─ timescaledb:5432     (Database - internal)               │
│  ├─ redis:6379           (Cache - internal)                  │
│  └─ storage:9090         (Metrics endpoint - internal)       │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Volume Strategy

```
Persistent Volumes (Data that survives container restarts):
├─ timescaledb_data       → /var/lib/postgresql/data
├─ redis_data             → /data
├─ grafana_data           → /var/lib/grafana
├─ pgadmin_data           → /var/lib/pgadmin
├─ backup_data            → /backups
└─ prometheus_data        → /prometheus

Development Volumes (Source code mounts):
├─ ./crates/collector     → /app/crates/collector
├─ ./crates/api           → /app/crates/api
├─ ./crates/storage       → /app/crates/storage
├─ ./crates/core          → /app/crates/core
├─ ./crates/providers     → /app/crates/providers
├─ ./crates/sdk           → /app/crates/sdk
├─ ./crates/cli           → /app/crates/cli
├─ ./Cargo.toml           → /app/Cargo.toml
└─ ./Cargo.lock           → /app/Cargo.lock

Build Cache Volumes (Faster rebuilds):
├─ cargo_registry         → /usr/local/cargo/registry
├─ cargo_git              → /usr/local/cargo/git
└─ target_cache           → /app/target
```

---

## Implementation Phases

### Phase 1: Core Application Services (Week 1, Days 1-3)

**Goal:** Containerize all Rust services with basic functionality

#### Day 1: Collector Service
**Tasks:**
1. Create Dockerfile.collector (development + production)
2. Add collector service to docker-compose.yml
3. Configure OTLP endpoints (gRPC :4317, HTTP :4318)
4. Set up environment variable mapping
5. Test OTLP ingestion with sample data

**Deliverables:**
- `docker/Dockerfile.collector`
- `docker/Dockerfile.collector.dev`
- Updated `docker-compose.yml` with collector service
- Sample OTLP test data

#### Day 2: Storage Service
**Tasks:**
1. Create Dockerfile.storage (development + production)
2. Add storage service to docker-compose.yml
3. Configure database connection pooling
4. Set up migration runner
5. Test batch writer functionality

**Deliverables:**
- `docker/Dockerfile.storage`
- `docker/Dockerfile.storage.dev`
- Migration runner configuration
- Storage service in docker-compose.yml

#### Day 3: API Service
**Tasks:**
1. Create Dockerfile.api (development + production)
2. Add API service to docker-compose.yml
3. Configure REST/GraphQL endpoints
4. Set up authentication/authorization
5. Test API endpoints

**Deliverables:**
- `docker/Dockerfile.api`
- `docker/Dockerfile.api.dev`
- API service in docker-compose.yml
- Postman/Thunder Client collection

---

### Phase 2: Development Experience (Week 1, Days 4-5)

**Goal:** Enable hot reload and fast iteration

#### Day 4: Hot Reload Setup
**Tasks:**
1. Add cargo-watch to development containers
2. Configure volume mounts for source code
3. Set up incremental compilation
4. Optimize Dockerfile layers for caching
5. Test hot reload with code changes

**Deliverables:**
- Development Dockerfiles with cargo-watch
- docker-compose.dev.yml for development overrides
- Hot reload documentation

#### Day 5: Debugging Configuration
**Tasks:**
1. Configure debug builds with symbols
2. Create VSCode launch.json
3. Create RustRover run configurations
4. Set up remote debugging
5. Test debugger attachment

**Deliverables:**
- `.vscode/launch.json`
- `.idea/runConfigurations/*.xml`
- Debugging guide

---

### Phase 3: Testing Infrastructure (Week 1-2, Days 6-7)

**Goal:** Enable automated testing in Docker

#### Day 6: Test Containers
**Tasks:**
1. Create docker-compose.test.yml
2. Set up isolated test databases
3. Configure parallel test execution
4. Add test data seeding
5. Integrate with CI/CD

**Deliverables:**
- `docker-compose.test.yml`
- Test database initialization scripts
- CI/CD workflow files

#### Day 7: Integration Testing
**Tasks:**
1. Create end-to-end test suite
2. Set up service mocking
3. Configure test data fixtures
4. Add performance benchmarks
5. Create test report generation

**Deliverables:**
- Integration test suite
- Performance test suite
- Test documentation

---

### Phase 4: Developer Tooling (Week 2, Days 8-9)

**Goal:** Provide useful development utilities

#### Day 8: CLI Tools Container
**Tasks:**
1. Create Dockerfile.cli
2. Add CLI tools service to docker-compose
3. Create migration runner scripts
4. Add data seeding utilities
5. Create backup/restore helpers

**Deliverables:**
- `docker/Dockerfile.cli`
- CLI tools service in docker-compose.yml
- Utility scripts

#### Day 9: Monitoring & Observability
**Tasks:**
1. Add Prometheus service
2. Configure service discovery
3. Add Jaeger for distributed tracing
4. Set up log aggregation
5. Create default dashboards

**Deliverables:**
- Prometheus configuration
- Jaeger service
- Grafana dashboards
- Log aggregation setup

---

### Phase 5: Documentation & Polish (Week 2, Days 10)

**Goal:** Complete documentation and finalize

#### Day 10: Documentation
**Tasks:**
1. Write comprehensive README
2. Create quick start guide (0-5 min)
3. Document common workflows
4. Create troubleshooting guide
5. Add architecture diagrams

**Deliverables:**
- `docker/README.md`
- `docs/QUICK_START.md`
- `docs/DOCKER_WORKFLOWS.md`
- `docs/TROUBLESHOOTING_DOCKER.md`

---

## Detailed Component Specifications

### 1. Collector Service

#### Purpose
Receive OpenTelemetry data (traces, metrics, logs) via OTLP protocol and forward to storage layer.

#### Dockerfile Strategy

**Development (Dockerfile.collector.dev):**
```dockerfile
FROM rust:1.75-slim as base

WORKDIR /app

# Install development dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Install cargo-watch for hot reload
RUN cargo install cargo-watch

# Copy workspace manifests
COPY Cargo.toml Cargo.lock ./

# Create dummy projects for caching dependencies
RUN mkdir -p crates/collector/src \
    && echo "fn main() {}" > crates/collector/src/main.rs

# Build dependencies (cached layer)
RUN cargo build --bin llm-observatory-collector

# Remove dummy files
RUN rm -rf crates/

# Development command with hot reload
CMD ["cargo", "watch", "-x", "run --bin llm-observatory-collector"]
```

**Production (Dockerfile.collector):**
```dockerfile
# Build stage
FROM rust:1.75-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Copy workspace
COPY . .

# Build release binary
RUN cargo build --release --bin llm-observatory-collector

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/llm-observatory-collector /usr/local/bin/

# Create non-root user
RUN useradd -m -u 1000 collector
USER collector

EXPOSE 4317 4318 9090

CMD ["llm-observatory-collector"]
```

#### Docker Compose Configuration

```yaml
collector:
  build:
    context: .
    dockerfile: docker/Dockerfile.collector.dev
  container_name: llm-observatory-collector
  restart: unless-stopped
  ports:
    - "${COLLECTOR_OTLP_GRPC_PORT:-4317}:4317"  # OTLP gRPC
    - "${COLLECTOR_OTLP_HTTP_PORT:-4318}:4318"  # OTLP HTTP
    - "${COLLECTOR_METRICS_PORT:-9091}:9090"    # Metrics endpoint
  environment:
    # Server configuration
    OTLP_GRPC_ENDPOINT: "0.0.0.0:4317"
    OTLP_HTTP_ENDPOINT: "0.0.0.0:4318"
    METRICS_ENDPOINT: "0.0.0.0:9090"

    # Storage configuration
    STORAGE_SERVICE_URL: "http://storage:8080"

    # Database configuration (for direct writes)
    DATABASE_URL: "${DATABASE_APP_URL}"

    # Redis configuration
    REDIS_URL: "${REDIS_URL}"

    # Processing configuration
    BATCH_SIZE: "1000"
    FLUSH_INTERVAL: "1s"
    MAX_QUEUE_SIZE: "10000"
    WORKER_THREADS: "4"

    # Feature flags
    ENABLE_PII_DETECTION: "true"
    ENABLE_COST_CALCULATION: "true"
    ENABLE_SAMPLING: "false"

    # Logging
    RUST_LOG: "info,llm_observatory_collector=debug"
    LOG_FORMAT: "json"

  volumes:
    # Development: Mount source code for hot reload
    - ./crates/collector:/app/crates/collector
    - ./crates/core:/app/crates/core
    - ./crates/providers:/app/crates/providers
    - ./crates/storage:/app/crates/storage
    - ./Cargo.toml:/app/Cargo.toml
    - ./Cargo.lock:/app/Cargo.lock

    # Cache volumes for faster builds
    - cargo_registry:/usr/local/cargo/registry
    - cargo_git:/usr/local/cargo/git
    - collector_target:/app/target

  networks:
    - llm-observatory-network

  depends_on:
    timescaledb:
      condition: service_healthy
    redis:
      condition: service_healthy
    storage:
      condition: service_started

  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:9090/health"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 60s  # Allow time for initial cargo build
```

---

### 2. Storage Service

#### Purpose
Provide high-performance database access layer with connection pooling and batch writing.

#### Dockerfile Strategy

**Development (Dockerfile.storage.dev):**
```dockerfile
FROM rust:1.75-slim as base

WORKDIR /app

# Install development dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install cargo-watch and sqlx-cli
RUN cargo install cargo-watch sqlx-cli --no-default-features --features postgres

# Copy workspace manifests
COPY Cargo.toml Cargo.lock ./

# Create dummy projects
RUN mkdir -p crates/storage/src \
    && echo "fn main() {}" > crates/storage/src/main.rs

# Build dependencies
RUN cargo build --bin llm-observatory-storage

# Remove dummy files
RUN rm -rf crates/

# Development command
CMD ["cargo", "watch", "-x", "run --bin llm-observatory-storage"]
```

**Production (Dockerfile.storage):**
```dockerfile
FROM rust:1.75-slim as builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN cargo build --release --bin llm-observatory-storage

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/llm-observatory-storage /usr/local/bin/
COPY --from=builder /app/crates/storage/migrations /migrations

RUN useradd -m -u 1000 storage
USER storage

EXPOSE 8080 9090

CMD ["llm-observatory-storage"]
```

#### Docker Compose Configuration

```yaml
storage:
  build:
    context: .
    dockerfile: docker/Dockerfile.storage.dev
  container_name: llm-observatory-storage
  restart: unless-stopped
  ports:
    - "${STORAGE_API_PORT:-8081}:8080"      # Internal API
    - "${STORAGE_METRICS_PORT:-9092}:9090"  # Metrics endpoint
  environment:
    # Database configuration
    DATABASE_URL: "${DATABASE_APP_URL}"

    # Connection pool
    DB_POOL_MIN_SIZE: "${DB_POOL_MIN_SIZE:-5}"
    DB_POOL_MAX_SIZE: "${DB_POOL_MAX_SIZE:-20}"
    DB_POOL_TIMEOUT: "${DB_POOL_TIMEOUT:-30}"

    # Redis configuration
    REDIS_URL: "${REDIS_URL}"

    # Writer configuration
    BATCH_SIZE: "1000"
    FLUSH_INTERVAL_SECS: "1"
    WRITE_METHOD: "copy"  # Use PostgreSQL COPY protocol

    # API configuration
    API_HOST: "0.0.0.0"
    API_PORT: "8080"

    # Metrics
    METRICS_ENABLED: "true"
    METRICS_PORT: "9090"

    # Logging
    RUST_LOG: "info,llm_observatory_storage=debug,sqlx=warn"

    # Run migrations on startup
    RUN_MIGRATIONS: "true"

  volumes:
    # Development: Mount source code
    - ./crates/storage:/app/crates/storage
    - ./crates/core:/app/crates/core
    - ./Cargo.toml:/app/Cargo.toml
    - ./Cargo.lock:/app/Cargo.lock

    # Cache volumes
    - cargo_registry:/usr/local/cargo/registry
    - cargo_git:/usr/local/cargo/git
    - storage_target:/app/target

  networks:
    - llm-observatory-network

  depends_on:
    timescaledb:
      condition: service_healthy
    redis:
      condition: service_healthy

  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:9090/health"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 60s
```

---

### 3. API Service

#### Purpose
Provide REST and GraphQL APIs for querying and managing LLM observability data.

#### Dockerfile Strategy

**Development (Dockerfile.api.dev):**
```dockerfile
FROM rust:1.75-slim as base

WORKDIR /app

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN cargo install cargo-watch

COPY Cargo.toml Cargo.lock ./

RUN mkdir -p crates/api/src \
    && echo "fn main() {}" > crates/api/src/main.rs

RUN cargo build --bin llm-observatory-api

RUN rm -rf crates/

CMD ["cargo", "watch", "-x", "run --bin llm-observatory-api"]
```

**Production (Dockerfile.api):**
```dockerfile
FROM rust:1.75-slim as builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN cargo build --release --bin llm-observatory-api

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/llm-observatory-api /usr/local/bin/

RUN useradd -m -u 1000 api
USER api

EXPOSE 8080 9090

CMD ["llm-observatory-api"]
```

#### Docker Compose Configuration

```yaml
api:
  build:
    context: .
    dockerfile: docker/Dockerfile.api.dev
  container_name: llm-observatory-api
  restart: unless-stopped
  ports:
    - "${API_PORT:-8080}:8080"              # API endpoint
    - "${API_METRICS_PORT:-9093}:9090"      # Metrics endpoint
  environment:
    # Server configuration
    HOST: "0.0.0.0"
    PORT: "8080"

    # Database configuration (read-only for API)
    DATABASE_URL: "${DATABASE_READONLY_URL}"

    # Redis configuration
    REDIS_URL: "${REDIS_URL}"

    # Authentication
    JWT_SECRET: "${JWT_SECRET}"
    JWT_ALGORITHM: "${JWT_ALGORITHM:-HS256}"
    JWT_EXPIRATION: "${JWT_EXPIRATION:-3600}"

    # CORS
    CORS_ORIGINS: "${CORS_ORIGINS}"

    # Rate limiting
    RATE_LIMIT_REQUESTS: "${RATE_LIMIT_REQUESTS:-100}"
    RATE_LIMIT_WINDOW: "${RATE_LIMIT_WINDOW:-60}"

    # GraphQL
    GRAPHQL_ENABLED: "true"
    GRAPHQL_PLAYGROUND: "true"  # Disable in production

    # Metrics
    METRICS_ENABLED: "true"
    METRICS_PORT: "9090"

    # Logging
    RUST_LOG: "info,llm_observatory_api=debug"

  volumes:
    # Development: Mount source code
    - ./crates/api:/app/crates/api
    - ./crates/core:/app/crates/core
    - ./crates/storage:/app/crates/storage
    - ./Cargo.toml:/app/Cargo.toml
    - ./Cargo.lock:/app/Cargo.lock

    # Cache volumes
    - cargo_registry:/usr/local/cargo/registry
    - cargo_git:/usr/local/cargo/git
    - api_target:/app/target

  networks:
    - llm-observatory-network

  depends_on:
    timescaledb:
      condition: service_healthy
    redis:
      condition: service_healthy
    storage:
      condition: service_started

  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 60s
```

---

### 4. CLI Tools Container

#### Purpose
Provide command-line utilities for database migrations, data seeding, and administrative tasks.

#### Dockerfile Strategy

```dockerfile
FROM rust:1.75-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install sqlx-cli for migrations
RUN cargo install sqlx-cli --no-default-features --features postgres

COPY . .

# Build CLI tools
RUN cargo build --release --bin llm-observatory-cli

# Install the binary
RUN cp target/release/llm-observatory-cli /usr/local/bin/

# Entry point script
COPY docker/scripts/cli-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["--help"]
```

#### Docker Compose Configuration

```yaml
cli:
  build:
    context: .
    dockerfile: docker/Dockerfile.cli
  container_name: llm-observatory-cli
  environment:
    DATABASE_URL: "${DATABASE_URL}"
    REDIS_URL: "${REDIS_URL}"
  volumes:
    # Mount scripts and migrations
    - ./scripts:/scripts:ro
    - ./crates/storage/migrations:/migrations:ro

    # Development: Mount source for CLI development
    - ./crates/cli:/app/crates/cli
    - ./crates/core:/app/crates/core

  networks:
    - llm-observatory-network

  depends_on:
    timescaledb:
      condition: service_healthy

  profiles:
    - tools  # Only start with --profile tools
```

#### CLI Entrypoint Script

```bash
#!/bin/bash
# docker/scripts/cli-entrypoint.sh

set -e

# Parse command
case "$1" in
  migrate)
    echo "Running database migrations..."
    cd /migrations
    sqlx migrate run
    ;;

  seed)
    echo "Seeding database with test data..."
    llm-observatory-cli seed --environment development
    ;;

  reset)
    echo "Resetting database..."
    llm-observatory-cli db reset --confirm
    ;;

  *)
    # Pass through to CLI
    exec llm-observatory-cli "$@"
    ;;
esac
```

---

### 5. Monitoring Services

#### Prometheus

```yaml
prometheus:
  image: prom/prometheus:v2.48.0
  container_name: llm-observatory-prometheus
  restart: unless-stopped
  ports:
    - "${PROMETHEUS_PORT:-9090}:9090"
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
    - '--storage.tsdb.retention.time=30d'
    - '--web.enable-lifecycle'
  volumes:
    - ./docker/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    - ./docker/prometheus/alerts:/etc/prometheus/alerts:ro
    - prometheus_data:/prometheus
  networks:
    - llm-observatory-network
  depends_on:
    - collector
    - storage
    - api
```

#### Jaeger (Distributed Tracing)

```yaml
jaeger:
  image: jaegertracing/all-in-one:1.52
  container_name: llm-observatory-jaeger
  restart: unless-stopped
  ports:
    - "16686:16686"   # Jaeger UI
    - "14268:14268"   # Jaeger collector HTTP
    - "14250:14250"   # Jaeger collector gRPC
  environment:
    COLLECTOR_OTLP_ENABLED: "true"
    SPAN_STORAGE_TYPE: "badger"
    BADGER_EPHEMERAL: "false"
    BADGER_DIRECTORY_VALUE: "/badger/data"
    BADGER_DIRECTORY_KEY: "/badger/key"
  volumes:
    - jaeger_data:/badger
  networks:
    - llm-observatory-network
```

---

## Developer Workflows

### 1. First-Time Setup (0-5 minutes)

```bash
# Clone repository
git clone https://github.com/llm-observatory/llm-observatory.git
cd llm-observatory

# Copy environment configuration
cp .env.example .env

# (Optional) Edit .env with your preferences
nano .env

# Start the entire stack
docker-compose up -d

# Wait for services to be healthy (30-60 seconds)
docker-compose ps

# Run migrations
docker-compose --profile tools run cli migrate

# Seed test data
docker-compose --profile tools run cli seed

# Open Grafana
open http://localhost:3000  # admin/admin

# Check API
curl http://localhost:8080/health
```

**Expected Output:**
```
✅ timescaledb: healthy
✅ redis: healthy
✅ grafana: healthy
✅ collector: healthy
✅ storage: healthy
✅ api: healthy

🎉 LLM Observatory is ready!
   - API: http://localhost:8080
   - Grafana: http://localhost:3000
   - Jaeger: http://localhost:16686
   - Prometheus: http://localhost:9090
```

---

### 2. Development Workflow (Hot Reload)

```bash
# Start services in development mode
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Edit code in your favorite IDE
# Changes are automatically detected and services reload

# Example: Edit collector code
vim crates/collector/src/main.rs
# Save file
# → Watch logs: cargo-watch detects change and rebuilds (~2-3 seconds)

# View logs for specific service
docker-compose logs -f collector

# Restart a specific service
docker-compose restart collector

# Rebuild after dependency changes
docker-compose build collector
docker-compose up -d collector
```

---

### 3. Testing Workflow

```bash
# Run unit tests (local)
cargo test

# Run integration tests in Docker
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Run specific test suite
docker-compose -f docker-compose.test.yml run --rm test-runner \
  cargo test --package llm-observatory-storage --test integration_*

# Run with test coverage
docker-compose -f docker-compose.test.yml run --rm test-runner \
  cargo tarpaulin --out Html --output-dir /reports

# View coverage report
open target/tarpaulin/index.html
```

---

### 4. Debugging Workflow

#### VSCode

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "lldb",
      "request": "attach",
      "name": "Attach to Collector",
      "pid": "${command:pickProcess}"
    },
    {
      "type": "lldb",
      "request": "launch",
      "name": "Debug API (Docker)",
      "program": "${workspaceFolder}/target/debug/llm-observatory-api",
      "args": [],
      "cwd": "${workspaceFolder}",
      "preLaunchTask": "docker-compose-debug-api"
    }
  ]
}
```

```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "docker-compose-debug-api",
      "type": "shell",
      "command": "docker-compose -f docker-compose.debug.yml up -d api",
      "problemMatcher": []
    }
  ]
}
```

**Debugging Steps:**
1. Start service in debug mode: `docker-compose -f docker-compose.debug.yml up -d api`
2. Set breakpoints in VSCode
3. Attach debugger: F5 → "Attach to API"
4. Trigger API endpoint
5. Debug!

---

### 5. Database Management

```bash
# Run migrations
docker-compose --profile tools run cli migrate

# Rollback last migration
docker-compose --profile tools run cli migrate revert

# Create new migration
docker-compose --profile tools run cli migrate create add_new_table

# Seed test data
docker-compose --profile tools run cli seed --count 1000

# Reset database (⚠️ Destructive!)
docker-compose --profile tools run cli reset --confirm

# Backup database
docker-compose --profile backup run backup

# Restore from backup
docker-compose --profile tools run cli restore /backups/latest.dump

# Open PgAdmin
docker-compose --profile admin up -d pgadmin
open http://localhost:5050  # admin@llm-observatory.local/admin
```

---

### 6. Common Tasks

#### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f collector

# Last 100 lines
docker-compose logs --tail=100 api

# Follow logs with grep filter
docker-compose logs -f | grep ERROR
```

#### Restart Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart collector

# Rebuild and restart
docker-compose up -d --build collector
```

#### Clean Up

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (⚠️ Deletes all data!)
docker-compose down -v

# Remove all unused Docker resources
docker system prune -a --volumes
```

#### Update Dependencies

```bash
# Update Cargo dependencies
cargo update

# Rebuild all services
docker-compose build --no-cache

# Restart services
docker-compose up -d
```

---

## Testing Strategy

### 1. Unit Tests

**Run locally (fast):**
```bash
cargo test
```

**Run in Docker (consistent):**
```bash
docker-compose run --rm test-runner cargo test
```

### 2. Integration Tests

**docker-compose.test.yml:**
```yaml
version: '3.8'

services:
  test-db:
    image: timescale/timescaledb:2.14.2-pg16
    environment:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: llm_observatory_test
    tmpfs:
      - /var/lib/postgresql/data  # In-memory for speed

  test-redis:
    image: redis:7.2-alpine
    tmpfs:
      - /data

  test-runner:
    build:
      context: .
      dockerfile: docker/Dockerfile.test
    environment:
      DATABASE_URL: postgresql://test:test@test-db:5432/llm_observatory_test
      REDIS_URL: redis://test-redis:6379
      RUST_LOG: debug
    depends_on:
      - test-db
      - test-redis
    volumes:
      - .:/app
      - test_target:/app/target
      - cargo_registry:/usr/local/cargo/registry
```

**Run integration tests:**
```bash
docker-compose -f docker-compose.test.yml up --abort-on-container-exit test-runner
```

### 3. End-to-End Tests

**Test complete flow:**
```bash
# Start all services
docker-compose up -d

# Wait for healthy
sleep 30

# Send test traces
./tests/e2e/send_test_traces.sh

# Query API
./tests/e2e/verify_api_responses.sh

# Check dashboards
./tests/e2e/verify_grafana_dashboards.sh

# Cleanup
docker-compose down
```

### 4. Performance Tests

```bash
# Start monitoring
docker-compose --profile monitoring up -d prometheus grafana

# Run load test
docker-compose run --rm load-tester \
  k6 run /tests/performance/collector_load_test.js

# View results in Grafana
open http://localhost:3000
```

---

## Documentation Requirements

### 1. Docker README (docker/README.md)

**Sections:**
- Overview of Docker setup
- Prerequisites
- Quick start guide
- Service descriptions
- Port mappings
- Volume descriptions
- Network architecture
- Troubleshooting

### 2. Quick Start Guide (docs/QUICK_START.md)

**Sections:**
- 5-minute setup
- Common commands
- First API call
- View dashboards
- Debugging tips

### 3. Docker Workflows (docs/DOCKER_WORKFLOWS.md)

**Sections:**
- Development workflow
- Testing workflow
- Debugging workflow
- Database management
- Monitoring and observability
- Common tasks

### 4. Troubleshooting Guide (docs/TROUBLESHOOTING_DOCKER.md)

**Sections:**
- Services won't start
- Port conflicts
- Volume permission issues
- Build failures
- Network connectivity issues
- Performance issues
- Data loss prevention

### 5. Architecture Documentation (docs/ARCHITECTURE_DOCKER.md)

**Sections:**
- Service architecture diagram
- Network topology
- Volume strategy
- Build strategy
- Security considerations
- Production differences

---

## Success Criteria

### Functional Criteria

✅ **FC1: Complete Service Coverage**
- All 5 application services containerized
- All infrastructure services configured
- Service health checks working
- Inter-service communication verified

✅ **FC2: Development Experience**
- Hot reload working for all services (< 3s reload time)
- Debug builds with symbols available
- IDE integration (VSCode, RustRover) configured
- Source code volume mounts working

✅ **FC3: Testing Infrastructure**
- Unit test execution in Docker
- Integration test isolation
- E2E test suite functional
- Performance testing capability

✅ **FC4: Documentation**
- Quick start guide (0-5 min setup)
- Development workflows documented
- Debugging guide complete
- Troubleshooting guide available

### Performance Criteria

✅ **PC1: Startup Time**
- Cold start (with downloads): < 5 minutes
- Warm restart: < 30 seconds
- Hot reload: < 3 seconds

✅ **PC2: Resource Usage**
- Total RAM usage: < 4GB for full stack
- CPU usage (idle): < 10%
- Disk usage: < 2GB (excluding data volumes)

✅ **PC3: Reliability**
- Services recover from crashes
- Data persists across restarts
- Health checks accurate
- Graceful shutdown working

### Quality Criteria

✅ **QC1: Code Quality**
- Dockerfiles follow best practices
- Multi-stage builds for production
- Proper layer caching
- Minimal image sizes

✅ **QC2: Security**
- Non-root users in containers
- Secrets from environment
- Network isolation
- No privileged containers

✅ **QC3: Maintainability**
- Clear separation of dev/prod configs
- Version pinning for images
- Commented configurations
- Upgrade path documented

---

## Appendix A: File Structure

### Expected File Tree

```
llm-observatory/
├── docker/
│   ├── Dockerfile.collector
│   ├── Dockerfile.collector.dev
│   ├── Dockerfile.storage
│   ├── Dockerfile.storage.dev
│   ├── Dockerfile.api
│   ├── Dockerfile.api.dev
│   ├── Dockerfile.cli
│   ├── Dockerfile.test
│   ├── init/
│   │   ├── 01-init-timescaledb.sql
│   │   └── 02-seed-test-data.sql
│   ├── scripts/
│   │   ├── cli-entrypoint.sh
│   │   ├── wait-for-it.sh
│   │   └── healthcheck.sh
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   ├── alerts/
│   │   │   └── storage_layer_alerts.yml
│   │   └── alertmanager.yml
│   └── README.md
├── docker-compose.yml           # Base configuration
├── docker-compose.dev.yml       # Development overrides
├── docker-compose.prod.yml      # Production configuration
├── docker-compose.test.yml      # Testing configuration
├── docker-compose.debug.yml     # Debugging configuration
├── .env.example
├── .env                         # User-specific (gitignored)
├── .dockerignore
├── .vscode/
│   ├── launch.json              # Debug configurations
│   └── tasks.json               # Build tasks
└── docs/
    ├── QUICK_START.md
    ├── DOCKER_WORKFLOWS.md
    ├── TROUBLESHOOTING_DOCKER.md
    └── ARCHITECTURE_DOCKER.md
```

---

## Appendix B: Environment Variables Reference

### Complete .env Template

```bash
# =============================================================================
# LLM Observatory - Docker Compose Environment Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# Core Services
# -----------------------------------------------------------------------------

# TimescaleDB
DB_HOST=timescaledb
DB_PORT=5432
DB_NAME=llm_observatory
DB_USER=postgres
DB_PASSWORD=postgres_dev_password
DB_APP_USER=llm_observatory_app
DB_APP_PASSWORD=app_dev_password
DB_READONLY_USER=llm_observatory_readonly
DB_READONLY_PASSWORD=readonly_dev_password

DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
DATABASE_APP_URL=postgresql://${DB_APP_USER}:${DB_APP_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
DATABASE_READONLY_URL=postgresql://${DB_READONLY_USER}:${DB_READONLY_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis_dev_password
REDIS_URL=redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/0

# -----------------------------------------------------------------------------
# Application Services
# -----------------------------------------------------------------------------

# Collector
COLLECTOR_OTLP_GRPC_PORT=4317
COLLECTOR_OTLP_HTTP_PORT=4318
COLLECTOR_METRICS_PORT=9091

# Storage
STORAGE_API_PORT=8081
STORAGE_METRICS_PORT=9092

# API
API_PORT=8080
API_METRICS_PORT=9093

# -----------------------------------------------------------------------------
# Monitoring Services
# -----------------------------------------------------------------------------

# Grafana
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin_dev

# Prometheus
PROMETHEUS_PORT=9090

# Jaeger
JAEGER_UI_PORT=16686

# PgAdmin (optional)
PGADMIN_PORT=5050
PGADMIN_EMAIL=admin@localhost
PGADMIN_PASSWORD=admin_dev

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------

JWT_SECRET=dev_jwt_secret_change_in_production
SECRET_KEY=dev_secret_key_change_in_production
CORS_ORIGINS=http://localhost:3000,http://localhost:8080

# -----------------------------------------------------------------------------
# Development Settings
# -----------------------------------------------------------------------------

ENVIRONMENT=development
RUST_LOG=info
LOG_FORMAT=pretty  # Use 'json' in production
DEBUG=true
AUTO_RELOAD=true
DB_QUERY_LOGGING=false

# -----------------------------------------------------------------------------
# Docker Compose
# -----------------------------------------------------------------------------

COMPOSE_PROJECT_NAME=llm-observatory
COMPOSE_FILE=docker-compose.yml:docker-compose.dev.yml
```

---

## Appendix C: Common Issues & Solutions

### Issue: Port Already in Use

**Symptom:**
```
Error starting userland proxy: listen tcp 0.0.0.0:5432: bind: address already in use
```

**Solution:**
```bash
# Find process using port
lsof -i :5432

# Change port in .env
DB_PORT=5433
```

---

### Issue: Permission Denied on Volumes

**Symptom:**
```
Permission denied: '/var/lib/postgresql/data'
```

**Solution:**
```bash
# Fix volume permissions
docker-compose down -v
docker volume prune
docker-compose up -d
```

---

### Issue: Slow Build Times

**Symptom:**
Build takes > 10 minutes

**Solution:**
```bash
# Use build cache volumes
# Already configured in docker-compose.yml

# Clear and rebuild
docker-compose build --no-cache collector
```

---

### Issue: Service Fails Health Check

**Symptom:**
```
unhealthy: health check failed
```

**Solution:**
```bash
# Check logs
docker-compose logs collector

# Increase start_period
# Edit docker-compose.yml: start_period: 120s

# Manual health check
docker-compose exec collector curl http://localhost:9090/health
```

---

## Conclusion

This plan provides a comprehensive roadmap for implementing a production-grade Docker Compose development environment for the LLM Observatory project. The phased approach ensures:

1. **Incremental Progress:** Build and test each component independently
2. **Fast Iteration:** Hot reload enables rapid development
3. **Production Parity:** Development closely mirrors production
4. **Developer Friendly:** One-command setup, clear documentation
5. **Maintainable:** Standard Docker patterns, well-organized

**Next Steps:**
1. Review and approve this plan
2. Begin Phase 1 implementation
3. Iterate based on developer feedback
4. Expand to production deployment

**Estimated Timeline:** 2 weeks for full implementation
**Effort:** ~80 hours (1 full-time developer)
**Status:** Ready to begin implementation

---

**Document Owner:** LLM Observatory Core Team
**Last Updated:** 2025-11-05
**Version:** 1.0

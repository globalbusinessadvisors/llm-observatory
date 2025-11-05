# Docker Architecture - LLM Observatory

Comprehensive architectural documentation for the Docker-based LLM Observatory infrastructure, including service design, networking, storage, security, and deployment strategies.

## Table of Contents

- [Overview](#overview)
- [Service Architecture](#service-architecture)
- [Network Topology](#network-topology)
- [Volume Strategy](#volume-strategy)
- [Build Strategy](#build-strategy)
- [Security Considerations](#security-considerations)
- [Production Deployment](#production-deployment)
- [Scaling Architecture](#scaling-architecture)

---

## Overview

### Design Principles

LLM Observatory's Docker architecture follows these core principles:

1. **Separation of Concerns**: Each service handles a specific responsibility
2. **Fault Isolation**: Service failures don't cascade
3. **Scalability**: Horizontal scaling for compute, vertical for storage
4. **Observability**: Built-in health checks and monitoring
5. **Security**: Defense in depth with multiple security layers
6. **Maintainability**: Clear configuration, well-documented

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           External Network                              │
│                      (Internet / Organization Network)                  │
└────────────────────┬────────────────────────────────────────────────────┘
                     │
                     │ HTTP/HTTPS (Ports: 3000, 5050, 8080, 4317/4318)
                     │
        ┌────────────▼──────────────────────────────────────────┐
        │          Reverse Proxy (Optional)                     │
        │          Nginx/Traefik/HAProxy                        │
        │          - TLS termination                            │
        │          - Load balancing                             │
        │          - Rate limiting                              │
        └────────────┬──────────────────────────────────────────┘
                     │
┌────────────────────▼───────────────────────────────────────────────────┐
│                    Docker Bridge Network                                │
│                  (llm-observatory-network)                              │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │                    Application Layer                             │ │
│  │                                                                  │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │ │
│  │  │ API Server   │  │  Collector   │  │   Grafana    │         │ │
│  │  │ (Rust/Axum)  │  │ (OTLP/gRPC)  │  │ (Web UI)     │         │ │
│  │  │ Port: 8080   │  │ Port: 4317   │  │ Port: 3000   │         │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │ │
│  │         │                  │                  │                 │ │
│  └─────────┼──────────────────┼──────────────────┼─────────────────┘ │
│            │                  │                  │                   │
│  ┌─────────▼──────────────────▼──────────────────▼─────────────────┐ │
│  │                    Storage Layer                                 │ │
│  │                                                                  │ │
│  │  ┌──────────────┐  ┌──────────────┐                            │ │
│  │  │ TimescaleDB  │  │    Redis     │                            │ │
│  │  │ (PostgreSQL) │  │   (Cache)    │                            │ │
│  │  │ Port: 5432   │  │  Port: 6379  │                            │ │
│  │  └──────┬───────┘  └──────┬───────┘                            │ │
│  │         │                  │                                     │ │
│  └─────────┼──────────────────┼─────────────────────────────────────┘ │
│            │                  │                                       │
│  ┌─────────▼──────────────────▼─────────────────────────────────────┐ │
│  │                   Persistent Volumes                              │ │
│  │                                                                   │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │ │
│  │  │  db-data     │  │ redis-data   │  │ grafana-data │          │ │
│  │  │  (Named)     │  │   (Named)    │  │   (Named)    │          │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘          │ │
│  │                                                                   │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    Admin Layer (Optional)                         │ │
│  │                                                                   │ │
│  │  ┌──────────────┐  ┌──────────────┐                            │ │
│  │  │   PgAdmin    │  │    Backup    │                            │ │
│  │  │  Port: 5050  │  │   Service    │                            │ │
│  │  │ [--profile   │  │ [--profile   │                            │ │
│  │  │   admin]     │  │   backup]    │                            │ │
│  │  └──────────────┘  └──────────────┘                            │ │
│  │                                                                   │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Service Architecture

### Core Services

#### TimescaleDB (PostgreSQL 16 + TimescaleDB 2.14.2)

**Purpose**: Primary storage for time-series LLM metrics and traces.

**Key Features**:
- Automatic time-series partitioning via hypertables
- Continuous aggregates for pre-computed rollups
- Native PostgreSQL compatibility (ACID, constraints, triggers)
- JSON/JSONB support for flexible schema
- Full-text search capabilities

**Resource Requirements**:
```yaml
resources:
  development:
    memory: 1GB
    cpu: 1 core
    storage: 10GB
  production:
    memory: 8GB
    cpu: 4 cores
    storage: 500GB (expandable)
```

**Configuration**:
- Shared buffers: 25% of RAM
- Effective cache size: 50-75% of RAM
- Max connections: 200 (pooled via application)
- Checkpoint timeout: 10-15 minutes
- WAL level: replica (for streaming replication)

**Health Check**:
```bash
pg_isready -U postgres -d llm_observatory
```

#### Redis (7.2-alpine)

**Purpose**: High-performance caching layer for query results, session management, and rate limiting.

**Key Features**:
- In-memory data structure store
- LRU eviction policy
- AOF persistence for durability
- Pub/Sub for real-time events
- Lua scripting support

**Resource Requirements**:
```yaml
resources:
  development:
    memory: 256MB
    cpu: 0.5 core
  production:
    memory: 2GB
    cpu: 2 cores
```

**Configuration**:
- Max memory: 256MB (dev), 2GB (prod)
- Eviction policy: allkeys-lru
- Persistence: AOF with fsync every second
- Max clients: 10,000

**Use Cases**:
1. Query result caching (TTL: 5-60 minutes)
2. Rate limiting counters
3. Session storage
4. Temporary aggregations
5. Real-time event streaming

#### Grafana (10.4.1)

**Purpose**: Visualization platform for dashboards and data exploration.

**Key Features**:
- PostgreSQL datasource (TimescaleDB)
- Template variables for dynamic dashboards
- Alerting integration
- API for programmatic management
- Plugin ecosystem

**Resource Requirements**:
```yaml
resources:
  development:
    memory: 512MB
    cpu: 0.5 core
  production:
    memory: 2GB
    cpu: 1 core
```

**Database Storage**:
- Uses TimescaleDB for metadata (not SQLite)
- Shared database reduces infrastructure
- Better reliability and backup strategy

#### API Server (Rust/Axum) - Coming Soon

**Purpose**: REST API for span ingestion, querying, and management.

**Planned Features**:
- RESTful API for span creation
- GraphQL endpoint for complex queries
- Authentication/Authorization (JWT)
- Rate limiting and quotas
- OpenAPI/Swagger documentation

**Endpoints**:
```
POST   /api/v1/spans           - Create span
GET    /api/v1/spans/:id       - Get span
GET    /api/v1/traces/:id      - Get full trace
POST   /api/v1/query           - Query spans
GET    /api/v1/metrics         - Get metrics
GET    /health                 - Health check
GET    /metrics                - Prometheus metrics
```

#### Collector (OTLP) - Coming Soon

**Purpose**: OpenTelemetry collector for receiving and processing telemetry.

**Planned Features**:
- OTLP gRPC and HTTP receivers
- Intelligent sampling (head and tail)
- PII redaction processor
- Batch processing and compression
- Export to TimescaleDB

**Sampling Strategies**:
1. Head sampling: Probabilistic (1-10%)
2. Tail sampling: Complete traces with errors or high latency
3. Cost-based sampling: Always sample expensive requests
4. Priority sampling: 100% for critical paths

### Optional Services

#### PgAdmin (8.4)

**Purpose**: Web-based database administration.

**Access**: `--profile admin`

**Use Cases**:
- Schema exploration
- Ad-hoc queries
- Performance analysis
- Database maintenance

#### Backup Service

**Purpose**: Automated database backups.

**Access**: `--profile backup`

**Features**:
- Scheduled backups via cron
- S3 upload support
- Retention policies
- Point-in-Time Recovery (PITR)

---

## Network Topology

### Bridge Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 llm-observatory-network                     │
│                    (Bridge Driver)                           │
│                                                              │
│  Network: 172.18.0.0/16 (default, may vary)                │
│  Gateway: 172.18.0.1                                        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Container IP Assignments (Dynamic via DHCP)          │  │
│  │                                                       │  │
│  │  timescaledb:  172.18.0.2:5432                       │  │
│  │  redis:        172.18.0.3:6379                       │  │
│  │  grafana:      172.18.0.4:3000                       │  │
│  │  api:          172.18.0.5:8080                       │  │
│  │  collector:    172.18.0.6:4317                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  DNS Resolution:                                            │
│  - timescaledb → 172.18.0.2                                │
│  - redis → 172.18.0.3                                       │
│  - grafana → 172.18.0.4                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         │
         │ Port Mappings (Host:Container)
         │
         ├─── 5432:5432  → TimescaleDB
         ├─── 6379:6379  → Redis
         ├─── 3000:3000  → Grafana
         ├─── 8080:8080  → API (coming soon)
         └─── 4317:4317  → Collector (coming soon)
```

### Network Security

**Isolation**:
- Dedicated bridge network isolates services
- No direct access between different deployments
- Optional network policies for enterprise

**Service Discovery**:
- Automatic DNS resolution via container names
- No need for IP addresses in configuration
- Example: `postgresql://postgres@timescaledb:5432/db`

**External Access**:
- Only mapped ports accessible from host
- Internal ports (e.g., metrics endpoints) remain internal
- Reverse proxy recommended for production

### Communication Patterns

```
Client Application
     │
     ├── HTTP → API Server (8080)
     │            │
     │            ├── PostgreSQL → TimescaleDB (5432)
     │            └── Redis → Redis (6379)
     │
     ├── OTLP gRPC → Collector (4317)
     │                  │
     │                  └── PostgreSQL → TimescaleDB (5432)
     │
     └── HTTP → Grafana (3000)
                    │
                    └── PostgreSQL → TimescaleDB (5432)
```

### Network Configuration Options

**Development** (current):
```yaml
networks:
  llm-observatory-network:
    driver: bridge
```

**Production** (with custom subnet):
```yaml
networks:
  llm-observatory-network:
    driver: bridge
    ipam:
      config:
        - subnet: 10.10.0.0/24
          gateway: 10.10.0.1
```

**Multi-Host** (Docker Swarm):
```yaml
networks:
  llm-observatory-network:
    driver: overlay
    attachable: true
```

---

## Volume Strategy

### Volume Architecture

```
Docker Volume Management
│
├─── Named Volumes (Managed by Docker)
│    │
│    ├─── llm-observatory-db-data
│    │    └── /var/lib/postgresql/data
│    │         - Database files
│    │         - WAL logs
│    │         - Configuration
│    │
│    ├─── llm-observatory-redis-data
│    │    └── /data
│    │         - RDB snapshots
│    │         - AOF logs
│    │
│    ├─── llm-observatory-grafana-data
│    │    └── /var/lib/grafana
│    │         - Dashboards
│    │         - Plugins
│    │         - Settings
│    │
│    ├─── llm-observatory-pgadmin-data
│    │    └── /var/lib/pgadmin
│    │         - Server configs
│    │         - User preferences
│    │
│    └─── llm-observatory-backup-data
│         └── /backups
│              - SQL dumps
│              - Compressed archives
│
└─── Bind Mounts (Configuration Only)
     │
     ├─── ./docker/init:/docker-entrypoint-initdb.d:ro
     │    - Database initialization scripts
     │
     ├─── ./scripts:/scripts:ro
     │    - Backup/restore scripts
     │
     └─── ./.env:/app/.env:ro
          - Environment configuration
```

### Volume Characteristics

| Volume | Size (Dev) | Size (Prod) | Growth Rate | Backup Priority | Snapshot Frequency |
|--------|------------|-------------|-------------|-----------------|-------------------|
| db-data | 1-10GB | 100GB-1TB | High | **CRITICAL** | Daily + PITR |
| redis-data | <100MB | 1-5GB | Low | Medium | Weekly |
| grafana-data | <500MB | 1-2GB | Low | High | Weekly |
| pgadmin-data | <100MB | <500MB | Minimal | Low | Monthly |
| backup-data | Variable | 50-200GB | Variable | **CRITICAL** | N/A (is backups) |

### Volume Performance Considerations

**Block Size**:
- TimescaleDB: 8KB (PostgreSQL default, optimal for most workloads)
- Redis: Not applicable (in-memory)

**Filesystem**:
- Linux: ext4 or XFS recommended
- macOS: APFS (via VM)
- Windows: NTFS (via WSL2/VM)

**I/O Patterns**:
- TimescaleDB: Sequential writes (WAL), random reads
- Redis: Sequential writes (AOF), sequential reads (RDB)
- Grafana: Random reads/writes (low volume)

### Backup Strategy

**TimescaleDB** (Critical):
```bash
# Logical backup (pg_dump) - Daily
0 2 * * * docker compose exec timescaledb pg_dump -Fc llm_observatory > backup_$(date +\%Y\%m\%d).dump

# Physical backup (pg_basebackup) - Weekly
0 3 * * 0 docker compose exec timescaledb pg_basebackup -D /backups/base_$(date +\%Y\%m\%d)

# WAL archiving - Continuous
archive_mode = on
archive_command = 'test ! -f /wal_archive/%f && cp %p /wal_archive/%f'
```

**Redis** (Medium):
```bash
# RDB snapshot - Daily (automatic)
save 900 1      # After 900 sec (15 min) if at least 1 key changed
save 300 10     # After 300 sec (5 min) if at least 10 keys changed
save 60 10000   # After 60 sec if at least 10000 keys changed

# AOF backup - Hourly
0 * * * * docker compose exec redis redis-cli -a password BGREWRITEAOF
```

**Grafana** (High):
```bash
# Dashboard export - Daily
0 4 * * * docker compose exec grafana grafana-cli dashboards export > grafana_backup_$(date +\%Y\%m\%d).json

# Volume snapshot - Weekly
0 5 * * 0 docker run --rm -v llm-observatory-grafana-data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/grafana_$(date +\%Y\%m\%d).tar.gz /data
```

---

## Build Strategy

### Development Build

**Current Approach** (Local Rust, Dockerized Infrastructure):

```bash
# Infrastructure only
docker compose up -d

# Application development
cargo watch -x 'run --bin llm-observatory-api'
cargo watch -x 'test'
```

**Advantages**:
- Fast iteration (no Docker rebuild)
- Native debugging tools
- IDE integration
- Hot reload via cargo-watch

### Production Build (Future)

**Multi-Stage Dockerfile**:

```dockerfile
# Stage 1: Builder
FROM rust:1.75-slim AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -u 1001 app

WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock ./
COPY crates/ crates/

# Build dependencies (cached layer)
RUN cargo build --release --locked

# Stage 2: Runtime
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -u 1001 app
USER app

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/target/release/llm-observatory-api /app/

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/llm-observatory-api", "health"]

# Run
CMD ["/app/llm-observatory-api"]
```

**Build Process**:

```bash
# Build with BuildKit
DOCKER_BUILDKIT=1 docker build \
  --tag llm-observatory/api:latest \
  --tag llm-observatory/api:0.1.0 \
  --cache-from llm-observatory/api:latest \
  --build-arg RUST_VERSION=1.75 \
  .

# Push to registry
docker push llm-observatory/api:0.1.0
docker push llm-observatory/api:latest
```

### Build Optimization

**Layer Caching**:
1. Base image layer (rarely changes)
2. System dependencies layer (occasional changes)
3. Cargo dependencies layer (frequent changes)
4. Application code layer (very frequent changes)

**BuildKit Features**:
- Parallel stage execution
- Build cache import/export
- Build secrets (for private dependencies)
- Multi-platform builds

**Build Time Comparison**:
```
Without cache: 15-20 minutes
With cache (code change): 2-3 minutes
With cache (dependency change): 8-10 minutes
```

### Continuous Integration

**GitHub Actions** (example):

```yaml
name: Build and Push

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            llm-observatory/api:latest
            llm-observatory/api:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Security Considerations

### Network Security

**Principle: Defense in Depth**

```
┌───────────────────────────────────────────────────────────┐
│ Layer 1: Reverse Proxy (Nginx/Traefik)                   │
│ - TLS termination (Let's Encrypt)                        │
│ - Rate limiting (100 req/min per IP)                     │
│ - IP allowlisting/blocklisting                           │
│ - DDoS protection                                         │
└───────────────────────┬───────────────────────────────────┘
                        │
┌───────────────────────▼───────────────────────────────────┐
│ Layer 2: Application Authentication                       │
│ - JWT token validation                                    │
│ - API key verification                                    │
│ - OAuth2/OIDC integration                                 │
└───────────────────────┬───────────────────────────────────┘
                        │
┌───────────────────────▼───────────────────────────────────┐
│ Layer 3: Application Authorization                        │
│ - Role-Based Access Control (RBAC)                        │
│ - Resource-level permissions                              │
│ - Audit logging                                           │
└───────────────────────┬───────────────────────────────────┘
                        │
┌───────────────────────▼───────────────────────────────────┐
│ Layer 4: Database Security                                │
│ - Separate users (admin, app, readonly)                  │
│ - Row-level security policies                             │
│ - SSL/TLS connections                                     │
│ - Connection pooling limits                               │
└───────────────────────────────────────────────────────────┘
```

### Secrets Management

**Development** (current):
```bash
# .env file (not committed)
DB_PASSWORD=changeme
REDIS_PASSWORD=changeme
SECRET_KEY=changeme
```

**Production** (recommended):

**Option 1: Docker Secrets** (Docker Swarm):
```yaml
secrets:
  db_password:
    external: true
  redis_password:
    external: true

services:
  timescaledb:
    secrets:
      - db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
```

**Option 2: HashiCorp Vault**:
```bash
# Fetch secrets at runtime
export DB_PASSWORD=$(vault kv get -field=password secret/llm-observatory/db)
export REDIS_PASSWORD=$(vault kv get -field=password secret/llm-observatory/redis)
```

**Option 3: AWS Secrets Manager**:
```bash
# Fetch from AWS
export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id llm-obs/db/password --query SecretString --output text)
```

### Container Security

**User Privileges**:
```yaml
# Don't run as root
services:
  api:
    user: "1001:1001"  # non-root user
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if binding to port <1024
```

**Read-Only Filesystem**:
```yaml
services:
  api:
    read_only: true
    tmpfs:
      - /tmp
      - /var/run
```

**Security Options**:
```yaml
services:
  timescaledb:
    security_opt:
      - no-new-privileges:true
      - seccomp:unconfined  # Only if needed
```

### SSL/TLS Configuration

**Production docker-compose.yml**:

```yaml
services:
  timescaledb:
    command: >
      postgres
      -c ssl=on
      -c ssl_cert_file=/etc/ssl/certs/server.crt
      -c ssl_key_file=/etc/ssl/private/server.key
    volumes:
      - ./certs/server.crt:/etc/ssl/certs/server.crt:ro
      - ./certs/server.key:/etc/ssl/private/server.key:ro

  redis:
    command: >
      redis-server
      --tls-port 6379
      --port 0
      --tls-cert-file /etc/ssl/certs/server.crt
      --tls-key-file /etc/ssl/private/server.key
    volumes:
      - ./certs/server.crt:/etc/ssl/certs/server.crt:ro
      - ./certs/server.key:/etc/ssl/private/server.key:ro
```

**Generate Certificates**:
```bash
# Self-signed (development)
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout certs/server.key \
  -out certs/server.crt \
  -days 365 \
  -subj "/CN=llm-observatory.local"

# Let's Encrypt (production)
certbot certonly --standalone -d llm-observatory.example.com
```

### PII Redaction

**Planned Feature** (OTLP Collector):

```yaml
# Redact sensitive data before storage
processors:
  pii_redaction:
    fields:
      - span.attributes.user.email
      - span.attributes.user.phone
      - span.attributes.user.ssn
    strategy: hash  # or mask, remove
```

---

## Production Deployment

### Production vs Development

| Aspect | Development | Production |
|--------|-------------|------------|
| **Passwords** | Default | Strong, rotated |
| **SSL/TLS** | Disabled | Required |
| **Resource Limits** | None | Configured |
| **Health Checks** | Basic | Comprehensive |
| **Logging** | Verbose | Structured JSON |
| **Monitoring** | Optional | Required |
| **Backups** | Manual | Automated |
| **High Availability** | No | Yes (replicas) |

### Production Checklist

**Pre-Deployment**:
- [ ] Change all default passwords
- [ ] Configure SSL/TLS certificates
- [ ] Set up automated backups
- [ ] Configure monitoring and alerting
- [ ] Review resource limits
- [ ] Enable audit logging
- [ ] Configure firewall rules
- [ ] Set up log rotation
- [ ] Test disaster recovery
- [ ] Document runbooks

**Deployment**:
```bash
# 1. Create production .env
cp .env.example .env.prod
# Edit .env.prod with production values

# 2. Deploy with production config
docker compose --env-file .env.prod -f docker-compose.yml -f docker-compose.prod.yml up -d

# 3. Verify deployment
./scripts/health-check.sh
./scripts/verify_deployment.sh

# 4. Configure monitoring
docker compose -f docker/monitoring-stack.yml up -d
```

**Post-Deployment**:
- Monitor logs for errors
- Verify backups working
- Test application functionality
- Run load tests
- Update documentation

### High Availability Setup

**Database Replication**:

```yaml
# Primary
services:
  timescaledb-primary:
    image: timescale/timescaledb:2.14.2-pg16
    environment:
      - POSTGRES_REPLICATION_MODE=master
    volumes:
      - primary-data:/var/lib/postgresql/data

# Replica (read-only)
  timescaledb-replica:
    image: timescale/timescaledb:2.14.2-pg16
    environment:
      - POSTGRES_REPLICATION_MODE=slave
      - POSTGRES_MASTER_SERVICE_HOST=timescaledb-primary
    volumes:
      - replica-data:/var/lib/postgresql/data
```

**Load Balancing**:

```yaml
# HAProxy configuration
services:
  haproxy:
    image: haproxy:2.8
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - api-1
      - api-2
      - api-3

  api-1:
    image: llm-observatory/api:latest
    deploy:
      replicas: 1

  api-2:
    image: llm-observatory/api:latest
    deploy:
      replicas: 1

  api-3:
    image: llm-observatory/api:latest
    deploy:
      replicas: 1
```

---

## Scaling Architecture

### Horizontal Scaling

**Application Tier**:
```bash
# Scale API servers
docker compose up -d --scale api=5

# Scale collectors
docker compose up -d --scale collector=3
```

**Load Balancing** (Nginx example):

```nginx
upstream api_backend {
    least_conn;
    server api-1:8080 max_fails=3 fail_timeout=30s;
    server api-2:8080 max_fails=3 fail_timeout=30s;
    server api-3:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    location / {
        proxy_pass http://api_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Vertical Scaling

**Database** (resource limits):
```yaml
services:
  timescaledb:
    deploy:
      resources:
        limits:
          cpus: '8.0'
          memory: 32G
        reservations:
          cpus: '4.0'
          memory: 16G
    environment:
      - DB_SHARED_BUFFERS=8GB
      - DB_EFFECTIVE_CACHE_SIZE=24GB
```

### Sharding Strategy (Future)

**Time-based Sharding**:
```sql
-- Shard by month
CREATE TABLE spans_2024_01 PARTITION OF spans
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE spans_2024_02 PARTITION OF spans
  FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
```

**Tenant-based Sharding**:
```sql
-- Shard by organization
CREATE TABLE spans_org_1 PARTITION OF spans
  FOR VALUES IN ('org-1');

CREATE TABLE spans_org_2 PARTITION OF spans
  FOR VALUES IN ('org-2');
```

---

## Monitoring Architecture

See [Monitoring Setup](/workspaces/llm-observatory/docs/MONITORING_SETUP.md) for detailed implementation.

**Stack**:
- Prometheus (metrics collection)
- Grafana (visualization)
- AlertManager (alerting)
- Loki (log aggregation) - optional

**Key Metrics**:
- Database: Connections, query latency, cache hit ratio
- Redis: Memory usage, cache hit ratio, evictions
- Application: Request rate, error rate, latency (RED method)
- System: CPU, memory, disk I/O, network

---

**Built with ❤️ for the LLM community**

For more details:
- [Docker README](/workspaces/llm-observatory/docker/README.md)
- [Docker Workflows](/workspaces/llm-observatory/docs/DOCKER_WORKFLOWS.md)
- [Troubleshooting](/workspaces/llm-observatory/docs/TROUBLESHOOTING_DOCKER.md)
- [Quick Start](/workspaces/llm-observatory/docs/QUICK_START.md)

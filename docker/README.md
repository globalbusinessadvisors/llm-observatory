# LLM Observatory - Docker Infrastructure

Complete guide to the Docker environment for LLM Observatory, including services, configuration, troubleshooting, and best practices.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Service Descriptions](#service-descriptions)
- [Port Mappings](#port-mappings)
- [Volume Descriptions](#volume-descriptions)
- [Network Architecture](#network-architecture)
- [Common Commands](#common-commands)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

---

## Overview

The LLM Observatory Docker environment provides a complete observability stack optimized for Large Language Model applications. Built around TimescaleDB for time-series metrics and Grafana for visualization, this setup enables production-grade monitoring with minimal configuration.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Network                            │
│              (llm-observatory-network)                       │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ TimescaleDB  │  │    Redis     │  │   Grafana    │     │
│  │   (Port      │  │  (Port 6379) │  │ (Port 3000)  │     │
│  │    5432)     │  │              │  │              │     │
│  │              │  │   Caching &  │  │ Dashboards & │     │
│  │ Time-series  │  │   Sessions   │  │   Queries    │     │
│  │   Metrics    │  │              │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                                     │             │
│         └─────────────────────────────────────┘             │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │   PgAdmin    │  │    Backup    │                        │
│  │ (Port 5050)  │  │   Service    │                        │
│  │              │  │              │                        │
│  │ Admin UI     │  │ Automated    │                        │
│  │ (Optional)   │  │ Backups      │                        │
│  └──────────────┘  └──────────────┘                        │
│   [--profile admin]  [--profile backup]                    │
└─────────────────────────────────────────────────────────────┘
```

### Key Features

- **TimescaleDB 2.14.2**: PostgreSQL 16 with time-series extensions for efficient metrics storage
- **Redis 7.2**: High-performance caching and session management
- **Grafana 10.4.1**: Modern visualization platform with pre-configured datasources
- **Health Checks**: Automated health monitoring for all services
- **Named Volumes**: Persistent data storage with clear naming conventions
- **Optional Services**: PgAdmin for database administration, automated backups
- **Production-Ready**: Configurable security, performance tuning, and monitoring

---

## Prerequisites

### Required Software

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher (included with Docker Desktop)

Check your installation:

```bash
docker --version
# Docker version 24.0.0 or higher

docker compose version
# Docker Compose version v2.20.0 or higher
```

### System Requirements

**Minimum (Development):**
- 4GB RAM
- 10GB disk space
- 2 CPU cores

**Recommended (Production):**
- 16GB RAM
- 100GB SSD storage
- 8 CPU cores

### Port Availability

Ensure these ports are available on your host machine:

- `5432` - TimescaleDB/PostgreSQL
- `6379` - Redis
- `3000` - Grafana
- `5050` - PgAdmin (optional, with `--profile admin`)

Check port availability:

```bash
# Linux/macOS
lsof -i :5432
lsof -i :6379
lsof -i :3000

# Windows (PowerShell)
Get-NetTCPConnection -LocalPort 5432
```

---

## Quick Start

### 1. Initial Setup

Clone the repository and navigate to the project root:

```bash
git clone https://github.com/llm-observatory/llm-observatory.git
cd llm-observatory
```

Copy the environment template:

```bash
cp .env.example .env
```

**IMPORTANT**: Edit `.env` and update the following before starting:

```bash
# Change these passwords!
DB_PASSWORD=your_secure_password_here
REDIS_PASSWORD=your_redis_password_here
GRAFANA_ADMIN_PASSWORD=your_grafana_password_here

# Application credentials
DB_APP_PASSWORD=your_app_password_here
DB_READONLY_PASSWORD=your_readonly_password_here

# Security keys (generate with: openssl rand -hex 32)
SECRET_KEY=your_secret_key_here
JWT_SECRET=your_jwt_secret_here
```

### 2. Start Core Services

Start TimescaleDB, Redis, and Grafana:

```bash
docker compose up -d
```

This will:
- Pull required Docker images (first time only)
- Create named volumes for data persistence
- Initialize the database with TimescaleDB extension
- Start all services with health checks

### 3. Verify Services

Check that all services are healthy:

```bash
docker compose ps
```

Expected output:

```
NAME                         IMAGE                                COMMAND                  SERVICE       CREATED          STATUS                    PORTS
llm-observatory-db           timescale/timescaledb:2.14.2-pg16   "docker-entrypoint.s…"   timescaledb   2 minutes ago    Up 2 minutes (healthy)    0.0.0.0:5432->5432/tcp
llm-observatory-grafana      grafana/grafana:10.4.1               "/run.sh"                grafana       2 minutes ago    Up 2 minutes (healthy)    0.0.0.0:3000->3000/tcp
llm-observatory-redis        redis:7.2-alpine                     "docker-entrypoint.s…"   redis         2 minutes ago    Up 2 minutes (healthy)    0.0.0.0:6379->6379/tcp
```

All services should show `(healthy)` status. If not, wait 30-60 seconds for initialization to complete.

### 4. Access Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Grafana** | http://localhost:3000 | `admin` / `admin` |
| **PgAdmin** | http://localhost:5050 | `admin@llm-observatory.local` / `admin` |

**Database connections** (from host machine):

```bash
# TimescaleDB (admin user)
psql postgresql://postgres:postgres@localhost:5432/llm_observatory

# Redis
redis-cli -h localhost -p 6379 -a redis_password
```

### 5. First Steps

1. **Login to Grafana**: Navigate to http://localhost:3000, login with `admin/admin`, and change the password when prompted

2. **Verify Database**:
   ```bash
   docker compose exec timescaledb psql -U postgres -d llm_observatory -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"
   ```

3. **Configure Datasources**: Grafana is pre-configured to connect to TimescaleDB

4. **Explore**: Start sending LLM metrics to the observatory!

---

## Service Descriptions

### TimescaleDB (PostgreSQL 16 + TimescaleDB Extension)

**Primary storage for time-series LLM metrics.**

- **Image**: `timescale/timescaledb:2.14.2-pg16`
- **Container Name**: `llm-observatory-db`
- **Purpose**: Time-series database optimized for LLM observability metrics

**Key Features**:
- TimescaleDB extension for efficient time-series queries
- Hypertables for automatic partitioning
- Continuous aggregates for pre-computed rollups
- Full PostgreSQL compatibility (SQL, indexes, constraints)

**Configuration**:
- Max connections: 200
- Shared buffers: 256MB (configurable via `.env`)
- Query logging enabled for slow queries (>1000ms)
- Automatic health checks via `pg_isready`

**Database Roles**:
- `postgres` - Superuser (admin operations)
- `llm_observatory_app` - Application user (read/write)
- `llm_observatory_readonly` - Analytics user (read-only)

**Extensions Installed**:
- `timescaledb` - Time-series functionality
- `uuid-ossp` - UUID generation
- `pg_stat_statements` - Query performance monitoring

### Redis

**High-performance caching and session storage.**

- **Image**: `redis:7.2-alpine`
- **Container Name**: `llm-observatory-redis`
- **Purpose**: Caching layer for query results, rate limiting, and session management

**Key Features**:
- In-memory data structure store
- LRU eviction policy for automatic cache management
- AOF persistence for data durability
- Password authentication enabled

**Configuration**:
- Max memory: 256MB
- Eviction policy: `allkeys-lru` (least recently used)
- Persistence: AOF with fsync every second
- Authentication: Password-protected (see `.env`)

**Use Cases**:
- Query result caching
- Rate limiting counters
- Session storage
- Temporary metrics aggregation

### Grafana

**Visualization and dashboarding platform.**

- **Image**: `grafana/grafana:10.4.1`
- **Container Name**: `llm-observatory-grafana`
- **Purpose**: Visualize LLM metrics, create dashboards, and run queries

**Key Features**:
- Pre-configured TimescaleDB datasource
- PostgreSQL-backed metadata storage (not SQLite)
- Plugin support for extended functionality
- API access for programmatic dashboard management

**Configuration**:
- Admin user: `admin` (change password on first login)
- Root URL: http://localhost:3000
- Anonymous access: Disabled by default
- Telemetry: Disabled

**Pre-configured**:
- TimescaleDB datasource (automatic connection)
- Grafana metadata stored in TimescaleDB
- Ready for dashboard provisioning

### PgAdmin (Optional)

**Web-based PostgreSQL administration tool.**

- **Image**: `dpage/pgadmin4:8.4`
- **Container Name**: `llm-observatory-pgadmin`
- **Purpose**: Visual database management and query tool
- **Profile**: `admin` (not started by default)

**Start with**:
```bash
docker compose --profile admin up -d
```

**Key Features**:
- Query editor with syntax highlighting
- Visual table browser and schema designer
- Import/export functionality
- Connection management

**Use Cases**:
- Database schema exploration
- Ad-hoc query execution
- Performance analysis
- Database maintenance

### Backup Service (Optional)

**Automated database backup solution.**

- **Image**: `postgres:16-alpine`
- **Container Name**: `llm-observatory-backup`
- **Purpose**: Scheduled and on-demand database backups
- **Profile**: `backup` (runs on-demand only)

**Run backup**:
```bash
docker compose --profile backup run backup
```

**Key Features**:
- `pg_dump` based backups
- Optional S3 integration
- Configurable retention policies
- Automatic compression

**Configuration**:
- Backup directory: `/backups` (mapped to `backup_data` volume)
- Retention: 30 days (configurable)
- S3 support: Optional (configure AWS credentials in `.env`)

---

## Port Mappings

| Host Port | Container Port | Service | Protocol | Description |
|-----------|----------------|---------|----------|-------------|
| `5432` | `5432` | TimescaleDB | TCP | PostgreSQL database connections |
| `6379` | `6379` | Redis | TCP | Redis cache connections |
| `3000` | `3000` | Grafana | HTTP | Grafana web interface |
| `5050` | `80` | PgAdmin | HTTP | PgAdmin web interface (optional) |

### Customizing Ports

If you need to change ports (e.g., conflict with existing services), edit `.env`:

```bash
# Change TimescaleDB port
DB_PORT=15432

# Change Grafana port
GRAFANA_PORT=13000

# Change Redis port
REDIS_PORT=16379

# Change PgAdmin port
PGADMIN_PORT=15050
```

Then restart:

```bash
docker compose down
docker compose up -d
```

---

## Volume Descriptions

### Named Volumes

All data is stored in Docker named volumes for easy management and persistence:

| Volume Name | Purpose | Typical Size | Backup Priority |
|-------------|---------|--------------|-----------------|
| `llm-observatory-db-data` | TimescaleDB data files | 10GB-1TB | **CRITICAL** |
| `llm-observatory-redis-data` | Redis AOF persistence | 256MB-1GB | Medium |
| `llm-observatory-grafana-data` | Grafana dashboards & settings | 100MB-1GB | High |
| `llm-observatory-pgadmin-data` | PgAdmin configuration | 50MB-200MB | Low |
| `llm-observatory-backup-data` | Database backups | Varies | **CRITICAL** |

### Volume Management

**List volumes**:
```bash
docker volume ls | grep llm-observatory
```

**Inspect a volume**:
```bash
docker volume inspect llm-observatory-db-data
```

**Backup a volume** (recommended before upgrades):
```bash
# Stop services first
docker compose down

# Backup database volume
docker run --rm -v llm-observatory-db-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/db-backup-$(date +%Y%m%d-%H%M%S).tar.gz /data
```

**Restore a volume**:
```bash
# Restore database volume
docker run --rm -v llm-observatory-db-data:/data -v $(pwd):/backup alpine \
  tar xzf /backup/db-backup-YYYYMMDD-HHMMSS.tar.gz -C /
```

**Remove volumes** (WARNING: Deletes all data):
```bash
# Remove all volumes (only when services are stopped)
docker compose down -v
```

### Volume Location

Docker volumes are typically stored at:

- **Linux**: `/var/lib/docker/volumes/`
- **macOS**: `~/Library/Containers/com.docker.docker/Data/vms/0/`
- **Windows**: `\\wsl$\docker-desktop-data\version-pack-data\community\docker\volumes\`

---

## Network Architecture

### Bridge Network

All services communicate via a custom bridge network: `llm-observatory-network`

**Benefits**:
- Service discovery via container names (e.g., `timescaledb:5432`)
- Isolated from other Docker networks
- Internal DNS resolution

**Network Details**:
```bash
docker network inspect llm-observatory-network
```

### Service Communication

```
┌─────────────────────────────────────────────────────┐
│         Application (Host or Container)             │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│            llm-observatory-network                  │
│                                                     │
│  ┌──────────────┐                                  │
│  │  Grafana     │                                  │
│  │  :3000       │                                  │
│  └──────┬───────┘                                  │
│         │                                           │
│         ├──► timescaledb:5432 (Database queries)   │
│         │                                           │
│  ┌──────▼───────┐      ┌──────────────┐           │
│  │ TimescaleDB  │      │    Redis     │           │
│  │  :5432       │      │    :6379     │           │
│  └──────────────┘      └──────────────┘           │
│         ▲                      ▲                    │
│         │                      │                    │
│         └──────────────────────┴─────── App        │
│              (via DATABASE_URL)   (via REDIS_URL)  │
└─────────────────────────────────────────────────────┘
```

### Connection Strings

**From host machine**:
```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/llm_observatory
REDIS_URL=redis://:redis_password@localhost:6379/0
```

**From another container** (in same network):
```bash
DATABASE_URL=postgresql://postgres:postgres@timescaledb:5432/llm_observatory
REDIS_URL=redis://:redis_password@redis:6379/0
```

**From application code**:
```rust
// Rust example
use sqlx::postgres::PgPoolOptions;

let pool = PgPoolOptions::new()
    .max_connections(5)
    .connect("postgresql://llm_observatory_app:password@timescaledb:5432/llm_observatory")
    .await?;
```

---

## Common Commands

### Service Management

**Start all services**:
```bash
docker compose up -d
```

**Start with admin tools**:
```bash
docker compose --profile admin up -d
```

**Stop all services**:
```bash
docker compose down
```

**Stop and remove volumes** (⚠️ DELETES DATA):
```bash
docker compose down -v
```

**Restart a specific service**:
```bash
docker compose restart timescaledb
docker compose restart redis
docker compose restart grafana
```

**View service status**:
```bash
docker compose ps
```

**View logs**:
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f timescaledb
docker compose logs -f grafana

# Last 100 lines
docker compose logs --tail 100 timescaledb
```

### Database Operations

**Connect to database (psql)**:
```bash
# As superuser
docker compose exec timescaledb psql -U postgres -d llm_observatory

# As application user
docker compose exec timescaledb psql -U llm_observatory_app -d llm_observatory
```

**Execute SQL file**:
```bash
docker compose exec -T timescaledb psql -U postgres -d llm_observatory < schema.sql
```

**Run SQL command**:
```bash
docker compose exec timescaledb psql -U postgres -d llm_observatory \
  -c "SELECT COUNT(*) FROM information_schema.tables;"
```

**Database backup**:
```bash
# Full backup
docker compose exec timescaledb pg_dump -U postgres llm_observatory > backup.sql

# Backup specific schema
docker compose exec timescaledb pg_dump -U postgres -n public llm_observatory > backup.sql

# Compressed backup
docker compose exec timescaledb pg_dump -U postgres llm_observatory | gzip > backup.sql.gz
```

**Database restore**:
```bash
# From SQL file
cat backup.sql | docker compose exec -T timescaledb psql -U postgres llm_observatory

# From compressed backup
gunzip -c backup.sql.gz | docker compose exec -T timescaledb psql -U postgres llm_observatory
```

**List databases**:
```bash
docker compose exec timescaledb psql -U postgres -l
```

**List extensions**:
```bash
docker compose exec timescaledb psql -U postgres -d llm_observatory -c "\dx"
```

### Redis Operations

**Connect to Redis CLI**:
```bash
docker compose exec redis redis-cli -a redis_password
```

**Run Redis commands**:
```bash
# Check connection
docker compose exec redis redis-cli -a redis_password ping

# Get all keys
docker compose exec redis redis-cli -a redis_password keys '*'

# Get memory usage
docker compose exec redis redis-cli -a redis_password info memory

# Flush all data (⚠️ WARNING: Deletes everything)
docker compose exec redis redis-cli -a redis_password flushall
```

### Performance Monitoring

**View container resource usage**:
```bash
docker stats
```

**View database size**:
```bash
docker compose exec timescaledb psql -U postgres -d llm_observatory -c \
  "SELECT pg_size_pretty(pg_database_size('llm_observatory'));"
```

**View table sizes**:
```bash
docker compose exec timescaledb psql -U postgres -d llm_observatory -c \
  "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
   FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"
```

**View active connections**:
```bash
docker compose exec timescaledb psql -U postgres -c \
  "SELECT count(*) FROM pg_stat_activity;"
```

**View slow queries**:
```bash
docker compose exec timescaledb psql -U postgres -d llm_observatory -c \
  "SELECT query, mean_exec_time FROM pg_stat_statements
   ORDER BY mean_exec_time DESC LIMIT 10;"
```

### Maintenance

**Vacuum database** (reclaim space):
```bash
docker compose exec timescaledb psql -U postgres -d llm_observatory -c "VACUUM VERBOSE ANALYZE;"
```

**Update Docker images**:
```bash
docker compose pull
docker compose up -d
```

**Rebuild containers** (after docker-compose.yml changes):
```bash
docker compose up -d --build
```

**Clean up unused resources**:
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove everything unused
docker system prune -a --volumes
```

---

## Troubleshooting

### Quick Diagnostics

**Health check status**:
```bash
docker compose ps
# Look for "(healthy)" status on all services
```

**View recent errors**:
```bash
docker compose logs --tail 50 | grep -i error
```

**Check network connectivity**:
```bash
# From Grafana to TimescaleDB
docker compose exec grafana nc -zv timescaledb 5432

# From application container
docker run --rm --network llm-observatory-network alpine nc -zv timescaledb 5432
```

### Common Issues

#### 1. Port Already in Use

**Symptom**:
```
Error: bind: address already in use
```

**Solution**:

Find which process is using the port:
```bash
# Linux/macOS
lsof -i :5432
# or
netstat -an | grep 5432

# Windows PowerShell
Get-NetTCPConnection -LocalPort 5432
```

Options:
- Change port in `.env`: `DB_PORT=15432`
- Stop the conflicting service
- Use a different port mapping

#### 2. Container Won't Start

**Symptom**:
```
Container exits immediately after starting
```

**Solution**:

Check logs for errors:
```bash
docker compose logs timescaledb
```

Common causes:
- Invalid environment variables in `.env`
- Corrupted volume data
- Insufficient permissions
- Out of disk space

**Reset and retry**:
```bash
docker compose down -v
docker compose up -d
```

#### 3. Database Connection Refused

**Symptom**:
```
psql: error: connection to server at "localhost" (127.0.0.1), port 5432 failed: Connection refused
```

**Solution**:

1. Check container is running:
   ```bash
   docker compose ps
   ```

2. Wait for health check to pass (30-60 seconds on first start)

3. Check database logs:
   ```bash
   docker compose logs timescaledb
   ```

4. Verify credentials in `.env` match database

#### 4. Out of Disk Space

**Symptom**:
```
ERROR: Could not write to file: No space left on device
```

**Solution**:

1. Check disk usage:
   ```bash
   df -h
   docker system df
   ```

2. Clean up Docker resources:
   ```bash
   docker system prune -a --volumes
   ```

3. Remove old backups:
   ```bash
   docker compose exec timescaledb find /backups -mtime +30 -delete
   ```

4. Increase disk allocation (Docker Desktop settings)

#### 5. Slow Database Performance

**Symptom**:
Queries taking longer than expected

**Solutions**:

1. Check resource usage:
   ```bash
   docker stats
   ```

2. Increase shared buffers in `.env`:
   ```bash
   DB_SHARED_BUFFERS=2GB
   DB_EFFECTIVE_CACHE_SIZE=8GB
   ```

3. Vacuum and analyze:
   ```bash
   docker compose exec timescaledb psql -U postgres -d llm_observatory -c "VACUUM ANALYZE;"
   ```

4. Create indexes on frequently queried columns

5. Check for long-running queries:
   ```bash
   docker compose exec timescaledb psql -U postgres -c \
     "SELECT pid, now() - pg_stat_activity.query_start AS duration, query
      FROM pg_stat_activity WHERE state = 'active' ORDER BY duration DESC;"
   ```

#### 6. Grafana Cannot Connect to Database

**Symptom**:
Grafana shows "Database connection error"

**Solution**:

1. Check TimescaleDB is healthy:
   ```bash
   docker compose ps
   ```

2. Test connection from Grafana container:
   ```bash
   docker compose exec grafana nc -zv timescaledb 5432
   ```

3. Verify environment variables in docker-compose.yml:
   - `GF_DATABASE_HOST=timescaledb:5432`
   - `GF_DATABASE_NAME=grafana`
   - Password matches `.env`

4. Restart Grafana after TimescaleDB is healthy:
   ```bash
   docker compose restart grafana
   ```

#### 7. Permission Denied on Volumes

**Symptom**:
```
Permission denied: '/var/lib/postgresql/data'
```

**Solution**:

On Linux, fix permissions:
```bash
# Get volume mount point
docker volume inspect llm-observatory-db-data --format '{{ .Mountpoint }}'

# Fix permissions (requires sudo)
sudo chown -R 999:999 /var/lib/docker/volumes/llm-observatory-db-data/_data
```

Or recreate volumes:
```bash
docker compose down -v
docker compose up -d
```

#### 8. Health Check Never Passes

**Symptom**:
Service stays in "starting" or "unhealthy" state

**Solution**:

1. Check health check command manually:
   ```bash
   # TimescaleDB
   docker compose exec timescaledb pg_isready -U postgres -d llm_observatory

   # Redis
   docker compose exec redis redis-cli -a redis_password ping

   # Grafana
   docker compose exec grafana wget -O- http://localhost:3000/api/health
   ```

2. Increase health check start period in docker-compose.yml:
   ```yaml
   healthcheck:
     start_period: 60s  # Increase from 30s
   ```

3. Check for resource constraints:
   ```bash
   docker stats
   ```

### Getting Help

If you're still experiencing issues:

1. Check the [Troubleshooting Docker Guide](/workspaces/llm-observatory/docs/TROUBLESHOOTING_DOCKER.md)
2. Review [Docker Workflows](/workspaces/llm-observatory/docs/DOCKER_WORKFLOWS.md)
3. Search [GitHub Issues](https://github.com/llm-observatory/llm-observatory/issues)
4. Join our [Discussions](https://github.com/llm-observatory/llm-observatory/discussions)

When reporting issues, include:
- Output of `docker compose ps`
- Relevant logs: `docker compose logs [service]`
- Your `.env` file (remove sensitive values)
- Docker version: `docker --version`
- OS and version

---

## Additional Resources

### Documentation

- [Quick Start Guide](/workspaces/llm-observatory/docs/QUICK_START.md) - Get up and running in 5 minutes
- [Docker Workflows](/workspaces/llm-observatory/docs/DOCKER_WORKFLOWS.md) - Development patterns and best practices
- [Docker Architecture](/workspaces/llm-observatory/docs/ARCHITECTURE_DOCKER.md) - Detailed architecture documentation
- [Troubleshooting](/workspaces/llm-observatory/docs/TROUBLESHOOTING_DOCKER.md) - Comprehensive troubleshooting guide

### External Documentation

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)
- [Grafana Documentation](https://grafana.com/docs/)

### Configuration Files

- [docker-compose.yml](/workspaces/llm-observatory/docker-compose.yml) - Main orchestration file
- [.env.example](/workspaces/llm-observatory/.env.example) - Configuration template
- [init/01-init-timescaledb.sql](/workspaces/llm-observatory/docker/init/01-init-timescaledb.sql) - Database initialization

### Tools

- [Backup Scripts](/workspaces/llm-observatory/scripts/) - Automated backup and restore
- [Monitoring Setup](/workspaces/llm-observatory/docs/MONITORING_SETUP.md) - Prometheus and alerting
- [Grafana Dashboards](/workspaces/llm-observatory/docs/grafana/) - Pre-built dashboards

---

## Next Steps

After getting the Docker environment running:

1. **Deploy Schema**: Run database migrations to create tables
   ```bash
   # Coming soon: schema migrations
   ```

2. **Configure Grafana**: Import pre-built dashboards for LLM metrics

3. **Start Application**: Run the LLM Observatory collector and API

4. **Send Metrics**: Instrument your LLM application to send telemetry

5. **Create Dashboards**: Build custom visualizations for your use case

6. **Set Up Alerts**: Configure Prometheus alerting for critical metrics

7. **Production Hardening**: Review security checklist and performance tuning

---

**Built with ❤️ for the LLM community**

For more information, see the [main README](/workspaces/llm-observatory/README.md) or visit our [documentation](/workspaces/llm-observatory/docs/).

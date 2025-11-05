# LLM Observatory - Docker Infrastructure

This directory contains the Docker infrastructure setup for the LLM Observatory project.

## Overview

The infrastructure consists of the following services:

- **TimescaleDB 2.14+** (PostgreSQL 16) - Time-series database for LLM metrics
- **Redis 7.2** - Caching and session storage
- **Grafana 10.4** - Visualization and dashboards
- **PgAdmin 8.4** - Optional database administration UI (admin profile)

## Quick Start

### 1. Initial Setup

Copy the environment template:

```bash
cp .env.example .env
```

Edit `.env` and update the passwords and any other configuration values as needed.

### 2. Start the Infrastructure

Start all core services (TimescaleDB, Redis, Grafana):

```bash
docker-compose up -d
```

Start with PgAdmin for database administration:

```bash
docker-compose --profile admin up -d
```

### 3. Verify Services

Check that all services are healthy:

```bash
docker-compose ps
```

View logs for a specific service:

```bash
docker-compose logs -f timescaledb
docker-compose logs -f grafana
docker-compose logs -f redis
```

## Service Access

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| TimescaleDB | `localhost:5432` | postgres/postgres |
| Redis | `localhost:6379` | Password: redis_password |
| Grafana | http://localhost:3000 | admin/admin |
| PgAdmin | http://localhost:5050 | admin@llm-observatory.local/admin |

## Database Initialization

The database is automatically initialized on first startup using the scripts in `docker/init/`:

1. **01-init-timescaledb.sql** - Creates the database, installs TimescaleDB extension, sets up roles and permissions

The initialization script creates:
- `llm_observatory` database
- TimescaleDB extension
- `llm_observatory_app` role (read/write access)
- `llm_observatory_readonly` role (read-only access)
- Additional extensions: uuid-ossp, pg_stat_statements

## Database Connections

Use these connection strings from your application:

**Admin User (full access):**
```
postgresql://postgres:postgres@localhost:5432/llm_observatory
```

**Application User (read/write):**
```
postgresql://llm_observatory_app:change_me_in_production@localhost:5432/llm_observatory
```

**Read-only User (analytics):**
```
postgresql://llm_observatory_readonly:change_me_readonly@localhost:5432/llm_observatory
```

## Common Operations

### Stop All Services

```bash
docker-compose down
```

### Stop and Remove Volumes (WARNING: Deletes all data)

```bash
docker-compose down -v
```

### Restart a Specific Service

```bash
docker-compose restart timescaledb
```

### Execute SQL in TimescaleDB

```bash
docker-compose exec timescaledb psql -U postgres -d llm_observatory
```

### Access Redis CLI

```bash
docker-compose exec redis redis-cli -a redis_password
```

### View Real-time Logs

```bash
docker-compose logs -f
```

### Backup Database

```bash
docker-compose exec timescaledb pg_dump -U postgres llm_observatory > backup.sql
```

### Restore Database

```bash
cat backup.sql | docker-compose exec -T timescaledb psql -U postgres llm_observatory
```

## Volume Management

Persistent data is stored in named Docker volumes:

- `llm-observatory-db-data` - TimescaleDB data
- `llm-observatory-redis-data` - Redis data
- `llm-observatory-grafana-data` - Grafana dashboards and settings
- `llm-observatory-pgadmin-data` - PgAdmin configuration

List volumes:
```bash
docker volume ls | grep llm-observatory
```

Inspect volume:
```bash
docker volume inspect llm-observatory-db-data
```

## Health Checks

All services include health checks:

- **TimescaleDB**: `pg_isready` checks database availability
- **Redis**: Connection test with authentication
- **Grafana**: HTTP health endpoint check
- **PgAdmin**: HTTP ping endpoint check

Health status is visible in `docker-compose ps` output.

## Performance Tuning

### TimescaleDB

The PostgreSQL configuration is optimized for development. For production, adjust these in `.env`:

```env
DB_SHARED_BUFFERS=2GB
DB_WORK_MEM=64MB
DB_MAINTENANCE_WORK_MEM=512MB
DB_EFFECTIVE_CACHE_SIZE=8GB
```

### Redis

Redis is configured with:
- Max memory: 256MB
- Eviction policy: allkeys-lru
- Persistence: AOF with fsync every second

## Troubleshooting

### Database Won't Start

Check logs:
```bash
docker-compose logs timescaledb
```

Common issues:
- Port 5432 already in use (change DB_PORT in .env)
- Insufficient disk space
- Volume permission issues

### Connection Refused

Ensure the service is healthy:
```bash
docker-compose ps
```

Wait for health checks to pass (especially on first start).

### Reset Everything

To completely reset the infrastructure:
```bash
docker-compose down -v
docker-compose up -d
```

## Security Notes

**IMPORTANT for Production:**

1. Change all default passwords in `.env`
2. Use strong, randomly generated passwords
3. Consider using Docker secrets for sensitive data
4. Enable SSL/TLS for database connections
5. Restrict network access using firewall rules
6. Regularly update Docker images
7. Review and adjust security settings in docker-compose.yml

## Next Steps

After the infrastructure is running:

1. Create database schema migrations
2. Set up Grafana datasources and dashboards
3. Configure application connection pooling
4. Set up monitoring and alerting
5. Implement backup strategies

## Additional Resources

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)
- [Grafana Documentation](https://grafana.com/docs/)

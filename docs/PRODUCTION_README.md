# LLM Observatory - Production Deployment

Complete production-ready deployment configuration for LLM Observatory with enterprise-grade security, high availability, and operational best practices.

## Overview

This production deployment includes:

- **High Availability**: Primary/replica database, Redis Sentinel, multi-replica API servers
- **Security Hardening**: Non-root containers, read-only filesystems, capability dropping, TLS/SSL
- **Monitoring**: Comprehensive metrics, health checks, alerting
- **Backup & Recovery**: Automated encrypted backups, point-in-time recovery (PITR)
- **Scalability**: Horizontal and vertical scaling support
- **Compliance**: Audit logging, secret management, data retention policies

## Quick Links

- **[Production Quick Start](docs/PRODUCTION_QUICK_START.md)** - Deploy in under 1 hour
- **[Production Deployment Guide](docs/PRODUCTION_DEPLOYMENT.md)** - Comprehensive deployment documentation
- **[Production Checklist](docs/PRODUCTION_CHECKLIST.md)** - Complete deployment checklist
- **[Secrets Management](docs/SECRETS_MANAGEMENT.md)** - Secure credential management
- **[Scaling Guide](docs/SCALING_GUIDE.md)** - Performance optimization and scaling
- **[Operations Manual](docs/OPERATIONS_MANUAL.md)** - Day-to-day operations and maintenance

## Architecture

```
                         Internet
                            │
                            ▼
                    ┌───────────────┐
                    │  Nginx (443)  │
                    │  TLS/HSTS     │
                    └───────┬───────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
    ┌─────────────────┐         ┌─────────────────┐
    │  API Server 1   │         │  API Server 2   │
    │  (Primary)      │         │  (Replica)      │
    └────────┬────────┘         └────────┬────────┘
             │                           │
             └──────────┬────────────────┘
                        │
           ┌────────────┴───────────┐
           │                        │
           ▼                        ▼
    ┌─────────────┐          ┌─────────────┐
    │ TimescaleDB │          │   Redis     │
    │  (Primary)  │──────────│  (Master)   │
    └──────┬──────┘          └─────────────┘
           │
           │ Replication
           │
    ┌──────▼──────┐
    │ TimescaleDB │
    │  (Replica)  │
    └─────────────┘
```

## Features

### Security

- **TLS/SSL Everywhere**: End-to-end encryption for all services
- **Secret Management**: Docker secrets or external secret managers (AWS Secrets Manager, Vault)
- **Non-Root Containers**: All services run as unprivileged users
- **Read-Only Filesystems**: Minimized attack surface
- **Network Isolation**: Internal backend network with no external access
- **Firewall**: Only ports 80/443 exposed, fail2ban enabled
- **Security Headers**: HSTS, CSP, X-Frame-Options, etc.

### High Availability

- **Database Replication**: Streaming replication with automatic failover
- **Redis Sentinel**: Automatic Redis failover and monitoring
- **Load Balancing**: Nginx with least-connections algorithm
- **Health Checks**: Comprehensive health monitoring for all services
- **Automatic Restarts**: Services restart on failure
- **Zero-Downtime Updates**: Rolling updates with health verification

### Monitoring

- **Grafana Dashboards**: Real-time visualization of all metrics
- **Prometheus Metrics**: Application, system, and infrastructure metrics
- **Health Endpoints**: HTTP health checks for all services
- **Alerting**: Email/Slack/PagerDuty alerts for critical issues
- **Log Aggregation**: Centralized logging with rotation
- **Performance Tracking**: Slow query logging, request tracing

### Backup & Recovery

- **Automated Backups**: Daily full backups, hourly incremental
- **Point-in-Time Recovery**: WAL archiving for PITR
- **Encrypted Backups**: AES-256 encryption at rest
- **Off-Site Storage**: S3/cloud storage with lifecycle policies
- **Backup Verification**: Automated restore testing
- **Retention Policies**: Configurable retention (default 30 days)

### Scalability

- **Horizontal Scaling**: Scale API servers and collectors independently
- **Read Replicas**: Scale database read capacity
- **Connection Pooling**: PgBouncer for database connection management
- **Caching**: Multi-level caching (in-memory + Redis)
- **Compression**: TimescaleDB compression for historical data
- **Partitioning**: Time-based partitioning for efficient queries

## Prerequisites

### Infrastructure

- **Server**: 16GB RAM, 8 CPU cores, 500GB SSD (minimum)
- **OS**: Ubuntu 22.04 LTS (recommended)
- **Network**: Static IP, domain name, open ports 80/443
- **Storage**: Separate volumes for database, backups, logs

### Software

- **Docker**: 24.0+ with Docker Compose 2.20+
- **SSL Certificate**: Let's Encrypt or commercial certificate
- **SMTP**: Email server for alerts
- **Optional**: S3-compatible storage for backups

### Access

- **Root/Sudo Access**: For system configuration
- **DNS Control**: To configure domain records
- **Firewall Access**: To configure security rules

## Quick Start

### 1. Clone Repository

```bash
cd /opt
sudo git clone https://github.com/llm-observatory/llm-observatory.git
cd llm-observatory
```

### 2. Generate Secrets

```bash
./scripts/generate-secrets.sh
```

### 3. Configure Environment

```bash
cp docker/.env.production.example .env.production
nano .env.production  # Update domain, SMTP, S3 settings
```

### 4. Setup SSL Certificates

```bash
# Let's Encrypt
sudo certbot certonly --standalone -d observatory.yourdomain.com -d api.observatory.yourdomain.com

# Copy certificates
sudo cp /etc/letsencrypt/live/observatory.yourdomain.com/fullchain.pem docker/certs/nginx/server.crt
sudo cp /etc/letsencrypt/live/observatory.yourdomain.com/privkey.pem docker/certs/nginx/server.key
```

### 5. Deploy

```bash
# Create data directories
sudo mkdir -p /var/lib/llm-observatory/{timescaledb-primary,redis-master,grafana,backups}

# Start services
docker compose -f docker/compose/docker-compose.prod.yml up -d

# Verify
docker compose -f docker/compose/docker-compose.prod.yml ps
```

### 6. Access

- **Grafana**: https://observatory.yourdomain.com
- **API**: https://api.observatory.yourdomain.com
- **Credentials**: See `secrets/` directory

**Detailed Instructions**: See [Production Quick Start](docs/PRODUCTION_QUICK_START.md)

## Configuration Files

### Docker Compose

- **[docker/compose/docker-compose.prod.yml](docker/compose/docker-compose.prod.yml)**: Main production configuration
  - Services: PostgreSQL, Redis, Grafana, API, Nginx
  - Profiles: `with-replica`, `with-ha`, `backup`
  - Security: Non-root users, read-only filesystems, secrets
  - Monitoring: Health checks, resource limits, logging

### Environment Variables

- **[docker/.env.production.example](docker/.env.production.example)**: Production environment template
  - Database, Redis, application settings
  - Security, monitoring, backup configuration
  - All secrets use external secret management

### Database Configuration

- **[docker/postgresql.prod.conf](docker/postgresql.prod.conf)**: Primary database (32GB RAM)
- **[docker/postgresql.replica.conf](docker/postgresql.replica.conf)**: Read replica (16GB RAM)

### Cache Configuration

- **[docker/redis.prod.conf](docker/redis.prod.conf)**: Redis production settings

### Nginx Configuration

- **docker/nginx/nginx.prod.conf**: Main Nginx configuration
- **docker/nginx/conf.d/llm-observatory.conf**: Site configuration
- **docker/nginx/ssl-params.conf**: SSL/TLS security settings

## Deployment Profiles

### Standard Deployment

Single primary database, single Redis instance, multiple API replicas:

```bash
docker compose -f docker/compose/docker-compose.prod.yml up -d
```

### High Availability

Add read replica and Redis Sentinel:

```bash
docker compose -f docker/compose/docker-compose.prod.yml --profile with-replica --profile with-ha up -d
```

### With Backups

Enable automated backup service:

```bash
docker compose -f docker/compose/docker-compose.prod.yml --profile backup up -d
```

## Scaling

### Vertical Scaling

Increase server resources and update configuration:

```bash
# Edit .env.production
DB_SHARED_BUFFERS=16GB  # For 64GB RAM server
DB_EFFECTIVE_CACHE_SIZE=48GB

# Restart database
docker compose -f docker/compose/docker-compose.prod.yml restart timescaledb-primary
```

### Horizontal Scaling

Scale API servers:

```bash
docker compose -f docker/compose/docker-compose.prod.yml up -d --scale api-server=4
```

Add read replicas:

```bash
docker compose -f docker/compose/docker-compose.prod.yml --profile with-replica up -d
```

**Detailed Guide**: [Scaling Guide](docs/SCALING_GUIDE.md)

## Operations

### Daily Tasks

```bash
# Check service health
docker compose -f docker/compose/docker-compose.prod.yml ps

# View logs
docker compose -f docker/compose/docker-compose.prod.yml logs -f --tail=100

# Check resource usage
docker stats
```

### Backup

```bash
# Manual backup
docker compose -f docker/compose/docker-compose.prod.yml --profile backup run --rm backup

# Automated backups (cron)
0 2 * * * cd /opt/llm-observatory && docker compose -f docker/compose/docker-compose.prod.yml --profile backup run --rm backup
```

### Updates

```bash
# Pull latest images
docker compose -f docker/compose/docker-compose.prod.yml pull

# Rolling update
docker compose -f docker/compose/docker-compose.prod.yml up -d --no-deps --build api-server
```

### Monitoring

```bash
# Database performance
docker exec llm-observatory-db-primary psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Cache stats
docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" INFO stats

# API performance
curl https://api.observatory.yourdomain.com/metrics
```

**Detailed Guide**: [Operations Manual](docs/OPERATIONS_MANUAL.md)

## Security

### Secret Management

Secrets are stored in `secrets/` directory or external secret managers:

- **Docker Secrets**: Files in `secrets/*.txt`
- **AWS Secrets Manager**: `aws secretsmanager get-secret-value`
- **HashiCorp Vault**: `vault kv get`
- **Environment Variables**: Loaded from secrets files

**Never commit secrets to version control!**

### Secret Rotation

```bash
# Generate new secrets
./scripts/rotate-secrets.sh

# Update services
docker compose -f docker/compose/docker-compose.prod.yml restart
```

**Detailed Guide**: [Secrets Management](docs/SECRETS_MANAGEMENT.md)

### Security Best Practices

- [ ] Change all default passwords
- [ ] Enable firewall (only 80/443 open)
- [ ] Use strong SSL/TLS configuration
- [ ] Enable fail2ban
- [ ] Regular security updates
- [ ] Audit logging enabled
- [ ] Encrypt backups
- [ ] Use external secret management
- [ ] Regular security audits

## Monitoring and Alerting

### Grafana Dashboards

Access: https://observatory.yourdomain.com

Default Dashboards:
- System Overview
- Database Performance
- API Metrics
- Cache Performance
- Error Tracking

### Prometheus Metrics

API metrics: https://api.observatory.yourdomain.com/metrics

Key metrics:
- `http_requests_total`: Total HTTP requests
- `http_request_duration_seconds`: Request latency
- `db_query_duration_seconds`: Database query time
- `cache_hit_rate`: Cache effectiveness

### Alerts

Configure alerts in Grafana:
- High CPU/Memory usage
- Database connection errors
- High API error rate
- Low cache hit rate
- Disk space warnings
- Backup failures

**Detailed Guide**: [Monitoring Setup](docs/MONITORING.md)

## Troubleshooting

### Services Won't Start

```bash
# Check logs
docker compose -f docker/compose/docker-compose.prod.yml logs

# Check resources
docker stats
df -h

# Verify configuration
docker compose -f docker/compose/docker-compose.prod.yml config
```

### Database Connection Failed

```bash
# Check database
docker exec llm-observatory-db-primary pg_isready -U postgres

# Check connection string
cat secrets/database_url.txt

# Test connection
docker exec llm-observatory-db-primary psql -U postgres -c "SELECT 1;"
```

### SSL/TLS Issues

```bash
# Verify certificate
openssl x509 -in docker/certs/nginx/server.crt -text -noout

# Test SSL
curl -vI https://observatory.yourdomain.com

# Check nginx config
docker exec llm-observatory-nginx nginx -t
```

### Performance Issues

```bash
# Check slow queries
docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
"

# Check cache hit rate
docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" INFO stats

# Profile application
docker logs llm-observatory-api | grep -i slow
```

**Detailed Guide**: [Troubleshooting](docs/PRODUCTION_DEPLOYMENT.md#troubleshooting)

## Compliance

### Data Retention

- **Events**: 365 days (configurable)
- **Logs**: 90 days (configurable)
- **Backups**: 30 days (configurable)
- **Audit Logs**: 1 year (minimum)

### Encryption

- **In Transit**: TLS 1.2+ for all connections
- **At Rest**: Database encryption, encrypted backups
- **Secrets**: Encrypted in Docker secrets or external managers

### Audit Logging

- **Access Logs**: All HTTP requests
- **Authentication**: Login attempts, failures
- **Database**: DDL statements, admin actions
- **System**: Docker events, sudo commands

## Support

### Documentation

- [Production Deployment Guide](docs/PRODUCTION_DEPLOYMENT.md)
- [Production Checklist](docs/PRODUCTION_CHECKLIST.md)
- [Secrets Management](docs/SECRETS_MANAGEMENT.md)
- [Scaling Guide](docs/SCALING_GUIDE.md)
- [Operations Manual](docs/OPERATIONS_MANUAL.md)
- [Monitoring Setup](docs/MONITORING.md)

### Community

- **GitHub**: https://github.com/llm-observatory/llm-observatory
- **Issues**: https://github.com/llm-observatory/llm-observatory/issues
- **Discussions**: https://github.com/llm-observatory/llm-observatory/discussions
- **Discord**: https://discord.gg/llm-observatory

### Commercial Support

For enterprise support, custom development, or consulting services, contact:
- Email: enterprise@llm-observatory.io
- Website: https://llm-observatory.io/enterprise

## License

Apache License 2.0 - See [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

---

**Version**: 0.1.0
**Last Updated**: 2025-01-05
**Status**: Production Ready

**Next Steps**: [Production Quick Start](docs/PRODUCTION_QUICK_START.md)

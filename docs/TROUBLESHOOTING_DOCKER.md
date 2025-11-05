# Troubleshooting Docker - LLM Observatory

Comprehensive troubleshooting guide for Docker-related issues in LLM Observatory. This guide covers common problems, diagnostic steps, and solutions.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Port Conflicts](#port-conflicts)
- [Volume Permission Issues](#volume-permission-issues)
- [Build Failures](#build-failures)
- [Network Connectivity](#network-connectivity)
- [Performance Issues](#performance-issues)
- [Data Recovery](#data-recovery)
- [Service-Specific Issues](#service-specific-issues)
- [Advanced Debugging](#advanced-debugging)

---

## Quick Diagnostics

### Health Check Script

Run this first to identify issues:

```bash
#!/bin/bash
# Quick diagnostic script

echo "=== Docker Environment ==="
docker --version
docker compose version
echo ""

echo "=== Service Status ==="
docker compose ps
echo ""

echo "=== Recent Errors ==="
docker compose logs --tail 20 --no-color | grep -i error
echo ""

echo "=== Disk Space ==="
df -h | grep -E '(Filesystem|/dev/)'
docker system df
echo ""

echo "=== Resource Usage ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo ""

echo "=== Network ==="
docker network ls | grep llm-observatory
```

Save as `scripts/diagnose.sh`, make executable, and run:

```bash
chmod +x scripts/diagnose.sh
./scripts/diagnose.sh
```

### Essential Commands

```bash
# Check service status
docker compose ps

# View logs for all services
docker compose logs --tail 50

# View logs for specific service
docker compose logs -f timescaledb

# Check health manually
docker compose exec timescaledb pg_isready -U postgres
docker compose exec redis redis-cli -a redis_password ping
docker compose exec grafana wget -O- http://localhost:3000/api/health

# Restart problematic service
docker compose restart timescaledb

# Full restart
docker compose down && docker compose up -d
```

---

## Port Conflicts

### Symptom

```
Error response from daemon: driver failed programming external connectivity:
Bind for 0.0.0.0:5432 failed: port is already allocated
```

### Diagnosis

**Linux/macOS**:
```bash
# Find process using port
sudo lsof -i :5432
# or
sudo netstat -tulpn | grep :5432

# Find process ID
sudo fuser 5432/tcp
```

**Windows PowerShell**:
```powershell
Get-NetTCPConnection -LocalPort 5432 | Select-Object -Property LocalPort, OwningProcess
Get-Process -Id [ProcessId]
```

### Solution 1: Change Port

Edit `.env`:

```bash
# Original port conflict on 5432
DB_PORT=15432

# Similarly for other services
REDIS_PORT=16379
GRAFANA_PORT=13000
PGADMIN_PORT=15050
```

Update connection strings:

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:15432/llm_observatory
REDIS_URL=redis://:redis_password@localhost:16379/0
```

Restart services:

```bash
docker compose down
docker compose up -d
```

### Solution 2: Stop Conflicting Service

**PostgreSQL conflict**:
```bash
# Linux/macOS
sudo systemctl stop postgresql
# or
brew services stop postgresql

# Disable autostart
sudo systemctl disable postgresql
```

**Redis conflict**:
```bash
sudo systemctl stop redis
# or
brew services stop redis
```

### Solution 3: Use Docker Network Only

Remove port mappings to prevent conflicts (access only from other containers):

```yaml
# docker-compose.yml
services:
  timescaledb:
    # ports:
    #   - "${DB_PORT:-5432}:5432"  # Commented out
    # Services in same network can still connect via timescaledb:5432
```

---

## Volume Permission Issues

### Symptom

```
initdb: error: could not create directory "/var/lib/postgresql/data": Permission denied
```

or

```
mkdir: cannot create directory '/var/lib/grafana': Permission denied
```

### Diagnosis

```bash
# Check volume ownership
docker volume inspect llm-observatory-db-data --format '{{ .Mountpoint }}'

# On Linux, check permissions (requires sudo)
sudo ls -la /var/lib/docker/volumes/llm-observatory-db-data/_data
```

### Solution 1: Recreate Volumes

**WARNING**: This deletes all data. Backup first if needed.

```bash
# Backup data if needed
docker compose exec timescaledb pg_dump -U postgres llm_observatory > backup.sql

# Stop and remove volumes
docker compose down -v

# Start fresh
docker compose up -d

# Restore data if backed up
cat backup.sql | docker compose exec -T timescaledb psql -U postgres llm_observatory
```

### Solution 2: Fix Permissions (Linux Only)

```bash
# Stop containers
docker compose down

# Fix permissions for PostgreSQL (UID 999)
sudo chown -R 999:999 /var/lib/docker/volumes/llm-observatory-db-data/_data

# Fix permissions for Grafana (UID 472)
sudo chown -R 472:472 /var/lib/docker/volumes/llm-observatory-grafana-data/_data

# Restart
docker compose up -d
```

### Solution 3: Use Named Volumes (Recommended)

Ensure you're using named volumes, not bind mounts:

```yaml
# Good: Named volume (Docker manages permissions)
volumes:
  - timescaledb_data:/var/lib/postgresql/data

# Avoid: Bind mount (permission issues on Linux)
# volumes:
#   - ./data/postgres:/var/lib/postgresql/data
```

### Solution 4: SELinux Context (RHEL/CentOS)

If running on RHEL/CentOS with SELinux:

```bash
# Check SELinux status
getenforce

# Add SELinux context to volumes
sudo chcon -Rt svirt_sandbox_file_t /var/lib/docker/volumes/llm-observatory-db-data/

# Or disable SELinux temporarily (not recommended for production)
sudo setenforce 0
```

---

## Build Failures

### Symptom

```
ERROR [internal] load metadata for docker.io/library/timescale/timescaledb:2.14.2-pg16
```

or

```
failed to solve: failed to fetch oauth token: unexpected status from GET request to...
```

### Solution 1: Check Internet Connection

```bash
# Test connectivity
ping -c 3 registry-1.docker.io

# Test DNS resolution
nslookup registry-1.docker.io

# Check Docker daemon connectivity
docker pull hello-world
```

### Solution 2: Configure Docker Registry Mirror

Create or edit `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": [
    "https://mirror.gcr.io"
  ],
  "dns": ["8.8.8.8", "8.8.4.4"]
}
```

Restart Docker:

```bash
# Linux
sudo systemctl restart docker

# macOS/Windows
# Restart Docker Desktop
```

### Solution 3: Pull Images Manually

```bash
# Pull each image separately
docker pull timescale/timescaledb:2.14.2-pg16
docker pull redis:7.2-alpine
docker pull grafana/grafana:10.4.1
docker pull dpage/pgadmin4:8.4

# Then start services
docker compose up -d
```

### Solution 4: Clear Docker Build Cache

```bash
# Clear build cache
docker builder prune -a

# Remove all images and rebuild
docker system prune -a
docker compose up -d
```

### Solution 5: Login to Docker Registry

If using private registry:

```bash
docker login
# Enter username and password

# Or use access token
echo $DOCKER_TOKEN | docker login --username $DOCKER_USER --password-stdin
```

---

## Network Connectivity

### Symptom

```
could not translate host name "timescaledb" to address: Name or service not known
```

or

```
dial tcp: lookup timescaledb: no such host
```

### Diagnosis

```bash
# Check network exists
docker network ls | grep llm-observatory

# Inspect network
docker network inspect llm-observatory-network

# Check which containers are connected
docker network inspect llm-observatory-network --format '{{range .Containers}}{{.Name}} {{end}}'

# Test connectivity between containers
docker compose exec grafana ping -c 3 timescaledb
docker compose exec grafana nc -zv timescaledb 5432
```

### Solution 1: Restart Networking

```bash
# Restart services
docker compose down
docker compose up -d

# If that doesn't work, recreate network
docker network rm llm-observatory-network
docker compose up -d
```

### Solution 2: Verify Network Configuration

Check `docker-compose.yml`:

```yaml
networks:
  llm-observatory-network:
    driver: bridge
    name: llm-observatory-network

services:
  timescaledb:
    networks:
      - llm-observatory-network
  grafana:
    networks:
      - llm-observatory-network
```

### Solution 3: Use Explicit Links (Legacy)

If DNS resolution fails:

```yaml
services:
  grafana:
    depends_on:
      - timescaledb
    links:
      - timescaledb:database
    environment:
      - GF_DATABASE_HOST=database:5432
```

### Solution 4: Check Docker DNS

```bash
# Test Docker DNS from container
docker compose exec grafana cat /etc/resolv.conf

# Should show Docker's DNS server (usually 127.0.0.11)
# nameserver 127.0.0.11

# Test resolution
docker compose exec grafana nslookup timescaledb

# If DNS fails, restart Docker daemon
sudo systemctl restart docker
```

### Solution 5: Firewall Issues

**Linux (iptables/firewalld)**:
```bash
# Check if Docker rules exist
sudo iptables -L DOCKER

# Check firewalld (RHEL/CentOS)
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=docker --list-all

# Allow Docker interface
sudo firewall-cmd --permanent --zone=trusted --add-interface=docker0
sudo firewall-cmd --reload
```

**macOS**:
```bash
# Check if Little Snitch or similar blocking Docker
# Allow Docker.app in firewall settings
```

---

## Performance Issues

### Symptom 1: Slow Queries

**Diagnosis**:
```bash
# Check slow queries
docker compose exec timescaledb psql -U postgres -d llm_observatory <<EOF
SELECT
    substring(query, 1, 100) AS query,
    calls,
    ROUND(mean_exec_time::numeric, 2) AS mean_ms,
    ROUND(max_exec_time::numeric, 2) AS max_ms
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC
LIMIT 10;
EOF

# Check for missing indexes
docker compose exec timescaledb psql -U postgres -d llm_observatory <<EOF
SELECT
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    seq_tup_read / seq_scan AS avg_seq_tup
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_scan DESC
LIMIT 10;
EOF
```

**Solutions**:

1. **Increase shared buffers** (`.env`):
```bash
DB_SHARED_BUFFERS=2GB
DB_EFFECTIVE_CACHE_SIZE=8GB
DB_WORK_MEM=64MB
```

2. **Add indexes**:
```sql
-- Example indexes for common queries
CREATE INDEX CONCURRENTLY idx_spans_ts ON spans(ts DESC);
CREATE INDEX CONCURRENTLY idx_spans_trace_id ON spans(trace_id);
CREATE INDEX CONCURRENTLY idx_spans_attrs_model ON spans((attributes->>'model_name'));
```

3. **Vacuum and analyze**:
```bash
docker compose exec timescaledb psql -U postgres -d llm_observatory -c "VACUUM ANALYZE;"
```

4. **Use connection pooling**:
```rust
// In application code
let pool = PgPoolOptions::new()
    .max_connections(20)
    .min_connections(5)
    .acquire_timeout(Duration::from_secs(30))
    .connect(&database_url)
    .await?;
```

### Symptom 2: High CPU Usage

**Diagnosis**:
```bash
# Monitor resource usage
docker stats

# Check CPU-intensive queries
docker compose exec timescaledb psql -U postgres <<EOF
SELECT
    pid,
    NOW() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;
EOF
```

**Solutions**:

1. **Limit CPU usage**:
```yaml
# docker-compose.yml
services:
  timescaledb:
    deploy:
      resources:
        limits:
          cpus: '4.0'
```

2. **Optimize queries**:
```bash
# Use EXPLAIN ANALYZE to find bottlenecks
docker compose exec timescaledb psql -U postgres -d llm_observatory <<EOF
EXPLAIN ANALYZE
SELECT * FROM spans WHERE ts > NOW() - INTERVAL '1 hour';
EOF
```

3. **Enable query result caching**:
```bash
# Use Redis for caching frequent queries
# Configure in application
```

### Symptom 3: Out of Memory

**Diagnosis**:
```bash
# Check memory usage
docker stats --no-stream

# Check PostgreSQL memory
docker compose exec timescaledb psql -U postgres -c "SHOW shared_buffers;"
docker compose exec timescaledb psql -U postgres -c "SHOW work_mem;"

# Check Redis memory
docker compose exec redis redis-cli -a redis_password INFO memory
```

**Solutions**:

1. **Increase Docker memory limit** (Docker Desktop):
   - Open Docker Desktop > Settings > Resources
   - Increase Memory slider to 8GB or more

2. **Reduce shared buffers** (`.env`):
```bash
DB_SHARED_BUFFERS=512MB
DB_WORK_MEM=16MB
```

3. **Configure Redis memory limit**:
```yaml
# docker-compose.yml
services:
  redis:
    command: >
      redis-server
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
```

4. **Enable swap** (Linux):
```bash
# Check swap
free -h

# Create swap file if needed
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Symptom 4: Disk I/O Bottleneck

**Diagnosis**:
```bash
# Check disk usage
df -h

# Check I/O wait (Linux)
iostat -x 1 5

# Check Docker disk usage
docker system df -v
```

**Solutions**:

1. **Use SSD for volumes**:
```bash
# Move volumes to SSD mount point
docker volume create --driver local \
  --opt type=none \
  --opt device=/mnt/ssd/docker-volumes/llm-observatory \
  --opt o=bind \
  llm-observatory-db-data
```

2. **Optimize TimescaleDB**:
```bash
# Increase checkpoint intervals
docker compose exec timescaledb psql -U postgres -c \
  "ALTER SYSTEM SET checkpoint_timeout = '15min';"
docker compose restart timescaledb
```

3. **Clean up logs**:
```bash
# Truncate large log files
docker compose down
sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log
docker compose up -d

# Or configure log rotation
# Edit docker-compose.yml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

---

## Data Recovery

### Scenario 1: Accidentally Deleted Database

**If you have a backup**:

```bash
# Stop services
docker compose down

# Start only database
docker compose up -d timescaledb

# Wait for healthy
docker compose ps

# Restore from backup
cat backup.sql | docker compose exec -T timescaledb psql -U postgres llm_observatory

# Verify data
docker compose exec timescaledb psql -U postgres -d llm_observatory -c "SELECT COUNT(*) FROM spans;"

# Restart all services
docker compose up -d
```

**If no backup (data may be in volume)**:

```bash
# Check if volume still exists
docker volume ls | grep llm-observatory-db-data

# If volume exists, restart with existing volume
docker compose up -d

# Export data immediately
docker compose exec timescaledb pg_dump -U postgres llm_observatory > recovery_backup.sql
```

### Scenario 2: Corrupted Database

**Symptoms**:
```
ERROR: could not read block 0 in file "base/16384/2608": read only 0 of 8192 bytes
```

**Recovery steps**:

1. **Stop all connections**:
```bash
docker compose stop api collector grafana
```

2. **Try pg_resetwal** (last resort):
```bash
# WARNING: This may lose recent transactions
docker compose exec timescaledb pg_resetwal -f /var/lib/postgresql/data
docker compose restart timescaledb
```

3. **Recover what you can**:
```bash
# Dump uncorrupted tables
docker compose exec timescaledb pg_dump -U postgres -t spans llm_observatory > partial_backup.sql
```

4. **Restore from backup**:
```bash
# Recreate database
docker compose exec timescaledb psql -U postgres -c "DROP DATABASE IF EXISTS llm_observatory;"
docker compose exec timescaledb psql -U postgres -c "CREATE DATABASE llm_observatory;"

# Restore
cat last_good_backup.sql | docker compose exec -T timescaledb psql -U postgres llm_observatory
```

### Scenario 3: Lost Volume

**If using Docker volumes (data in volume)**:

```bash
# Check if volume truly deleted
docker volume ls

# If volume gone, check Docker volume backups
ls -la /var/lib/docker/volumes/

# If you have volume backups
docker volume create llm-observatory-db-data
docker run --rm -v llm-observatory-db-data:/data -v $(pwd):/backup alpine \
  tar xzf /backup/db-volume-backup.tar.gz -C /data
```

**Prevention**:

```bash
# Regular volume backups
docker run --rm -v llm-observatory-db-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/db-volume-backup-$(date +%Y%m%d).tar.gz /data

# Scheduled backups (crontab)
0 2 * * * cd /path/to/llm-observatory && docker compose --profile backup run backup
```

### Scenario 4: Split-Brain / Inconsistent State

**Symptoms**:
- Grafana shows different data than database queries
- Redis cache out of sync

**Solution**:

```bash
# Clear Redis cache
docker compose exec redis redis-cli -a redis_password FLUSHALL

# Restart Grafana to clear UI cache
docker compose restart grafana

# Verify data directly
docker compose exec timescaledb psql -U postgres -d llm_observatory -c "SELECT COUNT(*) FROM spans;"

# Refresh Grafana dashboards (Ctrl+R in browser)
```

---

## Service-Specific Issues

### TimescaleDB Issues

**Won't start / Crashes immediately**:

```bash
# Check logs
docker compose logs timescaledb

# Common issues:
# 1. Corrupted data directory
docker compose down -v  # WARNING: Deletes data
docker compose up -d

# 2. Out of disk space
df -h
docker system prune -a

# 3. Port conflict
# See Port Conflicts section
```

**Slow queries**:

```bash
# Enable query logging
docker compose exec timescaledb psql -U postgres -c \
  "ALTER SYSTEM SET log_statement = 'all';"
docker compose restart timescaledb

# View logs
docker compose logs -f timescaledb | grep "LOG:"

# Disable after debugging
docker compose exec timescaledb psql -U postgres -c \
  "ALTER SYSTEM SET log_statement = 'mod';"
docker compose restart timescaledb
```

### Redis Issues

**Connection refused**:

```bash
# Check if Redis is running
docker compose ps redis

# Test connection
docker compose exec redis redis-cli -a redis_password ping

# Check password
echo $REDIS_PASSWORD
docker compose exec redis redis-cli -a $REDIS_PASSWORD ping
```

**Out of memory**:

```bash
# Check memory usage
docker compose exec redis redis-cli -a redis_password INFO memory

# Clear cache
docker compose exec redis redis-cli -a redis_password FLUSHDB

# Increase max memory in docker-compose.yml
command: redis-server --maxmemory 512mb
```

### Grafana Issues

**Can't login**:

```bash
# Reset admin password
docker compose exec grafana grafana-cli admin reset-admin-password newpassword

# Or recreate Grafana container
docker compose stop grafana
docker volume rm llm-observatory-grafana-data
docker compose up -d grafana
```

**Database connection error**:

```bash
# Check Grafana can reach TimescaleDB
docker compose exec grafana nc -zv timescaledb 5432

# Check environment variables
docker compose exec grafana env | grep GF_DATABASE

# Restart after TimescaleDB is healthy
docker compose restart grafana
```

---

## Advanced Debugging

### Enable Debug Logging

**For all services**:

```yaml
# docker-compose.yml
services:
  timescaledb:
    command: postgres -c log_statement=all
  redis:
    command: redis-server --loglevel debug
  grafana:
    environment:
      - GF_LOG_LEVEL=debug
```

### Inspect Container Internals

```bash
# Shell into container
docker compose exec timescaledb bash

# View process list
docker compose exec timescaledb ps aux

# View environment variables
docker compose exec timescaledb env

# View filesystem
docker compose exec timescaledb ls -la /var/lib/postgresql/data

# View running processes
docker compose exec timescaledb top
```

### Network Debugging with tcpdump

```bash
# Capture network traffic
docker compose exec timescaledb tcpdump -i any -n -s 0 -w /tmp/capture.pcap port 5432

# Download capture file
docker cp llm-observatory-db:/tmp/capture.pcap .

# Analyze with Wireshark or tcpdump
tcpdump -r capture.pcap -A
```

### Strace Running Processes

```bash
# Attach to process with strace
docker compose exec timescaledb strace -p $(pidof postgres)

# Trace system calls for new processes
docker compose exec timescaledb strace -f -e trace=open,close,read,write postgres
```

### Memory Profiling

```bash
# Check memory map
docker compose exec timescaledb cat /proc/1/maps

# Check memory usage breakdown
docker compose exec timescaledb cat /proc/1/status | grep -i mem
```

---

## Getting Help

If none of the above solutions work:

### Gather Information

```bash
# Create diagnostic bundle
mkdir -p debug_info
docker compose ps > debug_info/services.txt
docker compose logs --no-color > debug_info/logs.txt
docker system df > debug_info/disk.txt
docker version > debug_info/version.txt
docker compose config > debug_info/compose_config.txt
cp .env debug_info/.env.sanitized  # Remove sensitive values!
tar czf debug_bundle.tar.gz debug_info/
```

### Report Issue

Include in your bug report:
1. `debug_bundle.tar.gz`
2. Steps to reproduce
3. Expected vs actual behavior
4. Docker version and OS
5. `.env` file (sanitized)

### Community Support

- **GitHub Issues**: https://github.com/llm-observatory/llm-observatory/issues
- **Discussions**: https://github.com/llm-observatory/llm-observatory/discussions
- **Documentation**: /workspaces/llm-observatory/docs/

---

## Prevention

### Regular Maintenance

```bash
# Weekly tasks
docker system prune -f
docker volume prune -f
docker compose exec timescaledb psql -U postgres -d llm_observatory -c "VACUUM ANALYZE;"

# Monthly tasks
docker system prune -a
docker images prune -a
docker compose pull
docker compose up -d
```

### Monitoring

Set up alerts for:
- Disk space < 20%
- Memory usage > 80%
- High error rates
- Slow queries
- Failed health checks

See [Monitoring Setup](/workspaces/llm-observatory/docs/MONITORING_SETUP.md).

### Backups

```bash
# Daily automated backups
0 2 * * * cd /path/to/llm-observatory && docker compose exec timescaledb pg_dump -U postgres llm_observatory | gzip > /backups/daily_$(date +\%Y\%m\%d).sql.gz

# Weekly volume snapshots
0 3 * * 0 docker run --rm -v llm-observatory-db-data:/data -v /backups:/backup alpine tar czf /backup/volume_$(date +\%Y\%m\%d).tar.gz /data
```

---

**Built with ❤️ for the LLM community**

For more help, see:
- [Docker Workflows](/workspaces/llm-observatory/docs/DOCKER_WORKFLOWS.md)
- [Quick Start](/workspaces/llm-observatory/docs/QUICK_START.md)
- [Architecture](/workspaces/llm-observatory/docs/ARCHITECTURE_DOCKER.md)

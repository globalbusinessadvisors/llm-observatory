# Scaling and Optimization Guide

Comprehensive guide for scaling LLM Observatory from single-server deployments to high-traffic, multi-region production systems.

## Table of Contents

- [Overview](#overview)
- [Scaling Strategies](#scaling-strategies)
- [Vertical Scaling](#vertical-scaling)
- [Horizontal Scaling](#horizontal-scaling)
- [Database Scaling](#database-scaling)
- [Caching Optimization](#caching-optimization)
- [Load Balancing](#load-balancing)
- [Performance Tuning](#performance-tuning)
- [Monitoring and Metrics](#monitoring-and-metrics)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

## Overview

### Scaling Dimensions

LLM Observatory can be scaled across multiple dimensions:

1. **Compute**: API servers, collectors
2. **Storage**: Database, cache
3. **Network**: Load balancers, CDN
4. **Geography**: Multi-region deployments

### Growth Stages

**Stage 1: Single Server (0-10K requests/day)**
- Single Docker host
- Basic monitoring
- Daily backups
- Resource: 8 cores, 16GB RAM

**Stage 2: Vertical Scaling (10K-100K requests/day)**
- Larger server
- Enhanced monitoring
- Hourly backups
- Resource: 16 cores, 32GB RAM

**Stage 3: Horizontal Scaling (100K-1M requests/day)**
- Multiple API replicas
- Read replicas
- Redis cluster
- Load balancer
- Resource: 3x 16-core servers

**Stage 4: Distributed System (1M+ requests/day)**
- Kubernetes orchestration
- Multi-region deployment
- Auto-scaling
- Advanced caching
- Resource: Cloud auto-scaling

## Scaling Strategies

### Assess Current Performance

```bash
#!/bin/bash
# assess-performance.sh - Baseline performance metrics

echo "=== System Resources ==="
echo "CPU cores: $(nproc)"
echo "Total RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Used RAM: $(free -h | awk '/^Mem:/ {print $3}')"
echo "Disk space: $(df -h / | awk 'NR==2 {print $2}')"
echo "Disk used: $(df -h / | awk 'NR==2 {print $3}')"

echo -e "\n=== Database Stats ==="
docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -t -c "
SELECT
  pg_size_pretty(pg_database_size('llm_observatory')) as size,
  (SELECT count(*) FROM pg_stat_activity WHERE datname='llm_observatory') as connections,
  (SELECT sum(numbackends) FROM pg_stat_database WHERE datname='llm_observatory') as backends;
"

echo -e "\n=== Redis Stats ==="
docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" INFO stats | grep -E "total_commands_processed|keyspace_hits|keyspace_misses|used_memory_human"

echo -e "\n=== API Performance ==="
# Average response time (last 1000 requests)
docker exec llm-observatory-nginx awk '
  {sum+=$11; count++}
  END {print "Avg response time: " sum/count "s"}
' /var/log/nginx/access.log | tail -1000

echo -e "\n=== Request Rate ==="
# Requests per second (last minute)
docker exec llm-observatory-nginx awk '
  {print $4}
' /var/log/nginx/access.log | tail -60 | sort | uniq -c

echo -e "\n=== Container Resources ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Capacity Planning

**Formula for API Server Scaling:**

```
Required Replicas = (Peak RPS × Avg Response Time) / Target CPU Utilization
```

**Example:**
- Peak: 1000 requests/second
- Avg response: 50ms (0.05s)
- Target CPU: 70%

```
Replicas = (1000 × 0.05) / 0.7 = 71.4 ≈ 72 concurrent handlers

If each server handles 20 concurrent requests:
Servers = 72 / 20 = 3.6 ≈ 4 servers
```

**Database Sizing:**

```
Storage = (Events/Day × Avg Event Size × Retention Days) × 1.5 (indexes/overhead)
```

**Example:**
- 1M events/day
- 2KB average size
- 365 day retention

```
Storage = (1M × 2KB × 365) × 1.5 = 1.1 TB
```

## Vertical Scaling

### Hardware Upgrades

**CPU Optimization:**

```bash
# Current usage
mpstat -P ALL 1 5

# Identify CPU-bound processes
docker stats --format "table {{.Name}}\t{{.CPUPerc}}" | sort -k2 -rn

# Upgrade: Increase CPU cores
# AWS: t3.xlarge (4 cores) → c5.2xlarge (8 cores)
# GCP: n2-standard-4 → n2-highcpu-8
```

**Memory Optimization:**

```bash
# Check memory pressure
free -h
vmstat 1 5

# Check container memory
docker stats --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Upgrade database memory settings (16GB → 32GB server)
# Edit .env.production:
DB_SHARED_BUFFERS=8GB              # 25% of RAM
DB_EFFECTIVE_CACHE_SIZE=24GB       # 75% of RAM
DB_WORK_MEM=128MB
DB_MAINTENANCE_WORK_MEM=1GB

# Restart database
docker compose -f docker-compose.prod.yml restart timescaledb-primary
```

**Storage Optimization:**

```bash
# Check I/O performance
iostat -x 1 5

# Check disk usage
df -h
du -sh /var/lib/llm-observatory/*

# Upgrade to faster storage
# HDD → SSD → NVMe
# AWS: gp2 → gp3 (3000 IOPS → 16000 IOPS)
# GCP: pd-standard → pd-ssd → pd-extreme

# Resize volume (AWS)
aws ec2 modify-volume --volume-id vol-xxx --size 1000 --volume-type gp3 --iops 16000

# Extend filesystem
sudo growpart /dev/nvme1n1 1
sudo resize2fs /dev/nvme1n1p1
```

### PostgreSQL Tuning

**Memory Configuration (32GB server):**

```ini
# docker/postgresql.prod.conf

# Memory
shared_buffers = 8GB
effective_cache_size = 24GB
work_mem = 128MB
maintenance_work_mem = 2GB
max_stack_depth = 7MB

# WAL
wal_buffers = 16MB
max_wal_size = 8GB
min_wal_size = 2GB
wal_compression = on

# Query Planning
random_page_cost = 1.1  # SSD
effective_io_concurrency = 200  # SSD

# Checkpoints
checkpoint_completion_target = 0.9
checkpoint_timeout = 15min
checkpoint_warning = 30s

# Connections
max_connections = 400
superuser_reserved_connections = 3

# Parallel Query
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_worker_processes = 8

# Logging
log_min_duration_statement = 100ms
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
```

**Apply Configuration:**

```bash
# Copy configuration
cp docker/postgresql.prod.conf /var/lib/llm-observatory/timescaledb-primary/postgresql.auto.conf

# Reload configuration (no restart needed for most settings)
docker exec llm-observatory-db-primary psql -U postgres -c "SELECT pg_reload_conf();"

# Verify settings
docker exec llm-observatory-db-primary psql -U postgres -c "SHOW shared_buffers; SHOW effective_cache_size;"
```

## Horizontal Scaling

### API Server Scaling

**Scale to Multiple Replicas:**

```bash
# Edit docker-compose.prod.yml or use CLI
docker compose -f docker-compose.prod.yml up -d --scale api-server=4

# Verify
docker compose -f docker-compose.prod.yml ps api-server

# Check distribution
curl https://api.observatory.yourdomain.com/health
# Repeat to see different container IDs (via load balancer)
```

**Session Affinity (if needed):**

```nginx
# docker/nginx/conf.d/llm-observatory.conf

upstream api_backend {
    least_conn;
    server api-server-1:8080;
    server api-server-2:8080;
    server api-server-3:8080;
    server api-server-4:8080;

    # Enable sticky sessions based on IP
    ip_hash;

    # Or use cookies
    # sticky cookie srv_id expires=1h domain=.observatory.yourdomain.com path=/;
}
```

### Database Read Replicas

**Enable Read Replica:**

```bash
# Start replica
docker compose -f docker-compose.prod.yml --profile with-replica up -d timescaledb-replica

# Verify replication
docker exec llm-observatory-db-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check replication lag
docker exec llm-observatory-db-primary psql -U postgres -c "
SELECT
  client_addr,
  state,
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as lag_bytes,
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) / 1024 / 1024 as lag_mb
FROM pg_stat_replication;
"
```

**Configure Application for Read/Write Splitting:**

```rust
// Example: Rust application
use sqlx::PgPool;

struct Database {
    write_pool: PgPool,
    read_pool: PgPool,
}

impl Database {
    async fn new() -> Result<Self> {
        let write_pool = PgPool::connect("postgresql://...timescaledb-primary:5432/...").await?;
        let read_pool = PgPool::connect("postgresql://...timescaledb-replica:5432/...").await?;

        Ok(Self { write_pool, read_pool })
    }

    // Use write pool for mutations
    async fn insert_event(&self, event: Event) -> Result<()> {
        sqlx::query!("INSERT INTO events ...")
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    // Use read pool for queries
    async fn get_events(&self, filters: Filters) -> Result<Vec<Event>> {
        sqlx::query_as!("SELECT * FROM events WHERE ...")
            .fetch_all(&self.read_pool)
            .await
    }
}
```

**PgBouncer for Connection Pooling:**

```yaml
# docker-compose.prod.yml

services:
  pgbouncer:
    image: edoburu/pgbouncer:1.21.0
    container_name: llm-observatory-pgbouncer
    restart: always
    environment:
      DATABASE_URL: "postgres://postgres:${DB_PASSWORD}@timescaledb-primary:5432/llm_observatory"
      POOL_MODE: transaction
      MAX_CLIENT_CONN: 1000
      DEFAULT_POOL_SIZE: 25
      RESERVE_POOL_SIZE: 5
      SERVER_IDLE_TIMEOUT: 600
      LOG_CONNECTIONS: 1
      LOG_DISCONNECTIONS: 1
    ports:
      - "127.0.0.1:6432:5432"
    networks:
      - backend
    depends_on:
      - timescaledb-primary

# Application connects to pgbouncer:5432 instead of direct database
```

### Redis High Availability

**Redis Sentinel Setup:**

```bash
# Start Redis Sentinel (already in docker-compose.prod.yml)
docker compose -f docker-compose.prod.yml --profile with-ha up -d redis-sentinel

# Verify Sentinel
docker exec llm-observatory-redis-sentinel redis-cli -p 26379 SENTINEL masters
docker exec llm-observatory-redis-sentinel redis-cli -p 26379 SENTINEL slaves mymaster

# Test failover
docker exec llm-observatory-redis-sentinel redis-cli -p 26379 SENTINEL failover mymaster
```

**Redis Cluster (for >100GB data):**

```yaml
# docker-compose.redis-cluster.yml

version: '3.8'

services:
  redis-node-1:
    image: redis:7.2-alpine
    command: redis-server --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes
    ports:
      - "7001:6379"
    volumes:
      - redis-node-1:/data

  redis-node-2:
    image: redis:7.2-alpine
    command: redis-server --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes
    ports:
      - "7002:6379"
    volumes:
      - redis-node-2:/data

  redis-node-3:
    image: redis:7.2-alpine
    command: redis-server --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes
    ports:
      - "7003:6379"
    volumes:
      - redis-node-3:/data

volumes:
  redis-node-1:
  redis-node-2:
  redis-node-3:
```

```bash
# Create cluster
docker exec -it redis-node-1 redis-cli --cluster create \
  redis-node-1:6379 redis-node-2:6379 redis-node-3:6379 \
  --cluster-replicas 0

# Verify cluster
docker exec -it redis-node-1 redis-cli cluster info
```

## Database Scaling

### Partitioning (TimescaleDB)

**Time-Based Partitioning:**

```sql
-- Create hypertable with partitioning
SELECT create_hypertable(
  'llm_events',
  'timestamp',
  chunk_time_interval => INTERVAL '1 day',
  if_not_exists => TRUE
);

-- Add space partitioning (optional, for multi-tenancy)
SELECT add_dimension(
  'llm_events',
  'tenant_id',
  number_partitions => 4
);

-- View chunks
SELECT * FROM timescaledb_information.chunks
WHERE hypertable_name = 'llm_events'
ORDER BY range_start DESC;

-- Drop old chunks (data retention)
SELECT drop_chunks('llm_events', INTERVAL '365 days');
```

**Compression:**

```sql
-- Enable compression
ALTER TABLE llm_events SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'tenant_id',
  timescaledb.compress_orderby = 'timestamp DESC'
);

-- Add compression policy (compress chunks older than 7 days)
SELECT add_compression_policy('llm_events', INTERVAL '7 days');

-- View compression status
SELECT
  hypertable_name,
  pg_size_pretty(before_compression_total_bytes) AS before,
  pg_size_pretty(after_compression_total_bytes) AS after,
  round(100.0 - (100.0 * after_compression_total_bytes / before_compression_total_bytes), 2) AS compression_ratio
FROM timescaledb_information.hypertable_compression_stats
WHERE hypertable_name = 'llm_events';
```

**Continuous Aggregates:**

```sql
-- Create materialized view for common queries
CREATE MATERIALIZED VIEW llm_events_hourly
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', timestamp) AS hour,
  tenant_id,
  model_name,
  COUNT(*) AS event_count,
  AVG(latency_ms) AS avg_latency,
  MAX(latency_ms) AS max_latency,
  SUM(tokens_total) AS total_tokens
FROM llm_events
GROUP BY hour, tenant_id, model_name;

-- Add refresh policy (refresh every hour for last 3 hours)
SELECT add_continuous_aggregate_policy(
  'llm_events_hourly',
  start_offset => INTERVAL '3 hours',
  end_offset => INTERVAL '1 hour',
  schedule_interval => INTERVAL '1 hour'
);

-- Query aggregate
SELECT * FROM llm_events_hourly
WHERE hour >= NOW() - INTERVAL '24 hours'
ORDER BY hour DESC;
```

### Indexing Strategy

**Essential Indexes:**

```sql
-- Time-based queries
CREATE INDEX idx_events_timestamp ON llm_events (timestamp DESC);

-- Tenant isolation
CREATE INDEX idx_events_tenant ON llm_events (tenant_id, timestamp DESC);

-- Model analytics
CREATE INDEX idx_events_model ON llm_events (model_name, timestamp DESC);

-- Composite indexes for common queries
CREATE INDEX idx_events_tenant_model ON llm_events (tenant_id, model_name, timestamp DESC);

-- Partial indexes for specific conditions
CREATE INDEX idx_events_errors ON llm_events (timestamp DESC)
WHERE status_code >= 400;

-- Verify index usage
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Remove unused indexes
SELECT
  schemaname || '.' || tablename AS table,
  indexname AS index,
  pg_size_pretty(pg_relation_size(indexrelid)) AS size,
  idx_scan AS scans
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE 'pg_%'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Query Optimization

```sql
-- Enable query timing
\timing on

-- Analyze query plan
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * FROM llm_events
WHERE tenant_id = '12345'
  AND timestamp >= NOW() - INTERVAL '1 day'
ORDER BY timestamp DESC
LIMIT 100;

-- Update table statistics
ANALYZE llm_events;

-- Vacuum and analyze
VACUUM ANALYZE llm_events;

-- Check table bloat
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS external_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Caching Optimization

### Multi-Level Caching

**L1: Application-Level Cache (In-Memory):**

```rust
// Rust example with moka
use moka::sync::Cache;
use std::time::Duration;

struct CacheManager {
    l1: Cache<String, Vec<u8>>,  // In-memory cache
    l2: redis::Client,            // Redis cache
}

impl CacheManager {
    fn new(redis_url: &str) -> Self {
        let l1 = Cache::builder()
            .max_capacity(10_000)
            .time_to_live(Duration::from_secs(60))
            .build();

        let l2 = redis::Client::open(redis_url).unwrap();

        Self { l1, l2 }
    }

    async fn get(&self, key: &str) -> Option<Vec<u8>> {
        // Try L1 cache first
        if let Some(value) = self.l1.get(key) {
            return Some(value);
        }

        // Try L2 cache (Redis)
        if let Ok(value) = self.get_from_redis(key).await {
            // Populate L1 cache
            self.l1.insert(key.to_string(), value.clone());
            return Some(value);
        }

        None
    }

    async fn set(&self, key: &str, value: Vec<u8>, ttl: Duration) {
        // Set in both caches
        self.l1.insert(key.to_string(), value.clone());
        self.set_in_redis(key, value, ttl).await;
    }
}
```

**L2: Redis Configuration:**

```bash
# docker/redis.prod.conf

# Memory management
maxmemory 4gb
maxmemory-policy allkeys-lru

# LRU tuning
lru-samples 10

# Save policy (adjust based on needs)
save 900 1       # Save after 15 min if >= 1 key changed
save 300 10      # Save after 5 min if >= 10 keys changed
save 60 10000    # Save after 1 min if >= 10000 keys changed

# AOF persistence
appendonly yes
appendfsync everysec
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Performance
tcp-backlog 511
timeout 300
tcp-keepalive 60
```

**Cache Warming:**

```bash
#!/bin/bash
# warm-cache.sh - Pre-populate cache with hot data

redis-cli -a "$(cat secrets/redis_password.txt)" <<EOF
# Popular queries
SET cache:dashboard:summary:24h "$(curl -s https://api.observatory.yourdomain.com/summary/24h)" EX 300
SET cache:models:list "$(curl -s https://api.observatory.yourdomain.com/models)" EX 3600
SET cache:metrics:latest "$(curl -s https://api.observatory.yourdomain.com/metrics/latest)" EX 60
EOF
```

### Cache Invalidation Strategy

**Time-Based TTL:**

```rust
// Different TTLs based on data volatility
const CACHE_TTL_REALTIME: u64 = 10;      // 10 seconds
const CACHE_TTL_SHORT: u64 = 300;        // 5 minutes
const CACHE_TTL_MEDIUM: u64 = 3600;      // 1 hour
const CACHE_TTL_LONG: u64 = 86400;       // 24 hours

// Usage
cache.set("metrics:latest", data, CACHE_TTL_REALTIME);
cache.set("dashboard:summary", data, CACHE_TTL_SHORT);
cache.set("models:list", data, CACHE_TTL_LONG);
```

**Event-Based Invalidation:**

```rust
// Invalidate cache on write
async fn create_event(&self, event: Event) -> Result<()> {
    // Write to database
    self.db.insert_event(&event).await?;

    // Invalidate related caches
    self.cache.delete(&format!("events:tenant:{}", event.tenant_id)).await;
    self.cache.delete(&format!("summary:tenant:{}", event.tenant_id)).await;

    Ok(())
}
```

### CDN for Static Assets

**CloudFront Configuration:**

```bash
# Create CloudFront distribution
aws cloudfront create-distribution \
  --distribution-config file://cloudfront-config.json

# cloudfront-config.json
{
  "CallerReference": "llm-observatory-$(date +%s)",
  "Origins": {
    "Items": [{
      "Id": "llm-observatory-origin",
      "DomainName": "observatory.yourdomain.com",
      "CustomOriginConfig": {
        "HTTPPort": 80,
        "HTTPSPort": 443,
        "OriginProtocolPolicy": "https-only",
        "OriginSslProtocols": {
          "Items": ["TLSv1.2"],
          "Quantity": 1
        }
      }
    }]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "llm-observatory-origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Items": ["GET", "HEAD", "OPTIONS"],
      "Quantity": 3
    },
    "Compress": true,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "MinTTL": 0
  },
  "Enabled": true,
  "Comment": "LLM Observatory CDN"
}
```

## Load Balancing

### Nginx Load Balancing

**Advanced Configuration:**

```nginx
# docker/nginx/conf.d/llm-observatory.conf

upstream api_backend {
    least_conn;  # or: ip_hash, round_robin, random

    # Health checks
    server api-server-1:8080 max_fails=3 fail_timeout=30s;
    server api-server-2:8080 max_fails=3 fail_timeout=30s;
    server api-server-3:8080 max_fails=3 fail_timeout=30s;
    server api-server-4:8080 max_fails=3 fail_timeout=30s backup;  # Backup server

    # Connection pooling
    keepalive 32;
    keepalive_requests 100;
    keepalive_timeout 60s;
}

server {
    listen 443 ssl http2;
    server_name api.observatory.yourdomain.com;

    # Rate limiting by API key
    limit_req_zone $http_x_api_key zone=api_key:10m rate=100r/s;
    limit_req zone=api_key burst=200 nodelay;

    location / {
        proxy_pass http://api_backend;

        # Load balancer health checks
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 10s;

        # Connection reuse
        proxy_http_version 1.1;
        proxy_set_header Connection "";

        # Headers
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
}
```

### HAProxy (Alternative)

```bash
# haproxy.cfg

global
    maxconn 50000
    log /dev/log local0
    user haproxy
    group haproxy
    daemon

defaults
    mode http
    timeout connect 5s
    timeout client 30s
    timeout server 30s
    option httplog
    option dontlognull

frontend api_frontend
    bind *:443 ssl crt /etc/haproxy/certs/api.pem
    bind *:80
    redirect scheme https if !{ ssl_fc }

    # ACLs
    acl is_health path /health
    acl is_metrics path /metrics

    # Routing
    use_backend health_backend if is_health
    use_backend metrics_backend if is_metrics
    default_backend api_backend

backend api_backend
    balance leastconn
    option httpchk GET /health
    http-check expect status 200

    server api-1 api-server-1:8080 check inter 5s fall 3 rise 2
    server api-2 api-server-2:8080 check inter 5s fall 3 rise 2
    server api-3 api-server-3:8080 check inter 5s fall 3 rise 2
    server api-4 api-server-4:8080 check inter 5s fall 3 rise 2 backup
```

### External Load Balancers

**AWS Application Load Balancer:**

```bash
# Create target group
aws elbv2 create-target-group \
  --name llm-observatory-api \
  --protocol HTTPS \
  --port 443 \
  --vpc-id vpc-xxx \
  --health-check-protocol HTTPS \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3

# Create ALB
aws elbv2 create-load-balancer \
  --name llm-observatory-alb \
  --subnets subnet-xxx subnet-yyy \
  --security-groups sg-xxx \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:... \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=arn:aws:acm:... \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:...
```

## Performance Tuning

### Application Profiling

**CPU Profiling:**

```bash
# Rust: flamegraph
cargo install flamegraph

# Profile application
cargo flamegraph --bin api-server

# View in browser
open flamegraph.svg
```

**Memory Profiling:**

```bash
# Heap profiling with valgrind
valgrind --tool=massif --massif-out-file=massif.out ./api-server

# Analyze
ms_print massif.out > memory-profile.txt
```

**Query Profiling:**

```sql
-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 10 slowest queries
SELECT
  query,
  calls,
  total_exec_time / 1000 AS total_time_sec,
  mean_exec_time / 1000 AS avg_time_sec,
  max_exec_time / 1000 AS max_time_sec
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = 'llm_observatory')
ORDER BY total_exec_time DESC
LIMIT 10;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

### Network Optimization

**TCP Tuning:**

```bash
# /etc/sysctl.conf

# Increase connection backlog
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# Fast port recycling
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# Buffer sizes
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Congestion control
net.ipv4.tcp_congestion_control = bbr

# Apply
sudo sysctl -p
```

**HTTP/2 Optimization:**

```nginx
# nginx.conf

http {
    # HTTP/2 settings
    http2_max_concurrent_streams 128;
    http2_max_field_size 16k;
    http2_max_header_size 32k;

    # Connection pooling
    keepalive_timeout 65;
    keepalive_requests 100;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Brotli (if enabled)
    brotli on;
    brotli_comp_level 6;
    brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
```

## Monitoring and Metrics

### Key Performance Indicators (KPIs)

**Application Metrics:**

```rust
// Prometheus metrics
use prometheus::{IntCounter, Histogram, register_int_counter, register_histogram};

lazy_static! {
    static ref HTTP_REQUESTS_TOTAL: IntCounter = register_int_counter!(
        "http_requests_total",
        "Total HTTP requests"
    ).unwrap();

    static ref HTTP_REQUEST_DURATION: Histogram = register_histogram!(
        "http_request_duration_seconds",
        "HTTP request duration in seconds"
    ).unwrap();

    static ref DB_QUERY_DURATION: Histogram = register_histogram!(
        "db_query_duration_seconds",
        "Database query duration in seconds"
    ).unwrap();

    static ref CACHE_HITS_TOTAL: IntCounter = register_int_counter!(
        "cache_hits_total",
        "Total cache hits"
    ).unwrap();

    static ref CACHE_MISSES_TOTAL: IntCounter = register_int_counter!(
        "cache_misses_total",
        "Total cache misses"
    ).unwrap();
}

// Usage
HTTP_REQUESTS_TOTAL.inc();
let timer = HTTP_REQUEST_DURATION.start_timer();
// ... handle request ...
timer.observe_duration();
```

**Alerting Rules:**

```yaml
# prometheus/alerts.yml

groups:
  - name: performance
    interval: 30s
    rules:
      # High API latency
      - alert: HighAPILatency
        expr: histogram_quantile(0.95, http_request_duration_seconds) > 1.0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High API latency (p95 > 1s)"

      # High database latency
      - alert: HighDatabaseLatency
        expr: histogram_quantile(0.95, db_query_duration_seconds) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High database latency (p95 > 500ms)"

      # Low cache hit rate
      - alert: LowCacheHitRate
        expr: rate(cache_hits_total[5m]) / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m])) < 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low cache hit rate (< 80%)"

      # High error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate (> 1%)"
```

## Cost Optimization

### Resource Right-Sizing

```bash
#!/bin/bash
# analyze-resource-usage.sh

echo "=== 7-Day Average Resource Usage ==="

# CPU usage
docker stats --no-stream --format "{{.Name}},{{.CPUPerc}}" | \
  awk -F',' '{print $1 ": " $2}' | \
  column -t

# Memory usage
docker stats --no-stream --format "{{.Name}},{{.MemUsage}}" | \
  awk -F',' '{print $1 ": " $2}' | \
  column -t

# Recommendations
echo -e "\n=== Recommendations ==="
docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemPerc}}" | \
  awk -F',' '
    {
      cpu = substr($2, 1, length($2)-1);
      mem = substr($3, 1, length($3)-1);

      if (cpu < 30 && mem < 50)
        print $1 ": Consider downsizing (low utilization)";
      else if (cpu > 80 || mem > 80)
        print $1 ": Consider upsizing (high utilization)";
    }
  '
```

### Database Storage Optimization

```sql
-- Find largest tables
SELECT
  schemaname || '.' || tablename AS table,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS data_size,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS external_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

-- Compress old data
SELECT compress_chunk(i, if_not_compressed => true)
FROM show_chunks('llm_events', older_than => INTERVAL '30 days') i;

-- Drop old data (if allowed)
SELECT drop_chunks('llm_events', INTERVAL '365 days');
```

### S3 Lifecycle Policies

```json
{
  "Rules": [
    {
      "Id": "ArchiveOldBackups",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "backups/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 2555
      }
    }
  ]
}
```

## Troubleshooting

### Performance Issues

**Slow API Responses:**

```bash
# Check API server load
docker stats api-server

# Check database connections
docker exec llm-observatory-db-primary psql -U postgres -c "
SELECT count(*), state
FROM pg_stat_activity
WHERE datname = 'llm_observatory'
GROUP BY state;
"

# Check slow queries
docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duration DESC;
"

# Check cache hit rate
docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" INFO stats | grep keyspace
```

**Database Performance:**

```bash
# Check lock waits
docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "
SELECT
  blocked_locks.pid AS blocked_pid,
  blocked_activity.usename AS blocked_user,
  blocking_locks.pid AS blocking_pid,
  blocking_activity.usename AS blocking_user,
  blocked_activity.query AS blocked_statement,
  blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
  AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
  AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
  AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
  AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
  AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
  AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
  AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
  AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
  AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
  AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
"
```

**Memory Leaks:**

```bash
# Monitor memory over time
while true; do
  echo "$(date) - Memory Usage:"
  docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"
  sleep 300  # Every 5 minutes
done >> memory-monitor.log
```

---

**Next Steps:**
- [Production Deployment Guide](./PRODUCTION_DEPLOYMENT.md)
- [Operations Manual](./OPERATIONS_MANUAL.md)
- [Monitoring Guide](./MONITORING.md)

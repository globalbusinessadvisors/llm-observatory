# Analytics API - Deployment Guide

Complete guide for deploying the Analytics API to production.

## Table of Contents

1. [Infrastructure Requirements](#infrastructure-requirements)
2. [Docker Deployment](#docker-deployment)
3. [Kubernetes Deployment](#kubernetes-deployment)
4. [Environment Variables](#environment-variables)
5. [Database Setup](#database-setup)
6. [Monitoring & Logging](#monitoring--logging)
7. [Scaling](#scaling)
8. [Security](#security)
9. [Health Checks](#health-checks)

---

## Infrastructure Requirements

### Minimum Requirements

| Component | Specification |
|-----------|--------------|
| **CPU** | 2 cores (4 recommended) |
| **Memory** | 2GB (4GB recommended) |
| **Storage** | 20GB (for logs and temp files) |
| **Network** | 1 Gbps |

### Production Recommendations

| Component | Specification | Notes |
|-----------|--------------|-------|
| **API Instances** | 3-5 instances | For high availability |
| **PostgreSQL** | 4 vCPU, 16GB RAM | TimescaleDB with SSD storage |
| **Redis** | 2GB RAM | For caching and rate limiting |
| **Load Balancer** | AWS ALB / NGINX | SSL termination |

---

## Docker Deployment

### 1. Build the Image

```bash
# Build from project root
docker build -f services/analytics-api/Dockerfile \
  -t analytics-api:1.0.0 .
```

### 2. Run with Docker Compose

**docker-compose.yml:**

```yaml
version: '3.8'

services:
  analytics-api:
    image: analytics-api:1.0.0
    ports:
      - "8080:8080"
      - "9091:9091"  # Metrics
    environment:
      - DATABASE_URL=postgres://user:pass@postgres:5432/llm_observatory
      - REDIS_URL=redis://redis:6379/0
      - JWT_SECRET=${JWT_SECRET}
      - RUST_LOG=analytics_api=info
      - API_PORT=8080
      - API_METRICS_PORT=9091
      - CACHE_DEFAULT_TTL=60
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  postgres:
    image: timescale/timescaledb:latest-pg15
    environment:
      - POSTGRES_DB=llm_observatory
      - POSTGRES_USER=llm_user
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./crates/storage/migrations:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --maxmemory 2gb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### 3. Start the Stack

```bash
# Set environment variables
export JWT_SECRET="your-secure-jwt-secret-minimum-32-characters"
export POSTGRES_PASSWORD="your-secure-database-password"

# Start services
docker-compose up -d

# Check logs
docker-compose logs -f analytics-api

# Verify health
curl http://localhost:8080/health
```

---

## Kubernetes Deployment

### 1. ConfigMap

**analytics-api-config.yaml:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: analytics-api-config
  namespace: llm-observatory
data:
  API_PORT: "8080"
  API_METRICS_PORT: "9091"
  CACHE_DEFAULT_TTL: "60"
  RUST_LOG: "analytics_api=info,tower_http=info"
  DATABASE_POOL_SIZE: "20"
  DATABASE_MIN_CONNECTIONS: "5"
```

### 2. Secrets

```bash
# Create secrets
kubectl create secret generic analytics-api-secrets \
  --from-literal=jwt-secret='your-jwt-secret' \
  --from-literal=database-url='postgres://user:pass@postgres:5432/llm_observatory' \
  --from-literal=redis-url='redis://redis:6379/0' \
  -n llm-observatory
```

### 3. Deployment

**analytics-api-deployment.yaml:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-api
  namespace: llm-observatory
  labels:
    app: analytics-api
    version: v1.0.0
spec:
  replicas: 3
  selector:
    matchLabels:
      app: analytics-api
  template:
    metadata:
      labels:
        app: analytics-api
        version: v1.0.0
    spec:
      containers:
      - name: analytics-api
        image: analytics-api:1.0.0
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 9091
          name: metrics
        env:
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: analytics-api-secrets
              key: jwt-secret
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: analytics-api-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: analytics-api-secrets
              key: redis-url
        envFrom:
        - configMapRef:
            name: analytics-api-config
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 30
```

### 4. Service

**analytics-api-service.yaml:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: analytics-api
  namespace: llm-observatory
  labels:
    app: analytics-api
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  - port: 9091
    targetPort: 9091
    protocol: TCP
    name: metrics
  selector:
    app: analytics-api
```

### 5. Horizontal Pod Autoscaler

**analytics-api-hpa.yaml:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: analytics-api
  namespace: llm-observatory
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: analytics-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 6. Ingress

**analytics-api-ingress.yaml:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: analytics-api
  namespace: llm-observatory
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.llm-observatory.io
    secretName: analytics-api-tls
  rules:
  - host: api.llm-observatory.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: analytics-api
            port:
              number: 80
```

### 7. Deploy

```bash
# Apply configuration
kubectl apply -f analytics-api-config.yaml
kubectl apply -f analytics-api-deployment.yaml
kubectl apply -f analytics-api-service.yaml
kubectl apply -f analytics-api-hpa.yaml
kubectl apply -f analytics-api-ingress.yaml

# Verify deployment
kubectl get pods -n llm-observatory
kubectl logs -f -l app=analytics-api -n llm-observatory

# Test endpoint
curl https://api.llm-observatory.io/health
```

---

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgres://user:pass@host:5432/db` |
| `REDIS_URL` | Redis connection string | `redis://host:6379/0` |
| `JWT_SECRET` | JWT signing secret (32+ chars) | `your-secure-secret-key-here` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `API_PORT` | HTTP server port | `8080` |
| `API_METRICS_PORT` | Prometheus metrics port | `9091` |
| `APP_HOST` | Bind address | `0.0.0.0` |
| `CACHE_DEFAULT_TTL` | Cache TTL in seconds | `3600` |
| `RUST_LOG` | Log level | `info` |
| `CORS_ORIGINS` | Allowed CORS origins | `*` |
| `DATABASE_POOL_SIZE` | Max database connections | `20` |
| `DATABASE_MIN_CONNECTIONS` | Min database connections | `5` |

---

## Database Setup

### 1. Run Migrations

```bash
# Install sqlx-cli
cargo install sqlx-cli --no-default-features --features postgres

# Run migrations
export DATABASE_URL="postgres://user:pass@localhost:5432/llm_observatory"
cd crates/storage
sqlx migrate run
```

### 2. Create Continuous Aggregates

Continuous aggregates are created automatically by migrations. Verify:

```sql
SELECT view_name
FROM timescaledb_information.continuous_aggregates;

-- Expected: traces_1min, traces_1hour, traces_1day
```

### 3. Configure Retention

```sql
-- Add retention policy (keep 90 days)
SELECT add_retention_policy('traces', INTERVAL '90 days');

-- Add compression policy (compress after 7 days)
SELECT add_compression_policy('traces', INTERVAL '7 days');
```

---

## Monitoring & Logging

### Prometheus Metrics

**prometheus.yml:**

```yaml
scrape_configs:
  - job_name: 'analytics-api'
    static_configs:
      - targets: ['analytics-api:9091']
    metrics_path: /metrics
    scrape_interval: 15s
```

**Key Metrics:**

- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request latency histogram
- `db_pool_connections` - Active database connections
- `cache_hits_total` - Cache hit count
- `cache_misses_total` - Cache miss count
- `rate_limit_exceeded_total` - Rate limit violations

### Grafana Dashboard

Import pre-built dashboard from `docs/grafana-dashboard.json`

### Logging

```bash
# View logs in Docker
docker-compose logs -f analytics-api

# View logs in Kubernetes
kubectl logs -f -l app=analytics-api -n llm-observatory

# Filter by level
kubectl logs -l app=analytics-api -n llm-observatory | grep ERROR
```

---

## Scaling

### Horizontal Scaling

```bash
# Kubernetes
kubectl scale deployment analytics-api --replicas=5 -n llm-observatory

# Docker Swarm
docker service scale analytics-api=5
```

### Database Read Replicas

```yaml
environment:
  - DATABASE_URL=postgres://primary:5432/db  # Write operations
  - DATABASE_READONLY_URL=postgres://replica:5432/db  # Read operations
```

### Redis Cluster

For high availability, use Redis Cluster or Sentinel:

```yaml
environment:
  - REDIS_URL=redis://sentinel-node1:26379,sentinel-node2:26379,sentinel-node3:26379/mymaster
```

---

## Security

### 1. TLS/SSL

Always use HTTPS in production:

```yaml
# Ingress with TLS
spec:
  tls:
  - hosts:
    - api.llm-observatory.io
    secretName: analytics-api-tls
```

### 2. Network Policies

**analytics-api-network-policy.yaml:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: analytics-api
  namespace: llm-observatory
spec:
  podSelector:
    matchLabels:
      app: analytics-api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
```

### 3. Secrets Management

Use a secrets manager:

- AWS Secrets Manager
- HashiCorp Vault
- Kubernetes Secrets with encryption at rest

### 4. Security Headers

The API automatically includes security headers. Verify:

```bash
curl -I https://api.llm-observatory.io/health
```

Expected headers:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`

---

## Health Checks

### Health Endpoint

```bash
curl https://api.llm-observatory.io/health
```

**Healthy Response:**

```json
{
  "status": "healthy",
  "database": "healthy",
  "redis": "healthy",
  "timestamp": "2025-11-05T10:30:00Z"
}
```

### Kubernetes Probes

**Liveness:** Checks if application is running
**Readiness:** Checks if application can serve traffic
**Startup:** Checks if application has started

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod analytics-api-xxx -n llm-observatory

# Check logs
kubectl logs analytics-api-xxx -n llm-observatory

# Common issues:
# - Missing secrets
# - Database connection failed
# - Redis connection failed
```

### High Memory Usage

```bash
# Check memory usage
kubectl top pods -n llm-observatory

# Increase memory limit in deployment
resources:
  limits:
    memory: "2Gi"
```

### Database Connection Issues

```bash
# Verify database connectivity
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
  psql postgres://user:pass@postgres:5432/llm_observatory

# Check connection pool
# Look for "DATABASE_CONNECTION_FAILED" errors in logs
```

---

## Backup & Recovery

### Database Backup

```bash
# Backup
pg_dump -h localhost -U llm_user llm_observatory > backup.sql

# Restore
psql -h localhost -U llm_user llm_observatory < backup.sql
```

### Continuous Backup (Kubernetes)

Use Velero or native cloud backups for automated backups.

---

## Production Checklist

- [ ] TLS/SSL certificates configured
- [ ] Environment variables set
- [ ] Database migrations applied
- [ ] Continuous aggregates created
- [ ] Retention and compression policies set
- [ ] Monitoring configured (Prometheus + Grafana)
- [ ] Logging aggregation configured
- [ ] Health checks passing
- [ ] Horizontal pod autoscaler configured
- [ ] Network policies applied
- [ ] Secrets encrypted at rest
- [ ] Backup strategy implemented
- [ ] Load testing completed
- [ ] Runbooks documented

---

**Last Updated:** 2025-11-05
**Version:** 1.0.0

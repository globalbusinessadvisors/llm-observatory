# LLM Observatory - Production Deployment Guide

## Table of Contents

1. [Overview](#overview)
2. [AWS Deployment](#aws-deployment)
3. [GCP Deployment](#gcp-deployment)
4. [Azure Deployment](#azure-deployment)
5. [Kubernetes Deployment](#kubernetes-deployment)
6. [Environment Configuration](#environment-configuration)
7. [Scaling Guide](#scaling-guide)
8. [Security Hardening](#security-hardening)

## Overview

LLM Observatory can be deployed on any cloud provider using Docker or Kubernetes.

**Recommended Stack:**
- Kubernetes for orchestration
- Managed PostgreSQL/TimescaleDB for metrics
- Redis for caching
- Object storage (S3/GCS/Azure Blob) for Tempo traces

## AWS Deployment

### Architecture

```
                    ┌──────────────────┐
                    │   Application    │
                    │   Load Balancer  │
                    └────────┬─────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
    ┌─────▼────┐      ┌──────▼──────┐   ┌──────▼──────┐
    │Collector │      │ Storage     │   │ API Service │
    │ECS/EKS   │      │ Service     │   │ ECS/EKS     │
    └─────┬────┘      └──────┬──────┘   └──────┬──────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
         ┌───────────────────┼────────────────────┐
         │                   │                    │
    ┌────▼───────┐   ┌───────▼───────┐   ┌───────▼──────┐
    │ RDS        │   │ ElastiCache   │   │   S3         │
    │ PostgreSQL │   │ (Redis)       │   │ (Tempo)      │
    └────────────┘   └───────────────┘   └──────────────┘
```

### ECS Deployment

```bash
# 1. Create RDS PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier llm-observatory-db \
  --db-instance-class db.r6g.xlarge \
  --engine postgres \
  --engine-version 16.1 \
  --master-username postgres \
  --master-user-password YOUR_PASSWORD \
  --allocated-storage 100

# 2. Create ElastiCache Redis cluster
aws elasticache create-cache-cluster \
  --cache-cluster-id llm-observatory-redis \
  --cache-node-type cache.r6g.large \
  --engine redis \
  --num-cache-nodes 1

# 3. Deploy using ECS
aws ecs create-cluster --cluster-name llm-observatory

# 4. Create task definitions (see ecs-task-definition.json)
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json

# 5. Create services
aws ecs create-service \
  --cluster llm-observatory \
  --service-name collector \
  --task-definition llm-observatory-collector \
  --desired-count 3
```

### EKS Deployment

```bash
# 1. Create EKS cluster
eksctl create cluster \
  --name llm-observatory \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type m5.xlarge \
  --nodes 3

# 2. Deploy using Helm
helm repo add llm-observatory https://llm-observatory.github.io/helm-charts
helm install llm-observatory llm-observatory/llm-observatory \
  --set database.host=your-rds-endpoint \
  --set redis.host=your-elasticache-endpoint
```

## GCP Deployment

### GKE with Cloud SQL

```bash
# 1. Create GKE cluster
gcloud container clusters create llm-observatory \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-4

# 2. Create Cloud SQL instance
gcloud sql instances create llm-observatory-db \
  --database-version=POSTGRES_16 \
  --tier=db-custom-4-16384 \
  --region=us-central1

# 3. Create Cloud Memorystore (Redis)
gcloud redis instances create llm-observatory-redis \
  --size=5 \
  --region=us-central1

# 4. Deploy using kubectl
kubectl apply -f k8s/
```

## Azure Deployment

### AKS with Azure Database

```bash
# 1. Create resource group
az group create --name llm-observatory --location eastus

# 2. Create AKS cluster
az aks create \
  --resource-group llm-observatory \
  --name llm-observatory-cluster \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --generate-ssh-keys

# 3. Create Azure Database for PostgreSQL
az postgres server create \
  --resource-group llm-observatory \
  --name llm-observatory-db \
  --sku-name GP_Gen5_4 \
  --version 16

# 4. Create Azure Cache for Redis
az redis create \
  --resource-group llm-observatory \
  --name llm-observatory-redis \
  --sku Standard \
  --vm-size c3

# 5. Deploy application
kubectl apply -f k8s/azure/
```

## Kubernetes Deployment

### Kubernetes Manifests

**Namespace:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: llm-observatory
```

**Collector Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: collector
  namespace: llm-observatory
spec:
  replicas: 3
  selector:
    matchLabels:
      app: collector
  template:
    metadata:
      labels:
        app: collector
    spec:
      containers:
      - name: collector
        image: llm-observatory/collector:latest
        ports:
        - containerPort: 4317
          name: otlp-grpc
        - containerPort: 4318
          name: otlp-http
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: url
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
```

**Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: collector
  namespace: llm-observatory
spec:
  selector:
    app: collector
  ports:
  - name: otlp-grpc
    port: 4317
    targetPort: 4317
  - name: otlp-http
    port: 4318
    targetPort: 4318
  type: LoadBalancer
```

**HorizontalPodAutoscaler:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: collector-hpa
  namespace: llm-observatory
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: collector
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Environment Configuration

### Production Environment Variables

```bash
# Environment
ENVIRONMENT=production

# Database
DATABASE_URL=postgresql://user:pass@db-host:5432/llm_observatory
DB_POOL_MIN_SIZE=10
DB_POOL_MAX_SIZE=50
DB_SSL_MODE=require

# Redis
REDIS_URL=redis://redis-host:6379/0
REDIS_TLS=true

# Security
JWT_SECRET=<generate-with-openssl-rand-hex-32>
SECRET_KEY=<generate-with-openssl-rand-hex-32>

# Logging
RUST_LOG=info,llm_observatory=info
LOG_FORMAT=json

# Retention
RETENTION_TRACES_DAYS=30
RETENTION_METRICS_DAYS=90

# Performance
COLLECTOR_BATCH_SIZE=1000
COLLECTOR_NUM_WORKERS=8
COPY_BATCH_SIZE=10000
```

## Scaling Guide

### Horizontal Scaling

**Collector:**
- Start with 3 replicas
- Scale to 10+ replicas for > 500k spans/sec
- Use CPU-based autoscaling (target: 70%)

**Storage Service:**
- Start with 2 replicas
- Scale based on write latency
- Monitor database connection pool usage

**API Service:**
- Start with 2 replicas
- Scale based on request rate
- Cache heavily queried data in Redis

### Vertical Scaling

**Database Sizing:**
- Small: 4 vCPU, 16 GB RAM (< 100k spans/day)
- Medium: 8 vCPU, 32 GB RAM (100k-1M spans/day)
- Large: 16 vCPU, 64 GB RAM (1M-10M spans/day)

## Security Hardening

1. **Network Security:**
   - Use private VPC/VNet
   - Restrict database access to application subnets
   - Enable TLS for all connections

2. **Authentication:**
   - Enable JWT authentication for API
   - Rotate secrets regularly
   - Use managed identity for cloud resources

3. **Encryption:**
   - Enable encryption at rest for databases
   - Enable TLS 1.3 for all network communication
   - Use KMS for secret management

4. **Monitoring:**
   - Enable audit logging
   - Set up alerts for security events
   - Monitor for unusual access patterns

See [PRODUCTION_DEPLOYMENT.md](./PRODUCTION_DEPLOYMENT.md) for detailed production setup.

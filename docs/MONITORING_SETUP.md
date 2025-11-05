# Monitoring Setup Guide

This guide walks you through setting up the complete monitoring stack for LLM Observatory storage.

## Quick Start

### 1. Start the Monitoring Stack

```bash
# Start PostgreSQL, Redis, Prometheus, and Grafana
docker-compose -f docker/monitoring-stack.yml up -d

# Wait for services to be ready
docker-compose -f docker/monitoring-stack.yml ps
```

Services will be available at:
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379
- **Prometheus**: http://localhost:9091
- **Grafana**: http://localhost:3000 (admin/admin)

### 2. Configure Environment

Create a `.env` file:

```bash
# Database configuration
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=llm_observatory
POSTGRES_USER=llm_user
POSTGRES_PASSWORD=llm_password

# Redis configuration (optional)
REDIS_URL=redis://localhost:6379

# Pool configuration
POOL_MAX_CONNECTIONS=20
POOL_MIN_CONNECTIONS=2
POOL_CONNECT_TIMEOUT_SECS=30
POOL_IDLE_TIMEOUT_SECS=600
POOL_MAX_LIFETIME_SECS=1800
```

### 3. Run the Example

```bash
# Run the monitoring example
cargo run --example monitoring_example

# In another terminal, check the health endpoint
curl http://localhost:9090/health | jq

# Check the metrics endpoint
curl http://localhost:9090/metrics
```

### 4. View Metrics in Grafana

1. Open http://localhost:3000
2. Login with `admin` / `admin`
3. Navigate to Dashboards
4. Import dashboards from `docs/grafana/`:
   - `storage-overview.json`
   - `database-health.json`

## Manual Setup

### Install Prometheus

#### macOS
```bash
brew install prometheus
prometheus --config.file=docker/prometheus.yml
```

#### Linux
```bash
# Download and extract
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvfz prometheus-*.tar.gz
cd prometheus-*

# Run with custom config
./prometheus --config.file=/path/to/docker/prometheus.yml
```

#### Docker
```bash
docker run -d \
  --name prometheus \
  -p 9091:9090 \
  -v $(pwd)/docker/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus
```

### Install Grafana

#### macOS
```bash
brew install grafana
brew services start grafana
```

#### Linux
```bash
# Add Grafana repository
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

# Install
sudo apt-get update
sudo apt-get install grafana

# Start service
sudo systemctl start grafana-server
```

#### Docker
```bash
docker run -d \
  --name grafana \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana/grafana
```

## Configuration

### Prometheus Scrape Configuration

The storage service exposes metrics on port 9090 by default. Configure Prometheus to scrape:

```yaml
scrape_configs:
  - job_name: 'llm-observatory-storage'
    scrape_interval: 10s
    static_configs:
      - targets: ['localhost:9090']
```

### Grafana Datasource

1. Navigate to Configuration → Data Sources
2. Add new Prometheus datasource
3. Set URL to `http://localhost:9091` (or your Prometheus address)
4. Click "Save & Test"

### Import Dashboards

#### Via UI
1. Dashboards → Import
2. Upload JSON file from `docs/grafana/`
3. Select Prometheus datasource
4. Click Import

#### Via Provisioning
Create `/etc/grafana/provisioning/dashboards/llm-observatory.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'LLM Observatory'
    orgId: 1
    folder: 'LLM Observatory'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /path/to/docs/grafana
```

## Application Integration

### Basic Setup

```rust
use llm_observatory_storage::{
    HealthServer, StorageConfig, StorageMetrics, StoragePool,
};
use std::sync::Arc;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize storage
    let config = StorageConfig::from_env()?;
    let pool = StoragePool::new(config).await?;
    let metrics = Arc::new(StorageMetrics::new());

    // Start health and metrics server
    let health_server = HealthServer::new(pool.clone());
    tokio::spawn(async move {
        health_server.serve("0.0.0.0:9090").await.unwrap();
    });

    // Start periodic pool metrics updates
    let pool_clone = pool.clone();
    tokio::spawn(async move {
        let mut ticker = tokio::time::interval(
            std::time::Duration::from_secs(10)
        );
        loop {
            ticker.tick().await;
            pool_clone.update_metrics();
        }
    });

    // Your application code...

    Ok(())
}
```

### Using Instrumented Components

```rust
use llm_observatory_storage::{
    writers::InstrumentedTraceWriter,
    repositories::InstrumentedTraceRepository,
};

// Writers automatically record metrics
let writer = InstrumentedTraceWriter::new(pool.clone(), metrics.clone());
writer.write_trace(trace).await?;

// Repositories automatically record metrics
let repo = InstrumentedTraceRepository::new(pool.clone(), metrics.clone());
let traces = repo.list(filters).await?;
```

## Kubernetes Deployment

### Service with Monitoring

```yaml
apiVersion: v1
kind: Service
metadata:
  name: llm-observatory-storage
  labels:
    app: llm-observatory
    component: storage
spec:
  selector:
    app: llm-observatory
    component: storage
  ports:
    - name: http
      port: 8080
      targetPort: 8080
    - name: metrics
      port: 9090
      targetPort: 9090
  type: ClusterIP
```

### ServiceMonitor for Prometheus Operator

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: llm-observatory-storage
  labels:
    app: llm-observatory
    component: storage
spec:
  selector:
    matchLabels:
      app: llm-observatory
      component: storage
  endpoints:
    - port: metrics
      interval: 10s
      path: /metrics
```

### Health Probes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-observatory-storage
spec:
  template:
    spec:
      containers:
        - name: storage
          image: llm-observatory/storage:latest
          ports:
            - name: http
              containerPort: 8080
            - name: metrics
              containerPort: 9090
          livenessProbe:
            httpGet:
              path: /health/live
              port: 9090
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 9090
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
```

## Alert Configuration

### Prometheus Alert Rules

Create `docker/alerts/storage.yml`:

```yaml
groups:
  - name: storage
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: rate(storage_errors_total[5m]) > 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High storage error rate"
          description: "Error rate is {{ $value }} errors/sec"

      - alert: ConnectionPoolNearCapacity
        expr: (storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Connection pool near capacity"
          description: "Pool utilization is {{ $value }}%"

      - alert: HighWriteLatency
        expr: histogram_quantile(0.95, rate(storage_write_duration_seconds_bucket[5m])) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High write latency detected"
          description: "P95 write latency is {{ $value }}s"
```

### Alertmanager Configuration

Create `docker/alertmanager.yml`:

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: critical
    - match:
        severity: warning
      receiver: warning

receivers:
  - name: 'default'
    # Configure your default notification method

  - name: 'critical'
    # Configure critical alerts (e.g., PagerDuty, Slack)
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts-critical'
        title: 'Critical Alert'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'warning'
    # Configure warning alerts
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts-warning'
        title: 'Warning Alert'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Testing

### Load Testing with Metrics

```bash
# Install k6 for load testing
brew install k6  # macOS
# or download from https://k6.io/

# Create a simple load test script
cat > loadtest.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 10 },
    { duration: '3m', target: 50 },
    { duration: '1m', target: 0 },
  ],
};

export default function() {
  let res = http.get('http://localhost:9090/health');
  check(res, { 'status was 200': (r) => r.status == 200 });
  sleep(1);
}
EOF

# Run load test
k6 run loadtest.js
```

Watch the metrics in Grafana while the load test runs.

### Verify Metrics

```bash
# Check if metrics are being exposed
curl http://localhost:9090/metrics | grep storage_

# Check specific metric
curl http://localhost:9090/metrics | grep storage_writes_total

# Query Prometheus directly
curl 'http://localhost:9091/api/v1/query?query=storage_writes_total'
```

## Troubleshooting

### Metrics Not Appearing

1. **Check metrics endpoint**
   ```bash
   curl http://localhost:9090/metrics
   ```

2. **Check Prometheus targets**
   - Open http://localhost:9091/targets
   - Verify storage target is UP

3. **Check Prometheus logs**
   ```bash
   docker logs llm-observatory-prometheus
   ```

### Dashboards Not Loading

1. **Verify datasource**
   - Grafana → Configuration → Data Sources
   - Test Prometheus connection

2. **Check dashboard JSON**
   - Ensure valid JSON format
   - Verify metric names match

3. **Check Grafana logs**
   ```bash
   docker logs llm-observatory-grafana
   ```

### High Memory Usage

1. **Adjust Prometheus retention**
   ```yaml
   # In prometheus.yml
   storage:
     tsdb:
       retention.time: 15d
       retention.size: 50GB
   ```

2. **Reduce scrape frequency**
   ```yaml
   scrape_interval: 30s  # instead of 10s
   ```

## Production Recommendations

### 1. Resource Allocation

- **Prometheus**: 2 CPU cores, 4GB RAM minimum
- **Grafana**: 1 CPU core, 1GB RAM minimum
- **Storage Service**: Metrics overhead <1% CPU, <10MB RAM

### 2. High Availability

- Run multiple Prometheus instances with federation
- Use Thanos or Cortex for long-term storage
- Deploy Grafana with database backend (PostgreSQL)

### 3. Security

- Enable authentication on all endpoints
- Use TLS for metrics scraping
- Implement network policies in Kubernetes
- Restrict metrics endpoint access

### 4. Backup

- Backup Prometheus data directory regularly
- Export Grafana dashboards to version control
- Store alert rules in Git

### 5. Scaling

- Use remote write for high-volume metrics
- Implement metric relabeling to reduce cardinality
- Use recording rules for expensive queries

## Further Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [LLM Observatory Monitoring Guide](MONITORING.md)

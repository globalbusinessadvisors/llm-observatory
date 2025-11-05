# Prometheus Monitoring Configuration

This directory contains Prometheus and Alertmanager configuration for monitoring the LLM Observatory storage layer.

## Files

- **storage_layer_alerts.yml** - Prometheus alert rules for the storage layer
- **alertmanager.yml** - Alertmanager configuration for routing alerts
- **prometheus.yml** - Prometheus server configuration (to be created)

## Quick Start

### 1. Configure Prometheus

Create a `prometheus.yml` file:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'llm-observatory'
    environment: 'production'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'alertmanager:9093'

# Load alert rules
rule_files:
  - "storage_layer_alerts.yml"

# Scrape configurations
scrape_configs:
  # Storage Layer Application
  - job_name: 'storage-layer'
    static_configs:
      - targets:
          - 'localhost:9090'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
      - source_labels: [__address__]
        regex: '([^:]+)(?::\d+)?'
        target_label: hostname

  # TimescaleDB / PostgreSQL
  - job_name: 'timescaledb'
    static_configs:
      - targets:
          - 'postgres-exporter:9187'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance

  # Redis
  - job_name: 'redis'
    static_configs:
      - targets:
          - 'redis-exporter:9121'

  # Node Exporter (system metrics)
  - job_name: 'node'
    static_configs:
      - targets:
          - 'node-exporter:9100'
```

### 2. Update Alertmanager Configuration

Edit `alertmanager.yml` and replace placeholders:

```bash
# Slack webhook URL
sed -i 's|YOUR_SLACK_WEBHOOK_URL|https://hooks.slack.com/services/YOUR/WEBHOOK/URL|g' alertmanager.yml

# PagerDuty service keys
sed -i 's|YOUR_PAGERDUTY_SERVICE_KEY_CRITICAL|your-actual-key|g' alertmanager.yml
sed -i 's|YOUR_PAGERDUTY_SERVICE_KEY_DATABASE|your-actual-key|g' alertmanager.yml
sed -i 's|YOUR_PAGERDUTY_SERVICE_KEY_BACKUP|your-actual-key|g' alertmanager.yml

# Email password
sed -i 's|YOUR_EMAIL_PASSWORD|your-actual-password|g' alertmanager.yml
```

### 3. Deploy with Docker Compose

Add to your `docker-compose.yml`:

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: llm-observatory-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./docker/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./docker/prometheus/storage_layer_alerts.yml:/etc/prometheus/storage_layer_alerts.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    networks:
      - llm-observatory-network

  alertmanager:
    image: prom/alertmanager:latest
    container_name: llm-observatory-alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./docker/prometheus/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    restart: unless-stopped
    networks:
      - llm-observatory-network

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: llm-observatory-postgres-exporter
    ports:
      - "9187:9187"
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:${DB_PASSWORD}@timescaledb:5432/llm_observatory?sslmode=disable"
    depends_on:
      - timescaledb
    restart: unless-stopped
    networks:
      - llm-observatory-network

  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: llm-observatory-redis-exporter
    ports:
      - "9121:9121"
    environment:
      REDIS_ADDR: "redis:6379"
      REDIS_PASSWORD: "${REDIS_PASSWORD}"
    depends_on:
      - redis
    restart: unless-stopped
    networks:
      - llm-observatory-network

  node-exporter:
    image: prom/node-exporter:latest
    container_name: llm-observatory-node-exporter
    ports:
      - "9100:9100"
    command:
      - '--path.rootfs=/host'
    volumes:
      - '/:/host:ro,rslave'
    restart: unless-stopped
    networks:
      - llm-observatory-network

volumes:
  prometheus_data:
    name: llm-observatory-prometheus-data
  alertmanager_data:
    name: llm-observatory-alertmanager-data
```

### 4. Start Monitoring Stack

```bash
# Start Prometheus and Alertmanager
docker-compose up -d prometheus alertmanager postgres-exporter redis-exporter node-exporter

# Verify Prometheus is running
curl http://localhost:9090/-/healthy

# Verify Alertmanager is running
curl http://localhost:9093/-/healthy

# View Prometheus targets
open http://localhost:9090/targets

# View Alertmanager
open http://localhost:9093
```

## Alert Severity Levels

### Critical Alerts
**Response Time:** Immediate (Page on-call engineer)

Examples:
- DatabaseDown
- StorageServiceDown
- ConnectionPoolExhausted
- BackupFailed
- DatabaseDiskSpaceLow

**Action:** These alerts require immediate investigation and resolution.

### Warning Alerts
**Response Time:** Within 30 minutes (Notify team)

Examples:
- ConnectionPoolHighUsage
- SlowQueryDetected
- HighLatency
- DatabaseMemoryPressure

**Action:** These alerts should be investigated soon to prevent escalation.

### Info Alerts
**Response Time:** Within 24 hours (Create ticket)

Examples:
- HighQueryRate
- DatabaseGrowthHigh
- RedisCacheHitRateLow

**Action:** These alerts are informational and may require capacity planning.

## Alert Categories

### Database Availability
- Database connection failures
- Database down
- Read-only mode

### Connection Pool
- Pool exhaustion
- High usage
- Idle connections
- Long-running connections

### Query Performance
- Slow queries
- Performance degradation
- High query rate

### Application Performance
- High error rate
- High latency
- Service down

### Database Resources
- Disk space
- CPU usage
- Memory pressure
- I/O wait

### Cache Performance
- Redis down
- Memory usage
- Cache hit rate

### Data Integrity
- Replication lag
- Lock contention
- Deadlocks

### TimescaleDB Specific
- Compression failures
- Continuous aggregate refresh
- Retention policy execution

### Backup and Recovery
- Backup failures
- Old backups

### Capacity Planning
- Database growth
- Table bloat

## Testing Alerts

### Test Alert Configuration

```bash
# Validate Prometheus configuration
docker exec llm-observatory-prometheus promtool check config /etc/prometheus/prometheus.yml

# Validate alert rules
docker exec llm-observatory-prometheus promtool check rules /etc/prometheus/storage_layer_alerts.yml

# Test Alertmanager configuration
docker exec llm-observatory-alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
```

### Trigger Test Alert

```bash
# Create a test alert
cat << 'EOF' | curl --data-binary @- http://localhost:9093/api/v1/alerts
[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "warning",
    "component": "test",
    "instance": "localhost"
  },
  "annotations": {
    "summary": "This is a test alert",
    "description": "Testing alert routing and notifications"
  }
}]
EOF

# View active alerts
curl http://localhost:9093/api/v1/alerts | jq .
```

### Silence Alerts

```bash
# Silence all alerts for maintenance
docker exec llm-observatory-alertmanager amtool silence add \
  --comment="Maintenance window" \
  --duration=2h \
  alertname=~".+"

# Silence specific alert
docker exec llm-observatory-alertmanager amtool silence add \
  --comment="Known issue" \
  --duration=1h \
  alertname="SlowQueryDetected"

# List active silences
docker exec llm-observatory-alertmanager amtool silence query
```

## Customizing Alerts

### Adjusting Thresholds

Edit `storage_layer_alerts.yml` to adjust alert thresholds:

```yaml
# Example: Change high error rate threshold from 1% to 2%
- alert: HighErrorRate
  expr: |
    sum(rate(http_requests_total{job="storage-layer",status=~"5.."}[5m])) by (instance)
    /
    sum(rate(http_requests_total{job="storage-layer"}[5m])) by (instance)
    > 0.02  # Changed from 0.01 to 0.02
```

### Adding New Alerts

Add new alerts to `storage_layer_alerts.yml`:

```yaml
- alert: YourNewAlert
  expr: your_metric > threshold
  for: 5m
  labels:
    severity: warning
    component: your-component
    layer: storage
  annotations:
    summary: "Brief description"
    description: "Detailed description with {{ $value }}"
    runbook_url: "https://docs.llm-observatory.io/runbooks/your-alert"
```

### Modifying Notification Routes

Edit `alertmanager.yml` to change routing:

```yaml
routes:
  - match:
      your_label: your_value
    receiver: your-receiver
    group_wait: 30s
    repeat_interval: 4h
```

## Monitoring Best Practices

### 1. Alert Fatigue Prevention
- Set appropriate thresholds to avoid false positives
- Use `for` duration to filter transient issues
- Implement alert inhibition rules
- Regular review and tune alert rules

### 2. Alert Actionability
- Every alert should have a clear action
- Include runbook links in annotations
- Add context with metric values
- Link to relevant dashboards

### 3. Notification Management
- Route critical alerts to on-call
- Use different channels for different severities
- Implement time-based routing for maintenance windows
- Set appropriate repeat intervals

### 4. Alert Documentation
- Document alert meaning and impact
- Create runbooks for each alert
- Include troubleshooting steps
- Document resolution procedures

## Troubleshooting

### Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
docker logs llm-observatory-prometheus

# Check target status
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}'
```

### Alerts Not Firing

```bash
# Check if rule is loaded
curl http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name=="storage_database_availability")'

# Check alert state
curl http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {alertname: .labels.alertname, state: .state}'

# Check PromQL query manually
curl -G http://localhost:9090/api/v1/query --data-urlencode 'query=up{job="storage-layer"}'
```

### Alerts Not Notifying

```bash
# Check Alertmanager logs
docker logs llm-observatory-alertmanager

# Check Alertmanager configuration
curl http://localhost:9093/api/v1/status | jq .

# View alert receivers
curl http://localhost:9093/api/v1/receivers | jq .
```

## Integration with Grafana

Create dashboards in Grafana to visualize alerts:

```json
{
  "dashboard": {
    "title": "Storage Layer Alerts",
    "panels": [
      {
        "title": "Active Alerts",
        "targets": [
          {
            "expr": "ALERTS{alertstate=\"firing\",layer=\"storage\"}"
          }
        ]
      }
    ]
  }
}
```

## Further Reading

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Alert Rule Best Practices](https://prometheus.io/docs/practices/alerting/)
- [Postgres Exporter](https://github.com/prometheus-community/postgres_exporter)

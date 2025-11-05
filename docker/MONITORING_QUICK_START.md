# LLM Observatory - Monitoring Quick Start

Get your complete observability stack up and running in minutes.

## Prerequisites

- Docker and Docker Compose installed
- Ports available: 3000, 3100, 4317, 4318, 9090, 9093, 9100, 9121, 9187, 16686

## Quick Start

### 1. Start the Complete Stack

```bash
# From the project root
docker-compose up -d
```

This starts:
- TimescaleDB (database)
- Redis (cache)
- Prometheus (metrics)
- Alertmanager (alerts)
- Jaeger (tracing)
- Loki (logs)
- Promtail (log collector)
- Grafana (dashboards)
- All exporters (PostgreSQL, Redis, Node)

### 2. Verify Services

```bash
# Run the verification script
./docker/scripts/verify-observability.sh
```

### 3. Access Dashboards

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | - |
| Alertmanager | http://localhost:9093 | - |
| Jaeger UI | http://localhost:16686 | - |

## First Steps in Grafana

1. Open Grafana: http://localhost:3000
2. Login with: `admin` / `admin`
3. Change your password when prompted
4. Navigate to **Dashboards** → **Browse**
5. Open **LLM Observatory - Observability Overview**

### Pre-configured Dashboards

- **Observability Overview**: Service health, request rates, latencies
- **Storage Layer**: Database metrics, connection pool, cache performance
- **Database Health**: TimescaleDB-specific metrics
- **Node Exporter**: System resource utilization
- **Prometheus Stats**: Monitoring system health

## Sending Telemetry Data

### Metrics (Prometheus)

Your Rust applications can expose Prometheus metrics:

```rust
use prometheus::{Encoder, TextEncoder, Counter, register_counter};

// Create metrics
let requests = register_counter!("http_requests_total", "Total HTTP requests").unwrap();

// Increment on each request
requests.inc();

// Expose metrics endpoint
#[get("/metrics")]
async fn metrics() -> String {
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    let mut buffer = vec![];
    encoder.encode(&metric_families, &mut buffer).unwrap();
    String::from_utf8(buffer).unwrap()
}
```

### Traces (Jaeger via OTLP)

Send traces to Jaeger:

```rust
use opentelemetry::trace::TracerProvider;
use opentelemetry_otlp::WithExportConfig;

let tracer_provider = opentelemetry_otlp::new_pipeline()
    .tracing()
    .with_exporter(
        opentelemetry_otlp::new_exporter()
            .tonic()
            .with_endpoint("http://localhost:4317")
    )
    .install_batch(opentelemetry::runtime::Tokio)?;
```

### Logs (Loki)

Logs are automatically collected from Docker containers. For structured logging:

```rust
use tracing::{info, error};
use tracing_subscriber::fmt;

// Initialize logging
tracing_subscriber::fmt()
    .json()
    .with_target(true)
    .with_current_span(true)
    .init();

// Log with structured data
info!(
    trace_id = %trace_id,
    user_id = %user_id,
    "Processing LLM request"
);
```

## Common Operations

### View Logs

```bash
# View Loki logs in Grafana
# 1. Go to Explore
# 2. Select "Loki" data source
# 3. Query: {service="api"} |= "error"
```

### View Traces

```bash
# Open Jaeger UI: http://localhost:16686
# 1. Select service from dropdown
# 2. Click "Find Traces"
# 3. Click on a trace to view details
```

### View Metrics

```bash
# Open Prometheus: http://localhost:9090
# 1. Go to Graph tab
# 2. Enter query: rate(http_requests_total[5m])
# 3. Execute
```

### Check Alerts

```bash
# Open Alertmanager: http://localhost:9093
# View active alerts and silences
```

## Troubleshooting

### Services Not Starting

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs prometheus
docker-compose logs jaeger
docker-compose logs grafana

# Restart specific service
docker-compose restart prometheus
```

### Prometheus Not Scraping

```bash
# Check targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Verify exporter is running
curl http://localhost:9187/metrics  # PostgreSQL
curl http://localhost:9121/metrics  # Redis
curl http://localhost:9100/metrics  # Node
```

### Grafana Dashboards Not Loading

```bash
# Check Grafana logs
docker-compose logs grafana

# Verify data sources
curl -u admin:admin http://localhost:3000/api/datasources

# Restart Grafana
docker-compose restart grafana
```

### Jaeger Not Receiving Traces

```bash
# Test OTLP endpoint
curl http://localhost:4318/v1/traces

# Check Jaeger logs
docker-compose logs jaeger

# Verify sampling configuration
cat docker/jaeger/sampling.json
```

## Advanced Configuration

### Customize Scrape Intervals

Edit `docker/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'my-service'
    scrape_interval: 10s  # More frequent
    static_configs:
      - targets: ['my-service:9090']
```

### Add Custom Alerts

Create `docker/prometheus/alerts/custom_alerts.yml`:

```yaml
groups:
  - name: my_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_errors_total[5m]) > 0.01
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
```

### Configure Alert Notifications

Edit `docker/prometheus/alertmanager.yml`:

```yaml
receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK'
        channel: '#alerts'
```

### Adjust Log Retention

Edit `docker/loki/loki-config.yml`:

```yaml
limits_config:
  retention_period: 720h  # 30 days
```

### Change Jaeger Sampling

Edit `docker/jaeger/sampling.json`:

```json
{
  "default_strategy": {
    "type": "probabilistic",
    "param": 0.1  // Sample 10%
  }
}
```

## Performance Tuning

### High-Volume Scenarios

1. **Reduce Prometheus scrape frequency**:
   ```yaml
   global:
     scrape_interval: 30s  # Instead of 15s
   ```

2. **Adjust Jaeger sampling**:
   ```json
   {"param": 0.01}  // Sample only 1%
   ```

3. **Limit Loki ingestion**:
   ```yaml
   ingestion_rate_mb: 30  // Increase limit
   ```

4. **Use recording rules** for complex queries (already configured)

## Data Retention

Default retention periods:

- **Prometheus**: 30 days
- **Jaeger**: Until disk full (persistent storage)
- **Loki**: 30 days
- **Grafana**: Permanent (dashboards/settings only)

### Clean Up Old Data

```bash
# Stop services
docker-compose down

# Remove only metric data (preserves config)
docker volume rm llm-observatory-prometheus-data
docker volume rm llm-observatory-jaeger-data
docker volume rm llm-observatory-loki-data

# Restart
docker-compose up -d
```

## Security

### Production Checklist

- [ ] Change Grafana default password
- [ ] Restrict ports to localhost or VPN
- [ ] Enable TLS for external access
- [ ] Configure authentication for Prometheus
- [ ] Set up proper firewall rules
- [ ] Use secrets management for credentials
- [ ] Enable audit logging
- [ ] Regular security updates

### Basic Security Setup

```yaml
# docker-compose.override.yml
services:
  prometheus:
    ports:
      - "127.0.0.1:9090:9090"  # Localhost only

  jaeger:
    ports:
      - "127.0.0.1:16686:16686"
```

## Next Steps

1. **Explore Dashboards**: Browse pre-configured dashboards in Grafana
2. **Set Up Alerts**: Configure Alertmanager for your notification channels
3. **Instrument Code**: Add metrics, traces, and logs to your services
4. **Create Custom Dashboards**: Build dashboards for your specific needs
5. **Review Documentation**: Read `/workspaces/llm-observatory/docker/OBSERVABILITY.md`

## Resources

- [Full Observability Documentation](OBSERVABILITY.md)
- [Prometheus Configuration](prometheus/prometheus.yml)
- [Alert Rules](prometheus/alerts/)
- [Grafana Dashboards](grafana/dashboards/)
- [Jaeger Sampling](jaeger/sampling.json)

## Getting Help

If you encounter issues:

1. Check service logs: `docker-compose logs <service>`
2. Verify health: `./docker/scripts/verify-observability.sh`
3. Review configuration files in `/docker/`
4. Check Prometheus targets: http://localhost:9090/targets
5. Review alerts: http://localhost:9090/alerts

## Example Queries

### Prometheus (PromQL)

```promql
# Request rate
rate(http_requests_total[5m])

# Error percentage
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Database connection pool usage
pg_stat_database_numbackends / on(instance) pg_settings_max_connections * 100
```

### Loki (LogQL)

```logql
# All errors
{service=~".+"} |= "error"

# Errors with trace correlation
{service="api"} | json | level="error" | trace_id != ""

# Rate of log lines
rate({service="storage"}[5m])

# Top errors by service
topk(10, sum by (service) (rate({level="error"}[1h])))
```

### Jaeger (Search)

- Search by service: Select from dropdown
- Search by operation: Select from dropdown
- Search by tags: `http.status_code=500`
- Search by duration: `> 1s`
- Search by time: Last hour, 24h, custom range

---

**Happy Monitoring!** 🎉

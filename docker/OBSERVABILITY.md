# LLM Observatory - Complete Observability Stack

This document describes the complete monitoring and observability infrastructure for LLM Observatory.

## Overview

The observability stack provides comprehensive monitoring, tracing, and logging capabilities:

- **Prometheus**: Metrics collection and storage (30-day retention)
- **Alertmanager**: Alert routing and notification
- **Jaeger**: Distributed tracing with OTLP support
- **Loki**: Log aggregation and querying
- **Grafana**: Unified visualization dashboard
- **Exporters**: PostgreSQL, Redis, and Node metrics

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Application Layer                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   API    │  │Collector │  │ Storage  │  │   Rust   │       │
│  │ Services │  │  (OTLP)  │  │  Layer   │  │   Apps   │       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
│       │             │             │             │               │
│       └─────────────┴─────────────┴─────────────┘               │
│                     │                                            │
└─────────────────────┼────────────────────────────────────────────┘
                      │
         ┌────────────┴────────────┐
         │                         │
         ▼                         ▼
┌─────────────────┐       ┌─────────────────┐
│   Prometheus    │       │     Jaeger      │
│   (Metrics)     │       │    (Traces)     │
│  Port: 9090     │       │  Port: 16686    │
└────────┬────────┘       └────────┬────────┘
         │                         │
         │                ┌────────▼────────┐
         │                │      Loki       │
         │                │     (Logs)      │
         │                │  Port: 3100     │
         │                └────────┬────────┘
         │                         │
         └────────────┬────────────┘
                      │
              ┌───────▼───────┐
              │    Grafana    │
              │ Visualization │
              │  Port: 3000   │
              └───────────────┘
```

## Services

### Prometheus (Metrics)
- **Image**: `prom/prometheus:v2.48.0`
- **Port**: `9090`
- **Retention**: 30 days
- **Storage**: Persistent volume (`prometheus_data`)

**Features**:
- Service discovery for all components
- Custom alert rules for storage layer
- Recording rules for performance metrics
- Integration with Alertmanager

**Configuration**:
- Main config: `/workspaces/llm-observatory/docker/prometheus/prometheus.yml`
- Alert rules: `/workspaces/llm-observatory/docker/prometheus/alerts/`
- Recording rules: `/workspaces/llm-observatory/docker/prometheus/rules/`

### Alertmanager (Alerts)
- **Image**: `prom/alertmanager:v0.26.0`
- **Port**: `9093`
- **Storage**: Persistent volume (`alertmanager_data`)

**Features**:
- Alert routing and grouping
- Multiple notification channels (Slack, PagerDuty, Email)
- Alert silencing and inhibition
- Web UI for alert management

**Configuration**:
- Config: `/workspaces/llm-observatory/docker/prometheus/alertmanager.yml`

### Jaeger (Distributed Tracing)
- **Image**: `jaegertracing/all-in-one:1.52`
- **Ports**:
  - UI: `16686`
  - OTLP gRPC: `4317`
  - OTLP HTTP: `4318`
  - Jaeger gRPC: `14250`
  - HTTP Collector: `14268`
- **Storage**: Badger (persistent, non-ephemeral)

**Features**:
- OTLP protocol support (OpenTelemetry)
- Persistent trace storage
- Configurable sampling strategies
- Service dependency graphs
- Trace search and analysis

**Configuration**:
- Sampling: `/workspaces/llm-observatory/docker/jaeger/sampling.json`

### Loki (Log Aggregation)
- **Image**: `grafana/loki:2.9.3`
- **Port**: `3100`
- **Retention**: 30 days
- **Storage**: Persistent volume (`loki_data`)

**Features**:
- Label-based log indexing
- LogQL query language
- Log retention policies
- Integration with Promtail for log collection
- Correlation with traces and metrics

**Configuration**:
- Loki: `/workspaces/llm-observatory/docker/loki/loki-config.yml`
- Promtail: `/workspaces/llm-observatory/docker/loki/promtail-config.yml`

### Promtail (Log Collector)
- **Image**: `grafana/promtail:2.9.3`
- Collects logs from Docker containers and system logs
- Automatic service discovery
- Log parsing and labeling

### Grafana (Visualization)
- **Image**: `grafana/grafana:10.4.1`
- **Port**: `3000`
- **Default Credentials**: `admin` / `admin`

**Features**:
- Pre-configured data sources (Prometheus, Loki, Jaeger, TimescaleDB)
- Auto-provisioned dashboards
- Unified observability interface
- Trace-to-log and metric-to-trace correlation

**Dashboards**:
- Observability Overview
- Storage Layer Metrics
- Database Health
- Node Exporter (System)
- Prometheus Stats
- Jaeger Tracing

### Exporters

#### PostgreSQL Exporter
- **Image**: `prometheuscommunity/postgres-exporter:v0.15.0`
- **Port**: `9187`
- Custom queries for TimescaleDB-specific metrics
- Table bloat detection
- Lock monitoring

#### Redis Exporter
- **Image**: `oliver006/redis_exporter:v1.55.0`
- **Port**: `9121`
- Cache hit rate metrics
- Memory utilization
- Command statistics

#### Node Exporter
- **Image**: `prom/node-exporter:v1.7.0`
- **Port**: `9100`
- CPU, memory, disk metrics
- Network statistics
- System load

## Quick Start

### Starting the Complete Stack

```bash
# Start all observability services
docker-compose up -d prometheus alertmanager jaeger loki promtail grafana \
  postgres-exporter redis-exporter node-exporter

# Verify all services are running
docker-compose ps
```

### Starting Individual Services

```bash
# Start only monitoring (Prometheus + Grafana)
docker-compose up -d prometheus grafana postgres-exporter redis-exporter

# Start only tracing
docker-compose up -d jaeger

# Start only logging
docker-compose up -d loki promtail
```

## Accessing Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | None |
| Alertmanager | http://localhost:9093 | None |
| Jaeger UI | http://localhost:16686 | None |

## Environment Variables

Add these to your `.env` file:

```bash
# Prometheus
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION=30d

# Alertmanager
ALERTMANAGER_PORT=9093

# Jaeger
JAEGER_UI_PORT=16686
JAEGER_OTLP_GRPC_PORT=4317
JAEGER_OTLP_HTTP_PORT=4318

# Loki
LOKI_PORT=3100

# Grafana
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin

# Exporters
POSTGRES_EXPORTER_PORT=9187
REDIS_EXPORTER_PORT=9121
NODE_EXPORTER_PORT=9100
```

## Metrics Collection

### Scrape Targets

Prometheus scrapes the following targets:

1. **TimescaleDB**: Database metrics via postgres-exporter
2. **Redis**: Cache metrics via redis-exporter
3. **Node**: System metrics via node-exporter
4. **Collector**: LLM telemetry collection metrics
5. **Storage**: Storage layer performance metrics
6. **API**: REST/GraphQL API metrics
7. **Grafana**: Dashboard metrics
8. **Jaeger**: Tracing system metrics
9. **Loki**: Log aggregation metrics
10. **Prometheus**: Self-monitoring

### Recording Rules

Pre-computed metrics for dashboard performance:

- **Database Performance**: Query rates, rollback rates, connection pool utilization
- **Query Performance**: P50/P95/P99 latencies
- **Redis Performance**: Cache hit rates, memory utilization
- **HTTP Performance**: Request rates, error rates, latencies
- **LLM Metrics**: Token usage, costs, request rates
- **System Resources**: CPU, memory, disk utilization
- **Collector Performance**: Span processing rates
- **Storage Performance**: Write/query throughput and latency

See: `/workspaces/llm-observatory/docker/prometheus/rules/recording_rules.yml`

## Alerting

### Alert Rules

Comprehensive alerting for:

- **Database Availability**: Connection failures, downtime
- **Connection Pool**: Exhaustion, high usage
- **Query Performance**: Slow queries, degradation
- **Application Performance**: Error rates, high latency
- **Resource Utilization**: CPU, memory, disk
- **Cache Performance**: Redis downtime, memory pressure
- **Data Integrity**: Replication lag, deadlocks
- **Backup & Recovery**: Failed backups

See: `/workspaces/llm-observatory/docker/prometheus/alerts/storage_layer_alerts.yml`

### Notification Channels

Configure in `/workspaces/llm-observatory/docker/prometheus/alertmanager.yml`:

- Slack
- PagerDuty
- Email
- Webhook

## Distributed Tracing

### OTLP Integration

Send traces to Jaeger via OTLP:

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

### Sampling Strategies

Configured in `/workspaces/llm-observatory/docker/jaeger/sampling.json`:

- **Collector**: 100% (all OTLP traces)
- **Storage**: 10% (1% for write operations)
- **API**: 10% (50% for GraphQL, 10% for REST)
- **Default**: 0.1% for unknown services

## Log Aggregation

### Log Collection

Promtail collects logs from:

1. Docker container logs (all LLM Observatory services)
2. System logs (`/var/log`)
3. Application-specific log files

### LogQL Queries

Example queries:

```logql
# All errors in the last hour
{service=~".+"} |= "error" | json

# API errors with trace correlation
{service="api"} |= "ERROR" | json | trace_id != ""

# High-latency requests
{service="storage"} | json | duration_ms > 1000

# Group errors by service
sum by (service) (count_over_time({level="error"}[1h]))
```

## Grafana Dashboards

### Pre-provisioned Dashboards

1. **Observability Overview**
   - Service health status
   - Request rates and latencies
   - Error rates
   - Resource utilization

2. **Storage Layer**
   - Database performance
   - Connection pool metrics
   - Query performance
   - Cache hit rates

3. **Database Health**
   - TimescaleDB-specific metrics
   - Table sizes and bloat
   - Lock contention
   - Replication status

4. **Node Exporter**
   - CPU, memory, disk usage
   - Network traffic
   - I/O statistics
   - Load averages

5. **Prometheus Stats**
   - Sample ingestion rates
   - Storage usage
   - Active time series
   - Scrape durations

### Custom Dashboards

Add custom dashboards to:
- `/workspaces/llm-observatory/docker/grafana/dashboards/llm-observatory/`
- `/workspaces/llm-observatory/docker/grafana/dashboards/system/`
- `/workspaces/llm-observatory/docker/grafana/dashboards/infrastructure/`

Dashboards are auto-imported on startup.

## Data Source Configuration

### Prometheus
- URL: `http://prometheus:9090`
- Query timeout: 60s
- Default data source

### Loki
- URL: `http://loki:3100`
- Max lines: 1000
- Trace-to-log correlation enabled

### Jaeger
- URL: `http://jaeger:16686`
- Trace-to-log correlation
- Trace-to-metrics correlation
- Node graph enabled

### TimescaleDB
- URL: `timescaledb:5432`
- Database: `llm_observatory`
- Connection pooling: 5-10 connections

## Best Practices

### 1. Metric Naming

Follow Prometheus naming conventions:
```
component_subsystem_metric_unit{labels}
```

Examples:
- `llm_requests_total{model="gpt-4",provider="openai"}`
- `storage_write_duration_seconds{table="spans"}`
- `db_query_duration_seconds{query_type="select"}`

### 2. Labeling Strategy

- Keep cardinality low (< 10 unique values per label)
- Use recording rules for high-cardinality aggregations
- Avoid user IDs or trace IDs as labels
- Use consistent label names across metrics

### 3. Alert Design

- **Symptom-based**: Alert on user-visible problems
- **Actionable**: Include runbook links
- **Specific**: Clear description and threshold
- **Appropriate severity**: Critical, Warning, Info

### 4. Dashboard Design

- **Single metric per panel**: Easy to understand
- **Consistent time ranges**: Use template variables
- **Annotations**: Mark deployments and incidents
- **Documentation**: Add panel descriptions

### 5. Resource Management

- **Prometheus**: Monitor storage usage, tune retention
- **Jaeger**: Adjust sampling rates based on volume
- **Loki**: Configure log retention policies
- **Grafana**: Limit query time ranges

## Troubleshooting

### Prometheus Not Scraping

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq

# Verify service is exposing metrics
curl http://localhost:9187/metrics  # postgres-exporter

# Check Prometheus logs
docker logs llm-observatory-prometheus
```

### Jaeger Not Receiving Traces

```bash
# Verify OTLP endpoint
curl http://localhost:4318/v1/traces

# Check Jaeger collector logs
docker logs llm-observatory-jaeger

# Test trace submission
curl -X POST http://localhost:14268/api/traces \
  -H 'Content-Type: application/json' \
  -d '{"data": []}'
```

### Loki Not Receiving Logs

```bash
# Check Loki status
curl http://localhost:3100/ready

# Verify Promtail is running
docker logs llm-observatory-promtail

# Check Loki logs
docker logs llm-observatory-loki
```

### Grafana Data Source Issues

```bash
# Test Prometheus connectivity
curl http://prometheus:9090/api/v1/query?query=up

# Test Loki connectivity
curl http://loki:3100/loki/api/v1/labels

# Check Grafana logs
docker logs llm-observatory-grafana
```

## Scaling Considerations

### High-Volume Scenarios

1. **Prometheus**:
   - Use recording rules to pre-compute expensive queries
   - Increase storage capacity
   - Consider Prometheus federation for multi-cluster

2. **Jaeger**:
   - Adjust sampling rates (reduce from 100%)
   - Use tail-based sampling
   - Consider external storage (Cassandra, Elasticsearch)

3. **Loki**:
   - Reduce log retention period
   - Filter verbose logs at source
   - Use object storage (S3) for chunks

4. **Grafana**:
   - Use query caching
   - Limit dashboard auto-refresh rates
   - Use recording rules for complex queries

## Security

### Network Isolation

All services run in isolated Docker network: `llm-observatory-network`

### Authentication

- **Grafana**: Username/password (change default!)
- **Prometheus**: No auth (internal network only)
- **Jaeger**: No auth (internal network only)

### Best Practices

1. Change default Grafana password
2. Restrict port exposure to localhost in production
3. Use reverse proxy with TLS for external access
4. Enable authentication on all services for production
5. Implement network policies to restrict inter-service communication

## Maintenance

### Regular Tasks

1. **Weekly**: Review alerts and adjust thresholds
2. **Monthly**: Check storage usage and retention policies
3. **Quarterly**: Review and optimize dashboard queries
4. **Annually**: Audit and clean up unused metrics/dashboards

### Backup

Persistent volumes to backup:
- `prometheus_data`: Metric data
- `jaeger_data`: Trace data
- `loki_data`: Log data
- `grafana_data`: Dashboards and settings
- `alertmanager_data`: Alert state

```bash
# Backup all observability data
docker run --rm \
  -v llm-observatory-prometheus-data:/source:ro \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/prometheus-$(date +%Y%m%d).tar.gz -C /source .
```

## Performance Tuning

### Prometheus

```yaml
# prometheus.yml
global:
  scrape_interval: 15s      # Increase for lower overhead
  evaluation_interval: 15s

storage:
  tsdb:
    retention.time: 30d     # Reduce for less storage
    wal_compression: true   # Enable compression
```

### Jaeger

```json
// sampling.json
{
  "default_strategy": {
    "type": "probabilistic",
    "param": 0.001  // Sample 0.1% by default
  }
}
```

### Loki

```yaml
# loki-config.yml
limits_config:
  ingestion_rate_mb: 15           # Increase for high volume
  ingestion_burst_size_mb: 30
  max_streams_per_user: 10000     # Tune based on cardinality
```

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [OpenTelemetry Specification](https://opentelemetry.io/docs/)
- [Storage Layer Alerts README](/workspaces/llm-observatory/docker/prometheus/README.md)

## Support

For issues or questions:
- Check service logs: `docker logs <container-name>`
- Review Grafana dashboards for service health
- Check Prometheus targets: http://localhost:9090/targets
- Verify alert rules: http://localhost:9090/alerts

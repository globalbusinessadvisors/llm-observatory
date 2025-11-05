# Grafana Dashboards

This directory contains pre-built Grafana dashboards for monitoring LLM Observatory storage.

## Available Dashboards

### 1. Storage Overview (`storage-overview.json`)

**Purpose**: At-a-glance view of storage performance and health.

**Panels:**
- Write Throughput (ops/sec)
- Write Latency (p95)
- Items Written per Second
- Batch Sizes (p50 and p95)
- Connection Pool Utilization
- Query Latency (p95)
- Error Rate
- Buffer Sizes
- Flush Operations
- Retry Rate
- Query Result Counts (avg)
- Connection Acquisition Time (p95)

**Best For:**
- Daily monitoring
- Performance overview
- Quick health checks
- Capacity planning

### 2. Database Health (`database-health.json`)

**Purpose**: Detailed database health and performance analysis.

**Panels:**
- Connection Pool Health (gauge)
- Write Success Rate (gauge)
- Query Success Rate (gauge)
- Active Connections Over Time
- Error Types Distribution (pie chart)
- Write Operations by Type
- Query Operations by Repository
- Write Latency Distribution (heatmap)
- Query Latency Distribution (heatmap)
- COPY vs INSERT Performance

**Best For:**
- Troubleshooting issues
- Performance analysis
- Understanding error patterns
- Comparing write methods

## Importing Dashboards

### Method 1: Grafana UI

1. Open Grafana (http://localhost:3000)
2. Login (default: admin/admin)
3. Click the "+" icon in the left sidebar
4. Select "Import"
5. Click "Upload JSON file"
6. Select the dashboard JSON file
7. Choose your Prometheus datasource
8. Click "Import"

### Method 2: Provisioning (Recommended for Production)

1. Copy dashboard files to Grafana provisioning directory:
   ```bash
   cp docs/grafana/*.json /etc/grafana/provisioning/dashboards/
   ```

2. Create a dashboard provider configuration:
   ```yaml
   # /etc/grafana/provisioning/dashboards/llm-observatory.yml
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
         path: /etc/grafana/provisioning/dashboards
   ```

3. Restart Grafana

### Method 3: Docker Compose

Dashboards are automatically provisioned when using the monitoring stack:

```bash
docker-compose -f docker/monitoring-stack.yml up -d
```

## Dashboard Variables

Both dashboards support the following variables (if configured):

- **Time Range**: Adjust the time window
- **Refresh Rate**: Auto-refresh interval (default: 10s)

You can add custom variables by editing the dashboard:

```json
{
  "templating": {
    "list": [
      {
        "name": "writer_type",
        "type": "query",
        "datasource": "Prometheus",
        "query": "label_values(storage_writes_total, writer_type)"
      }
    ]
  }
}
```

## Customization

### Adding Panels

1. Open the dashboard
2. Click "Add panel" at the top
3. Configure your query using Prometheus
4. Customize visualization settings
5. Save the dashboard

### Example Queries

**Write Throughput:**
```promql
rate(storage_writes_total{status="success"}[1m])
```

**Pool Utilization:**
```promql
(storage_pool_connections{state="active"} / storage_pool_connections{state="max"}) * 100
```

**Error Rate:**
```promql
rate(storage_errors_total[1m])
```

See [METRICS_REFERENCE.md](../METRICS_REFERENCE.md) for more queries.

## Dashboard Features

### Time Ranges

All panels support flexible time ranges:
- Last 5 minutes
- Last 15 minutes
- Last 1 hour
- Last 6 hours
- Last 24 hours
- Last 7 days
- Custom range

### Auto-Refresh

Dashboards auto-refresh every 10 seconds by default. Change this in the dashboard settings.

### Legends

- **Table Mode**: Shows min, max, avg, current values
- **List Mode**: Shows only series names
- **Hidden**: No legend displayed

### Tooltips

Hover over any panel to see:
- Exact values
- Timestamp
- All series at that point

### Zoom

- Click and drag to zoom into a specific time range
- Double-click to reset zoom

## Threshold Configuration

Panels use color-coded thresholds:

**Green (Good):**
- Pool utilization: <70%
- Success rates: >99%
- Latency: <100ms

**Yellow (Warning):**
- Pool utilization: 70-85%
- Success rates: 95-99%
- Latency: 100-500ms

**Red (Critical):**
- Pool utilization: >85%
- Success rates: <95%
- Latency: >500ms

## Alerting

You can configure alerts directly in Grafana:

1. Edit a panel
2. Click the "Alert" tab
3. Create alert rule
4. Set conditions and thresholds
5. Configure notification channels

Example alert for high error rate:

```
WHEN avg() OF query(A, 5m, now) IS ABOVE 1
SEND TO slack-critical
```

## Annotations

Add annotations to mark important events:

1. Dashboard settings → Annotations
2. Click "New"
3. Configure query or manual annotation
4. Save

Example annotation for deployments:

```promql
# Query deployments from your metrics
deployment_events{service="storage"}
```

## Export and Backup

### Export Dashboard

1. Dashboard settings (gear icon)
2. "JSON Model"
3. Copy JSON
4. Save to version control

### Backup All Dashboards

```bash
# Export all dashboards
curl -u admin:admin http://localhost:3000/api/search?type=dash-db | \
  jq -r '.[] | .uid' | \
  xargs -I {} curl -u admin:admin http://localhost:3000/api/dashboards/uid/{} | \
  jq -r '.dashboard' > backup.json
```

## Troubleshooting

### Dashboard Not Loading

**Issue**: Dashboard shows "No data"

**Solutions:**
1. Check Prometheus datasource connection
2. Verify metrics are being scraped
3. Check time range (metrics might be old)
4. Verify query syntax

### Metrics Missing

**Issue**: Some panels show "No data"

**Solutions:**
1. Ensure storage service is running
2. Check health endpoint: `curl http://localhost:9090/metrics`
3. Verify Prometheus is scraping: http://localhost:9091/targets
4. Check metric names match dashboard queries

### Slow Dashboard

**Issue**: Dashboard takes long to load

**Solutions:**
1. Reduce time range
2. Increase refresh interval
3. Use recording rules for expensive queries
4. Reduce number of series per panel

### Wrong Values

**Issue**: Metrics show unexpected values

**Solutions:**
1. Check time range and timezone
2. Verify query aggregation (rate, sum, avg)
3. Check label filters
4. Verify metric collection is working

## Best Practices

1. **Start with Overview**: Use storage-overview dashboard for daily monitoring
2. **Drill Down**: Use database-health dashboard for detailed analysis
3. **Set Time Range**: Adjust based on what you're investigating
4. **Use Variables**: Create dashboard variables for filtering
5. **Add Annotations**: Mark deployments and incidents
6. **Configure Alerts**: Set up alerts for critical metrics
7. **Regular Backups**: Export dashboards to version control
8. **Document Changes**: Add version notes when updating

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LLM Observatory Monitoring Guide](../MONITORING.md)
- [Metrics Reference](../METRICS_REFERENCE.md)
- [Setup Guide](../MONITORING_SETUP.md)

## Dashboard Maintenance

### Updating Dashboards

1. Make changes in Grafana UI
2. Test changes thoroughly
3. Export updated JSON
4. Update JSON file in this directory
5. Commit to version control

### Version History

Track dashboard versions:

```json
{
  "version": 1,
  "title": "Storage Overview",
  "description": "Initial version"
}
```

Increment version with each change.

## Support

For issues or questions:

1. Check [MONITORING.md](../MONITORING.md) documentation
2. Review [METRICS_REFERENCE.md](../METRICS_REFERENCE.md)
3. Verify Prometheus is collecting metrics
4. Check Grafana logs for errors

## Contributing

When contributing new dashboards:

1. Follow existing naming conventions
2. Use consistent color schemes
3. Add meaningful descriptions
4. Test with real data
5. Document any custom queries
6. Export and commit JSON

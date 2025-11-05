# Getting Started with LLM Observatory Analytics API

This guide will walk you through setting up and using the Analytics API in 15 minutes.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Authentication](#authentication)
4. [Your First Request](#your-first-request)
5. [Common Use Cases](#common-use-cases)
6. [Next Steps](#next-steps)

---

## Prerequisites

Before you begin, ensure you have:

- ✅ An LLM Observatory account
- ✅ API credentials (client ID and secret)
- ✅ `curl` or an HTTP client installed
- ✅ (Optional) Python 3.8+ or Node.js 14+ for SDK usage

---

## Quick Start

### 1. Get Your API Credentials

Log in to your LLM Observatory dashboard and navigate to **Settings → API Keys** to create a new API key pair.

```bash
CLIENT_ID="your_client_id_here"
CLIENT_SECRET="your_client_secret_here"
```

### 2. Get an Access Token

```bash
# Request an access token
curl -X POST https://auth.llm-observatory.io/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "'$CLIENT_ID'",
    "client_secret": "'$CLIENT_SECRET'",
    "grant_type": "client_credentials"
  }' | jq -r '.access_token'
```

Save the token:

```bash
export TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### 3. Test the API

```bash
# Check API health
curl https://api.llm-observatory.io/health

# Get your first traces
curl -H "Authorization: Bearer $TOKEN" \
  https://api.llm-observatory.io/api/v1/traces?limit=5
```

✅ **Success!** You're now connected to the Analytics API.

---

## Authentication

All API requests require a JWT Bearer token in the Authorization header:

```bash
Authorization: Bearer YOUR_JWT_TOKEN
```

### Token Lifecycle

| Property | Value |
|----------|-------|
| **Expiration** | 24 hours |
| **Refresh** | Request new token before expiration |
| **Scope** | Determined by your API key permissions |

### Example: Token Request

```python
import requests

response = requests.post(
    "https://auth.llm-observatory.io/token",
    json={
        "client_id": "your_client_id",
        "client_secret": "your_client_secret",
        "grant_type": "client_credentials"
    }
)

token = response.json()["access_token"]
```

---

## Your First Request

### List Recent Traces

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.llm-observatory.io/api/v1/traces?\
start_time=2025-11-01T00:00:00Z&\
limit=10"
```

**Response:**

```json
{
  "data": [
    {
      "trace_id": "550e8400-e29b-41d4-a716-446655440000",
      "model": "gpt-4",
      "provider": "openai",
      "total_cost_usd": 0.015,
      "duration_ms": 1250,
      "status_code": "200",
      "ts": "2025-11-05T10:30:00Z"
    }
  ],
  "pagination": {
    "total": 15420,
    "limit": 10,
    "offset": 0,
    "has_more": true
  }
}
```

### Filter by Provider

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.llm-observatory.io/api/v1/traces?\
provider=openai&\
model=gpt-4&\
limit=10"
```

### Get Performance Metrics

```bash
curl "https://api.llm-observatory.io/api/v1/metrics/performance?\
start_time=2025-11-01T00:00:00Z&\
granularity=1hour"
```

**Response:**

```json
{
  "request_count": 15420,
  "avg_latency_ms": 850.5,
  "p95_latency_ms": 1800.0,
  "p99_latency_ms": 3200.0,
  "time_series": [...]
}
```

---

## Common Use Cases

### 1. Monitor LLM Costs

Track spending across all LLM providers:

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.llm-observatory.io/api/v1/costs/analytics?\
start_time=2025-11-01T00:00:00Z&\
end_time=2025-11-30T23:59:59Z"
```

**Use Case:** Generate monthly cost reports

```python
import requests
from datetime import datetime, timedelta

# Get costs for current month
start = datetime.now().replace(day=1, hour=0, minute=0, second=0)
end = datetime.now()

response = requests.get(
    "https://api.llm-observatory.io/api/v1/costs/analytics",
    headers={"Authorization": f"Bearer {token}"},
    params={
        "start_time": start.isoformat(),
        "end_time": end.isoformat()
    }
)

costs = response.json()
print(f"Total cost this month: ${costs['total_cost']:.2f}")
print(f"Average per request: ${costs['avg_cost_per_request']:.4f}")
```

---

### 2. Compare Model Performance

Compare GPT-4 vs GPT-3.5-turbo:

```bash
curl "https://api.llm-observatory.io/api/v1/models/compare" \
  -H "Content-Type: application/json" \
  -d '{
    "models": ["gpt-4", "gpt-3.5-turbo"],
    "metrics": ["latency", "cost", "quality"],
    "start_time": "2025-11-01T00:00:00Z",
    "end_time": "2025-11-05T23:59:59Z"
  }'
```

**Result:** Get recommendations on which model to use

---

### 3. Search for Errors

Find all failed requests:

```bash
curl -X POST "https://api.llm-observatory.io/api/v1/traces/search" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "field": "status_code",
      "operator": "in",
      "value": ["500", "502", "503"]
    },
    "limit": 100
  }'
```

**Use Case:** Debug production issues

---

### 4. Export Data

Create an export job for offline analysis:

```bash
curl -X POST "https://api.llm-observatory.io/api/v1/export/traces" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "format": "json",
    "compression": "gzip",
    "start_time": "2025-11-01T00:00:00Z",
    "end_time": "2025-11-30T23:59:59Z",
    "limit": 100000
  }'
```

**Response:**

```json
{
  "job_id": "job_abc123",
  "status": "pending",
  "status_url": "/api/v1/export/jobs/job_abc123"
}
```

Check status:

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.llm-observatory.io/api/v1/export/jobs/job_abc123"
```

Download when complete:

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.llm-observatory.io/api/v1/export/jobs/job_abc123/download" \
  -o traces.json.gz
```

---

### 5. Real-Time Monitoring

Subscribe to live updates via WebSocket:

```javascript
const ws = new WebSocket(
  `wss://api.llm-observatory.io/ws?token=${token}`
);

// Subscribe to events
ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'subscribe',
    events: ['trace_created', 'cost_threshold'],
    filters: {
      provider: 'openai',
      environment: 'production'
    }
  }));
};

// Handle events
ws.onmessage = (event) => {
  const message = JSON.parse(event.data);

  if (message.type === 'event') {
    console.log('New trace:', message.data);

    // Alert if cost exceeds threshold
    if (message.event_type === 'cost_threshold') {
      alert(`Cost threshold exceeded: $${message.data.current_value}`);
    }
  }
};
```

---

## Using SDKs

### Python SDK

```bash
pip install llm-observatory
```

```python
from llm_observatory import AnalyticsClient

client = AnalyticsClient(
    client_id="your_client_id",
    client_secret="your_client_secret"
)

# List traces
traces = client.traces.list(
    provider="openai",
    model="gpt-4",
    limit=10
)

for trace in traces:
    print(f"{trace.model}: ${trace.total_cost_usd:.4f}")

# Get performance metrics
metrics = client.metrics.performance(
    start_time="2025-11-01T00:00:00Z",
    granularity="1hour"
)

print(f"Average latency: {metrics.avg_latency_ms}ms")
print(f"P95 latency: {metrics.p95_latency_ms}ms")

# Compare models
comparison = client.models.compare(
    models=["gpt-4", "gpt-3.5-turbo"],
    metrics=["latency", "cost", "quality"]
)

print(f"Fastest: {comparison.summary.fastest_model}")
print(f"Cheapest: {comparison.summary.cheapest_model}")
```

### JavaScript/TypeScript SDK

```bash
npm install @llm-observatory/sdk
```

```typescript
import { AnalyticsClient } from '@llm-observatory/sdk';

const client = new AnalyticsClient({
  clientId: 'your_client_id',
  clientSecret: 'your_client_secret',
});

// List traces
const traces = await client.traces.list({
  provider: 'openai',
  model: 'gpt-4',
  limit: 10,
});

traces.data.forEach(trace => {
  console.log(`${trace.model}: $${trace.total_cost_usd.toFixed(4)}`);
});

// Get costs
const costs = await client.costs.analytics({
  startTime: '2025-11-01T00:00:00Z',
  endTime: '2025-11-30T23:59:59Z',
});

console.log(`Total cost: $${costs.total_cost.toFixed(2)}`);
```

---

## Rate Limiting

The API enforces rate limits based on your role:

| Role | Requests/Minute | Burst |
|------|----------------|-------|
| Developer | 10,000 | 12,000 |
| Viewer | 1,000 | 1,200 |

### Handling Rate Limits

```python
import time
import requests

def make_request_with_retry(url, headers, max_retries=3):
    for attempt in range(max_retries):
        response = requests.get(url, headers=headers)

        if response.status_code == 429:
            # Rate limited - wait and retry
            retry_after = int(response.headers.get('Retry-After', 60))
            print(f"Rate limited. Retrying in {retry_after}s...")
            time.sleep(retry_after)
            continue

        return response

    raise Exception("Max retries exceeded")
```

### Rate Limit Headers

```http
X-RateLimit-Limit: 10000
X-RateLimit-Remaining: 9950
X-RateLimit-Reset: 1699200000
```

---

## Optimization Tips

### 1. Use Field Selection

Request only the fields you need:

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.llm-observatory.io/api/v1/traces?\
fields=trace_id,model,cost,duration_ms&\
limit=100"
```

**Benefits:**
- Smaller response payloads
- Faster network transfer
- Lower bandwidth costs

### 2. Implement Caching

Use ETags to avoid re-downloading unchanged data:

```python
import requests

# First request
response = requests.get(url, headers=headers)
etag = response.headers.get('ETag')
data = response.json()

# Subsequent request with ETag
response = requests.get(
    url,
    headers={
        **headers,
        'If-None-Match': etag
    }
)

if response.status_code == 304:
    # Use cached data
    print("Using cached data")
else:
    # New data available
    data = response.json()
```

### 3. Use Continuous Aggregates

For time-series queries, use appropriate granularity:

```bash
# For real-time (last hour) - use 1min
granularity=1min

# For daily reports - use 1hour
granularity=1hour

# For monthly reports - use 1day
granularity=1day
```

### 4. Batch Operations

Instead of multiple API calls, use advanced search:

```python
# INEFFICIENT: Multiple requests
for provider in ['openai', 'anthropic', 'google']:
    traces = client.traces.list(provider=provider)

# EFFICIENT: Single search request
traces = client.traces.search({
    'filter': {
        'field': 'provider',
        'operator': 'in',
        'value': ['openai', 'anthropic', 'google']
    }
})
```

---

## Error Handling

All errors follow a standardized format:

```json
{
  "error": {
    "code": 1200,
    "error_code": "INVALID_REQUEST",
    "category": "VALIDATION",
    "message": "Invalid value for field 'limit'",
    "details": "Limit must be between 1 and 1000"
  },
  "meta": {
    "timestamp": "2025-11-05T10:30:00Z",
    "documentation_url": "https://docs.llm-observatory.io/errors/1200"
  }
}
```

### Handling Errors in Python

```python
import requests

try:
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    data = response.json()

except requests.exceptions.HTTPError as e:
    if e.response.status_code == 401:
        print("Authentication failed. Check your token.")
    elif e.response.status_code == 403:
        print("Insufficient permissions.")
    elif e.response.status_code == 429:
        print("Rate limit exceeded. Please wait.")
    elif e.response.status_code == 500:
        print("Server error. Please try again later.")
    else:
        error = e.response.json()
        print(f"Error {error['error']['code']}: {error['error']['message']}")
```

---

## Example: Complete Monitoring Script

Here's a complete example that monitors costs and sends alerts:

```python
#!/usr/bin/env python3
import requests
from datetime import datetime, timedelta
import time

class LLMObservatory:
    def __init__(self, client_id, client_secret):
        self.base_url = "https://api.llm-observatory.io"
        self.token = self.get_token(client_id, client_secret)

    def get_token(self, client_id, client_secret):
        response = requests.post(
            "https://auth.llm-observatory.io/token",
            json={
                "client_id": client_id,
                "client_secret": client_secret,
                "grant_type": "client_credentials"
            }
        )
        return response.json()["access_token"]

    def get_daily_costs(self):
        today = datetime.now().replace(hour=0, minute=0, second=0)
        response = requests.get(
            f"{self.base_url}/api/v1/costs/analytics",
            headers={"Authorization": f"Bearer {self.token}"},
            params={
                "start_time": today.isoformat(),
                "end_time": datetime.now().isoformat()
            }
        )
        return response.json()

    def get_error_rate(self):
        response = requests.get(
            f"{self.base_url}/api/v1/metrics/quality",
            params={
                "start_time": (datetime.now() - timedelta(hours=1)).isoformat()
            }
        )
        return response.json()

    def monitor(self, cost_threshold=100.0, error_threshold=0.05):
        """Monitor costs and error rates"""
        # Check costs
        costs = self.get_daily_costs()
        if costs['total_cost'] > cost_threshold:
            print(f"⚠️  ALERT: Daily cost ${costs['total_cost']:.2f} exceeds threshold ${cost_threshold}")

        # Check error rate
        quality = self.get_error_rate()
        if quality['error_rate'] > error_threshold:
            print(f"⚠️  ALERT: Error rate {quality['error_rate']:.2%} exceeds threshold {error_threshold:.2%}")

        print(f"✅ Monitoring OK - Cost: ${costs['total_cost']:.2f}, Error Rate: {quality['error_rate']:.2%}")

# Run monitoring
if __name__ == "__main__":
    client = LLMObservatory(
        client_id="your_client_id",
        client_secret="your_client_secret"
    )

    while True:
        client.monitor(cost_threshold=100.0, error_threshold=0.05)
        time.sleep(300)  # Check every 5 minutes
```

---

## Next Steps

Now that you've got the basics, explore these advanced features:

1. **[SDK Integration Guide](./SDK_INTEGRATION.md)** - Deep dive into Python, JS, and other SDKs
2. **[API Reference](./API_REFERENCE.md)** - Complete endpoint documentation
3. **[Advanced Filtering](./ADVANCED_FILTERING.md)** - Complex queries and searches
4. **[WebSocket Guide](./WEBSOCKET.md)** - Real-time event streaming
5. **[Deployment Guide](./DEPLOYMENT.md)** - Self-hosting and production deployment
6. **[Performance Guide](../PERFORMANCE_GUIDE.md)** - Optimization strategies

---

## Getting Help

Need assistance?

- **📚 Documentation:** https://docs.llm-observatory.io
- **💬 Community:** https://community.llm-observatory.io
- **🐛 Issues:** https://github.com/llm-observatory/llm-observatory/issues
- **📧 Email:** support@llm-observatory.io

---

## Quick Reference Card

```bash
# Authentication
curl -X POST https://auth.llm-observatory.io/token \
  -H "Content-Type: application/json" \
  -d '{"client_id":"ID","client_secret":"SECRET","grant_type":"client_credentials"}'

# List traces
curl -H "Authorization: Bearer $TOKEN" \
  https://api.llm-observatory.io/api/v1/traces?limit=10

# Performance metrics
curl https://api.llm-observatory.io/api/v1/metrics/performance

# Cost analytics
curl -H "Authorization: Bearer $TOKEN" \
  https://api.llm-observatory.io/api/v1/costs/analytics

# Compare models
curl -X POST https://api.llm-observatory.io/api/v1/models/compare \
  -H "Content-Type: application/json" \
  -d '{"models":["gpt-4","gpt-3.5-turbo"],"metrics":["latency","cost"]}'

# Export data
curl -X POST -H "Authorization: Bearer $TOKEN" \
  https://api.llm-observatory.io/api/v1/export/traces \
  -H "Content-Type: application/json" \
  -d '{"format":"json","compression":"gzip"}'
```

---

**Ready to build?** Start exploring the [API Reference](./API_REFERENCE.md) or jump into [SDK Integration](./SDK_INTEGRATION.md)!

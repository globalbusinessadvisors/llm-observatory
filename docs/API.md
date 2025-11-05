# LLM Observatory - API Reference

**Version:** 1.0  
**Last Updated:** 2025-11-05  
**Base URL:** `http://localhost:8080/api/v1`

## Overview

LLM Observatory provides REST, GraphQL, and WebSocket APIs for accessing telemetry data.

## Authentication

```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "your_password"
}
```

Response includes JWT token for subsequent requests:
```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## REST API Endpoints

### Get Metrics
```http
GET /api/v1/metrics?service=rag-service&from=now-1h&to=now&aggregation=5m
```

### Get Cost Summary
```http
GET /api/v1/costs/summary?period=daily&from=2025-11-01&to=2025-11-05
```

### Search Traces
```http
POST /api/v1/traces/search
{
  "min_duration_ms": 1000,
  "min_cost_usd": 0.01,
  "from": "2025-11-05T00:00:00Z",
  "to": "2025-11-05T23:59:59Z"
}
```

## GraphQL API

Endpoint: `POST /graphql`

Example query:
```graphql
query {
  llmMetrics(service: "rag-service", from: "now-1h", to: "now") {
    timestamp modelName totalCostUsd durationMs
  }
}
```

## Error Codes

- 400: Bad Request
- 401: Unauthorized
- 404: Not Found
- 429: Rate Limit Exceeded
- 500: Internal Server Error

See full documentation in [API.md](./API.md)

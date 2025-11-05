# REST API Implementation Plan - Query Traces and Metrics

**Project:** LLM Observatory
**Feature:** REST API for Querying Traces and Metrics
**Version:** 1.0
**Date:** 2025-11-05
**Status:** Approved for Implementation

---

## Executive Summary

This document provides a comprehensive implementation plan for the REST API that enables querying of traces and metrics in the LLM Observatory platform. This API is a critical component (Item #4 from the original project plan) that will enable users to programmatically access observability data, power the dashboard UI, and support integrations with external tools.

### Objectives

1. **Enable Programmatic Access**: Provide REST API endpoints for querying trace and metric data
2. **Power Dashboard UI**: Backend API for all dashboard visualizations and interactions
3. **Support Integrations**: Enable third-party tools to integrate with LLM Observatory data
4. **Maintain Performance**: Ensure sub-second query response times for most operations
5. **Ensure Security**: Implement proper authentication, authorization, and data privacy controls

### Scope

**In Scope:**
- Trace query endpoints with advanced filtering, search, and pagination
- Metrics query endpoints with time-series aggregation and grouping
- Cost analysis endpoints for financial tracking and attribution
- Export functionality for bulk data extraction
- Real-time updates via WebSocket API
- Authentication and authorization middleware
- Rate limiting and query optimization
- API documentation and client examples

**Out of Scope:**
- Data ingestion APIs (already implemented in storage service)
- Admin/configuration APIs (separate implementation)
- GraphQL API (future enhancement)
- SDK development (separate project)

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Architecture Overview](#2-architecture-overview)
3. [API Endpoint Specifications](#3-api-endpoint-specifications)
4. [Data Models and Schemas](#4-data-models-and-schemas)
5. [Security and Authentication](#5-security-and-authentication)
6. [Performance and Optimization](#6-performance-and-optimization)
7. [Implementation Phases](#7-implementation-phases)
8. [Testing Strategy](#8-testing-strategy)
9. [Deployment Plan](#9-deployment-plan)
10. [Success Metrics](#10-success-metrics)

---

## 1. Current State Analysis

### 1.1 Existing Infrastructure

**Analytics API Service** (Rust/Axum):
- **Location**: `/workspaces/llm-observatory/services/analytics-api/`
- **Status**: ✅ Fully operational
- **Endpoints**: Cost analytics, performance metrics, quality metrics, model comparison
- **Features**: Redis caching, Prometheus metrics, health checks, CORS support

**Storage Layer** (Rust):
- **Location**: `/workspaces/llm-observatory/crates/storage/`
- **Status**: ✅ Production-ready
- **Database**: TimescaleDB (PostgreSQL) with continuous aggregates
- **Features**: Connection pooling, COPY protocol optimization, repository pattern
- **Tables**: `llm_traces`, `llm_metrics`, `llm_logs`
- **Continuous Aggregates**: 1min, 1hour, 1day rollups with automatic refresh

**Data Models** (Rust):
- **Location**: `/workspaces/llm-observatory/crates/core/src/`
- **Status**: ✅ Well-defined
- **Key Types**: `LlmSpan`, `TokenUsage`, `Cost`, `Metadata`, `Provider` enum

### 1.2 Gaps and Requirements

**Missing Functionality:**
1. ❌ **Trace Query API**: No endpoints for listing/searching traces
2. ❌ **Pagination**: No cursor-based pagination implementation
3. ❌ **Advanced Filtering**: Limited filter support with operators
4. ❌ **Field Selection**: Cannot select specific fields to return
5. ❌ **Semantic Search**: No vector similarity search capability
6. ❌ **Export API**: No bulk export functionality
7. ❌ **WebSocket API**: No real-time update mechanism
8. ❌ **Enhanced Rate Limiting**: Basic rate limiting, needs token bucket algorithm
9. ❌ **API Documentation**: No OpenAPI/Swagger documentation

**Existing Strengths to Leverage:**
- ✅ Solid Axum framework with middleware stack
- ✅ Redis caching infrastructure
- ✅ TimescaleDB with optimized continuous aggregates
- ✅ Repository pattern for database access
- ✅ JWT configuration ready
- ✅ Health check and metrics endpoints
- ✅ Docker Compose deployment setup

### 1.3 Technology Stack Confirmation

**Backend:**
- **Language**: Rust
- **Framework**: Axum (async web framework)
- **Database**: TimescaleDB (PostgreSQL extension)
- **Cache**: Redis 7+
- **Authentication**: JWT (JSON Web Tokens)
- **Serialization**: serde_json

**Infrastructure:**
- **Deployment**: Docker Compose (development), Kubernetes (production)
- **Monitoring**: Prometheus + Grafana
- **Tracing**: OpenTelemetry
- **Load Balancing**: Nginx/Traefik

---

## 2. Architecture Overview

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Client Layer                           │
│  (Web Dashboard, CLI Tools, External Integrations)          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway Layer                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Nginx/     │  │  Rate Limit  │  │     CORS     │      │
│  │   Traefik    │  │  Middleware  │  │  Middleware  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            Analytics API Service (Axum/Rust)                 │
│  ┌────────────────────────────────────────────────────┐     │
│  │         Authentication Middleware (JWT)            │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  Existing Routes │  │   New Routes     │                │
│  │  ──────────────  │  │  ──────────────  │                │
│  │  • /analytics/*  │  │  • /traces       │                │
│  │  • /costs/*      │  │  • /traces/:id   │                │
│  │  • /performance  │  │  • /traces/search│                │
│  │  • /quality      │  │  • /metrics      │                │
│  │  • /models/*     │  │  • /metrics/query│                │
│  │                  │  │  • /export/*     │                │
│  └──────────────────┘  └──────────────────┘                │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │              Service Layer                          │     │
│  │  • TraceQueryService                               │     │
│  │  • MetricQueryService                              │     │
│  │  • TimescaleDBService (existing)                   │     │
│  └────────────────────────────────────────────────────┘     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Cache Layer (Redis)                       │
│  • Query result caching                                      │
│  • Rate limit counters                                       │
│  • Session storage                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Storage Layer (Rust Crate)                      │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ TraceRepository  │  │ MetricRepository │                │
│  │ (NEW METHODS)    │  │  (NEW METHODS)   │                │
│  └──────────────────┘  └──────────────────┘                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            TimescaleDB (PostgreSQL)                          │
│  ┌────────────────┐  ┌─────────────────┐                   │
│  │  llm_traces    │  │ Continuous      │                   │
│  │  (hypertable)  │  │ Aggregates      │                   │
│  │                │  │ • llm_metrics_  │                   │
│  │                │  │   1min          │                   │
│  │                │  │ • llm_metrics_  │                   │
│  │                │  │   1hour         │                   │
│  │                │  │ • llm_metrics_  │                   │
│  │                │  │   1day          │                   │
│  └────────────────┘  └─────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Responsibilities

**API Gateway Layer:**
- SSL termination
- Load balancing across API instances
- Global rate limiting (per IP)
- CORS header handling
- Request logging

**Analytics API Service:**
- Request routing and validation
- JWT authentication and authorization
- Per-API-key rate limiting
- Query parsing and validation
- Response formatting and serialization
- Cache management (Redis)
- Error handling and logging

**Service Layer:**
- Business logic implementation
- Query construction and optimization
- Cache key generation
- Data transformation
- Aggregation calculations
- Permission checking

**Storage Layer:**
- Database connection management
- SQL query execution
- Transaction management
- Data mapping (DB ↔ Rust structs)
- Repository pattern implementation

**TimescaleDB:**
- Data persistence
- Time-series optimization
- Continuous aggregate computation
- Index management
- Query execution

### 2.3 Request Flow

**Typical Query Request:**

1. **Client** sends HTTP request: `GET /api/v1/traces?from=now-1h&provider=openai`
2. **API Gateway** validates request, checks IP rate limit, forwards to API service
3. **Auth Middleware** validates JWT token, extracts user context
4. **Rate Limit Middleware** checks per-API-key rate limit
5. **Route Handler** receives request, parses query parameters
6. **Service Layer**:
   - Generates cache key from query parameters
   - Checks Redis cache for existing result
   - If cache miss: queries database via repository
   - If cache hit: returns cached result
7. **Repository Layer**:
   - Constructs SQL query with filters
   - Applies authorization (project access)
   - Executes query on TimescaleDB
   - Maps results to Rust structs
8. **Service Layer**:
   - Transforms data (if needed)
   - Stores result in Redis cache
   - Returns to route handler
9. **Route Handler** serializes response to JSON
10. **Client** receives response with data and metadata

**Performance Targets:**
- **P50 Latency**: < 100ms (cached queries)
- **P95 Latency**: < 500ms (simple database queries)
- **P99 Latency**: < 2000ms (complex aggregations)
- **Timeout**: 30 seconds (configurable)

---

## 3. API Endpoint Specifications

### 3.1 Trace Query Endpoints

#### **GET /api/v1/traces**

**Purpose:** List and filter traces with pagination

**Authentication:** Required (JWT Bearer token)

**Query Parameters:**

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `from` | string | No | Start time (ISO 8601 or relative) | `2025-11-05T00:00:00Z` or `now-1h` |
| `to` | string | No | End time (ISO 8601 or relative) | `2025-11-05T23:59:59Z` or `now` |
| `project_id` | string | No | Filter by project ID | `proj_abc123` |
| `trace_id` | string | No | Filter by trace ID | `trace_xyz789` |
| `provider` | string | No | Filter by provider | `openai` |
| `model` | string | No | Filter by model | `gpt-4` |
| `status` | string | No | Filter by status | `success`, `error`, `pending` |
| `min_duration` | i32 | No | Minimum duration (ms) | `1000` |
| `max_duration` | i32 | No | Maximum duration (ms) | `5000` |
| `min_cost` | f64 | No | Minimum cost (USD) | `0.01` |
| `max_cost` | f64 | No | Maximum cost (USD) | `1.0` |
| `environment` | string | No | Filter by environment | `production` |
| `user_id` | string | No | Filter by user ID | `user_123` |
| `session_id` | string | No | Filter by session ID | `sess_456` |
| `tags` | string | No | Comma-separated tags | `urgent,customer-facing` |
| `search` | string | No | Full-text search query | `error timeout` |
| `cursor` | string | No | Pagination cursor | `eyJpZCI6MTIzfQ==` |
| `limit` | i32 | No | Results per page (default: 50, max: 1000) | `100` |
| `sort_by` | string | No | Field to sort by | `start_time` |
| `sort_order` | string | No | Sort direction | `asc` or `desc` |
| `fields` | string | No | Comma-separated fields to include | `trace_id,cost,duration_ms` |
| `include` | string | No | Related data to include | `children,evaluations` |

**Response (200 OK):**

```json
{
  "status": "success",
  "data": [
    {
      "trace_id": "trace_abc123",
      "span_id": "span_xyz789",
      "parent_span_id": null,
      "project_id": "proj_001",
      "start_time": "2025-11-05T10:30:00Z",
      "end_time": "2025-11-05T10:30:02.456Z",
      "duration_ms": 2456,
      "provider": "openai",
      "model": "gpt-4-turbo",
      "operation_type": "chat",
      "input": {
        "messages": [
          {"role": "user", "content": "Hello!"}
        ],
        "parameters": {
          "temperature": 0.7,
          "max_tokens": 150
        }
      },
      "output": {
        "content": "Hi! How can I help you today?",
        "finish_reason": "stop"
      },
      "usage": {
        "prompt_tokens": 10,
        "completion_tokens": 8,
        "total_tokens": 18
      },
      "cost": {
        "amount": 0.00054,
        "currency": "USD",
        "breakdown": {
          "prompt_cost": 0.0003,
          "completion_cost": 0.00024
        }
      },
      "latency": {
        "total_ms": 2456,
        "first_token_ms": 856,
        "tokens_per_second": 3.26
      },
      "metadata": {
        "environment": "production",
        "user_id": "user_789",
        "session_id": "sess_456",
        "tags": ["customer-support"]
      },
      "status": "success"
    }
  ],
  "pagination": {
    "cursor": "eyJzdGFydF90aW1lIjoiMjAyNS0xMS0wNVQxMDozMDowMFoiLCJpZCI6MTIzfQ==",
    "has_more": true,
    "limit": 50,
    "total": null
  },
  "meta": {
    "timestamp": "2025-11-05T10:35:00Z",
    "execution_time_ms": 45,
    "cached": false,
    "version": "1.0"
  }
}
```

**Error Response (400 Bad Request):**

```json
{
  "status": "error",
  "error": {
    "code": "INVALID_PARAMETER",
    "message": "Invalid value for parameter 'from'",
    "details": "Expected ISO 8601 timestamp or relative time format (e.g., 'now-1h')",
    "field": "from"
  },
  "meta": {
    "timestamp": "2025-11-05T10:35:00Z",
    "request_id": "req_abc123"
  }
}
```

---

#### **GET /api/v1/traces/:trace_id**

**Purpose:** Get a single trace by ID with all spans and details

**Authentication:** Required

**Path Parameters:**
- `trace_id` (string, required): The trace ID to retrieve

**Query Parameters:**
- `include` (string, optional): Comma-separated list of related data to include
  - `children` - Include child spans
  - `evaluations` - Include evaluation results
  - `feedback` - Include user feedback
  - Example: `include=children,evaluations`

**Response (200 OK):**

```json
{
  "status": "success",
  "data": {
    "trace_id": "trace_abc123",
    "project_id": "proj_001",
    "start_time": "2025-11-05T10:30:00Z",
    "end_time": "2025-11-05T10:30:05.234Z",
    "duration_ms": 5234,
    "total_cost": 0.00162,
    "total_tokens": 54,
    "status": "success",
    "spans": [
      {
        "span_id": "span_root",
        "parent_span_id": null,
        "name": "chat_completion",
        "provider": "openai",
        "model": "gpt-4-turbo",
        "start_time": "2025-11-05T10:30:00Z",
        "duration_ms": 5234,
        "input": {...},
        "output": {...},
        "usage": {...},
        "cost": {...},
        "status": "success"
      },
      {
        "span_id": "span_child_1",
        "parent_span_id": "span_root",
        "name": "function_call",
        "start_time": "2025-11-05T10:30:02Z",
        "duration_ms": 1234,
        "status": "success"
      }
    ],
    "evaluations": [
      {
        "evaluator_name": "toxicity_detector",
        "score": 0.02,
        "passed": true,
        "timestamp": "2025-11-05T10:30:06Z"
      }
    ],
    "metadata": {...}
  },
  "meta": {
    "timestamp": "2025-11-05T10:35:00Z",
    "execution_time_ms": 12,
    "cached": true
  }
}
```

**Error Response (404 Not Found):**

```json
{
  "status": "error",
  "error": {
    "code": "TRACE_NOT_FOUND",
    "message": "Trace with ID 'trace_abc123' not found",
    "details": "The trace may have been deleted or you may not have access to it"
  },
  "meta": {
    "timestamp": "2025-11-05T10:35:00Z",
    "request_id": "req_def456"
  }
}
```

---

#### **POST /api/v1/traces/search**

**Purpose:** Advanced trace search with complex filters and full-text search

**Authentication:** Required

**Request Body:**

```json
{
  "filters": {
    "and": [
      {
        "field": "cost.amount",
        "operator": "gte",
        "value": 0.01
      },
      {
        "field": "duration_ms",
        "operator": "between",
        "value": [1000, 5000]
      },
      {
        "or": [
          {
            "field": "provider",
            "operator": "eq",
            "value": "openai"
          },
          {
            "field": "provider",
            "operator": "eq",
            "value": "anthropic"
          }
        ]
      }
    ]
  },
  "search": {
    "query": "timeout error",
    "fields": ["input.prompt", "output.content", "error.message"],
    "operator": "and"
  },
  "time_range": {
    "from": "2025-11-01T00:00:00Z",
    "to": "2025-11-05T23:59:59Z"
  },
  "sort": [
    {
      "field": "cost.amount",
      "order": "desc"
    }
  ],
  "pagination": {
    "cursor": null,
    "limit": 100
  },
  "include": ["evaluations"]
}
```

**Filter Operators:**
- `eq` - Equal
- `ne` - Not equal
- `gt` - Greater than
- `gte` - Greater than or equal
- `lt` - Less than
- `lte` - Less than or equal
- `in` - In array
- `nin` - Not in array
- `contains` - String contains (case-insensitive)
- `startsWith` - String starts with
- `endsWith` - String ends with
- `regex` - Regular expression match
- `exists` - Field exists (value: true/false)
- `between` - Between two values (value: [min, max])

**Response:** Same format as `GET /api/v1/traces`

---

### 3.2 Metrics Query Endpoints

#### **GET /api/v1/metrics**

**Purpose:** Query time-series metrics with aggregation

**Authentication:** Required

**Query Parameters:**

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `from` | string | Yes | Start time | `now-24h` |
| `to` | string | Yes | End time | `now` |
| `metrics` | string | Yes | Comma-separated metric names | `request_count,latency` |
| `project_id` | string | No | Filter by project | `proj_001` |
| `provider` | string | No | Filter by provider | `openai` |
| `model` | string | No | Filter by model | `gpt-4` |
| `environment` | string | No | Filter by environment | `production` |
| `interval` | string | No | Time bucket size | `1m`, `5m`, `1h`, `1d` |
| `aggregation` | string | No | Aggregation function | `avg`, `sum`, `p95` |
| `group_by` | string | No | Dimensions to group by | `provider,model` |
| `fill_gaps` | bool | No | Fill missing time buckets | `true` |
| `fill_value` | string | No | Value for gaps | `0`, `previous`, `interpolate` |

**Metric Names:**
- `request_count` - Total number of requests
- `token_usage` - Total tokens consumed
- `prompt_tokens` - Prompt tokens only
- `completion_tokens` - Completion tokens only
- `cost_usd` - Total cost in USD
- `latency` - Request latency (ms)
- `time_to_first_token` - TTFT (ms)
- `tokens_per_second` - Throughput
- `error_rate` - Error rate (percentage)
- `success_rate` - Success rate (percentage)

**Response (200 OK):**

```json
{
  "status": "success",
  "data": {
    "metrics": {
      "request_count": {
        "timestamps": [
          1730790000000,
          1730790060000,
          1730790120000
        ],
        "values": [45, 52, 48],
        "unit": "requests",
        "aggregation": "sum"
      },
      "latency": {
        "timestamps": [
          1730790000000,
          1730790060000,
          1730790120000
        ],
        "values": [1234, 1456, 1123],
        "unit": "ms",
        "aggregation": "avg"
      }
    },
    "interval": "1m",
    "time_range": {
      "from": "2025-11-05T00:00:00Z",
      "to": "2025-11-05T23:59:59Z"
    }
  },
  "meta": {
    "timestamp": "2025-11-05T10:35:00Z",
    "execution_time_ms": 78,
    "data_points": 1440,
    "cached": true
  }
}
```

---

#### **GET /api/v1/metrics/summary**

**Purpose:** Get aggregated summary statistics for a time range

**Authentication:** Required

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `from` | string | Yes | Start time |
| `to` | string | Yes | End time |
| `project_id` | string | No | Filter by project |
| `provider` | string | No | Filter by provider |
| `model` | string | No | Filter by model |
| `environment` | string | No | Filter by environment |
| `compare_previous` | bool | No | Include previous period comparison |

**Response (200 OK):**

```json
{
  "status": "success",
  "data": {
    "request_count": 12543,
    "total_cost": {
      "amount": 34.56,
      "currency": "USD",
      "by_provider": [
        {"provider": "openai", "amount": 28.34, "percentage": 81.98},
        {"provider": "anthropic", "amount": 6.22, "percentage": 18.02}
      ],
      "by_model": [
        {"model": "gpt-4-turbo", "amount": 20.11, "percentage": 58.19},
        {"model": "gpt-3.5-turbo", "amount": 8.23, "percentage": 23.81},
        {"model": "claude-3-opus", "amount": 6.22, "percentage": 18.00}
      ]
    },
    "tokens": {
      "total": 1543267,
      "prompt": 856432,
      "completion": 686835
    },
    "latency": {
      "avg": 1234,
      "p50": 987,
      "p95": 2345,
      "p99": 4567,
      "min": 234,
      "max": 8901
    },
    "errors": {
      "count": 45,
      "rate": 0.36,
      "by_type": [
        {"type": "rate_limit", "count": 23},
        {"type": "timeout", "count": 12},
        {"type": "invalid_request", "count": 10}
      ]
    },
    "quality": {
      "avg_evaluation_score": 0.87,
      "pass_rate": 94.5,
      "avg_feedback_rating": 4.2
    }
  },
  "comparison": {
    "previous_period": {
      "request_count": 11234,
      "total_cost": 31.45,
      "error_rate": 0.42
    },
    "change": {
      "request_count": {
        "absolute": 1309,
        "percentage": 11.65
      },
      "total_cost": {
        "absolute": 3.11,
        "percentage": 9.89
      },
      "error_rate": {
        "absolute": -0.06,
        "percentage": -14.29
      }
    }
  },
  "meta": {
    "timestamp": "2025-11-05T10:35:00Z",
    "time_range": {
      "from": "2025-11-01T00:00:00Z",
      "to": "2025-11-05T23:59:59Z"
    },
    "execution_time_ms": 156
  }
}
```

---

#### **POST /api/v1/metrics/query**

**Purpose:** Custom metric queries with complex aggregations and grouping

**Authentication:** Required

**Request Body:**

```json
{
  "time_range": {
    "from": "2025-11-01T00:00:00Z",
    "to": "2025-11-05T23:59:59Z"
  },
  "metrics": [
    {
      "name": "cost_usd",
      "aggregation": "sum",
      "alias": "total_cost"
    },
    {
      "name": "latency",
      "aggregation": "p95",
      "alias": "p95_latency"
    },
    {
      "name": "request_count",
      "aggregation": "count",
      "alias": "requests"
    }
  ],
  "filters": {
    "provider": ["openai", "anthropic"],
    "environment": "production",
    "status": "success"
  },
  "group_by": ["provider", "model"],
  "having": [
    {
      "metric": "total_cost",
      "operator": "gt",
      "value": 1.0
    }
  ],
  "order_by": [
    {
      "metric": "total_cost",
      "order": "desc"
    }
  ],
  "limit": 10
}
```

**Response (200 OK):**

```json
{
  "status": "success",
  "data": {
    "results": [
      {
        "dimensions": {
          "provider": "openai",
          "model": "gpt-4-turbo"
        },
        "metrics": {
          "total_cost": 20.11,
          "p95_latency": 2345,
          "requests": 5432
        }
      },
      {
        "dimensions": {
          "provider": "openai",
          "model": "gpt-3.5-turbo"
        },
        "metrics": {
          "total_cost": 8.23,
          "p95_latency": 1234,
          "requests": 6789
        }
      },
      {
        "dimensions": {
          "provider": "anthropic",
          "model": "claude-3-opus"
        },
        "metrics": {
          "total_cost": 6.22,
          "p95_latency": 1876,
          "requests": 322
        }
      }
    ],
    "total_results": 3
  },
  "meta": {
    "timestamp": "2025-11-05T10:35:00Z",
    "execution_time_ms": 234
  }
}
```

---

### 3.3 Cost Analysis Endpoints

#### **GET /api/v1/costs/summary**

**Purpose:** Get cost summary with breakdowns

**Authentication:** Required

**Query Parameters:**
- `from` (string, required): Start time
- `to` (string, required): End time
- `project_id` (string, optional): Filter by project
- `group_by` (string, optional): Grouping dimension (`provider`, `model`, `user`, `tag`)
- `period` (string, optional): Time period for trend (`hourly`, `daily`, `weekly`, `monthly`)

**Response:** See example in section 3.2 `/api/v1/metrics/summary`

---

#### **GET /api/v1/costs/attribution**

**Purpose:** Detailed cost attribution by user, team, tag, etc.

**Authentication:** Required

**Query Parameters:**
- `from` (string, required): Start time
- `to` (string, required): End time
- `project_id` (string, optional): Filter by project
- `attribute_by` (string, required): Attribution dimension (`user`, `team`, `department`, `tag`)
- `limit` (i32, optional): Number of top results (default: 50)

**Response (200 OK):**

```json
{
  "status": "success",
  "data": {
    "total_cost": 34.56,
    "attribution": [
      {
        "dimension": "user_123",
        "cost": 12.34,
        "percentage": 35.70,
        "requests": 4567,
        "tokens": 543210,
        "avg_cost_per_request": 0.0027
      },
      {
        "dimension": "user_456",
        "cost": 8.91,
        "percentage": 25.78,
        "requests": 3214,
        "tokens": 398765,
        "avg_cost_per_request": 0.0028
      }
    ],
    "top_expensive_traces": [
      {
        "trace_id": "trace_xyz789",
        "cost": 2.34,
        "timestamp": "2025-11-05T10:30:00Z",
        "user": "user_123",
        "model": "gpt-4-turbo"
      }
    ]
  },
  "meta": {
    "timestamp": "2025-11-05T10:35:00Z",
    "time_range": {
      "from": "2025-11-01T00:00:00Z",
      "to": "2025-11-05T23:59:59Z"
    }
  }
}
```

---

### 3.4 Export Endpoints

#### **POST /api/v1/export/traces**

**Purpose:** Export filtered traces to various formats

**Authentication:** Required

**Request Body:**

```json
{
  "filters": {
    "from": "2025-11-01T00:00:00Z",
    "to": "2025-11-05T23:59:59Z",
    "provider": "openai",
    "status": "success"
  },
  "format": "csv",
  "compression": "gzip",
  "fields": [
    "trace_id",
    "start_time",
    "provider",
    "model",
    "cost.amount",
    "usage.total_tokens",
    "duration_ms"
  ],
  "limit": 100000
}
```

**Supported Formats:**
- `json` - JSON array
- `jsonl` - JSON Lines (one object per line)
- `csv` - Comma-separated values

**Supported Compression:**
- `none` - No compression
- `gzip` - Gzip compression
- `zip` - Zip archive

**Response (202 Accepted):**

For large exports, return a job ID:

```json
{
  "status": "success",
  "data": {
    "job_id": "export_abc123",
    "status": "processing",
    "estimated_completion": "2025-11-05T10:40:00Z"
  },
  "meta": {
    "timestamp": "2025-11-05T10:35:00Z"
  }
}
```

**Check Export Status:**

```
GET /api/v1/export/jobs/:job_id
```

**Response when complete:**

```json
{
  "status": "success",
  "data": {
    "job_id": "export_abc123",
    "status": "completed",
    "download_url": "https://api.example.com/downloads/export_abc123.csv.gz",
    "expires_at": "2025-11-06T10:35:00Z",
    "file_size_bytes": 1234567,
    "record_count": 50000
  }
}
```

---

### 3.5 WebSocket API (Real-time Updates)

#### **WebSocket Connection**

**Endpoint:** `ws://api.example.com/api/v1/stream`

**Authentication:** JWT token in query parameter or first message

**Connection:**

```javascript
const ws = new WebSocket('ws://api.example.com/api/v1/stream?token=JWT_TOKEN');
```

**Subscribe to Trace Updates:**

```json
{
  "action": "subscribe",
  "channel": "traces",
  "filters": {
    "project_id": "proj_001",
    "provider": "openai"
  }
}
```

**Server Response (Subscription Confirmation):**

```json
{
  "type": "subscription_confirmed",
  "channel": "traces",
  "subscription_id": "sub_abc123"
}
```

**Real-time Event (New Trace):**

```json
{
  "type": "trace_created",
  "channel": "traces",
  "data": {
    "trace_id": "trace_new123",
    "provider": "openai",
    "model": "gpt-4-turbo",
    "cost": 0.00054,
    "duration_ms": 2456,
    "status": "success",
    "timestamp": "2025-11-05T10:35:30Z"
  }
}
```

**Unsubscribe:**

```json
{
  "action": "unsubscribe",
  "subscription_id": "sub_abc123"
}
```

**Event Types:**
- `trace_created` - New trace added
- `trace_updated` - Trace modified (evaluation added, feedback added)
- `metric_threshold_exceeded` - Metric exceeds threshold
- `alert_triggered` - Alert condition met
- `cost_alert` - Cost threshold exceeded

---

## 4. Data Models and Schemas

### 4.1 Core Data Models (Rust)

**Trace Model:**

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Trace {
    // Identifiers
    pub trace_id: Uuid,
    pub span_id: Uuid,
    pub parent_span_id: Option<Uuid>,
    pub project_id: String,

    // Timestamps
    pub start_time: DateTime<Utc>,
    pub end_time: Option<DateTime<Utc>>,
    pub duration_ms: Option<i32>,

    // Provider details
    pub provider: Provider,
    pub model: String,
    pub operation_type: OperationType,

    // Input/Output
    pub input: TraceInput,
    pub output: Option<TraceOutput>,

    // Metrics
    pub usage: TokenUsage,
    pub cost: Cost,
    pub latency: Latency,

    // Context
    pub metadata: Metadata,

    // Quality
    pub evaluations: Option<Vec<Evaluation>>,
    pub feedback: Option<Feedback>,

    // Status
    pub status: TraceStatus,
    pub redacted: bool,

    // Audit
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Provider {
    OpenAI,
    Anthropic,
    Google,
    Mistral,
    Cohere,
    SelfHosted,
    Custom(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum OperationType {
    Completion,
    Chat,
    Embedding,
    FineTune,
    Moderation,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceInput {
    pub prompt: Option<String>,
    pub messages: Option<Vec<Message>>,
    pub system_prompt: Option<String>,
    pub parameters: HashMap<String, serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceOutput {
    pub content: Option<String>,
    pub messages: Option<Vec<Message>>,
    pub finish_reason: Option<String>,
    pub error: Option<ErrorDetails>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub role: MessageRole,
    pub content: String,
    pub name: Option<String>,
    pub function_call: Option<FunctionCall>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MessageRole {
    System,
    User,
    Assistant,
    Function,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenUsage {
    pub prompt_tokens: u32,
    pub completion_tokens: u32,
    pub total_tokens: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Cost {
    pub amount: f64,
    pub currency: String,
    pub breakdown: CostBreakdown,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CostBreakdown {
    pub prompt_cost: f64,
    pub completion_cost: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Latency {
    pub total_ms: i32,
    pub first_token_ms: Option<i32>,
    pub tokens_per_second: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Metadata {
    pub environment: Option<String>,
    pub version: Option<String>,
    pub user_id: Option<String>,
    pub session_id: Option<String>,
    pub tags: Vec<String>,
    pub attributes: HashMap<String, serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Evaluation {
    pub evaluator_name: String,
    pub score: f64,
    pub passed: bool,
    pub details: Option<serde_json::Value>,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Feedback {
    pub rating: Option<f64>,
    pub comment: Option<String>,
    pub user_id: Option<String>,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum TraceStatus {
    Success,
    Error,
    Pending,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorDetails {
    pub code: String,
    pub message: String,
    pub stack: Option<String>,
}
```

---

**Query Filter Models:**

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceFilters {
    // Time range
    pub from: Option<DateTime<Utc>>,
    pub to: Option<DateTime<Utc>>,

    // Identifiers
    pub trace_id: Option<String>,
    pub project_id: Option<String>,
    pub session_id: Option<String>,
    pub user_id: Option<String>,

    // Provider/Model
    pub provider: Option<Vec<String>>,
    pub model: Option<Vec<String>>,
    pub operation_type: Option<String>,

    // Performance
    pub min_duration: Option<i32>,
    pub max_duration: Option<i32>,
    pub min_cost: Option<f64>,
    pub max_cost: Option<f64>,
    pub min_tokens: Option<u32>,
    pub max_tokens: Option<u32>,

    // Status
    pub status: Option<TraceStatus>,
    pub finish_reason: Option<String>,

    // Metadata
    pub environment: Option<String>,
    pub version: Option<String>,
    pub tags: Option<Vec<String>>,

    // Search
    pub search: Option<String>,

    // Pagination
    pub cursor: Option<String>,
    pub limit: Option<i32>,

    // Sorting
    pub sort_by: Option<String>,
    pub sort_order: Option<SortOrder>,

    // Field selection
    pub fields: Option<Vec<String>>,
    pub include: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SortOrder {
    Asc,
    Desc,
}

impl Default for SortOrder {
    fn default() -> Self {
        SortOrder::Desc
    }
}

impl Default for TraceFilters {
    fn default() -> Self {
        Self {
            from: None,
            to: None,
            trace_id: None,
            project_id: None,
            session_id: None,
            user_id: None,
            provider: None,
            model: None,
            operation_type: None,
            min_duration: None,
            max_duration: None,
            min_cost: None,
            max_cost: None,
            min_tokens: None,
            max_tokens: None,
            status: None,
            finish_reason: None,
            environment: None,
            version: None,
            tags: None,
            search: None,
            cursor: None,
            limit: Some(50),
            sort_by: Some("start_time".to_string()),
            sort_order: Some(SortOrder::Desc),
            fields: None,
            include: None,
        }
    }
}
```

---

**Response Models:**

```rust
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiResponse<T> {
    pub status: ResponseStatus,
    pub data: Option<T>,
    pub error: Option<ApiError>,
    pub meta: ResponseMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ResponseStatus {
    Success,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginatedResponse<T> {
    pub status: ResponseStatus,
    pub data: Vec<T>,
    pub pagination: PaginationMetadata,
    pub meta: ResponseMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginationMetadata {
    pub cursor: Option<String>,
    pub has_more: bool,
    pub limit: i32,
    pub total: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResponseMetadata {
    pub timestamp: DateTime<Utc>,
    pub execution_time_ms: u64,
    pub cached: bool,
    pub version: String,
    pub request_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiError {
    pub code: String,
    pub message: String,
    pub details: Option<String>,
    pub field: Option<String>,
}
```

---

### 4.2 Database Schema

**Existing Tables (from current implementation):**

```sql
-- Main traces table (TimescaleDB hypertable)
CREATE TABLE llm_traces (
    -- Primary key
    ts TIMESTAMPTZ NOT NULL,
    trace_id TEXT NOT NULL,
    span_id TEXT NOT NULL,

    -- Parent relationship
    parent_span_id TEXT,

    -- Identity
    service_name TEXT,
    span_name TEXT,

    -- LLM-specific fields
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    input_text TEXT,
    output_text TEXT,

    -- Token usage
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    total_tokens INTEGER,

    -- Cost
    prompt_cost_usd DOUBLE PRECISION,
    completion_cost_usd DOUBLE PRECISION,
    total_cost_usd DOUBLE PRECISION,

    -- Performance
    duration_ms INTEGER,
    ttft_ms INTEGER, -- Time to first token

    -- Status
    status_code TEXT,
    error_message TEXT,

    -- Metadata (JSONB for flexibility)
    user_id TEXT,
    session_id TEXT,
    environment TEXT,
    tags TEXT[],
    attributes JSONB,

    -- Primary key constraint
    PRIMARY KEY (ts, trace_id, span_id)
);

-- Convert to hypertable (TimescaleDB)
SELECT create_hypertable('llm_traces', 'ts',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- Indexes for common queries
CREATE INDEX idx_llm_traces_trace_id ON llm_traces(trace_id, ts DESC);
CREATE INDEX idx_llm_traces_provider_model ON llm_traces(provider, model, ts DESC);
CREATE INDEX idx_llm_traces_user_id ON llm_traces(user_id, ts DESC) WHERE user_id IS NOT NULL;
CREATE INDEX idx_llm_traces_session_id ON llm_traces(session_id, ts DESC) WHERE session_id IS NOT NULL;
CREATE INDEX idx_llm_traces_status ON llm_traces(status_code, ts DESC);
CREATE INDEX idx_llm_traces_environment ON llm_traces(environment, ts DESC) WHERE environment IS NOT NULL;
CREATE INDEX idx_llm_traces_cost ON llm_traces(total_cost_usd DESC, ts DESC) WHERE total_cost_usd IS NOT NULL;
CREATE INDEX idx_llm_traces_duration ON llm_traces(duration_ms DESC, ts DESC) WHERE duration_ms IS NOT NULL;

-- GIN index for JSONB attributes
CREATE INDEX idx_llm_traces_attributes ON llm_traces USING GIN(attributes);

-- Full-text search index
CREATE INDEX idx_llm_traces_input_text ON llm_traces USING GIN(to_tsvector('english', input_text));
CREATE INDEX idx_llm_traces_output_text ON llm_traces USING GIN(to_tsvector('english', output_text));
```

**Continuous Aggregates (existing):**

```sql
-- 1-minute aggregates (real-time monitoring)
CREATE MATERIALIZED VIEW llm_metrics_1min
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 minute', ts) AS bucket,
    provider,
    model,
    environment,
    COUNT(*) AS request_count,
    SUM(total_tokens) AS total_tokens,
    SUM(prompt_tokens) AS prompt_tokens,
    SUM(completion_tokens) AS completion_tokens,
    SUM(total_cost_usd) AS total_cost_usd,
    AVG(duration_ms) AS avg_duration_ms,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY duration_ms) AS p50_duration_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms) AS p95_duration_ms,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY duration_ms) AS p99_duration_ms,
    MIN(duration_ms) AS min_duration_ms,
    MAX(duration_ms) AS max_duration_ms,
    COUNT(*) FILTER (WHERE status_code != 'OK') AS error_count
FROM llm_traces
GROUP BY bucket, provider, model, environment;

-- Refresh policy: every 30 seconds
SELECT add_continuous_aggregate_policy('llm_metrics_1min',
    start_offset => INTERVAL '1 hour',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '30 seconds'
);

-- 1-hour aggregates (recent history)
CREATE MATERIALIZED VIEW llm_metrics_1hour
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', ts) AS bucket,
    provider,
    model,
    environment,
    user_id,
    COUNT(*) AS request_count,
    SUM(total_tokens) AS total_tokens,
    SUM(total_cost_usd) AS total_cost_usd,
    AVG(duration_ms) AS avg_duration_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms) AS p95_duration_ms,
    COUNT(*) FILTER (WHERE status_code != 'OK') AS error_count,
    COUNT(DISTINCT session_id) AS unique_sessions
FROM llm_traces
GROUP BY bucket, provider, model, environment, user_id;

-- Refresh policy: every 5 minutes
SELECT add_continuous_aggregate_policy('llm_metrics_1hour',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '5 minutes'
);

-- 1-day aggregates (long-term trends)
CREATE MATERIALIZED VIEW llm_metrics_1day
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', ts) AS bucket,
    provider,
    model,
    environment,
    COUNT(*) AS request_count,
    SUM(total_tokens) AS total_tokens,
    SUM(total_cost_usd) AS total_cost_usd,
    AVG(duration_ms) AS avg_duration_ms,
    COUNT(*) FILTER (WHERE status_code != 'OK') AS error_count,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(DISTINCT session_id) AS unique_sessions
FROM llm_traces
GROUP BY bucket, provider, model, environment;

-- Refresh policy: every 1 hour
SELECT add_continuous_aggregate_policy('llm_metrics_1day',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 hour'
);
```

---

## 5. Security and Authentication

### 5.1 Authentication Mechanisms

**JWT (JSON Web Tokens):**

**Token Structure:**
```json
{
  "sub": "user_abc123",
  "org_id": "org_xyz789",
  "projects": ["proj_001", "proj_002"],
  "role": "developer",
  "permissions": ["read:traces", "read:metrics", "write:feedback"],
  "iat": 1699200000,
  "exp": 1699203600
}
```

**Token Validation Flow:**

1. Client includes token in `Authorization` header:
   ```
   Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

2. API middleware extracts and validates token:
   ```rust
   use jsonwebtoken::{decode, DecodingKey, Validation};

   pub async fn validate_jwt(
       headers: &HeaderMap,
       jwt_secret: &str,
   ) -> Result<Claims, AuthError> {
       let auth_header = headers
           .get("Authorization")
           .ok_or(AuthError::MissingToken)?
           .to_str()
           .map_err(|_| AuthError::InvalidToken)?;

       let token = auth_header
           .strip_prefix("Bearer ")
           .ok_or(AuthError::InvalidToken)?;

       let token_data = decode::<Claims>(
           token,
           &DecodingKey::from_secret(jwt_secret.as_ref()),
           &Validation::default(),
       )
       .map_err(|_| AuthError::InvalidToken)?;

       Ok(token_data.claims)
   }
   ```

3. Extract user context for authorization:
   ```rust
   pub struct UserContext {
       pub user_id: String,
       pub org_id: String,
       pub projects: Vec<String>,
       pub role: Role,
       pub permissions: Vec<String>,
   }
   ```

---

**API Keys (Alternative/Complementary):**

**Use Cases:**
- Programmatic access from scripts/services
- SDK authentication
- Long-lived access without interactive login

**Key Format:**
```
llmo_sk_live_abc123def456ghi789...
llmo_sk_test_xyz789abc123def456...

Prefix format: llmo_<type>_<env>_<random>
- llmo = LLM Observatory
- sk = Secret Key
- live/test = Environment
- random = 32+ character random string
```

**Storage:**
```sql
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key_hash TEXT NOT NULL UNIQUE,
    key_prefix TEXT NOT NULL, -- First 8 chars for identification
    name TEXT NOT NULL,
    user_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    projects TEXT[] NOT NULL,
    permissions TEXT[] NOT NULL,
    rate_limit_tier TEXT NOT NULL DEFAULT 'standard',
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_api_keys_key_hash ON api_keys(key_hash);
CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);
```

**Validation:**
```rust
pub async fn validate_api_key(
    key: &str,
    db: &PgPool,
) -> Result<ApiKeyContext, AuthError> {
    let key_hash = hash_api_key(key);

    let api_key = sqlx::query_as::<_, ApiKey>(
        r#"
        UPDATE api_keys
        SET last_used_at = NOW()
        WHERE key_hash = $1
          AND (expires_at IS NULL OR expires_at > NOW())
          AND revoked_at IS NULL
        RETURNING *
        "#
    )
    .bind(&key_hash)
    .fetch_optional(db)
    .await?
    .ok_or(AuthError::InvalidApiKey)?;

    Ok(ApiKeyContext {
        user_id: api_key.user_id,
        org_id: api_key.org_id,
        projects: api_key.projects,
        permissions: api_key.permissions,
        rate_limit_tier: api_key.rate_limit_tier,
    })
}
```

---

### 5.2 Authorization (RBAC)

**Roles:**

| Role | Permissions | Description |
|------|-------------|-------------|
| `admin` | All permissions | Full access to all resources |
| `developer` | `read:*`, `write:feedback`, `write:evaluations` | Read all data, write feedback/evaluations |
| `viewer` | `read:traces`, `read:metrics`, `read:costs` | Read-only access to data |
| `billing` | `read:costs`, `read:usage` | Access to cost/usage data only |

**Permission Checks:**

```rust
pub fn check_permission(
    user: &UserContext,
    required_permission: &str,
) -> Result<(), AuthError> {
    if user.role == Role::Admin {
        return Ok(());
    }

    if user.permissions.contains(&required_permission.to_string()) {
        Ok(())
    } else {
        Err(AuthError::InsufficientPermissions)
    }
}
```

**Project-Level Authorization:**

```rust
pub async fn enforce_project_access(
    user: &UserContext,
    project_id: &str,
) -> Result<(), AuthError> {
    if user.role == Role::Admin {
        return Ok(());
    }

    if user.projects.contains(&project_id.to_string()) {
        Ok(())
    } else {
        Err(AuthError::ProjectAccessDenied)
    }
}
```

**Query-Level Filtering:**

All queries automatically scoped to user's accessible projects:

```rust
pub async fn list_traces(
    user: &UserContext,
    filters: TraceFilters,
) -> Result<Vec<Trace>> {
    let mut query_filters = filters;

    // Enforce project access
    if user.role != Role::Admin {
        let accessible_project = query_filters.project_id
            .filter(|p| user.projects.contains(p))
            .or_else(|| user.projects.first().cloned());

        query_filters.project_id = accessible_project;
    }

    // Execute query with enforced filters
    trace_repository.list(query_filters).await
}
```

---

### 5.3 Rate Limiting

**Token Bucket Algorithm:**

```rust
use std::time::{Duration, Instant};

pub struct TokenBucket {
    capacity: u32,
    tokens: f64,
    refill_rate: f64, // Tokens per second
    last_refill: Instant,
}

impl TokenBucket {
    pub fn new(capacity: u32, refill_rate: f64) -> Self {
        Self {
            capacity,
            tokens: capacity as f64,
            refill_rate,
            last_refill: Instant::now(),
        }
    }

    pub fn try_consume(&mut self, tokens: u32) -> bool {
        self.refill();

        if self.tokens >= tokens as f64 {
            self.tokens -= tokens as f64;
            true
        } else {
            false
        }
    }

    fn refill(&mut self) {
        let now = Instant::now();
        let elapsed = now.duration_since(self.last_refill).as_secs_f64();

        self.tokens = (self.tokens + elapsed * self.refill_rate)
            .min(self.capacity as f64);

        self.last_refill = now;
    }
}
```

**Rate Limit Tiers:**

| Tier | Requests/minute | Burst Capacity | Use Case |
|------|-----------------|----------------|----------|
| `basic` | 100 | 120 | Free/trial users |
| `standard` | 1,000 | 1,200 | Standard users |
| `premium` | 10,000 | 12,000 | Premium users |
| `enterprise` | 100,000 | 120,000 | Enterprise users |

**Redis-Backed Rate Limiting:**

```rust
use redis::aio::ConnectionManager;

pub async fn check_rate_limit(
    redis: &mut ConnectionManager,
    key: &str,
    tier: &str,
) -> Result<bool, RedisError> {
    let limits = match tier {
        "basic" => (100, 60),
        "standard" => (1000, 60),
        "premium" => (10000, 60),
        "enterprise" => (100000, 60),
        _ => (100, 60),
    };

    let (limit, window) = limits;
    let count: u32 = redis::cmd("INCR")
        .arg(key)
        .query_async(redis)
        .await?;

    if count == 1 {
        redis::cmd("EXPIRE")
            .arg(key)
            .arg(window)
            .query_async::<_, ()>(redis)
            .await?;
    }

    Ok(count <= limit)
}
```

**Rate Limit Headers:**

```rust
pub fn add_rate_limit_headers(
    response: &mut Response,
    limit: u32,
    remaining: u32,
    reset: u64,
) {
    response.headers_mut().insert(
        "X-RateLimit-Limit",
        limit.to_string().parse().unwrap(),
    );
    response.headers_mut().insert(
        "X-RateLimit-Remaining",
        remaining.to_string().parse().unwrap(),
    );
    response.headers_mut().insert(
        "X-RateLimit-Reset",
        reset.to_string().parse().unwrap(),
    );
}
```

---

### 5.4 Data Privacy

**PII Redaction:**

```rust
use regex::Regex;

pub struct PIIRedactor {
    patterns: Vec<(Regex, &'static str)>,
}

impl PIIRedactor {
    pub fn new() -> Self {
        let patterns = vec![
            (Regex::new(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b").unwrap(), "[EMAIL]"),
            (Regex::new(r"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b").unwrap(), "[PHONE]"),
            (Regex::new(r"\b\d{3}-\d{2}-\d{4}\b").unwrap(), "[SSN]"),
            (Regex::new(r"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b").unwrap(), "[CARD]"),
            (Regex::new(r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b").unwrap(), "[IP]"),
        ];

        Self { patterns }
    }

    pub fn redact(&self, text: &str) -> String {
        let mut result = text.to_string();

        for (pattern, replacement) in &self.patterns {
            result = pattern.replace_all(&result, *replacement).to_string();
        }

        result
    }
}
```

**Field-Level Redaction:**

```rust
pub fn redact_trace(trace: &mut Trace, redact_config: &RedactConfig) {
    if redact_config.redact_input {
        if let Some(prompt) = &trace.input.prompt {
            trace.input.prompt = Some(redact_pii(prompt));
        }
        if let Some(messages) = &trace.input.messages {
            trace.input.messages = Some(
                messages.iter()
                    .map(|m| Message {
                        content: redact_pii(&m.content),
                        ..m.clone()
                    })
                    .collect()
            );
        }
    }

    if redact_config.redact_output {
        if let Some(ref mut output) = trace.output {
            if let Some(content) = &output.content {
                output.content = Some(redact_pii(content));
            }
        }
    }

    trace.redacted = true;
}
```

---

### 5.5 Audit Logging

**Audit Log Entry:**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditLogEntry {
    pub id: Uuid,
    pub timestamp: DateTime<Utc>,
    pub user_id: String,
    pub org_id: String,
    pub action: AuditAction,
    pub resource_type: String,
    pub resource_id: String,
    pub success: bool,
    pub ip_address: String,
    pub user_agent: String,
    pub request_id: String,
    pub metadata: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AuditAction {
    Create,
    Read,
    Update,
    Delete,
    Export,
    Search,
}
```

**Database Table:**

```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id TEXT NOT NULL,
    org_id TEXT NOT NULL,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT NOT NULL,
    success BOOLEAN NOT NULL,
    ip_address INET,
    user_agent TEXT,
    request_id TEXT,
    metadata JSONB
);

-- Convert to hypertable for efficient time-based queries
SELECT create_hypertable('audit_logs', 'ts',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE
);

-- Retention policy: 90 days
SELECT add_retention_policy('audit_logs', INTERVAL '90 days');

-- Indexes
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id, ts DESC);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id, ts DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs(action, ts DESC);
```

**Logging Middleware:**

```rust
pub async fn audit_log_middleware(
    req: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let user_context = req.extensions().get::<UserContext>().cloned();
    let request_id = Uuid::new_v4().to_string();
    let start_time = Instant::now();

    let response = next.run(req).await;

    let duration = start_time.elapsed();

    if let Some(user) = user_context {
        // Log audit entry
        let audit_entry = AuditLogEntry {
            id: Uuid::new_v4(),
            timestamp: Utc::now(),
            user_id: user.user_id,
            org_id: user.org_id,
            action: determine_action(&req),
            resource_type: extract_resource_type(&req),
            resource_id: extract_resource_id(&req),
            success: response.status().is_success(),
            ip_address: extract_ip(&req),
            user_agent: extract_user_agent(&req),
            request_id,
            metadata: json!({
                "duration_ms": duration.as_millis(),
                "status_code": response.status().as_u16(),
            }),
        };

        // Async log to database (don't wait)
        tokio::spawn(async move {
            let _ = save_audit_log(audit_entry).await;
        });
    }

    Ok(response)
}
```

---

## 6. Performance and Optimization

### 6.1 Caching Strategy

**Multi-Layer Caching:**

```
┌─────────────────────────────────────┐
│   Application Layer (In-Memory)     │
│   • Response caching (moka)         │
│   • 10-60 seconds TTL               │
│   • LRU eviction                    │
└─────────────┬───────────────────────┘
              │ Cache Miss
              ▼
┌─────────────────────────────────────┐
│   Redis Layer (Distributed)         │
│   • Query result caching            │
│   • 1-60 minutes TTL                │
│   • Cluster for HA                  │
└─────────────┬───────────────────────┘
              │ Cache Miss
              ▼
┌─────────────────────────────────────┐
│   Database Layer (TimescaleDB)      │
│   • Continuous aggregates           │
│   • Materialized views              │
│   • Query result cache              │
└─────────────────────────────────────┘
```

**Cache Key Generation:**

```rust
use sha2::{Sha256, Digest};

pub fn generate_cache_key(
    endpoint: &str,
    filters: &TraceFilters,
) -> String {
    let mut hasher = Sha256::new();

    hasher.update(endpoint.as_bytes());
    hasher.update(serde_json::to_string(filters).unwrap().as_bytes());

    let hash = hasher.finalize();
    format!("cache:{}:{:x}", endpoint, hash)
}
```

**Redis Caching Implementation:**

```rust
use redis::aio::ConnectionManager;

pub async fn get_or_compute<T, F, Fut>(
    redis: &mut ConnectionManager,
    key: &str,
    ttl_seconds: u64,
    compute_fn: F,
) -> Result<T, CacheError>
where
    T: Serialize + DeserializeOwned,
    F: FnOnce() -> Fut,
    Fut: Future<Output = Result<T, anyhow::Error>>,
{
    // Try to get from cache
    if let Ok(cached) = redis::cmd("GET")
        .arg(key)
        .query_async::<_, Option<String>>(redis)
        .await
    {
        if let Some(cached_value) = cached {
            if let Ok(result) = serde_json::from_str::<T>(&cached_value) {
                return Ok(result);
            }
        }
    }

    // Cache miss: compute value
    let value = compute_fn().await?;

    // Store in cache
    let serialized = serde_json::to_string(&value)?;
    let _: () = redis::cmd("SETEX")
        .arg(key)
        .arg(ttl_seconds)
        .arg(serialized)
        .query_async(redis)
        .await?;

    Ok(value)
}
```

**TTL Guidelines:**

| Query Type | TTL | Justification |
|------------|-----|---------------|
| Real-time metrics (1min buckets) | 30s | Recent data, frequent updates |
| Recent traces (last 1h) | 60s | Balance freshness and performance |
| Historical metrics (1hour buckets) | 5min | Less frequent changes |
| Historical metrics (1day buckets) | 1hour | Stable data |
| Cost summaries | 15min | Financial data, moderate freshness |
| Single trace lookup | 5min | Immutable after creation |
| Expensive aggregations | 30min | Computationally costly |

**Cache Invalidation:**

```rust
pub async fn invalidate_cache_pattern(
    redis: &mut ConnectionManager,
    pattern: &str,
) -> Result<(), RedisError> {
    let keys: Vec<String> = redis::cmd("KEYS")
        .arg(pattern)
        .query_async(redis)
        .await?;

    if !keys.is_empty() {
        redis::cmd("DEL")
            .arg(&keys)
            .query_async::<_, ()>(redis)
            .await?;
    }

    Ok(())
}

// Example: Invalidate all cost caches when new data ingested
pub async fn on_new_trace_ingested(trace: &Trace, redis: &mut ConnectionManager) {
    let patterns = vec![
        format!("cache:costs:{}:*", trace.project_id),
        format!("cache:metrics:{}:*", trace.project_id),
        "cache:summary:*",
    ];

    for pattern in patterns {
        let _ = invalidate_cache_pattern(redis, &pattern).await;
    }
}
```

---

### 6.2 Query Optimization

**Continuous Aggregate Selection:**

```rust
pub fn select_aggregate_table(
    time_range: &TimeRange,
) -> &'static str {
    let duration = time_range.to - time_range.from;

    if duration <= Duration::hours(6) {
        "llm_metrics_1min"
    } else if duration <= Duration::days(7) {
        "llm_metrics_1hour"
    } else {
        "llm_metrics_1day"
    }
}
```

**Query Builder with Optimization:**

```rust
pub struct TraceQueryBuilder {
    filters: TraceFilters,
    use_aggregate: bool,
}

impl TraceQueryBuilder {
    pub fn new(filters: TraceFilters) -> Self {
        Self {
            filters,
            use_aggregate: false,
        }
    }

    pub fn build(&self) -> String {
        let mut query = if self.use_aggregate {
            "SELECT * FROM llm_metrics_1hour".to_string()
        } else {
            "SELECT * FROM llm_traces".to_string()
        };

        let mut conditions = vec![];

        // Time range (required)
        if let Some(from) = &self.filters.from {
            conditions.push(format!("ts >= '{}'", from.to_rfc3339()));
        }
        if let Some(to) = &self.filters.to {
            conditions.push(format!("ts <= '{}'", to.to_rfc3339()));
        }

        // Provider filter
        if let Some(providers) = &self.filters.provider {
            let provider_list = providers
                .iter()
                .map(|p| format!("'{}'", p))
                .collect::<Vec<_>>()
                .join(", ");
            conditions.push(format!("provider IN ({})", provider_list));
        }

        // Model filter
        if let Some(models) = &self.filters.model {
            let model_list = models
                .iter()
                .map(|m| format!("'{}'", m))
                .collect::<Vec<_>>()
                .join(", ");
            conditions.push(format!("model IN ({})", model_list));
        }

        // Duration range
        if let Some(min_duration) = &self.filters.min_duration {
            conditions.push(format!("duration_ms >= {}", min_duration));
        }
        if let Some(max_duration) = &self.filters.max_duration {
            conditions.push(format!("duration_ms <= {}", max_duration));
        }

        // Cost range
        if let Some(min_cost) = &self.filters.min_cost {
            conditions.push(format!("total_cost_usd >= {}", min_cost));
        }
        if let Some(max_cost) = &self.filters.max_cost {
            conditions.push(format!("total_cost_usd <= {}", max_cost));
        }

        // Status filter
        if let Some(status) = &self.filters.status {
            conditions.push(format!("status_code = '{:?}'", status));
        }

        // Project filter
        if let Some(project_id) = &self.filters.project_id {
            conditions.push(format!("attributes->>'project_id' = '{}'", project_id));
        }

        // User filter
        if let Some(user_id) = &self.filters.user_id {
            conditions.push(format!("user_id = '{}'", user_id));
        }

        // Environment filter
        if let Some(environment) = &self.filters.environment {
            conditions.push(format!("environment = '{}'", environment));
        }

        if !conditions.is_empty() {
            query.push_str(" WHERE ");
            query.push_str(&conditions.join(" AND "));
        }

        // Order by
        let sort_by = self.filters.sort_by.as_deref().unwrap_or("ts");
        let sort_order = match &self.filters.sort_order {
            Some(SortOrder::Asc) => "ASC",
            _ => "DESC",
        };
        query.push_str(&format!(" ORDER BY {} {}", sort_by, sort_order));

        // Limit
        let limit = self.filters.limit.unwrap_or(50);
        query.push_str(&format!(" LIMIT {}", limit));

        query
    }
}
```

**Index Usage Monitoring:**

```sql
-- Check index usage
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

-- Identify unused indexes
SELECT
    schemaname,
    tablename,
    indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND schemaname = 'public';
```

---

### 6.3 Connection Pooling

**PgPool Configuration:**

```rust
use sqlx::postgres::{PgPoolOptions, PgConnectOptions};

pub async fn create_db_pool(
    database_url: &str,
    max_connections: u32,
) -> Result<PgPool, sqlx::Error> {
    let connect_options = database_url
        .parse::<PgConnectOptions>()?
        .application_name("llm-observatory-api");

    PgPoolOptions::new()
        .max_connections(max_connections)
        .min_connections(5)
        .acquire_timeout(Duration::from_secs(5))
        .idle_timeout(Duration::from_secs(600)) // 10 minutes
        .max_lifetime(Duration::from_secs(1800)) // 30 minutes
        .connect_with(connect_options)
        .await
}
```

**Pool Size Guidelines:**

| Deployment | API Instances | Connections per Instance | Total Connections |
|------------|---------------|-------------------------|-------------------|
| Development | 1 | 10 | 10 |
| Staging | 2 | 20 | 40 |
| Production (small) | 3 | 20 | 60 |
| Production (medium) | 5 | 30 | 150 |
| Production (large) | 10 | 50 | 500 |

**PostgreSQL Configuration:**

```conf
# postgresql.conf optimizations

# Connection settings
max_connections = 500
shared_buffers = 8GB
effective_cache_size = 24GB
maintenance_work_mem = 2GB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 64MB
min_wal_size = 2GB
max_wal_size = 8GB

# TimescaleDB settings
timescaledb.max_background_workers = 8
```

---

### 6.4 Response Compression

**Gzip Middleware:**

```rust
use tower_http::compression::CompressionLayer;
use tower_http::compression::predicate::{SizeAbove, Predicate};

pub fn create_compression_layer() -> CompressionLayer {
    CompressionLayer::new()
        .gzip(true)
        .br(true)
        .compress_when(
            SizeAbove::new(1024) // Only compress responses > 1KB
                .and(DefaultPredicate::new())
        )
}
```

**Compression Benefits:**

| Response Size | Uncompressed | Gzip Compressed | Savings |
|---------------|--------------|-----------------|---------|
| Trace list (50) | 250 KB | 35 KB | 86% |
| Metrics time-series | 500 KB | 50 KB | 90% |
| Single trace detail | 15 KB | 3 KB | 80% |

---

### 6.5 Pagination Optimization

**Cursor-Based Pagination Implementation:**

```rust
use base64::{Engine as _, engine::general_purpose};

#[derive(Debug, Serialize, Deserialize)]
pub struct PaginationCursor {
    pub timestamp: DateTime<Utc>,
    pub id: Uuid,
}

impl PaginationCursor {
    pub fn encode(&self) -> String {
        let json = serde_json::to_string(self).unwrap();
        general_purpose::STANDARD.encode(json.as_bytes())
    }

    pub fn decode(cursor: &str) -> Result<Self, DecodeError> {
        let bytes = general_purpose::STANDARD.decode(cursor)?;
        let json = String::from_utf8(bytes)?;
        let cursor: PaginationCursor = serde_json::from_str(&json)?;
        Ok(cursor)
    }
}

pub async fn list_traces_paginated(
    db: &PgPool,
    filters: TraceFilters,
) -> Result<PaginatedResponse<Trace>> {
    let limit = filters.limit.unwrap_or(50) as i64;

    let mut query = QueryBuilder::new("SELECT * FROM llm_traces WHERE ");

    // Apply filters
    apply_filters(&mut query, &filters);

    // Apply cursor for pagination
    if let Some(cursor_str) = &filters.cursor {
        let cursor = PaginationCursor::decode(cursor_str)?;
        query.push(" AND (ts, trace_id) < (");
        query.push_bind(cursor.timestamp);
        query.push(", ");
        query.push_bind(cursor.id);
        query.push(")");
    }

    query.push(" ORDER BY ts DESC, trace_id DESC");
    query.push(" LIMIT ");
    query.push_bind(limit + 1); // Fetch one extra to determine has_more

    let traces: Vec<Trace> = query.build_query_as().fetch_all(db).await?;

    let has_more = traces.len() > limit as usize;
    let mut data = traces;

    if has_more {
        data.pop(); // Remove extra record
    }

    let next_cursor = if has_more {
        data.last().map(|t| PaginationCursor {
            timestamp: t.start_time,
            id: t.trace_id,
        }.encode())
    } else {
        None
    };

    Ok(PaginatedResponse {
        status: ResponseStatus::Success,
        data,
        pagination: PaginationMetadata {
            cursor: next_cursor,
            has_more,
            limit: limit as i32,
            total: None,
        },
        meta: ResponseMetadata {
            timestamp: Utc::now(),
            execution_time_ms: 0, // Filled by middleware
            cached: false,
            version: "1.0".to_string(),
            request_id: None,
        },
    })
}
```

---

## 7. Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

**Goals:**
- Set up project structure
- Implement authentication/authorization
- Create basic trace query endpoint

**Tasks:**

**Week 1:**
1. **Project Setup**
   - Create new route modules in `services/analytics-api/src/routes/`
     - `traces.rs`
     - `metrics_query.rs`
   - Set up middleware for JWT authentication
   - Configure rate limiting infrastructure
   - Duration: 2 days

2. **Authentication Implementation**
   - Implement JWT validation middleware
   - Add API key authentication
   - Create `UserContext` extraction
   - Write unit tests
   - Duration: 3 days

**Week 2:**
3. **Basic Trace Query Endpoint**
   - Implement `GET /api/v1/traces` with basic filters:
     - Time range (`from`, `to`)
     - Provider, model
     - Status
     - Project ID
   - Add offset-based pagination (temporary, replaced in Phase 2)
   - Response formatting
   - Duration: 3 days

4. **Storage Repository Methods**
   - Add `TraceRepository::list()` method
   - Implement basic SQL query builder
   - Add integration tests
   - Duration: 2 days

**Deliverables:**
- ✅ JWT authentication working
- ✅ `GET /api/v1/traces` endpoint functional
- ✅ Basic filtering and pagination
- ✅ 80%+ test coverage

**Success Criteria:**
- Can query traces with filters
- Authentication blocks unauthorized access
- Response time < 1s for simple queries

---

### Phase 2: Advanced Querying (Weeks 3-4)

**Goals:**
- Implement cursor-based pagination
- Add advanced filtering
- Create single trace lookup endpoint

**Tasks:**

**Week 3:**
1. **Cursor-Based Pagination**
   - Implement `PaginationCursor` encoding/decoding
   - Update `TraceRepository::list()` to support cursors
   - Add `has_more` and `next_cursor` to responses
   - Write migration guide for clients
   - Duration: 3 days

2. **Advanced Filtering**
   - Add filter operators (gt, gte, lt, lte, in, contains)
   - Implement `POST /api/v1/traces/search` endpoint
   - Support complex filters (AND, OR, NOT)
   - Add filter validation
   - Duration: 2 days

**Week 4:**
3. **Single Trace Endpoint**
   - Implement `GET /api/v1/traces/:trace_id`
   - Add support for `include` parameter (children, evaluations, feedback)
   - Implement child span loading
   - Add Redis caching
   - Duration: 2 days

4. **Full-Text Search**
   - Add PostgreSQL full-text search support
   - Create GIN indexes for searchable fields
   - Implement search query parsing
   - Duration: 2 days

5. **Testing & Documentation**
   - Write integration tests for all endpoints
   - Create API documentation (OpenAPI/Swagger)
   - Performance testing
   - Duration: 1 day

**Deliverables:**
- ✅ Cursor-based pagination working
- ✅ Advanced filtering with operators
- ✅ `POST /api/v1/traces/search` endpoint
- ✅ `GET /api/v1/traces/:trace_id` endpoint
- ✅ Full-text search functional
- ✅ OpenAPI documentation

**Success Criteria:**
- Can search traces with complex filters
- Pagination stable across result set changes
- P95 latency < 500ms
- 85%+ test coverage

---

### Phase 3: Metrics API (Weeks 5-6)

**Goals:**
- Implement time-series metrics query
- Create metrics summary endpoint
- Add custom metric queries

**Tasks:**

**Week 5:**
1. **Metrics Query Endpoint**
   - Implement `GET /api/v1/metrics`
   - Support multiple metric names
   - Add time bucketing (interval selection)
   - Implement aggregation functions (avg, sum, p95, etc.)
   - Duration: 3 days

2. **Continuous Aggregate Integration**
   - Add logic to select appropriate aggregate table
   - Implement fall-back to raw table for percentiles
   - Optimize queries for different time ranges
   - Duration: 2 days

**Week 6:**
3. **Metrics Summary Endpoint**
   - Implement `GET /api/v1/metrics/summary`
   - Add cost breakdowns
   - Implement period comparison logic
   - Add quality metrics
   - Duration: 2 days

4. **Custom Metric Queries**
   - Implement `POST /api/v1/metrics/query`
   - Support group by multiple dimensions
   - Add HAVING clause support
   - Implement complex aggregations
   - Duration: 2 days

5. **Caching Optimization**
   - Add Redis caching for metrics
   - Implement cache warming for common queries
   - Add cache invalidation on new data
   - Duration: 1 day

**Deliverables:**
- ✅ `GET /api/v1/metrics` endpoint
- ✅ `GET /api/v1/metrics/summary` endpoint
- ✅ `POST /api/v1/metrics/query` endpoint
- ✅ Redis caching for metrics
- ✅ Query optimization

**Success Criteria:**
- Can query time-series metrics
- Correct aggregate table selection
- P95 latency < 1s
- Cache hit rate > 70%

---

### Phase 4: Cost Analysis (Weeks 7-8)

**Goals:**
- Implement cost summary endpoint
- Add cost attribution
- Create cost forecasting

**Tasks:**

**Week 7:**
1. **Cost Summary Endpoint**
   - Implement `GET /api/v1/costs/summary`
   - Add breakdowns by provider, model
   - Implement trend calculation
   - Add top expensive traces
   - Duration: 2 days

2. **Cost Attribution**
   - Implement `GET /api/v1/costs/attribution`
   - Support attribution by user, team, tag
   - Add cost per request calculations
   - Duration: 2 days

3. **Cost Forecasting**
   - Implement `GET /api/v1/costs/forecast`
   - Add linear regression for projections
   - Support different forecast periods
   - Duration: 1 day

**Week 8:**
4. **Budget Alerts Integration**
   - Add budget checking logic
   - Implement threshold alerts
   - Create alert history endpoint
   - Duration: 2 days

5. **Testing & Optimization**
   - Write comprehensive tests
   - Performance optimization
   - Add caching for cost queries
   - Duration: 2 days

**Deliverables:**
- ✅ Cost summary endpoint
- ✅ Cost attribution endpoint
- ✅ Cost forecasting
- ✅ Budget alert integration

**Success Criteria:**
- Accurate cost calculations
- Sub-second response times
- Cost forecasts within 10% accuracy

---

### Phase 5: Export & Real-time (Weeks 9-10)

**Goals:**
- Implement export functionality
- Add WebSocket API for real-time updates

**Tasks:**

**Week 9:**
1. **Export Endpoints**
   - Implement `POST /api/v1/export/traces`
   - Support CSV, JSON, JSONL formats
   - Add compression (gzip, zip)
   - Implement async job processing
   - Duration: 3 days

2. **Export Job Management**
   - Create job status tracking
   - Implement download URL generation
   - Add job cleanup (expired downloads)
   - Duration: 2 days

**Week 10:**
3. **WebSocket API**
   - Implement WebSocket connection handler
   - Add subscription management
   - Create event publisher
   - Support filtering on subscriptions
   - Duration: 3 days

4. **Real-time Event Types**
   - Implement trace creation events
   - Add metric threshold events
   - Create alert triggered events
   - Duration: 1 day

5. **Integration with Ingestion**
   - Connect WebSocket to trace ingestion
   - Add event filtering logic
   - Test real-time performance
   - Duration: 1 day

**Deliverables:**
- ✅ Export API functional
- ✅ WebSocket API operational
- ✅ Real-time events working
- ✅ Job management system

**Success Criteria:**
- Can export up to 1M traces
- WebSocket connections stable
- Event latency < 1s
- Export jobs complete within 5 minutes (100K traces)

---

### Phase 6: Enhancement & Polish (Weeks 11-12)

**Goals:**
- Enhance rate limiting
- Add HTTP caching headers
- Implement field selection
- Polish error handling

**Tasks:**

**Week 11:**
1. **Enhanced Rate Limiting**
   - Implement token bucket algorithm
   - Add Redis-backed rate limiting
   - Support tiered limits
   - Add rate limit headers
   - Duration: 2 days

2. **HTTP Caching**
   - Add ETag generation
   - Implement Last-Modified headers
   - Support conditional requests (304 Not Modified)
   - Duration: 2 days

3. **Field Selection**
   - Implement `fields` query parameter
   - Add projection to SQL queries
   - Support nested field selection
   - Duration: 1 day

**Week 12:**
4. **Error Handling Polish**
   - Standardize error response format
   - Add detailed error messages
   - Implement error code catalog
   - Duration: 2 days

5. **Performance Tuning**
   - Run load tests
   - Optimize slow queries
   - Tune cache TTLs
   - Database index optimization
   - Duration: 2 days

6. **Final Testing**
   - End-to-end integration tests
   - Load testing (1K, 10K, 100K requests)
   - Security audit
   - Duration: 1 day

**Deliverables:**
- ✅ Token bucket rate limiting
- ✅ HTTP caching headers
- ✅ Field selection working
- ✅ Polished error handling
- ✅ Performance optimized
- ✅ All tests passing

**Success Criteria:**
- P95 latency < 500ms (trace queries)
- P99 latency < 2s (complex aggregations)
- Rate limiting prevents abuse
- 90%+ test coverage
- Zero critical security issues

---

### Phase 7: Documentation & Launch (Weeks 13-14)

**Goals:**
- Complete API documentation
- Create integration guides
- Launch beta

**Tasks:**

**Week 13:**
1. **API Documentation**
   - Complete OpenAPI specification
   - Generate interactive docs (Swagger UI)
   - Write endpoint descriptions
   - Add request/response examples
   - Duration: 3 days

2. **Integration Guides**
   - Write Python client example
   - Create JavaScript/TypeScript examples
   - Document authentication flows
   - Add rate limiting guidance
   - Duration: 2 days

**Week 14:**
3. **Deployment Preparation**
   - Update Docker Compose configuration
   - Create Kubernetes manifests
   - Write deployment guide
   - Duration: 2 days

4. **Beta Launch**
   - Deploy to staging
   - Invite beta users
   - Monitor performance
   - Gather feedback
   - Duration: 2 days

5. **Bug Fixes & Adjustments**
   - Address beta feedback
   - Fix discovered issues
   - Performance tweaks
   - Duration: 1 day

**Deliverables:**
- ✅ Complete OpenAPI documentation
- ✅ Integration guides published
- ✅ Beta deployed
- ✅ Initial user feedback collected

**Success Criteria:**
- Beta users successfully integrate
- < 5 critical bugs reported
- Documentation rated 4+/5
- API uptime > 99.5%

---

## 8. Testing Strategy

### 8.1 Unit Tests

**Coverage Target:** 85%+

**Test Framework:** `tokio-test`, `mockall`

**Example Unit Test:**

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use mockall::mock;

    mock! {
        TraceRepo {}

        #[async_trait]
        impl TraceRepository for TraceRepo {
            async fn list(&self, filters: TraceFilters) -> Result<Vec<Trace>>;
            async fn get_by_id(&self, trace_id: &str) -> Result<Option<Trace>>;
        }
    }

    #[tokio::test]
    async fn test_list_traces_with_filters() {
        let mut mock_repo = MockTraceRepo::new();

        mock_repo
            .expect_list()
            .times(1)
            .returning(|filters| {
                assert_eq!(filters.provider, Some(vec!["openai".to_string()]));
                Ok(vec![create_test_trace()])
            });

        let result = list_traces(&mock_repo, create_test_filters()).await;

        assert!(result.is_ok());
        let traces = result.unwrap();
        assert_eq!(traces.len(), 1);
    }

    #[test]
    fn test_pagination_cursor_encoding() {
        let cursor = PaginationCursor {
            timestamp: Utc::now(),
            id: Uuid::new_v4(),
        };

        let encoded = cursor.encode();
        let decoded = PaginationCursor::decode(&encoded).unwrap();

        assert_eq!(cursor.timestamp, decoded.timestamp);
        assert_eq!(cursor.id, decoded.id);
    }
}
```

---

### 8.2 Integration Tests

**Test Database:** Separate TimescaleDB instance with test data

**Framework:** `sqlx` with transactions, `axum-test`

**Example Integration Test:**

```rust
#[cfg(test)]
mod integration_tests {
    use super::*;
    use axum::http::StatusCode;
    use axum_test::TestServer;

    async fn setup_test_server() -> TestServer {
        let app = create_app().await;
        TestServer::new(app).unwrap()
    }

    #[tokio::test]
    async fn test_get_traces_endpoint() {
        let server = setup_test_server().await;

        // Insert test data
        let db = get_test_db().await;
        insert_test_traces(&db, 10).await;

        // Make request
        let response = server
            .get("/api/v1/traces")
            .add_query_param("provider", "openai")
            .add_query_param("limit", "5")
            .add_header("Authorization", "Bearer test_token")
            .await;

        // Assertions
        assert_eq!(response.status_code(), StatusCode::OK);

        let body: PaginatedResponse<Trace> = response.json();
        assert_eq!(body.data.len(), 5);
        assert!(body.pagination.has_more);
        assert!(body.pagination.cursor.is_some());
    }

    #[tokio::test]
    async fn test_unauthorized_access() {
        let server = setup_test_server().await;

        let response = server
            .get("/api/v1/traces")
            .await;

        assert_eq!(response.status_code(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn test_cursor_pagination_consistency() {
        let server = setup_test_server().await;
        let db = get_test_db().await;
        insert_test_traces(&db, 100).await;

        // First page
        let response1 = server
            .get("/api/v1/traces")
            .add_query_param("limit", "50")
            .add_header("Authorization", "Bearer test_token")
            .await;

        let body1: PaginatedResponse<Trace> = response1.json();
        let cursor = body1.pagination.cursor.unwrap();

        // Second page
        let response2 = server
            .get("/api/v1/traces")
            .add_query_param("limit", "50")
            .add_query_param("cursor", &cursor)
            .add_header("Authorization", "Bearer test_token")
            .await;

        let body2: PaginatedResponse<Trace> = response2.json();

        // Verify no overlap
        let ids1: HashSet<_> = body1.data.iter().map(|t| t.trace_id).collect();
        let ids2: HashSet<_> = body2.data.iter().map(|t| t.trace_id).collect();
        assert_eq!(ids1.intersection(&ids2).count(), 0);
    }
}
```

---

### 8.3 Load Testing

**Tool:** `k6` (Grafana k6)

**Scenarios:**

1. **Baseline Load**
   - 100 virtual users
   - 10 requests/second per user
   - Duration: 10 minutes
   - Target: P95 < 500ms, error rate < 1%

2. **Peak Load**
   - 1000 virtual users
   - 100 requests/second per user
   - Duration: 5 minutes
   - Target: P95 < 2s, error rate < 5%

3. **Stress Test**
   - Gradually increase from 100 to 5000 users
   - Identify breaking point
   - Duration: 30 minutes

**Example k6 Script:**

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },  // Ramp up
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 1000 }, // Spike to 1000
    { duration: '3m', target: 1000 }, // Stay at peak
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<2000'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = 'http://localhost:8080';
const AUTH_TOKEN = 'Bearer test_token';

export default function () {
  // Test 1: List traces
  const listRes = http.get(`${BASE_URL}/api/v1/traces?limit=50`, {
    headers: { 'Authorization': AUTH_TOKEN },
  });

  check(listRes, {
    'list traces status 200': (r) => r.status === 200,
    'list traces has data': (r) => JSON.parse(r.body).data.length > 0,
  });

  sleep(1);

  // Test 2: Get single trace
  const traceId = JSON.parse(listRes.body).data[0].trace_id;
  const getRes = http.get(`${BASE_URL}/api/v1/traces/${traceId}`, {
    headers: { 'Authorization': AUTH_TOKEN },
  });

  check(getRes, {
    'get trace status 200': (r) => r.status === 200,
  });

  sleep(1);

  // Test 3: Metrics summary
  const metricsRes = http.get(
    `${BASE_URL}/api/v1/metrics/summary?from=now-24h&to=now`,
    {
      headers: { 'Authorization': AUTH_TOKEN },
    }
  );

  check(metricsRes, {
    'metrics summary status 200': (r) => r.status === 200,
  });

  sleep(2);
}
```

**Running Load Tests:**

```bash
# Install k6
brew install k6  # macOS
# or
sudo apt install k6  # Ubuntu

# Run test
k6 run load-test.js

# Run with custom parameters
k6 run --vus 1000 --duration 5m load-test.js

# Run with output to InfluxDB for visualization
k6 run --out influxdb=http://localhost:8086/k6 load-test.js
```

---

### 8.4 Security Testing

**Checklist:**

1. **Authentication/Authorization:**
   - [ ] Invalid JWT rejected
   - [ ] Expired JWT rejected
   - [ ] Missing Authorization header returns 401
   - [ ] Insufficient permissions return 403
   - [ ] Cross-project access blocked

2. **Input Validation:**
   - [ ] SQL injection attempts blocked
   - [ ] XSS attempts sanitized
   - [ ] Oversized inputs rejected
   - [ ] Invalid parameter types rejected
   - [ ] Malformed JSON handled gracefully

3. **Rate Limiting:**
   - [ ] Rate limits enforced correctly
   - [ ] Rate limit headers present
   - [ ] Distributed rate limiting works (multiple API instances)

4. **Data Privacy:**
   - [ ] PII redaction working
   - [ ] Sensitive fields excluded from responses
   - [ ] API keys never returned

5. **Audit Logging:**
   - [ ] All API calls logged
   - [ ] Failed auth attempts logged
   - [ ] Sensitive actions audited

**Tools:**
- **OWASP ZAP**: Automated security scanning
- **Burp Suite**: Manual security testing
- **SQLMap**: SQL injection testing

---

## 9. Deployment Plan

### 9.1 Development Environment

**Docker Compose Configuration:**

```yaml
version: '3.8'

services:
  analytics-api:
    build:
      context: ./services/analytics-api
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - RUST_LOG=info
      - DATABASE_URL=postgres://llm_observatory_readonly:readonly_password@postgres:5432/llm_observatory
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
      - CACHE_TTL=300
    depends_on:
      - postgres
      - redis
    networks:
      - llm-observatory

  postgres:
    image: timescale/timescaledb:latest-pg15
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=llm_observatory
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./migrations:/docker-entrypoint-initdb.d
    networks:
      - llm-observatory

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis-data:/data
    networks:
      - llm-observatory

networks:
  llm-observatory:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
```

---

### 9.2 Production Deployment (Kubernetes)

**Deployment Manifest:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-api
  namespace: llm-observatory
spec:
  replicas: 3
  selector:
    matchLabels:
      app: analytics-api
  template:
    metadata:
      labels:
        app: analytics-api
    spec:
      containers:
      - name: analytics-api
        image: llm-observatory/analytics-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: readonly-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: jwt-secret
              key: secret
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "2000m"
            memory: "2Gi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

---
apiVersion: v1
kind: Service
metadata:
  name: analytics-api
  namespace: llm-observatory
spec:
  selector:
    app: analytics-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: ClusterIP

---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: analytics-api-hpa
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

---

### 9.3 Deployment Checklist

**Pre-Deployment:**
- [ ] All tests passing (unit, integration, load)
- [ ] Security audit completed
- [ ] Database migrations ready
- [ ] Environment variables configured
- [ ] Secrets stored securely (Vault/K8s Secrets)
- [ ] Monitoring configured (Prometheus/Grafana)
- [ ] Logging configured (ELK/Loki)
- [ ] Backup strategy verified
- [ ] Rollback plan documented

**Deployment Steps:**
1. [ ] Deploy to staging environment
2. [ ] Run smoke tests on staging
3. [ ] Verify monitoring and alerting
4. [ ] Deploy to production (blue-green or canary)
5. [ ] Monitor error rates and latency
6. [ ] Verify cache hit rates
7. [ ] Check database performance
8. [ ] Announce to users

**Post-Deployment:**
- [ ] Monitor for 24 hours
- [ ] Review error logs
- [ ] Check performance metrics
- [ ] Gather user feedback
- [ ] Document any issues

---

## 10. Success Metrics

### 10.1 Technical Metrics

**Performance:**
- P50 latency < 100ms (cached queries)
- P95 latency < 500ms (simple queries)
- P99 latency < 2s (complex aggregations)
- Timeout rate < 0.1%
- Error rate < 1%

**Scalability:**
- Support 10,000 requests/minute per instance
- Handle 1M traces in database
- Cache hit rate > 70%
- Database connection utilization < 80%

**Reliability:**
- API uptime > 99.9%
- Zero data loss
- Automatic failover < 30s
- Recovery time < 5 minutes

---

### 10.2 Business Metrics

**Adoption:**
- 50+ active API users in first month
- 1M+ API requests in first month
- 10+ third-party integrations
- 90%+ user satisfaction

**Usage:**
- 80% of dashboard powered by API
- Average 100 API calls per user per day
- 50% of queries using advanced filters
- 30% of users using export functionality

---

### 10.3 Quality Metrics

**Code Quality:**
- Test coverage > 85%
- Zero critical security vulnerabilities
- Code review approval required for all changes
- Documentation coverage 100%

**API Quality:**
- 100% OpenAPI spec compliance
- Response time SLA met 99%+
- Error messages clear and actionable
- API versioning maintained

---

## Conclusion

This implementation plan provides a comprehensive roadmap for building the REST API to query traces and metrics in LLM Observatory. The phased approach allows for incremental delivery while maintaining quality and performance standards.

**Key Highlights:**
- **7 implementation phases** over 14 weeks
- **Comprehensive security** with JWT auth, rate limiting, and PII redaction
- **High performance** with caching, query optimization, and connection pooling
- **Production-ready** with thorough testing, monitoring, and deployment strategies
- **Well-documented** with OpenAPI specs, integration guides, and examples

**Next Steps:**
1. Review and approve this plan
2. Allocate development resources
3. Set up development environment
4. Begin Phase 1 implementation
5. Establish regular progress reviews

---

**Document Control:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-05 | Claude Flow Swarm | Initial comprehensive plan |

**Approvals:**

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Technical Lead | | | |
| Product Manager | | | |
| Security Lead | | | |
| DevOps Lead | | | |

---

**References:**
1. LLM Observatory Project Plan: `/workspaces/llm-observatory/docs/plans/LLM-Observatory-Plan.md`
2. REST API Best Practices: `/workspaces/llm-observatory/docs/REST_API_BEST_PRACTICES.md`
3. Existing Codebase Analysis: Internal research report
4. TimescaleDB Documentation: https://docs.timescale.com/
5. Axum Framework: https://github.com/tokio-rs/axum

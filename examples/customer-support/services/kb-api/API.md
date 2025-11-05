# Knowledge Base API Documentation

## Base URL

```
http://localhost:3002
```

## Authentication

Currently, the API does not require authentication. In production, implement authentication middleware.

## Common Headers

```
Content-Type: application/json
X-Request-ID: <optional-uuid>
```

## Endpoints

### Health Check

#### GET /health

Check the health status of the API and its dependencies.

**Response:**

```json
{
  "status": "healthy",
  "version": "0.1.0",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "checks": {
    "database": { "status": "up", "latency": 5 },
    "qdrant": { "status": "up", "latency": 10 },
    "redis": { "status": "up", "latency": 2 }
  }
}
```

### Documents

#### POST /v1/documents

Upload and process a document.

**Request:**

```bash
curl -X POST http://localhost:3002/v1/documents \
  -F "file=@document.pdf" \
  -F "title=API Documentation" \
  -F "category=documentation" \
  -F "tags=[\"api\", \"guide\"]" \
  -F "author=john@example.com"
```

**Parameters:**

- `file` (required): Document file (PDF, TXT, MD, DOCX)
- `title` (optional): Document title
- `category` (optional): Document category
- `tags` (optional): JSON array of tags
- `author` (optional): Document author
- `source` (optional): Document source
- `metadata` (optional): JSON object with custom metadata

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "API Documentation",
    "filename": "document.pdf",
    "size": 1024000,
    "chunksCreated": 42,
    "status": "completed"
  }
}
```

#### GET /v1/documents

List documents with pagination and filtering.

**Query Parameters:**

- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20, max: 100)
- `category` (optional): Filter by category
- `tags` (optional): Comma-separated list of tags
- `search` (optional): Search in title/filename
- `sortBy` (optional): Sort field (createdAt, updatedAt, title)
- `sortOrder` (optional): Sort order (asc, desc)

**Example:**

```bash
curl "http://localhost:3002/v1/documents?page=1&limit=20&category=documentation&tags=api,guide"
```

**Response:**

```json
{
  "success": true,
  "data": {
    "documents": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "API Documentation",
        "filename": "document.pdf",
        "size": 1024000,
        "chunksCount": 42,
        "category": "documentation",
        "tags": ["api", "guide"],
        "createdAt": "2024-01-01T00:00:00.000Z",
        "updatedAt": "2024-01-01T00:00:00.000Z"
      }
    ],
    "total": 1,
    "page": 1,
    "limit": 20,
    "totalPages": 1
  }
}
```

#### GET /v1/documents/:id

Get a specific document by ID.

**Example:**

```bash
curl http://localhost:3002/v1/documents/550e8400-e29b-41d4-a716-446655440000
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "API Documentation",
    "content": "Full document content...",
    "metadata": {
      "filename": "document.pdf",
      "mimeType": "application/pdf",
      "size": 1024000,
      "category": "documentation",
      "tags": ["api", "guide"],
      "author": "john@example.com"
    },
    "chunks": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000_chunk_0",
        "documentId": "550e8400-e29b-41d4-a716-446655440000",
        "content": "Chunk content...",
        "chunkIndex": 0,
        "metadata": {
          "startPosition": 0,
          "endPosition": 500,
          "tokenCount": 100
        }
      }
    ],
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

#### DELETE /v1/documents/:id

Delete a document and all its chunks.

**Example:**

```bash
curl -X DELETE http://localhost:3002/v1/documents/550e8400-e29b-41d4-a716-446655440000
```

**Response:**

```json
{
  "success": true,
  "message": "Document deleted successfully"
}
```

### Search

#### POST /v1/search

Perform semantic search across all documents.

**Request:**

```json
{
  "query": "How do I authenticate with the API?",
  "limit": 10,
  "scoreThreshold": 0.7,
  "filter": {
    "category": "documentation",
    "tags": ["authentication"],
    "author": "john@example.com",
    "dateFrom": "2024-01-01",
    "dateTo": "2024-12-31"
  },
  "includeContent": true
}
```

**Parameters:**

- `query` (required): Search query
- `limit` (optional): Max results (default: 10, max: 100)
- `scoreThreshold` (optional): Minimum similarity score (0-1, default: 0.7)
- `filter` (optional): Metadata filters
  - `category` (optional): Filter by category
  - `tags` (optional): Filter by tags (array)
  - `source` (optional): Filter by source
  - `author` (optional): Filter by author
  - `dateFrom` (optional): Filter by creation date
  - `dateTo` (optional): Filter by creation date
  - `customFilters` (optional): Custom metadata filters
- `includeContent` (optional): Include chunk content (default: true)

**Example:**

```bash
curl -X POST http://localhost:3002/v1/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "authentication methods",
    "limit": 5,
    "scoreThreshold": 0.75
  }'
```

**Response:**

```json
{
  "success": true,
  "data": {
    "results": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000_chunk_5",
        "documentId": "550e8400-e29b-41d4-a716-446655440000",
        "score": 0.85,
        "content": "The API supports multiple authentication methods including API keys, OAuth 2.0, and JWT tokens...",
        "metadata": {
          "documentTitle": "API Documentation",
          "filename": "api-docs.pdf",
          "chunkIndex": 5,
          "category": "documentation",
          "tags": ["api", "authentication"],
          "createdAt": "2024-01-01T00:00:00.000Z"
        }
      }
    ],
    "total": 1,
    "query": "authentication methods",
    "limit": 5,
    "scoreThreshold": 0.75,
    "took": 45
  }
}
```

#### POST /v1/search/hybrid

Perform hybrid search (semantic + keyword matching with reranking).

Same request/response format as `/v1/search`.

#### POST /v1/search/rerank

Perform search with advanced reranking based on keyword matches.

Same request/response format as `/v1/search`.

### Embeddings

#### POST /v1/embed

Generate embeddings for text.

**Request:**

```json
{
  "texts": [
    "First text to embed",
    "Second text to embed"
  ],
  "model": "text-embedding-3-small"
}
```

**Parameters:**

- `texts` (required): Array of texts (1-100 items)
- `model` (optional): Embedding model name

**Example:**

```bash
curl -X POST http://localhost:3002/v1/embed \
  -H "Content-Type: application/json" \
  -d '{
    "texts": ["authentication methods", "API documentation"]
  }'
```

**Response:**

```json
{
  "success": true,
  "data": {
    "embeddings": [
      [0.123, -0.456, 0.789, ...],
      [0.234, -0.567, 0.890, ...]
    ],
    "model": "text-embedding-3-small",
    "dimensions": 1536,
    "tokensUsed": 12
  }
}
```

## Error Responses

### 400 Bad Request

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "path": "query",
        "message": "Query is required",
        "code": "invalid_type"
      }
    ]
  },
  "timestamp": "2024-01-01T00:00:00.000Z",
  "path": "/v1/search",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 404 Not Found

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Document with id 550e8400-e29b-41d4-a716-446655440000 not found"
  },
  "timestamp": "2024-01-01T00:00:00.000Z",
  "path": "/v1/documents/550e8400-e29b-41d4-a716-446655440000",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 429 Too Many Requests

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests, please try again later"
  },
  "timestamp": "2024-01-01T00:00:00.000Z",
  "path": "/v1/search",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 500 Internal Server Error

```json
{
  "error": {
    "code": "INTERNAL_SERVER_ERROR",
    "message": "An unexpected error occurred"
  },
  "timestamp": "2024-01-01T00:00:00.000Z",
  "path": "/v1/documents",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 503 Service Unavailable

```json
{
  "error": {
    "code": "SERVICE_UNAVAILABLE",
    "message": "Qdrant is currently unavailable"
  },
  "timestamp": "2024-01-01T00:00:00.000Z",
  "path": "/v1/search",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

## Rate Limits

Default rate limits:

- 100 requests per 15 minutes per IP
- Applies to all `/v1/*` endpoints
- Health check endpoints are not rate-limited

Rate limit headers:

```
RateLimit-Limit: 100
RateLimit-Remaining: 95
RateLimit-Reset: 1640995200
```

## CORS

The API supports CORS with configurable origins. Configure via `CORS_ORIGINS` environment variable.

## Request IDs

All responses include a `X-Request-ID` header for tracking and debugging. Provide this ID when reporting issues.

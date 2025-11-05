# Knowledge Base API

A high-performance Knowledge Base API with RAG (Retrieval-Augmented Generation) capabilities, featuring semantic search, document processing, and LLM Observatory integration.

## Features

- **Document Processing**: Upload and process PDF, TXT, MD, and DOCX files
- **Text Chunking**: Intelligent text chunking with configurable overlap
- **Embeddings**: OpenAI text-embedding-3-small integration
- **Vector Search**: Qdrant-powered semantic search
- **Hybrid Search**: Combine semantic and keyword search
- **LLM Observatory**: Full observability with OpenTelemetry
- **RESTful API**: Clean, well-documented REST endpoints
- **Type Safety**: Built with TypeScript

## Architecture

```
┌─────────────────┐
│   Client App    │
└────────┬────────┘
         │
    ┌────▼────┐
    │ KB API  │
    └────┬────┘
         │
    ┌────┴────────────────────┐
    │                         │
┌───▼──────┐         ┌───────▼─────┐
│  Qdrant  │         │   OpenAI    │
│ (Vectors)│         │ (Embeddings)│
└──────────┘         └─────────────┘
```

## Prerequisites

- Node.js >= 20.0.0
- npm >= 10.0.0
- Qdrant vector database
- OpenAI API key
- (Optional) LLM Observatory Collector

## Installation

```bash
npm install
```

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Key configuration:

```env
# OpenAI (Required)
OPENAI_API_KEY=your-openai-api-key

# Qdrant (Default: localhost:6333)
QDRANT_URL=http://localhost:6333

# LLM Observatory (Optional)
OBSERVATORY_ENABLED=true
OBSERVATORY_COLLECTOR_URL=http://localhost:4317
```

## Quick Start

### Development

```bash
# Start with hot reload
npm run dev
```

### Production

```bash
# Build
npm run build

# Start
npm start
```

### Docker

```bash
# Build image
docker build -t kb-api .

# Run container
docker run -p 3002:3002 --env-file .env kb-api
```

## API Endpoints

### Health Check

```bash
GET /health
```

### Documents

```bash
# Upload document
POST /v1/documents
Content-Type: multipart/form-data

{
  "file": <file>,
  "title": "Document Title",
  "category": "documentation",
  "tags": ["api", "guide"]
}

# List documents
GET /v1/documents?page=1&limit=20&category=documentation

# Get document
GET /v1/documents/:id

# Delete document
DELETE /v1/documents/:id
```

### Search

```bash
# Semantic search
POST /v1/search
Content-Type: application/json

{
  "query": "How do I authenticate?",
  "limit": 10,
  "scoreThreshold": 0.7,
  "filter": {
    "category": "documentation"
  }
}

# Hybrid search (semantic + keyword)
POST /v1/search/hybrid

# Search with reranking
POST /v1/search/rerank
```

### Embeddings

```bash
# Generate embeddings
POST /v1/embed
Content-Type: application/json

{
  "texts": ["text to embed", "another text"]
}
```

## API Response Format

### Success Response

```json
{
  "success": true,
  "data": {
    // Response data
  }
}
```

### Error Response

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Error message",
    "details": {}
  },
  "timestamp": "2024-01-01T00:00:00.000Z",
  "path": "/v1/documents",
  "requestId": "uuid"
}
```

## Development

### Scripts

```bash
# Development
npm run dev              # Start with hot reload
npm run build           # Build for production
npm start               # Start production server

# Code Quality
npm run lint            # Lint code
npm run lint:fix        # Fix lint issues
npm run format          # Format code
npm run typecheck       # Type check

# Testing
npm test                # Run tests
npm run test:watch      # Run tests in watch mode
npm run test:coverage   # Run tests with coverage

# Database
npm run recreate-collection  # Recreate Qdrant collection
```

### Testing

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Watch mode
npm run test:watch
```

## API Documentation

Full API documentation available in [API.md](./API.md)

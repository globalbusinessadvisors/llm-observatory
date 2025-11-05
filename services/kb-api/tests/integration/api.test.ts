import request from 'supertest';
import { Application } from 'express';
import { createApp, initializeServices } from '../../src/app';
import path from 'path';
import fs from 'fs/promises';

// Mock services for integration tests
jest.mock('../../src/services/qdrant', () => ({
  getQdrantService: jest.fn(() => ({
    initialize: jest.fn().mockResolvedValue(undefined),
    healthCheck: jest.fn().mockResolvedValue(true),
    upsertPoints: jest.fn().mockResolvedValue(undefined),
    search: jest.fn().mockResolvedValue([
      {
        id: 'test-chunk-1',
        score: 0.95,
        payload: {
          documentId: 'test-doc-1',
          chunkIndex: 0,
          content: 'This is a test chunk',
          metadata: { tokens: 5 },
        },
      },
    ]),
    deleteByDocumentId: jest.fn().mockResolvedValue(undefined),
    getCollectionInfo: jest.fn().mockResolvedValue({
      status: 'green',
      vectors_count: 100,
      points_count: 100,
      segments_count: 1,
      config: {
        params: {
          vectors: {
            size: 1536,
            distance: 'Cosine',
          },
        },
      },
    }),
    countPoints: jest.fn().mockResolvedValue(100),
  })),
}));

jest.mock('../../src/services/embeddings', () => ({
  getEmbeddingsService: jest.fn(() => ({
    generateEmbedding: jest.fn().mockResolvedValue({
      embedding: new Array(1536).fill(0).map(() => Math.random()),
      dimensions: 1536,
      model: 'text-embedding-3-small',
      tokens: 10,
    }),
    generateEmbeddingsBatch: jest.fn((texts: string[]) =>
      Promise.resolve(
        texts.map(() => ({
          embedding: new Array(1536).fill(0).map(() => Math.random()),
          dimensions: 1536,
          model: 'text-embedding-3-small',
          tokens: 10,
        }))
      )
    ),
    countTokens: jest.fn((text: string) => Math.ceil(text.length / 4)),
  })),
}));

jest.mock('../../src/services/chunking', () => ({
  getChunkingService: jest.fn(() => ({
    chunkTextWithEmbeddings: jest.fn().mockResolvedValue([
      {
        id: 'chunk-1',
        documentId: 'doc-1',
        content: 'Test chunk content',
        chunkIndex: 0,
        startChar: 0,
        endChar: 18,
        tokens: 4,
        embedding: new Array(1536).fill(0).map(() => Math.random()),
      },
    ]),
  })),
}));

describe('KB API Integration Tests', () => {
  let app: Application;

  beforeAll(async () => {
    app = createApp();
  });

  describe('Health Endpoints', () => {
    it('GET /health should return health status', async () => {
      const response = await request(app).get('/health').expect(200);

      expect(response.body).toHaveProperty('status');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('services');
    });

    it('GET /ready should return readiness status', async () => {
      const response = await request(app).get('/ready').expect(200);

      expect(response.body).toHaveProperty('status', 'ready');
      expect(response.body).toHaveProperty('timestamp');
    });

    it('GET /live should return liveness status', async () => {
      const response = await request(app).get('/live').expect(200);

      expect(response.body).toHaveProperty('status', 'alive');
      expect(response.body).toHaveProperty('timestamp');
    });
  });

  describe('Root Endpoint', () => {
    it('GET / should return API information', async () => {
      const response = await request(app).get('/').expect(200);

      expect(response.body).toHaveProperty('name');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('endpoints');
    });
  });

  describe('Document Endpoints', () => {
    it('GET /api/v1/kb/documents should return document list', async () => {
      const response = await request(app)
        .get('/api/v1/kb/documents')
        .expect(200);

      expect(response.body).toHaveProperty('documents');
      expect(response.body).toHaveProperty('total');
      expect(response.body).toHaveProperty('limit');
      expect(response.body).toHaveProperty('offset');
      expect(Array.isArray(response.body.documents)).toBe(true);
    });

    it('GET /api/v1/kb/documents/:id should return 404 for non-existent document', async () => {
      const response = await request(app)
        .get('/api/v1/kb/documents/non-existent-id')
        .expect(404);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toHaveProperty('code', 'DOCUMENT_NOT_FOUND');
    });

    it('POST /api/v1/kb/documents should require file', async () => {
      const response = await request(app)
        .post('/api/v1/kb/documents')
        .expect(400);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toHaveProperty('code', 'NO_FILE');
    });
  });

  describe('Search Endpoints', () => {
    it('POST /api/v1/kb/search should perform semantic search', async () => {
      const response = await request(app)
        .post('/api/v1/kb/search')
        .send({
          query: 'test query',
          limit: 10,
        })
        .expect(200);

      expect(response.body).toHaveProperty('query');
      expect(response.body).toHaveProperty('results');
      expect(response.body).toHaveProperty('total');
      expect(response.body).toHaveProperty('processingTimeMs');
      expect(Array.isArray(response.body.results)).toBe(true);
    });

    it('POST /api/v1/kb/search should validate query parameter', async () => {
      const response = await request(app)
        .post('/api/v1/kb/search')
        .send({
          query: '',
          limit: 10,
        })
        .expect(400);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toHaveProperty('code', 'VALIDATION_ERROR');
    });

    it('POST /api/v1/kb/search should use default limit', async () => {
      const response = await request(app)
        .post('/api/v1/kb/search')
        .send({
          query: 'test query',
        })
        .expect(200);

      expect(response.body.limit).toBe(10);
    });

    it('POST /api/v1/kb/search/embed should generate embeddings', async () => {
      const response = await request(app)
        .post('/api/v1/kb/search/embed')
        .send({
          text: 'test text',
        })
        .expect(200);

      expect(response.body).toHaveProperty('embedding');
      expect(response.body).toHaveProperty('dimensions');
      expect(response.body).toHaveProperty('model');
      expect(response.body).toHaveProperty('tokens');
      expect(Array.isArray(response.body.embedding)).toBe(true);
    });

    it('POST /api/v1/kb/search/batch should handle batch search', async () => {
      const response = await request(app)
        .post('/api/v1/kb/search/batch')
        .send({
          queries: ['query 1', 'query 2', 'query 3'],
        })
        .expect(200);

      expect(response.body).toHaveProperty('results');
      expect(response.body).toHaveProperty('total');
      expect(Array.isArray(response.body.results)).toBe(true);
      expect(response.body.results.length).toBe(3);
    });

    it('POST /api/v1/kb/search/batch should reject empty queries', async () => {
      const response = await request(app)
        .post('/api/v1/kb/search/batch')
        .send({
          queries: [],
        })
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });

    it('GET /api/v1/kb/search/stats should return statistics', async () => {
      const response = await request(app)
        .get('/api/v1/kb/search/stats')
        .expect(200);

      expect(response.body).toHaveProperty('totalVectors');
      expect(response.body).toHaveProperty('collectionInfo');
    });
  });

  describe('Error Handling', () => {
    it('should return 404 for non-existent routes', async () => {
      const response = await request(app)
        .get('/api/v1/kb/nonexistent')
        .expect(404);

      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toHaveProperty('code', 'ROUTE_NOT_FOUND');
    });

    it('should handle invalid JSON', async () => {
      const response = await request(app)
        .post('/api/v1/kb/search')
        .set('Content-Type', 'application/json')
        .send('invalid json')
        .expect(400);
    });
  });

  describe('CORS', () => {
    it('should include CORS headers', async () => {
      const response = await request(app)
        .options('/api/v1/kb/search')
        .expect(204);

      expect(response.headers).toHaveProperty('access-control-allow-origin');
      expect(response.headers).toHaveProperty('access-control-allow-methods');
    });
  });

  describe('Security Headers', () => {
    it('should include security headers', async () => {
      const response = await request(app).get('/').expect(200);

      expect(response.headers).toHaveProperty('x-content-type-options');
      expect(response.headers).toHaveProperty('x-frame-options');
    });
  });
});

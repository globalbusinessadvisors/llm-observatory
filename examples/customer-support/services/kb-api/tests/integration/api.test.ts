import request from 'supertest';
import { Application } from 'express';
import { createApp, AppDependencies } from '../../src/app';
import { DocumentService } from '../../src/services/DocumentService';
import { EmbeddingService } from '../../src/services/EmbeddingService';
import { QdrantService } from '../../src/services/QdrantService';
import { SearchService } from '../../src/services/SearchService';

// Mock services
jest.mock('../../src/services/QdrantService');
jest.mock('../../src/services/EmbeddingService');
jest.mock('../../src/services/DocumentService');
jest.mock('../../src/services/SearchService');

describe('API Integration Tests', () => {
  let app: Application;
  let dependencies: AppDependencies;

  beforeAll(() => {
    const qdrantService = new QdrantService() as jest.Mocked<QdrantService>;
    const embeddingService = new EmbeddingService() as jest.Mocked<EmbeddingService>;
    const documentService = new DocumentService(embeddingService, qdrantService) as jest.Mocked<DocumentService>;
    const searchService = new SearchService(embeddingService, qdrantService) as jest.Mocked<SearchService>;

    dependencies = {
      qdrantService,
      embeddingService,
      documentService,
      searchService,
    };

    app = createApp(dependencies);
  });

  describe('GET /', () => {
    it('should return service information', async () => {
      const response = await request(app).get('/');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('service');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('endpoints');
    });
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      dependencies.qdrantService.healthCheck = jest.fn().mockResolvedValue(true);

      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status');
      expect(response.body).toHaveProperty('checks');
    });
  });

  describe('POST /v1/search', () => {
    it('should perform search with valid query', async () => {
      const mockSearchResult = {
        results: [
          {
            id: 'chunk_1',
            documentId: 'doc_1',
            score: 0.85,
            content: 'Test content',
            metadata: {
              documentTitle: 'Test Doc',
              filename: 'test.pdf',
              chunkIndex: 0,
              createdAt: new Date().toISOString(),
            },
          },
        ],
        total: 1,
        query: 'test query',
        limit: 10,
        scoreThreshold: 0.7,
        took: 100,
      };

      dependencies.searchService.search = jest.fn().mockResolvedValue(mockSearchResult);

      const response = await request(app).post('/v1/search').send({
        query: 'test query',
        limit: 10,
      });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('results');
      expect(dependencies.searchService.search).toHaveBeenCalled();
    });

    it('should return 400 for invalid search request', async () => {
      const response = await request(app).post('/v1/search').send({
        // Missing required 'query' field
        limit: 10,
      });

      expect(response.status).toBe(400);
    });
  });

  describe('GET /v1/documents', () => {
    it('should list documents', async () => {
      const mockListResult = {
        documents: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 0,
      };

      dependencies.documentService.listDocuments = jest.fn().mockResolvedValue(mockListResult);

      const response = await request(app).get('/v1/documents');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('documents');
    });
  });

  describe('POST /v1/embed', () => {
    it('should generate embeddings', async () => {
      const mockEmbedResult = {
        embeddings: [[0.1, 0.2, 0.3]],
        model: 'text-embedding-3-small',
        dimensions: 3,
        tokensUsed: 10,
      };

      dependencies.embeddingService.generateEmbeddings = jest.fn().mockResolvedValue(mockEmbedResult);

      const response = await request(app).post('/v1/embed').send({
        texts: ['test text'],
      });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('embeddings');
      expect(dependencies.embeddingService.generateEmbeddings).toHaveBeenCalled();
    });

    it('should return 400 for empty texts array', async () => {
      const response = await request(app).post('/v1/embed').send({
        texts: [],
      });

      expect(response.status).toBe(400);
    });
  });

  describe('404 handler', () => {
    it('should return 404 for unknown routes', async () => {
      const response = await request(app).get('/unknown-route');

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error.code).toBe('NOT_FOUND');
    });
  });
});

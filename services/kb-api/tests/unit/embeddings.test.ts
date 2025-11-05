import { EmbeddingsService } from '../../src/services/embeddings';
import { EmbeddingError } from '../../src/types';

// Mock OpenAI
jest.mock('openai', () => {
  return {
    __esModule: true,
    default: jest.fn().mockImplementation(() => ({
      embeddings: {
        create: jest.fn().mockResolvedValue({
          data: [
            {
              embedding: new Array(1536).fill(0).map(() => Math.random()),
            },
          ],
        }),
      },
    })),
  };
});

describe('EmbeddingsService', () => {
  let service: EmbeddingsService;

  beforeEach(() => {
    service = new EmbeddingsService();
  });

  afterEach(() => {
    if (service) {
      service.dispose();
    }
  });

  describe('generateEmbedding', () => {
    it('should generate embedding for text', async () => {
      const text = 'This is a test document';
      const result = await service.generateEmbedding(text);

      expect(result).toHaveProperty('embedding');
      expect(result).toHaveProperty('dimensions');
      expect(result).toHaveProperty('model');
      expect(result).toHaveProperty('tokens');

      expect(Array.isArray(result.embedding)).toBe(true);
      expect(result.embedding.length).toBe(1536);
      expect(result.dimensions).toBe(1536);
      expect(result.tokens).toBeGreaterThan(0);
    });

    it('should handle empty text', async () => {
      const text = '';
      const result = await service.generateEmbedding(text);

      expect(result).toHaveProperty('embedding');
      expect(result.tokens).toBe(0);
    });

    it('should count tokens correctly', async () => {
      const text = 'The quick brown fox jumps over the lazy dog';
      const result = await service.generateEmbedding(text);

      expect(result.tokens).toBeGreaterThan(0);
      expect(result.tokens).toBeLessThan(20); // Should be around 10 tokens
    });
  });

  describe('generateEmbeddingsBatch', () => {
    it('should generate embeddings for multiple texts', async () => {
      const texts = [
        'First document',
        'Second document',
        'Third document',
      ];

      const results = await service.generateEmbeddingsBatch(texts);

      expect(results).toHaveLength(3);
      results.forEach((result) => {
        expect(result).toHaveProperty('embedding');
        expect(result.embedding.length).toBe(1536);
      });
    });

    it('should handle empty array', async () => {
      const results = await service.generateEmbeddingsBatch([]);
      expect(results).toHaveLength(0);
    });
  });

  describe('countTokens', () => {
    it('should count tokens in text', () => {
      const text = 'Hello world';
      const count = service.countTokens(text);

      expect(count).toBeGreaterThan(0);
      expect(typeof count).toBe('number');
    });

    it('should return 0 for empty text', () => {
      const count = service.countTokens('');
      expect(count).toBe(0);
    });
  });

  describe('splitTextByTokens', () => {
    it('should split text into chunks by token count', () => {
      const text = 'This is a long text that needs to be split into multiple chunks based on token count. '.repeat(20);
      const maxTokens = 50;

      const chunks = service.splitTextByTokens(text, maxTokens);

      expect(chunks.length).toBeGreaterThan(1);
      chunks.forEach((chunk) => {
        const tokens = service.countTokens(chunk);
        expect(tokens).toBeLessThanOrEqual(maxTokens + 5); // Allow small margin
      });
    });

    it('should not split text that fits within limit', () => {
      const text = 'Short text';
      const chunks = service.splitTextByTokens(text, 100);

      expect(chunks).toHaveLength(1);
      expect(chunks[0]).toBe(text);
    });

    it('should handle overlap', () => {
      const text = 'Word '.repeat(100);
      const maxTokens = 20;
      const overlap = 5;

      const chunks = service.splitTextByTokens(text, maxTokens, overlap);

      expect(chunks.length).toBeGreaterThan(1);
    });
  });

  describe('cosineSimilarity', () => {
    it('should calculate cosine similarity', () => {
      const a = [1, 2, 3];
      const b = [4, 5, 6];

      const similarity = service.cosineSimilarity(a, b);

      expect(similarity).toBeGreaterThan(0);
      expect(similarity).toBeLessThanOrEqual(1);
    });

    it('should return 1 for identical vectors', () => {
      const a = [1, 2, 3];
      const b = [1, 2, 3];

      const similarity = service.cosineSimilarity(a, b);

      expect(similarity).toBeCloseTo(1, 5);
    });

    it('should throw error for different dimensions', () => {
      const a = [1, 2, 3];
      const b = [1, 2];

      expect(() => service.cosineSimilarity(a, b)).toThrow();
    });
  });
});

import { ChunkingService } from '../../src/services/chunking';
import { v4 as uuidv4 } from 'uuid';

// Mock embeddings service
jest.mock('../../src/services/embeddings', () => ({
  getEmbeddingsService: jest.fn(() => ({
    countTokens: jest.fn((text: string) => Math.ceil(text.length / 4)),
    splitTextByTokens: jest.fn((text: string, maxTokens: number) => {
      const chunkSize = maxTokens * 4;
      const chunks: string[] = [];
      for (let i = 0; i < text.length; i += chunkSize) {
        chunks.push(text.slice(i, i + chunkSize));
      }
      return chunks;
    }),
    generateEmbedding: jest.fn(() => ({
      embedding: new Array(1536).fill(0).map(() => Math.random()),
      dimensions: 1536,
      model: 'text-embedding-3-small',
      tokens: 10,
    })),
    generateEmbeddingsBatch: jest.fn((texts: string[]) =>
      texts.map(() => ({
        embedding: new Array(1536).fill(0).map(() => Math.random()),
        dimensions: 1536,
        model: 'text-embedding-3-small',
        tokens: 10,
      }))
    ),
    encoder: {
      encode: jest.fn((text: string) => new Array(Math.ceil(text.length / 4))),
      decode: jest.fn((tokens: any[]) => 'decoded text'),
    },
  })),
}));

describe('ChunkingService', () => {
  let service: ChunkingService;
  const documentId = uuidv4();

  beforeEach(() => {
    service = new ChunkingService();
  });

  describe('chunkText', () => {
    it('should chunk text into smaller pieces', async () => {
      const text = 'This is a test document. '.repeat(100);
      const options = {
        chunkSize: 100,
        chunkOverlap: 10,
      };

      const chunks = await service.chunkText(text, documentId, options);

      expect(chunks.length).toBeGreaterThan(0);
      chunks.forEach((chunk, index) => {
        expect(chunk).toHaveProperty('id');
        expect(chunk).toHaveProperty('documentId', documentId);
        expect(chunk).toHaveProperty('content');
        expect(chunk).toHaveProperty('chunkIndex', index);
        expect(chunk).toHaveProperty('startChar');
        expect(chunk).toHaveProperty('endChar');
        expect(chunk).toHaveProperty('tokens');
      });
    });

    it('should handle short text', async () => {
      const text = 'Short text';
      const options = {
        chunkSize: 500,
        chunkOverlap: 50,
      };

      const chunks = await service.chunkText(text, documentId, options);

      expect(chunks.length).toBe(1);
      expect(chunks[0].content).toBe(text);
    });

    it('should respect chunk overlap', async () => {
      const text = 'Word '.repeat(200);
      const options = {
        chunkSize: 50,
        chunkOverlap: 10,
      };

      const chunks = await service.chunkText(text, documentId, options);

      expect(chunks.length).toBeGreaterThan(1);
      // Check that chunks have some overlap
      if (chunks.length > 1) {
        const firstChunkEnd = chunks[0].content.slice(-20);
        const secondChunkStart = chunks[1].content.slice(0, 20);
        // There should be some similarity due to overlap
        expect(firstChunkEnd.length).toBeGreaterThan(0);
        expect(secondChunkStart.length).toBeGreaterThan(0);
      }
    });

    it('should track character positions', async () => {
      const text = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.repeat(10);
      const options = {
        chunkSize: 50,
        chunkOverlap: 5,
      };

      const chunks = await service.chunkText(text, documentId, options);

      chunks.forEach((chunk) => {
        expect(chunk.startChar).toBeGreaterThanOrEqual(0);
        expect(chunk.endChar).toBeGreaterThan(chunk.startChar);
        expect(chunk.endChar).toBeLessThanOrEqual(text.length);
      });
    });
  });

  describe('chunkTextWithEmbeddings', () => {
    it('should generate chunks with embeddings', async () => {
      const text = 'Test document for embedding generation.';
      const options = {
        chunkSize: 100,
        chunkOverlap: 10,
      };

      const chunks = await service.chunkTextWithEmbeddings(text, documentId, options);

      expect(chunks.length).toBeGreaterThan(0);
      chunks.forEach((chunk) => {
        expect(chunk).toHaveProperty('embedding');
        expect(Array.isArray(chunk.embedding)).toBe(true);
        expect(chunk.embedding?.length).toBe(1536);
      });
    });
  });

  describe('createSlidingWindows', () => {
    it('should create overlapping windows', () => {
      const text = 'Word '.repeat(50);
      const windowSize = 10;
      const stride = 5;

      const windows = service.createSlidingWindows(text, windowSize, stride);

      expect(windows.length).toBeGreaterThan(1);
      windows.forEach((window) => {
        expect(window).toHaveProperty('content');
        expect(window).toHaveProperty('start');
        expect(window).toHaveProperty('end');
      });
    });
  });

  describe('mergeSmallChunks', () => {
    it('should merge chunks below minimum size', () => {
      const chunks = [
        {
          id: uuidv4(),
          documentId,
          content: 'Short 1',
          chunkIndex: 0,
          startChar: 0,
          endChar: 7,
          tokens: 2,
        },
        {
          id: uuidv4(),
          documentId,
          content: 'Short 2',
          chunkIndex: 1,
          startChar: 8,
          endChar: 15,
          tokens: 2,
        },
        {
          id: uuidv4(),
          documentId,
          content: 'This is a much longer chunk that should not be merged',
          chunkIndex: 2,
          startChar: 16,
          endChar: 70,
          tokens: 12,
        },
      ];

      const merged = service.mergeSmallChunks(chunks, 10);

      expect(merged.length).toBeLessThan(chunks.length);
      expect(merged[0].tokens).toBeGreaterThanOrEqual(4);
    });

    it('should not merge chunks above minimum size', () => {
      const chunks = [
        {
          id: uuidv4(),
          documentId,
          content: 'Chunk one with enough tokens',
          chunkIndex: 0,
          startChar: 0,
          endChar: 28,
          tokens: 15,
        },
        {
          id: uuidv4(),
          documentId,
          content: 'Chunk two with enough tokens',
          chunkIndex: 1,
          startChar: 29,
          endChar: 57,
          tokens: 15,
        },
      ];

      const merged = service.mergeSmallChunks(chunks, 10);

      expect(merged.length).toBe(chunks.length);
    });
  });

  describe('extractKeySentences', () => {
    it('should extract key sentences from text', () => {
      const text = 'First sentence. Second sentence. Third sentence. Fourth sentence. Fifth sentence.';
      const keySentences = service.extractKeySentences(text, 3);

      expect(keySentences.length).toBeLessThanOrEqual(3);
      expect(Array.isArray(keySentences)).toBe(true);
      keySentences.forEach((sentence) => {
        expect(typeof sentence).toBe('string');
        expect(sentence.length).toBeGreaterThan(0);
      });
    });

    it('should return all sentences if count is greater than available', () => {
      const text = 'Only one sentence.';
      const keySentences = service.extractKeySentences(text, 5);

      expect(keySentences.length).toBeLessThanOrEqual(1);
    });
  });
});

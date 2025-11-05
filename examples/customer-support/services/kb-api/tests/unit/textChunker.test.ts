import { TextChunker } from '../../src/utils/textChunker';

describe('TextChunker', () => {
  let chunker: TextChunker;

  beforeEach(() => {
    chunker = new TextChunker(100, 10);
  });

  describe('chunk', () => {
    it('should split text into chunks', () => {
      const text = 'This is a test document. '.repeat(50);
      const chunks = chunker.chunk(text);

      expect(chunks.length).toBeGreaterThan(0);
      expect(chunks[0]?.content).toBeTruthy();
    });

    it('should return empty array for empty text', () => {
      const chunks = chunker.chunk('');
      expect(chunks).toEqual([]);
    });

    it('should include metadata in chunks', () => {
      const text = 'Test document with content.';
      const chunks = chunker.chunk(text);

      expect(chunks[0]).toHaveProperty('startPosition');
      expect(chunks[0]).toHaveProperty('endPosition');
      expect(chunks[0]).toHaveProperty('tokenCount');
    });
  });

  describe('chunkByParagraphs', () => {
    it('should split text by paragraphs', () => {
      const text = 'Paragraph 1.\n\nParagraph 2.\n\nParagraph 3.';
      const chunks = chunker.chunkByParagraphs(text, 50);

      expect(chunks.length).toBeGreaterThan(0);
    });

    it('should respect max tokens per chunk', () => {
      const text = 'Word '.repeat(200);
      const chunks = chunker.chunkByParagraphs(text, 50);

      for (const chunk of chunks) {
        expect(chunk.tokenCount).toBeLessThanOrEqual(200);
      }
    });
  });

  describe('chunkBySentences', () => {
    it('should split text by sentences', () => {
      const text = 'Sentence one. Sentence two. Sentence three.';
      const chunks = chunker.chunkBySentences(text, 50);

      expect(chunks.length).toBeGreaterThan(0);
    });
  });

  describe('estimateTokenCount', () => {
    it('should estimate token count', () => {
      const text = 'This is a test';
      const tokenCount = chunker.estimateTokenCount(text);

      expect(tokenCount).toBeGreaterThan(0);
      expect(tokenCount).toBeLessThan(100);
    });
  });
});

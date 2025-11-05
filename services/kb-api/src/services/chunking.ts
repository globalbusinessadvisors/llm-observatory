import { v4 as uuidv4 } from 'uuid';
import { RecursiveCharacterTextSplitter } from 'langchain/text_splitter';
import { getEmbeddingsService } from './embeddings';
import logger from '../utils/logger';
import { Chunk, ChunkingError } from '../types';
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('kb-api-chunking');

export interface ChunkingOptions {
  chunkSize: number;
  chunkOverlap: number;
  separators?: string[];
  keepSeparator?: boolean;
}

export class ChunkingService {
  private embeddingsService = getEmbeddingsService();

  /**
   * Split text into chunks based on token count
   */
  async chunkText(
    text: string,
    documentId: string,
    options: ChunkingOptions,
  ): Promise<Chunk[]> {
    return tracer.startActiveSpan('chunking.chunk_text', async (span) => {
      try {
        span.setAttribute('document.id', documentId);
        span.setAttribute('text.length', text.length);
        span.setAttribute('chunk.size', options.chunkSize);
        span.setAttribute('chunk.overlap', options.chunkOverlap);

        logger.debug('Starting text chunking', {
          documentId,
          textLength: text.length,
          chunkSize: options.chunkSize,
          chunkOverlap: options.chunkOverlap,
        });

        // Use LangChain's text splitter for smart chunking
        const splitter = new RecursiveCharacterTextSplitter({
          chunkSize: options.chunkSize * 4, // Approximate chars per token
          chunkOverlap: options.chunkOverlap * 4,
          separators: options.separators || ['\n\n', '\n', '. ', '! ', '? ', '; ', ', ', ' ', ''],
          keepSeparator: options.keepSeparator ?? false,
        });

        const textChunks = await splitter.splitText(text);

        logger.debug('Text split into chunks', {
          documentId,
          chunksCount: textChunks.length,
        });

        // Create chunk objects with metadata
        const chunks: Chunk[] = [];
        let currentPosition = 0;

        for (let i = 0; i < textChunks.length; i++) {
          const content = textChunks[i];
          const startChar = text.indexOf(content, currentPosition);
          const endChar = startChar + content.length;

          // Count tokens for this chunk
          const tokens = this.embeddingsService.countTokens(content);

          // Validate chunk size
          if (tokens > options.chunkSize * 1.5) {
            logger.warn('Chunk exceeds size limit, will be split further', {
              documentId,
              chunkIndex: i,
              tokens,
              limit: options.chunkSize,
            });

            // Split oversized chunk by tokens
            const subChunks = this.embeddingsService.splitTextByTokens(
              content,
              options.chunkSize,
              options.chunkOverlap,
            );

            for (let j = 0; j < subChunks.length; j++) {
              const subContent = subChunks[j];
              const subStartChar = text.indexOf(subContent, currentPosition);
              const subEndChar = subStartChar + subContent.length;
              const subTokens = this.embeddingsService.countTokens(subContent);

              chunks.push({
                id: uuidv4(),
                documentId,
                content: subContent,
                chunkIndex: chunks.length,
                startChar: subStartChar,
                endChar: subEndChar,
                tokens: subTokens,
                metadata: {
                  isSubChunk: true,
                  parentChunkIndex: i,
                  subChunkIndex: j,
                },
              });

              currentPosition = subEndChar;
            }
          } else {
            chunks.push({
              id: uuidv4(),
              documentId,
              content,
              chunkIndex: i,
              startChar,
              endChar,
              tokens,
            });

            currentPosition = endChar;
          }
        }

        span.setAttribute('chunks.count', chunks.length);
        span.setAttribute('chunks.avg_tokens',
          chunks.reduce((sum, c) => sum + c.tokens, 0) / chunks.length
        );
        span.setStatus({ code: SpanStatusCode.OK });

        logger.info('Text chunking completed', {
          documentId,
          chunksCount: chunks.length,
          avgTokens: Math.round(chunks.reduce((sum, c) => sum + c.tokens, 0) / chunks.length),
          minTokens: Math.min(...chunks.map((c) => c.tokens)),
          maxTokens: Math.max(...chunks.map((c) => c.tokens)),
        });

        return chunks;
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });

        logger.error('Text chunking failed', {
          documentId,
          error: error instanceof Error ? error.message : String(error),
        });

        throw new ChunkingError(
          'Failed to chunk text',
          error instanceof Error ? error : undefined,
        );
      } finally {
        span.end();
      }
    });
  }

  /**
   * Chunk text with embeddings
   */
  async chunkTextWithEmbeddings(
    text: string,
    documentId: string,
    options: ChunkingOptions,
  ): Promise<Chunk[]> {
    return tracer.startActiveSpan('chunking.chunk_with_embeddings', async (span) => {
      try {
        // First, chunk the text
        const chunks = await this.chunkText(text, documentId, options);

        span.setAttribute('chunks.count', chunks.length);
        logger.debug('Generating embeddings for chunks', {
          documentId,
          count: chunks.length,
        });

        // Generate embeddings for all chunks
        const embeddings = await this.embeddingsService.generateEmbeddingsBatch(
          chunks.map((c) => c.content),
        );

        // Attach embeddings to chunks
        for (let i = 0; i < chunks.length; i++) {
          chunks[i].embedding = embeddings[i].embedding;
        }

        span.setStatus({ code: SpanStatusCode.OK });
        logger.info('Chunks with embeddings generated', {
          documentId,
          count: chunks.length,
        });

        return chunks;
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });

        logger.error('Failed to chunk text with embeddings', {
          documentId,
          error: error instanceof Error ? error.message : String(error),
        });

        throw error;
      } finally {
        span.end();
      }
    });
  }

  /**
   * Create overlapping windows for better context preservation
   */
  createSlidingWindows(
    text: string,
    windowSize: number,
    stride: number,
  ): { content: string; start: number; end: number }[] {
    const windows: { content: string; start: number; end: number }[] = [];
    const tokens = this.embeddingsService.encoder.encode(text);

    for (let i = 0; i < tokens.length; i += stride) {
      const windowTokens = tokens.slice(i, i + windowSize);
      const content = this.embeddingsService.encoder.decode(windowTokens);

      windows.push({
        content,
        start: i,
        end: i + windowTokens.length,
      });

      // Stop if we've reached the end
      if (i + windowSize >= tokens.length) break;
    }

    return windows;
  }

  /**
   * Merge small chunks to optimize storage and retrieval
   */
  mergeSmallChunks(chunks: Chunk[], minTokens: number): Chunk[] {
    const merged: Chunk[] = [];
    let currentChunk: Chunk | null = null;

    for (const chunk of chunks) {
      if (!currentChunk) {
        currentChunk = { ...chunk };
        continue;
      }

      if (currentChunk.tokens < minTokens) {
        // Merge with previous chunk
        currentChunk.content += '\n' + chunk.content;
        currentChunk.endChar = chunk.endChar;
        currentChunk.tokens += chunk.tokens;

        if (currentChunk.embedding && chunk.embedding) {
          // Average embeddings (simple approach)
          currentChunk.embedding = currentChunk.embedding.map(
            (val, idx) => (val + chunk.embedding![idx]) / 2,
          );
        }
      } else {
        merged.push(currentChunk);
        currentChunk = { ...chunk };
      }
    }

    if (currentChunk) {
      merged.push(currentChunk);
    }

    return merged;
  }

  /**
   * Extract key sentences from text for better chunking boundaries
   */
  extractKeySentences(text: string, count: number = 5): string[] {
    const sentences = text.split(/[.!?]+/).filter((s) => s.trim().length > 0);

    if (sentences.length <= count) {
      return sentences.map((s) => s.trim());
    }

    // Simple extraction based on length and position
    // In production, you might want to use a more sophisticated approach (e.g., TextRank)
    const scoredSentences = sentences.map((sentence, index) => {
      const positionScore = 1 - Math.abs(index - sentences.length / 2) / sentences.length;
      const lengthScore = Math.min(sentence.length / 100, 1);
      return {
        sentence: sentence.trim(),
        score: positionScore * 0.3 + lengthScore * 0.7,
      };
    });

    return scoredSentences
      .sort((a, b) => b.score - a.score)
      .slice(0, count)
      .map((s) => s.sentence);
  }
}

// Singleton instance
let chunkingServiceInstance: ChunkingService | null = null;

export const getChunkingService = (): ChunkingService => {
  if (!chunkingServiceInstance) {
    chunkingServiceInstance = new ChunkingService();
  }
  return chunkingServiceInstance;
};

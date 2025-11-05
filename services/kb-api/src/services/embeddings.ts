import OpenAI from 'openai';
import { encoding_for_model, TiktokenModel } from 'tiktoken';
import { openaiConfig } from '../config';
import logger from '../utils/logger';
import { EmbeddingError, EmbeddingResponse } from '../types';
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('kb-api-embeddings');

export class EmbeddingsService {
  private client: OpenAI;
  private encoder: ReturnType<typeof encoding_for_model>;
  private model: string;

  constructor() {
    this.client = new OpenAI({
      apiKey: openaiConfig.apiKey,
      timeout: openaiConfig.timeout,
    });
    this.model = openaiConfig.embeddingModel;

    try {
      // Try to get encoder for the specific model, fallback to gpt-3.5-turbo
      this.encoder = encoding_for_model(this.model as TiktokenModel);
    } catch (error) {
      logger.warn(`Failed to get encoder for model ${this.model}, using cl100k_base`, { error });
      this.encoder = encoding_for_model('gpt-3.5-turbo');
    }
  }

  /**
   * Generate embeddings for a single text
   */
  async generateEmbedding(text: string): Promise<EmbeddingResponse> {
    return tracer.startActiveSpan('embeddings.generate', async (span) => {
      try {
        const startTime = Date.now();

        // Count tokens
        const tokens = this.countTokens(text);
        span.setAttribute('text.tokens', tokens);
        span.setAttribute('embedding.model', this.model);

        logger.debug('Generating embedding', {
          textLength: text.length,
          tokens,
          model: this.model,
        });

        // Validate token count
        if (tokens > openaiConfig.maxTokens) {
          throw new EmbeddingError(
            `Text exceeds maximum token limit: ${tokens} > ${openaiConfig.maxTokens}`,
          );
        }

        // Generate embedding
        const response = await this.client.embeddings.create({
          model: this.model,
          input: text,
          encoding_format: 'float',
        });

        const embedding = response.data[0].embedding;
        const duration = Date.now() - startTime;

        span.setAttribute('embedding.dimensions', embedding.length);
        span.setAttribute('embedding.duration_ms', duration);
        span.setStatus({ code: SpanStatusCode.OK });

        logger.debug('Embedding generated successfully', {
          dimensions: embedding.length,
          tokens,
          durationMs: duration,
        });

        return {
          embedding,
          dimensions: embedding.length,
          model: this.model,
          tokens,
        };
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });

        logger.error('Failed to generate embedding', {
          error: error instanceof Error ? error.message : String(error),
        });

        if (error instanceof OpenAI.APIError) {
          throw new EmbeddingError(
            `OpenAI API error: ${error.message}`,
            error,
          );
        }

        throw new EmbeddingError(
          'Failed to generate embedding',
          error instanceof Error ? error : undefined,
        );
      } finally {
        span.end();
      }
    });
  }

  /**
   * Generate embeddings for multiple texts in batch
   */
  async generateEmbeddingsBatch(texts: string[]): Promise<EmbeddingResponse[]> {
    return tracer.startActiveSpan('embeddings.generate_batch', async (span) => {
      try {
        span.setAttribute('batch.size', texts.length);

        logger.debug('Generating embeddings batch', { count: texts.length });

        // OpenAI supports batching, but we'll process in smaller batches to avoid limits
        const batchSize = 100;
        const results: EmbeddingResponse[] = [];

        for (let i = 0; i < texts.length; i += batchSize) {
          const batch = texts.slice(i, i + batchSize);
          const batchResults = await Promise.all(
            batch.map((text) => this.generateEmbedding(text)),
          );
          results.push(...batchResults);
        }

        span.setStatus({ code: SpanStatusCode.OK });
        logger.debug('Batch embeddings generated successfully', {
          count: results.length,
        });

        return results;
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });

        logger.error('Failed to generate batch embeddings', {
          error: error instanceof Error ? error.message : String(error),
        });

        throw error;
      } finally {
        span.end();
      }
    });
  }

  /**
   * Count tokens in text
   */
  countTokens(text: string): number {
    try {
      const tokens = this.encoder.encode(text);
      return tokens.length;
    } catch (error) {
      logger.warn('Failed to count tokens, using approximation', { error });
      // Fallback: rough approximation (1 token ≈ 4 characters)
      return Math.ceil(text.length / 4);
    }
  }

  /**
   * Split text to fit within token limit
   */
  splitTextByTokens(text: string, maxTokens: number, overlap: number = 0): string[] {
    const tokens = this.encoder.encode(text);

    if (tokens.length <= maxTokens) {
      return [text];
    }

    const chunks: string[] = [];
    let start = 0;

    while (start < tokens.length) {
      const end = Math.min(start + maxTokens, tokens.length);
      const chunkTokens = tokens.slice(start, end);
      const chunkText = this.encoder.decode(chunkTokens);
      chunks.push(chunkText);

      // Move to next chunk with overlap
      start += maxTokens - overlap;
    }

    return chunks;
  }

  /**
   * Calculate cosine similarity between two embeddings
   */
  cosineSimilarity(a: number[], b: number[]): number {
    if (a.length !== b.length) {
      throw new Error('Embeddings must have the same dimensions');
    }

    let dotProduct = 0;
    let normA = 0;
    let normB = 0;

    for (let i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
  }

  /**
   * Cleanup resources
   */
  dispose(): void {
    this.encoder.free();
  }
}

// Singleton instance
let embeddingsServiceInstance: EmbeddingsService | null = null;

export const getEmbeddingsService = (): EmbeddingsService => {
  if (!embeddingsServiceInstance) {
    embeddingsServiceInstance = new EmbeddingsService();
  }
  return embeddingsServiceInstance;
};

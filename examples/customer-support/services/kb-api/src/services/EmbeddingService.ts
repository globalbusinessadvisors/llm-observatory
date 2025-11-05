import OpenAI from 'openai';
import { config } from '../config';
import logger from '../utils/logger';
import { InternalServerError, ServiceUnavailableError } from '../middleware/errorHandler';

export interface EmbeddingResult {
  embeddings: number[][];
  model: string;
  dimensions: number;
  tokensUsed: number;
}

export class EmbeddingService {
  private client: OpenAI;
  private model: string;

  constructor() {
    this.client = new OpenAI({
      apiKey: config.openai.apiKey,
    });
    this.model = config.openai.embeddingModel;
  }

  async generateEmbeddings(texts: string[]): Promise<EmbeddingResult> {
    if (texts.length === 0) {
      throw new InternalServerError('No texts provided for embedding generation');
    }

    try {
      logger.debug(`Generating embeddings for ${texts.length} texts`);

      const response = await this.client.embeddings.create({
        model: this.model,
        input: texts,
        encoding_format: 'float',
      });

      const embeddings = response.data.map((item) => item.embedding);
      const dimensions = embeddings[0]?.length || config.openai.embeddingDimensions;
      const tokensUsed = response.usage.total_tokens;

      logger.debug(`Generated ${embeddings.length} embeddings`, {
        dimensions,
        tokensUsed,
      });

      return {
        embeddings,
        model: response.model,
        dimensions,
        tokensUsed,
      };
    } catch (error) {
      if (error instanceof Error) {
        if (error.message.includes('API key')) {
          logger.error('OpenAI API key error', { error });
          throw new ServiceUnavailableError('OpenAI');
        }
        if (error.message.includes('rate limit')) {
          logger.error('OpenAI rate limit exceeded', { error });
          throw new ServiceUnavailableError('OpenAI');
        }
      }

      logger.error('Failed to generate embeddings', { error });
      throw new InternalServerError('Failed to generate embeddings');
    }
  }

  async generateEmbedding(text: string): Promise<number[]> {
    const result = await this.generateEmbeddings([text]);
    return result.embeddings[0] || [];
  }

  async batchEmbeddings(
    texts: string[],
    batchSize: number = 100
  ): Promise<EmbeddingResult> {
    const batches: string[][] = [];
    for (let i = 0; i < texts.length; i += batchSize) {
      batches.push(texts.slice(i, i + batchSize));
    }

    logger.debug(`Processing ${batches.length} batches of embeddings`);

    const results: EmbeddingResult[] = [];
    let totalTokensUsed = 0;

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      if (!batch) continue;

      logger.debug(`Processing batch ${i + 1}/${batches.length}`);
      const result = await this.generateEmbeddings(batch);
      results.push(result);
      totalTokensUsed += result.tokensUsed;

      // Add a small delay between batches to avoid rate limits
      if (i < batches.length - 1) {
        await new Promise((resolve) => setTimeout(resolve, 100));
      }
    }

    const allEmbeddings = results.flatMap((r) => r.embeddings);
    const model = results[0]?.model || this.model;
    const dimensions = results[0]?.dimensions || config.openai.embeddingDimensions;

    return {
      embeddings: allEmbeddings,
      model,
      dimensions,
      tokensUsed: totalTokensUsed,
    };
  }

  estimateTokens(text: string): number {
    // Rough estimation: 1 token ≈ 4 characters
    // This is a simplification; actual tokenization varies
    return Math.ceil(text.length / 4);
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.generateEmbedding('test');
      return true;
    } catch (error) {
      logger.error('OpenAI health check failed', { error });
      return false;
    }
  }
}

export default EmbeddingService;

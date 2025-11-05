import { QdrantClient } from '@qdrant/js-client-rest';
import { qdrantConfig } from '../config';
import logger from '../utils/logger';
import { VectorPoint, VectorSearchParams, VectorSearchResult, VectorStoreError } from '../types';
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('kb-api-qdrant');

export class QdrantService {
  private client: QdrantClient;
  private collectionName: string;

  constructor() {
    this.client = new QdrantClient({
      url: qdrantConfig.url,
      apiKey: qdrantConfig.apiKey,
    });
    this.collectionName = qdrantConfig.collectionName;
  }

  /**
   * Initialize the collection if it doesn't exist
   */
  async initialize(): Promise<void> {
    return tracer.startActiveSpan('qdrant.initialize', async (span) => {
      try {
        logger.info('Initializing Qdrant collection', {
          collection: this.collectionName,
        });

        // Check if collection exists
        const collections = await this.client.getCollections();
        const exists = collections.collections.some(
          (col) => col.name === this.collectionName,
        );

        if (!exists) {
          // Create collection
          await this.client.createCollection(this.collectionName, {
            vectors: {
              size: qdrantConfig.vectorSize,
              distance: qdrantConfig.distance,
            },
            optimizers_config: {
              default_segment_number: 2,
              indexing_threshold: 10000,
            },
            replication_factor: 1,
          });

          // Create indexes for common filters
          await this.client.createPayloadIndex(this.collectionName, {
            field_name: 'documentId',
            field_schema: 'keyword',
          });

          await this.client.createPayloadIndex(this.collectionName, {
            field_name: 'chunkIndex',
            field_schema: 'integer',
          });

          logger.info('Created Qdrant collection', {
            collection: this.collectionName,
            vectorSize: qdrantConfig.vectorSize,
            distance: qdrantConfig.distance,
          });
        } else {
          logger.info('Qdrant collection already exists', {
            collection: this.collectionName,
          });
        }

        span.setStatus({ code: SpanStatusCode.OK });
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });

        logger.error('Failed to initialize Qdrant collection', {
          error: error instanceof Error ? error.message : String(error),
        });

        throw new VectorStoreError(
          'Failed to initialize vector store',
          error instanceof Error ? error : undefined,
        );
      } finally {
        span.end();
      }
    });
  }

  /**
   * Upsert vector points
   */
  async upsertPoints(points: VectorPoint[]): Promise<void> {
    return tracer.startActiveSpan('qdrant.upsert_points', async (span) => {
      try {
        span.setAttribute('points.count', points.length);

        logger.debug('Upserting points to Qdrant', {
          count: points.length,
          collection: this.collectionName,
        });

        const formattedPoints = points.map((point) => ({
          id: point.id,
          vector: point.vector,
          payload: point.payload,
        }));

        await this.client.upsert(this.collectionName, {
          wait: true,
          points: formattedPoints,
        });

        span.setStatus({ code: SpanStatusCode.OK });
        logger.debug('Points upserted successfully', { count: points.length });
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });

        logger.error('Failed to upsert points', {
          error: error instanceof Error ? error.message : String(error),
        });

        throw new VectorStoreError(
          'Failed to upsert vectors',
          error instanceof Error ? error : undefined,
        );
      } finally {
        span.end();
      }
    });
  }

  /**
   * Search for similar vectors
   */
  async search(params: VectorSearchParams): Promise<VectorSearchResult[]> {
    return tracer.startActiveSpan('qdrant.search', async (span) => {
      try {
        span.setAttribute('search.limit', params.limit);
        span.setAttribute('search.vector_dim', params.vector.length);

        logger.debug('Searching in Qdrant', {
          limit: params.limit,
          offset: params.offset,
          hasFilter: !!params.filter,
          scoreThreshold: params.scoreThreshold,
        });

        const searchParams: any = {
          vector: params.vector,
          limit: params.limit,
          with_payload: true,
          with_vector: false,
        };

        if (params.offset) {
          searchParams.offset = params.offset;
        }

        if (params.filter) {
          searchParams.filter = this.buildFilter(params.filter);
        }

        if (params.scoreThreshold !== undefined) {
          searchParams.score_threshold = params.scoreThreshold;
        }

        const response = await this.client.search(this.collectionName, searchParams);

        const results: VectorSearchResult[] = response.map((item) => ({
          id: String(item.id),
          score: item.score,
          payload: item.payload as VectorSearchResult['payload'],
        }));

        span.setAttribute('results.count', results.length);
        span.setStatus({ code: SpanStatusCode.OK });

        logger.debug('Search completed', {
          resultsCount: results.length,
          topScore: results[0]?.score,
        });

        return results;
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });

        logger.error('Search failed', {
          error: error instanceof Error ? error.message : String(error),
        });

        throw new VectorStoreError(
          'Failed to search vectors',
          error instanceof Error ? error : undefined,
        );
      } finally {
        span.end();
      }
    });
  }

  /**
   * Delete points by document ID
   */
  async deleteByDocumentId(documentId: string): Promise<void> {
    return tracer.startActiveSpan('qdrant.delete_by_document', async (span) => {
      try {
        span.setAttribute('document.id', documentId);

        logger.debug('Deleting points by document ID', { documentId });

        await this.client.delete(this.collectionName, {
          wait: true,
          filter: {
            must: [
              {
                key: 'documentId',
                match: { value: documentId },
              },
            ],
          },
        });

        span.setStatus({ code: SpanStatusCode.OK });
        logger.debug('Points deleted successfully', { documentId });
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });

        logger.error('Failed to delete points', {
          documentId,
          error: error instanceof Error ? error.message : String(error),
        });

        throw new VectorStoreError(
          'Failed to delete vectors',
          error instanceof Error ? error : undefined,
        );
      } finally {
        span.end();
      }
    });
  }

  /**
   * Delete specific points by IDs
   */
  async deletePoints(ids: string[]): Promise<void> {
    return tracer.startActiveSpan('qdrant.delete_points', async (span) => {
      try {
        span.setAttribute('points.count', ids.length);

        logger.debug('Deleting points by IDs', { count: ids.length });

        await this.client.delete(this.collectionName, {
          wait: true,
          points: ids,
        });

        span.setStatus({ code: SpanStatusCode.OK });
        logger.debug('Points deleted successfully', { count: ids.length });
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({ code: SpanStatusCode.ERROR });

        logger.error('Failed to delete points', {
          error: error instanceof Error ? error.message : String(error),
        });

        throw new VectorStoreError(
          'Failed to delete vectors',
          error instanceof Error ? error : undefined,
        );
      } finally {
        span.end();
      }
    });
  }

  /**
   * Get collection info
   */
  async getCollectionInfo(): Promise<any> {
    try {
      return await this.client.getCollection(this.collectionName);
    } catch (error) {
      logger.error('Failed to get collection info', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw new VectorStoreError(
        'Failed to get collection info',
        error instanceof Error ? error : undefined,
      );
    }
  }

  /**
   * Count points in collection
   */
  async countPoints(filter?: Record<string, any>): Promise<number> {
    try {
      const params: any = {};

      if (filter) {
        params.filter = this.buildFilter(filter);
      }

      const response = await this.client.count(this.collectionName, params);
      return response.count;
    } catch (error) {
      logger.error('Failed to count points', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw new VectorStoreError(
        'Failed to count vectors',
        error instanceof Error ? error : undefined,
      );
    }
  }

  /**
   * Build Qdrant filter from simple key-value pairs
   */
  private buildFilter(filter: Record<string, any>): any {
    const must: any[] = [];

    for (const [key, value] of Object.entries(filter)) {
      if (value !== undefined && value !== null) {
        must.push({
          key,
          match: { value },
        });
      }
    }

    return must.length > 0 ? { must } : undefined;
  }

  /**
   * Health check
   */
  async healthCheck(): Promise<boolean> {
    try {
      await this.client.getCollections();
      return true;
    } catch (error) {
      logger.error('Qdrant health check failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  }
}

// Singleton instance
let qdrantServiceInstance: QdrantService | null = null;

export const getQdrantService = (): QdrantService => {
  if (!qdrantServiceInstance) {
    qdrantServiceInstance = new QdrantService();
  }
  return qdrantServiceInstance;
};

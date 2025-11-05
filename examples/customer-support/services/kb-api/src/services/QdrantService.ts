import { QdrantClient } from '@qdrant/js-client-rest';
import { config } from '../config';
import { QdrantPoint, QdrantSearchResult, SearchFilter } from '../types';
import logger from '../utils/logger';
import { ServiceUnavailableError, InternalServerError } from '../middleware/errorHandler';

export class QdrantService {
  private client: QdrantClient;
  private collectionName: string;

  constructor() {
    this.client = new QdrantClient({
      url: config.qdrant.url,
      apiKey: config.qdrant.apiKey,
    });
    this.collectionName = config.qdrant.collectionName;
  }

  async initialize(): Promise<void> {
    try {
      // Check if collection exists
      const collections = await this.client.getCollections();
      const collectionExists = collections.collections.some(
        (c) => c.name === this.collectionName
      );

      if (!collectionExists) {
        logger.info(`Creating Qdrant collection: ${this.collectionName}`);
        await this.createCollection();
      } else {
        logger.info(`Qdrant collection already exists: ${this.collectionName}`);
      }
    } catch (error) {
      logger.error('Failed to initialize Qdrant', { error });
      throw new ServiceUnavailableError('Qdrant');
    }
  }

  async createCollection(): Promise<void> {
    try {
      await this.client.createCollection(this.collectionName, {
        vectors: {
          size: config.openai.embeddingDimensions,
          distance: 'Cosine',
        },
        optimizers_config: {
          default_segment_number: 2,
        },
        replication_factor: 2,
      });

      // Create payload indexes for filtering
      await this.createPayloadIndexes();

      logger.info('Qdrant collection created successfully');
    } catch (error) {
      logger.error('Failed to create Qdrant collection', { error });
      throw new InternalServerError('Failed to create vector collection');
    }
  }

  async createPayloadIndexes(): Promise<void> {
    const indexes = [
      { field: 'documentId', type: 'keyword' as const },
      { field: 'category', type: 'keyword' as const },
      { field: 'source', type: 'keyword' as const },
      { field: 'author', type: 'keyword' as const },
      { field: 'tags', type: 'keyword' as const },
      { field: 'createdAt', type: 'datetime' as const },
    ];

    for (const index of indexes) {
      try {
        await this.client.createPayloadIndex(this.collectionName, {
          field_name: index.field,
          field_schema: index.type,
        });
        logger.debug(`Created payload index for field: ${index.field}`);
      } catch (error) {
        logger.warn(`Failed to create payload index for ${index.field}`, { error });
      }
    }
  }

  async upsertPoints(points: QdrantPoint[]): Promise<void> {
    try {
      const formattedPoints = points.map((point) => ({
        id: point.id,
        vector: point.vector,
        payload: point.payload,
      }));

      await this.client.upsert(this.collectionName, {
        wait: true,
        points: formattedPoints,
      });

      logger.debug(`Upserted ${points.length} points to Qdrant`);
    } catch (error) {
      logger.error('Failed to upsert points to Qdrant', { error });
      throw new InternalServerError('Failed to store embeddings');
    }
  }

  async search(
    vector: number[],
    limit: number = 10,
    scoreThreshold: number = 0.7,
    filter?: SearchFilter
  ): Promise<QdrantSearchResult[]> {
    try {
      const qdrantFilter = this.buildQdrantFilter(filter);

      const searchResult = await this.client.search(this.collectionName, {
        vector,
        limit,
        score_threshold: scoreThreshold,
        filter: qdrantFilter,
        with_payload: true,
      });

      return searchResult.map((result) => ({
        id: result.id as string,
        score: result.score,
        payload: result.payload as Record<string, unknown>,
      }));
    } catch (error) {
      logger.error('Failed to search in Qdrant', { error });
      throw new InternalServerError('Failed to perform vector search');
    }
  }

  async deletePoints(ids: string[]): Promise<void> {
    try {
      await this.client.delete(this.collectionName, {
        wait: true,
        points: ids,
      });
      logger.debug(`Deleted ${ids.length} points from Qdrant`);
    } catch (error) {
      logger.error('Failed to delete points from Qdrant', { error });
      throw new InternalServerError('Failed to delete embeddings');
    }
  }

  async deleteByDocumentId(documentId: string): Promise<void> {
    try {
      await this.client.delete(this.collectionName, {
        wait: true,
        filter: {
          must: [
            {
              key: 'documentId',
              match: {
                value: documentId,
              },
            },
          ],
        },
      });
      logger.debug(`Deleted all points for document ${documentId}`);
    } catch (error) {
      logger.error('Failed to delete document points from Qdrant', { error });
      throw new InternalServerError('Failed to delete document embeddings');
    }
  }

  async getCollectionInfo(): Promise<unknown> {
    try {
      return await this.client.getCollection(this.collectionName);
    } catch (error) {
      logger.error('Failed to get collection info', { error });
      throw new InternalServerError('Failed to get collection information');
    }
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.client.getCollections();
      return true;
    } catch (error) {
      logger.error('Qdrant health check failed', { error });
      return false;
    }
  }

  private buildQdrantFilter(filter?: SearchFilter): unknown {
    if (!filter) return undefined;

    const conditions: unknown[] = [];

    if (filter.category) {
      conditions.push({
        key: 'category',
        match: { value: filter.category },
      });
    }

    if (filter.source) {
      conditions.push({
        key: 'source',
        match: { value: filter.source },
      });
    }

    if (filter.author) {
      conditions.push({
        key: 'author',
        match: { value: filter.author },
      });
    }

    if (filter.tags && filter.tags.length > 0) {
      conditions.push({
        key: 'tags',
        match: { any: filter.tags },
      });
    }

    if (filter.dateFrom || filter.dateTo) {
      const rangeCondition: Record<string, unknown> = {
        key: 'createdAt',
        range: {},
      };

      if (filter.dateFrom) {
        (rangeCondition.range as Record<string, unknown>).gte = new Date(filter.dateFrom).toISOString();
      }

      if (filter.dateTo) {
        (rangeCondition.range as Record<string, unknown>).lte = new Date(filter.dateTo).toISOString();
      }

      conditions.push(rangeCondition);
    }

    // Add custom filters
    if (filter.customFilters) {
      for (const [key, value] of Object.entries(filter.customFilters)) {
        conditions.push({
          key,
          match: { value },
        });
      }
    }

    return conditions.length > 0 ? { must: conditions } : undefined;
  }

  async recreateCollection(): Promise<void> {
    try {
      // Delete existing collection
      try {
        await this.client.deleteCollection(this.collectionName);
        logger.info(`Deleted existing collection: ${this.collectionName}`);
      } catch (error) {
        logger.warn('Collection does not exist or could not be deleted', { error });
      }

      // Create new collection
      await this.createCollection();
      logger.info('Collection recreated successfully');
    } catch (error) {
      logger.error('Failed to recreate collection', { error });
      throw new InternalServerError('Failed to recreate collection');
    }
  }
}

export default QdrantService;

import { Router, Request, Response } from 'express';
import { getQdrantService } from '../services/qdrant';
import { getEmbeddingsService } from '../services/embeddings';
import { asyncHandler } from '../middleware/errorHandler';
import logger from '../utils/logger';
import {
  SearchQuerySchema,
  SearchResponse,
  SearchResult,
  EmbeddingRequestSchema,
} from '../types';
import { trackLLMOperation } from '../middleware/observatory';

const router = Router();
const qdrantService = getQdrantService();
const embeddingsService = getEmbeddingsService();

/**
 * POST /api/v1/kb/search
 * Perform semantic search on knowledge base
 */
router.post(
  '/',
  asyncHandler(async (req: Request, res: Response) => {
    const startTime = Date.now();

    // Validate request
    const searchQuery = SearchQuerySchema.parse(req.body);

    logger.info('Processing search query', {
      query: searchQuery.query,
      limit: searchQuery.limit,
      searchType: searchQuery.searchType,
    });

    let results: SearchResult[] = [];

    if (searchQuery.searchType === 'semantic' || searchQuery.searchType === 'hybrid') {
      // Generate embedding for query
      const { embedding } = await embeddingsService.generateEmbedding(searchQuery.query);

      // Search in Qdrant
      const vectorResults = await qdrantService.search({
        vector: embedding,
        limit: searchQuery.limit,
        offset: searchQuery.offset,
        filter: searchQuery.filters,
        scoreThreshold: searchQuery.scoreThreshold,
      });

      // Transform results
      results = vectorResults.map((result) => ({
        id: result.id,
        documentId: result.payload.documentId,
        content: result.payload.content,
        score: result.score,
        chunkIndex: result.payload.chunkIndex,
        metadata: searchQuery.includeMetadata ? result.payload.metadata : undefined,
        highlight: generateHighlight(result.payload.content, searchQuery.query),
      }));
    }

    // For hybrid search, combine with keyword search
    if (searchQuery.searchType === 'hybrid') {
      // TODO: Implement keyword search and merge results
      logger.debug('Hybrid search requested, but keyword search not yet implemented');
    }

    const processingTime = Date.now() - startTime;

    trackLLMOperation('search', {
      query: searchQuery.query,
      resultsCount: results.length,
      searchType: searchQuery.searchType,
    });

    const response: SearchResponse = {
      query: searchQuery.query,
      results,
      total: results.length,
      limit: searchQuery.limit,
      offset: searchQuery.offset,
      processingTimeMs: processingTime,
    };

    logger.info('Search completed', {
      query: searchQuery.query,
      resultsCount: results.length,
      processingTimeMs: processingTime,
    });

    res.json(response);
  }),
);

/**
 * POST /api/v1/kb/embed
 * Generate embeddings for text
 */
router.post(
  '/embed',
  asyncHandler(async (req: Request, res: Response) => {
    const startTime = Date.now();

    // Validate request
    const embeddingRequest = EmbeddingRequestSchema.parse(req.body);

    logger.debug('Generating embedding', {
      textLength: embeddingRequest.text.length,
      model: embeddingRequest.model,
    });

    // Generate embedding
    const result = await embeddingsService.generateEmbedding(embeddingRequest.text);

    const processingTime = Date.now() - startTime;

    trackLLMOperation('embedding', {
      model: result.model,
      tokens: result.tokens,
      dimensions: result.dimensions,
    });

    res.json({
      ...result,
      processingTimeMs: processingTime,
    });
  }),
);

/**
 * GET /api/v1/kb/search/similar/:documentId/:chunkIndex
 * Find similar chunks to a specific chunk
 */
router.get(
  '/similar/:documentId/:chunkIndex',
  asyncHandler(async (req: Request, res: Response) => {
    const startTime = Date.now();
    const { documentId, chunkIndex } = req.params;
    const limit = parseInt(req.query.limit as string) || 5;

    logger.debug('Finding similar chunks', {
      documentId,
      chunkIndex: parseInt(chunkIndex),
      limit,
    });

    // First, find the chunk to get its embedding
    const sourceResults = await qdrantService.search({
      vector: [], // Will be populated from the chunk
      limit: 1,
      filter: {
        documentId,
        chunkIndex: parseInt(chunkIndex),
      },
    });

    if (sourceResults.length === 0) {
      return res.status(404).json({
        error: {
          message: 'Chunk not found',
          code: 'CHUNK_NOT_FOUND',
        },
      });
    }

    // Get the chunk's content and generate embedding
    const sourceChunk = sourceResults[0];
    const { embedding } = await embeddingsService.generateEmbedding(sourceChunk.payload.content);

    // Search for similar chunks
    const similarResults = await qdrantService.search({
      vector: embedding,
      limit: limit + 1, // +1 to exclude self
      scoreThreshold: 0.7, // Minimum similarity threshold
    });

    // Filter out the source chunk and transform results
    const results: SearchResult[] = similarResults
      .filter((result) => result.id !== sourceChunk.id)
      .slice(0, limit)
      .map((result) => ({
        id: result.id,
        documentId: result.payload.documentId,
        content: result.payload.content,
        score: result.score,
        chunkIndex: result.payload.chunkIndex,
        metadata: result.payload.metadata,
      }));

    const processingTime = Date.now() - startTime;

    res.json({
      sourceChunk: {
        documentId: sourceChunk.payload.documentId,
        chunkIndex: sourceChunk.payload.chunkIndex,
        content: sourceChunk.payload.content,
      },
      similarChunks: results,
      total: results.length,
      processingTimeMs: processingTime,
    });
  }),
);

/**
 * POST /api/v1/kb/search/batch
 * Batch search for multiple queries
 */
router.post(
  '/batch',
  asyncHandler(async (req: Request, res: Response) => {
    const startTime = Date.now();
    const { queries } = req.body;

    if (!Array.isArray(queries) || queries.length === 0) {
      return res.status(400).json({
        error: {
          message: 'queries must be a non-empty array',
          code: 'INVALID_REQUEST',
        },
      });
    }

    if (queries.length > 10) {
      return res.status(400).json({
        error: {
          message: 'Maximum 10 queries allowed per batch',
          code: 'BATCH_SIZE_EXCEEDED',
        },
      });
    }

    logger.info('Processing batch search', { count: queries.length });

    // Process all queries in parallel
    const results = await Promise.all(
      queries.map(async (query: string, index: number) => {
        try {
          const searchQuery = SearchQuerySchema.parse({
            query,
            limit: 5,
          });

          const { embedding } = await embeddingsService.generateEmbedding(query);

          const vectorResults = await qdrantService.search({
            vector: embedding,
            limit: searchQuery.limit,
          });

          const searchResults: SearchResult[] = vectorResults.map((result) => ({
            id: result.id,
            documentId: result.payload.documentId,
            content: result.payload.content,
            score: result.score,
            chunkIndex: result.payload.chunkIndex,
          }));

          return {
            index,
            query,
            results: searchResults,
            success: true,
          };
        } catch (error) {
          logger.error('Batch search query failed', {
            index,
            query,
            error: error instanceof Error ? error.message : String(error),
          });

          return {
            index,
            query,
            error: error instanceof Error ? error.message : String(error),
            success: false,
          };
        }
      }),
    );

    const processingTime = Date.now() - startTime;

    logger.info('Batch search completed', {
      total: queries.length,
      successful: results.filter((r) => r.success).length,
      failed: results.filter((r) => !r.success).length,
      processingTimeMs: processingTime,
    });

    res.json({
      results,
      total: queries.length,
      processingTimeMs: processingTime,
    });
  }),
);

/**
 * GET /api/v1/kb/search/stats
 * Get search statistics
 */
router.get(
  '/stats',
  asyncHandler(async (req: Request, res: Response) => {
    try {
      const collectionInfo = await qdrantService.getCollectionInfo();
      const totalVectors = await qdrantService.countPoints();

      res.json({
        totalVectors,
        collectionInfo: {
          status: collectionInfo.status,
          vectorsCount: collectionInfo.vectors_count,
          pointsCount: collectionInfo.points_count,
          segmentsCount: collectionInfo.segments_count,
          config: {
            vectorSize: collectionInfo.config.params.vectors.size,
            distance: collectionInfo.config.params.vectors.distance,
          },
        },
      });
    } catch (error) {
      logger.error('Failed to get search stats', {
        error: error instanceof Error ? error.message : String(error),
      });

      res.status(503).json({
        error: {
          message: 'Failed to retrieve search statistics',
          code: 'STATS_UNAVAILABLE',
        },
      });
    }
  }),
);

/**
 * Generate highlight snippet from content
 */
function generateHighlight(content: string, query: string, contextLength: number = 200): string {
  const lowerContent = content.toLowerCase();
  const lowerQuery = query.toLowerCase();

  // Find the position of the query in content
  const index = lowerContent.indexOf(lowerQuery);

  if (index === -1) {
    // Query not found directly, return beginning of content
    return content.substring(0, contextLength) + (content.length > contextLength ? '...' : '');
  }

  // Calculate start and end positions for context
  const start = Math.max(0, index - contextLength / 2);
  const end = Math.min(content.length, index + query.length + contextLength / 2);

  let highlight = content.substring(start, end);

  // Add ellipsis if truncated
  if (start > 0) {
    highlight = '...' + highlight;
  }
  if (end < content.length) {
    highlight = highlight + '...';
  }

  return highlight;
}

export default router;

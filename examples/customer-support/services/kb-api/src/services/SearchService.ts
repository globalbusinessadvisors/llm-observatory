import { SearchRequest, SearchResponse, SearchResult } from '../types';
import { EmbeddingService } from './EmbeddingService';
import { QdrantService } from './QdrantService';
import logger from '../utils/logger';
import { config } from '../config';
import { BadRequestError } from '../middleware/errorHandler';

export class SearchService {
  private embeddingService: EmbeddingService;
  private qdrantService: QdrantService;

  constructor(embeddingService: EmbeddingService, qdrantService: QdrantService) {
    this.embeddingService = embeddingService;
    this.qdrantService = qdrantService;
  }

  async search(request: SearchRequest): Promise<SearchResponse> {
    const startTime = Date.now();

    if (!request.query || request.query.trim().length === 0) {
      throw new BadRequestError('Search query is required');
    }

    const limit = Math.min(
      request.limit || config.search.defaultLimit,
      config.search.maxLimit
    );
    const scoreThreshold = request.scoreThreshold || config.search.scoreThreshold;

    logger.debug('Performing semantic search', {
      query: request.query,
      limit,
      scoreThreshold,
    });

    try {
      // Generate embedding for query
      const queryEmbedding = await this.embeddingService.generateEmbedding(request.query);

      // Search in Qdrant
      const qdrantResults = await this.qdrantService.search(
        queryEmbedding,
        limit,
        scoreThreshold,
        request.filter
      );

      // Transform results
      const results: SearchResult[] = qdrantResults.map((result) => ({
        id: result.id as string,
        documentId: result.payload.documentId as string,
        score: result.score,
        content: request.includeContent !== false ? (result.payload.content as string) : '',
        metadata: {
          documentTitle: result.payload.documentTitle as string,
          filename: result.payload.filename as string,
          chunkIndex: result.payload.chunkIndex as number,
          category: result.payload.category as string | undefined,
          tags: result.payload.tags as string[] | undefined,
          source: result.payload.source as string | undefined,
          author: result.payload.author as string | undefined,
          createdAt: result.payload.createdAt as string,
        },
      }));

      const took = Date.now() - startTime;

      logger.info('Search completed', {
        query: request.query,
        resultsCount: results.length,
        took,
      });

      return {
        results,
        total: results.length,
        query: request.query,
        limit,
        scoreThreshold,
        took,
      };
    } catch (error) {
      logger.error('Search failed', { query: request.query, error });
      throw error;
    }
  }

  async searchWithReranking(request: SearchRequest): Promise<SearchResponse> {
    // First perform semantic search with higher limit
    const initialLimit = Math.min((request.limit || config.search.defaultLimit) * 3, 100);
    const initialRequest = { ...request, limit: initialLimit };
    const initialResults = await this.search(initialRequest);

    // Rerank results based on exact keyword matches
    const rerankedResults = this.rerankResults(
      initialResults.results,
      request.query
    );

    // Limit to requested size
    const finalLimit = request.limit || config.search.defaultLimit;
    const finalResults = rerankedResults.slice(0, finalLimit);

    return {
      ...initialResults,
      results: finalResults,
      total: finalResults.length,
      limit: finalLimit,
    };
  }

  private rerankResults(results: SearchResult[], query: string): SearchResult[] {
    const queryTerms = query.toLowerCase().split(/\s+/);

    return results
      .map((result) => {
        const content = result.content.toLowerCase();
        let bonusScore = 0;

        // Award bonus points for exact matches
        for (const term of queryTerms) {
          if (content.includes(term)) {
            bonusScore += 0.05;
          }
        }

        // Award bonus for multiple term matches
        const matchingTerms = queryTerms.filter((term) => content.includes(term));
        if (matchingTerms.length > 1) {
          bonusScore += 0.1 * (matchingTerms.length / queryTerms.length);
        }

        return {
          ...result,
          score: Math.min(result.score + bonusScore, 1.0),
        };
      })
      .sort((a, b) => b.score - a.score);
  }

  async hybridSearch(request: SearchRequest): Promise<SearchResponse> {
    // Combine semantic search with keyword search
    const semanticResults = await this.search(request);
    const rerankedResults = this.rerankResults(semanticResults.results, request.query);

    return {
      ...semanticResults,
      results: rerankedResults,
    };
  }

  async searchSimilarChunks(
    documentId: string,
    chunkIndex: number,
    limit: number = 5
  ): Promise<SearchResult[]> {
    // This would require fetching the chunk's embedding and searching for similar ones
    // Simplified implementation for now
    logger.debug('Searching for similar chunks', { documentId, chunkIndex, limit });

    // In a real implementation, we would:
    // 1. Get the chunk's embedding from Qdrant
    // 2. Search for similar embeddings
    // 3. Filter out chunks from the same document
    // 4. Return results

    return [];
  }
}

export default SearchService;

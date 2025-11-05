import { Router, Request, Response } from 'express';
import { SearchService } from '../services/SearchService';
import { EmbeddingService } from '../services/EmbeddingService';
import { asyncHandler } from '../middleware/errorHandler';
import { z } from 'zod';

const router = Router();

// Validation schemas
const searchSchema = z.object({
  query: z.string().min(1, 'Query is required'),
  limit: z.number().int().positive().max(100).optional(),
  scoreThreshold: z.number().min(0).max(1).optional(),
  filter: z
    .object({
      category: z.string().optional(),
      tags: z.array(z.string()).optional(),
      source: z.string().optional(),
      author: z.string().optional(),
      dateFrom: z.string().optional(),
      dateTo: z.string().optional(),
      customFilters: z.record(z.unknown()).optional(),
    })
    .optional(),
  includeContent: z.boolean().optional(),
});

const embedSchema = z.object({
  texts: z.array(z.string()).min(1, 'At least one text is required').max(100),
  model: z.string().optional(),
});

export function createSearchRouter(
  searchService: SearchService,
  embeddingService: EmbeddingService
): Router {
  // Semantic search
  router.post(
    '/',
    asyncHandler(async (req: Request, res: Response) => {
      const searchRequest = searchSchema.parse(req.body);
      const result = await searchService.search(searchRequest);

      res.json({
        success: true,
        data: result,
      });
    })
  );

  // Hybrid search (semantic + keyword reranking)
  router.post(
    '/hybrid',
    asyncHandler(async (req: Request, res: Response) => {
      const searchRequest = searchSchema.parse(req.body);
      const result = await searchService.hybridSearch(searchRequest);

      res.json({
        success: true,
        data: result,
      });
    })
  );

  // Search with reranking
  router.post(
    '/rerank',
    asyncHandler(async (req: Request, res: Response) => {
      const searchRequest = searchSchema.parse(req.body);
      const result = await searchService.searchWithReranking(searchRequest);

      res.json({
        success: true,
        data: result,
      });
    })
  );

  return router;
}

export function createEmbedRouter(embeddingService: EmbeddingService): Router {
  // Generate embeddings
  router.post(
    '/',
    asyncHandler(async (req: Request, res: Response) => {
      const embedRequest = embedSchema.parse(req.body);
      const result = await embeddingService.generateEmbeddings(embedRequest.texts);

      res.json({
        success: true,
        data: {
          embeddings: result.embeddings,
          model: result.model,
          dimensions: result.dimensions,
          tokensUsed: result.tokensUsed,
        },
      });
    })
  );

  return router;
}

export { createSearchRouter as default };

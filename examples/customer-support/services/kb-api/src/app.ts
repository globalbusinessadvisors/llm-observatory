import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import { requestLogger } from './middleware/requestLogger';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import { createDocumentsRouter } from './routes/documents';
import { createSearchRouter, createEmbedRouter } from './routes/search';
import { createHealthRouter } from './routes/health';
import { DocumentService } from './services/DocumentService';
import { EmbeddingService } from './services/EmbeddingService';
import { QdrantService } from './services/QdrantService';
import { SearchService } from './services/SearchService';
import logger from './utils/logger';

export interface AppDependencies {
  documentService: DocumentService;
  embeddingService: EmbeddingService;
  qdrantService: QdrantService;
  searchService: SearchService;
}

export function createApp(dependencies: AppDependencies): Application {
  const app = express();

  // Security middleware
  app.use(helmet());

  // CORS
  app.use(
    cors({
      origin: config.corsOrigins,
      credentials: true,
    })
  );

  // Compression
  app.use(compression());

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request logging
  app.use(requestLogger);

  // Rate limiting
  const limiter = rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: config.rateLimit.maxRequests,
    message: {
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Too many requests, please try again later',
      },
    },
    standardHeaders: true,
    legacyHeaders: false,
  });

  app.use('/v1', limiter);

  // Health check (no rate limiting)
  app.use('/health', createHealthRouter(dependencies.qdrantService, dependencies.embeddingService));

  // API routes
  app.use('/v1/documents', createDocumentsRouter(dependencies.documentService));
  app.use('/v1/search', createSearchRouter(dependencies.searchService, dependencies.embeddingService));
  app.use('/v1/embed', createEmbedRouter(dependencies.embeddingService));

  // Root endpoint
  app.get('/', (req: Request, res: Response) => {
    res.json({
      service: 'Knowledge Base API',
      version: '0.1.0',
      status: 'running',
      endpoints: {
        health: '/health',
        documents: '/v1/documents',
        search: '/v1/search',
        embed: '/v1/embed',
      },
    });
  });

  // 404 handler
  app.use(notFoundHandler);

  // Error handler (must be last)
  app.use(errorHandler);

  return app;
}

export async function initializeServices(): Promise<AppDependencies> {
  logger.info('Initializing services...');

  // Initialize services
  const qdrantService = new QdrantService();
  const embeddingService = new EmbeddingService();
  const documentService = new DocumentService(embeddingService, qdrantService);
  const searchService = new SearchService(embeddingService, qdrantService);

  // Initialize Qdrant collection
  await qdrantService.initialize();

  logger.info('Services initialized successfully');

  return {
    documentService,
    embeddingService,
    qdrantService,
    searchService,
  };
}

export default createApp;

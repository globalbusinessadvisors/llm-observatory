import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { appConfig } from './config';
import { initializeObservatory, observatoryMiddleware } from './middleware/observatory';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import { getQdrantService } from './services/qdrant';
import documentsRouter from './routes/documents';
import searchRouter from './routes/search';
import logger from './utils/logger';

/**
 * Create and configure Express application
 */
export function createApp(): Application {
  const app = express();

  // Initialize Observatory integration
  if (appConfig.env !== 'test') {
    initializeObservatory();
  }

  // Security middleware
  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", 'data:', 'https:'],
      },
    },
    crossOriginEmbedderPolicy: false,
  }));

  // CORS configuration
  app.use(cors({
    origin: appConfig.corsOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }));

  // Compression
  app.use(compression());

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request logging
  app.use((req: Request, res: Response, next) => {
    const start = Date.now();

    res.on('finish', () => {
      const duration = Date.now() - start;
      logger.info('HTTP Request', {
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        duration,
        userAgent: req.get('user-agent'),
      });
    });

    next();
  });

  // Observatory tracing middleware
  app.use(observatoryMiddleware);

  // Health check endpoint
  app.get('/health', async (req: Request, res: Response) => {
    try {
      const qdrantHealthy = await getQdrantService().healthCheck();

      const health = {
        status: qdrantHealthy ? 'healthy' : 'degraded',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: '0.1.0',
        services: {
          qdrant: qdrantHealthy ? 'up' : 'down',
        },
      };

      const statusCode = qdrantHealthy ? 200 : 503;
      res.status(statusCode).json(health);
    } catch (error) {
      logger.error('Health check failed', {
        error: error instanceof Error ? error.message : String(error),
      });

      res.status(503).json({
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        error: 'Health check failed',
      });
    }
  });

  // Readiness check endpoint
  app.get('/ready', async (req: Request, res: Response) => {
    try {
      const qdrantHealthy = await getQdrantService().healthCheck();

      if (!qdrantHealthy) {
        return res.status(503).json({
          status: 'not ready',
          message: 'Qdrant service is not available',
        });
      }

      res.json({
        status: 'ready',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      res.status(503).json({
        status: 'not ready',
        error: error instanceof Error ? error.message : String(error),
      });
    }
  });

  // Liveness check endpoint
  app.get('/live', (req: Request, res: Response) => {
    res.json({
      status: 'alive',
      timestamp: new Date().toISOString(),
    });
  });

  // Metrics endpoint (basic)
  app.get('/metrics', async (req: Request, res: Response) => {
    try {
      const qdrantService = getQdrantService();
      const collectionInfo = await qdrantService.getCollectionInfo();

      const metrics = {
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        cpu: process.cpuUsage(),
        vectorStore: {
          totalVectors: collectionInfo.points_count,
          status: collectionInfo.status,
        },
      };

      res.json(metrics);
    } catch (error) {
      logger.error('Failed to collect metrics', {
        error: error instanceof Error ? error.message : String(error),
      });

      res.status(500).json({
        error: 'Failed to collect metrics',
      });
    }
  });

  // API routes
  app.use('/api/v1/kb/documents', documentsRouter);
  app.use('/api/v1/kb/search', searchRouter);

  // Root endpoint
  app.get('/', (req: Request, res: Response) => {
    res.json({
      name: 'LLM Observatory Knowledge Base API',
      version: '0.1.0',
      description: 'RAG-powered knowledge base API with semantic search',
      endpoints: {
        health: '/health',
        ready: '/ready',
        live: '/live',
        metrics: '/metrics',
        documents: '/api/v1/kb/documents',
        search: '/api/v1/kb/search',
      },
      documentation: 'https://docs.llm-observatory.io/kb-api',
    });
  });

  // 404 handler
  app.use(notFoundHandler);

  // Error handler (must be last)
  app.use(errorHandler);

  return app;
}

/**
 * Initialize services
 */
export async function initializeServices(): Promise<void> {
  logger.info('Initializing services...');

  try {
    // Initialize Qdrant collection
    const qdrantService = getQdrantService();
    await qdrantService.initialize();

    logger.info('All services initialized successfully');
  } catch (error) {
    logger.error('Failed to initialize services', {
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

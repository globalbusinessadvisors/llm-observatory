import { Router, Request, Response } from 'express';
import { QdrantService } from '../services/QdrantService';
import { EmbeddingService } from '../services/EmbeddingService';
import { asyncHandler } from '../middleware/errorHandler';
import { HealthCheckResponse, ComponentHealth } from '../types';
import { config } from '../config';

const router = Router();

export function createHealthRouter(
  qdrantService: QdrantService,
  embeddingService: EmbeddingService
): Router {
  router.get(
    '/',
    asyncHandler(async (req: Request, res: Response) => {
      const startTime = Date.now();

      // Check Qdrant
      const qdrantStartTime = Date.now();
      const qdrantHealthy = await qdrantService.healthCheck();
      const qdrantLatency = Date.now() - qdrantStartTime;

      const qdrantHealth: ComponentHealth = {
        status: qdrantHealthy ? 'up' : 'down',
        latency: qdrantLatency,
      };

      // Overall status
      const allHealthy = qdrantHealthy;
      const status = allHealthy ? 'healthy' : 'unhealthy';

      const response: HealthCheckResponse = {
        status,
        version: '0.1.0',
        timestamp: new Date().toISOString(),
        checks: {
          database: { status: 'up' }, // Placeholder
          qdrant: qdrantHealth,
          redis: { status: 'up' }, // Placeholder
        },
      };

      const statusCode = allHealthy ? 200 : 503;
      res.status(statusCode).json(response);
    })
  );

  router.get('/ready', (req: Request, res: Response) => {
    res.json({
      status: 'ready',
      timestamp: new Date().toISOString(),
    });
  });

  router.get('/live', (req: Request, res: Response) => {
    res.json({
      status: 'alive',
      timestamp: new Date().toISOString(),
    });
  });

  return router;
}

export default createHealthRouter;

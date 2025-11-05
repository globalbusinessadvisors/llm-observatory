import { createApp, initializeServices } from './app';
import { appConfig } from './config';
import logger from './utils/logger';
import { shutdownObservatory } from './middleware/observatory';

/**
 * Start the server
 */
async function startServer(): Promise<void> {
  try {
    logger.info('Starting KB API server...', {
      env: appConfig.env,
      port: appConfig.port,
      nodeVersion: process.version,
    });

    // Initialize services
    await initializeServices();

    // Create Express app
    const app = createApp();

    // Start listening
    const server = app.listen(appConfig.port, () => {
      logger.info('KB API server started successfully', {
        port: appConfig.port,
        env: appConfig.env,
        pid: process.pid,
      });

      logger.info('Server endpoints', {
        base: `http://localhost:${appConfig.port}`,
        health: `http://localhost:${appConfig.port}/health`,
        documents: `http://localhost:${appConfig.port}/api/v1/kb/documents`,
        search: `http://localhost:${appConfig.port}/api/v1/kb/search`,
      });
    });

    // Graceful shutdown
    const gracefulShutdown = async (signal: string) => {
      logger.info(`Received ${signal}, starting graceful shutdown...`);

      server.close(async () => {
        logger.info('HTTP server closed');

        try {
          // Shutdown Observatory
          await shutdownObservatory();

          logger.info('All services shut down successfully');
          process.exit(0);
        } catch (error) {
          logger.error('Error during shutdown', {
            error: error instanceof Error ? error.message : String(error),
          });
          process.exit(1);
        }
      });

      // Force shutdown after timeout
      setTimeout(() => {
        logger.error('Forced shutdown due to timeout');
        process.exit(1);
      }, 10000); // 10 seconds
    };

    // Handle shutdown signals
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    // Handle uncaught errors
    process.on('uncaughtException', (error: Error) => {
      logger.error('Uncaught exception', {
        error: error.message,
        stack: error.stack,
      });
      process.exit(1);
    });

    process.on('unhandledRejection', (reason: any) => {
      logger.error('Unhandled rejection', {
        reason: reason instanceof Error ? reason.message : String(reason),
      });
      process.exit(1);
    });
  } catch (error) {
    logger.error('Failed to start server', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    process.exit(1);
  }
}

// Start the server
startServer();

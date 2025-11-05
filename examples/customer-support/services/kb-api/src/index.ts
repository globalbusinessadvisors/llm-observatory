import { config, validateConfig } from './config';
import { createApp, initializeServices } from './app';
import { initializeObservability, shutdownObservability } from './observability';
import logger from './utils/logger';

async function main(): Promise<void> {
  try {
    logger.info('Starting Knowledge Base API');
    logger.info(`Environment: ${config.env}`);
    logger.info(`Port: ${config.port}`);

    // Validate configuration
    validateConfig();

    // Initialize observability
    initializeObservability();

    // Initialize services
    const dependencies = await initializeServices();

    // Create Express app
    const app = createApp(dependencies);

    // Start server
    const server = app.listen(config.port, () => {
      logger.info(`Knowledge Base API is running on port ${config.port}`);
      logger.info(`Health check: http://localhost:${config.port}/health`);
      logger.info(`API docs: http://localhost:${config.port}/`);
    });

    // Graceful shutdown
    const shutdown = async () => {
      logger.info('Shutting down gracefully...');

      server.close(async () => {
        logger.info('HTTP server closed');

        // Shutdown observability
        await shutdownObservability();

        logger.info('Shutdown complete');
        process.exit(0);
      });

      // Force shutdown after 10 seconds
      setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
      }, 10000);
    };

    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);

    // Handle uncaught errors
    process.on('uncaughtException', (error) => {
      logger.error('Uncaught exception', { error });
      process.exit(1);
    });

    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled rejection', { reason, promise });
      process.exit(1);
    });
  } catch (error) {
    logger.error('Failed to start server', { error });
    process.exit(1);
  }
}

main();

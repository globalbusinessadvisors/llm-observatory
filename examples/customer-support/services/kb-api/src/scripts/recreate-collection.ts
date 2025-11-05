import dotenv from 'dotenv';
import { QdrantService } from '../services/QdrantService';
import logger from '../utils/logger';

dotenv.config();

async function main(): Promise<void> {
  logger.info('Recreating Qdrant collection...');

  try {
    const qdrantService = new QdrantService();
    await qdrantService.recreateCollection();
    logger.info('Collection recreated successfully');
    process.exit(0);
  } catch (error) {
    logger.error('Failed to recreate collection', { error });
    process.exit(1);
  }
}

main();

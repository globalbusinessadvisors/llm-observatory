import dotenv from 'dotenv';
import { AppConfig, QdrantConfig, OpenAIConfig, ObservatoryConfig } from '../types';

dotenv.config();

const getEnvVar = (key: string, defaultValue?: string): string => {
  const value = process.env[key];
  if (value === undefined && defaultValue === undefined) {
    throw new Error(`Environment variable ${key} is required but not set`);
  }
  return value || defaultValue!;
};

const getEnvVarNumber = (key: string, defaultValue: number): number => {
  const value = process.env[key];
  return value ? parseInt(value, 10) : defaultValue;
};

const getEnvVarBoolean = (key: string, defaultValue: boolean): boolean => {
  const value = process.env[key];
  if (value === undefined) return defaultValue;
  return value.toLowerCase() === 'true';
};

export const appConfig: AppConfig = {
  port: getEnvVarNumber('KB_API_PORT', 3001),
  env: (process.env.NODE_ENV || 'development') as 'development' | 'production' | 'test',
  corsOrigins: (process.env.CORS_ORIGINS || 'http://localhost:3000').split(','),
  maxFileSize: getEnvVarNumber('MAX_FILE_SIZE', 10 * 1024 * 1024), // 10MB default
  uploadDir: getEnvVar('UPLOAD_DIR', './uploads'),
};

export const qdrantConfig: QdrantConfig = {
  url: getEnvVar('QDRANT_URL', 'http://localhost:6333'),
  apiKey: process.env.QDRANT_API_KEY,
  collectionName: getEnvVar('QDRANT_COLLECTION', 'llm_observatory_kb'),
  vectorSize: getEnvVarNumber('VECTOR_SIZE', 1536), // text-embedding-3-small default
  distance: (process.env.QDRANT_DISTANCE || 'Cosine') as 'Cosine' | 'Euclid' | 'Dot',
};

export const openaiConfig: OpenAIConfig = {
  apiKey: getEnvVar('OPENAI_API_KEY'),
  embeddingModel: getEnvVar('OPENAI_EMBEDDING_MODEL', 'text-embedding-3-small'),
  maxTokens: getEnvVarNumber('OPENAI_MAX_TOKENS', 8191),
  timeout: getEnvVarNumber('OPENAI_TIMEOUT', 30000),
};

export const observatoryConfig: ObservatoryConfig = {
  enabled: getEnvVarBoolean('OBSERVATORY_ENABLED', true),
  collectorUrl: getEnvVar('OBSERVATORY_COLLECTOR_URL', 'http://localhost:4318'),
  serviceName: getEnvVar('OBSERVATORY_SERVICE_NAME', 'kb-api'),
  serviceVersion: getEnvVar('OBSERVATORY_SERVICE_VERSION', '0.1.0'),
};

export const config = {
  app: appConfig,
  qdrant: qdrantConfig,
  openai: openaiConfig,
  observatory: observatoryConfig,
};

export default config;

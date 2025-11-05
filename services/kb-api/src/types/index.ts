import { z } from 'zod';

// Document schemas
export const DocumentMetadataSchema = z.object({
  title: z.string().optional(),
  author: z.string().optional(),
  createdAt: z.date().optional(),
  source: z.string().optional(),
  tags: z.array(z.string()).optional(),
  customFields: z.record(z.string(), z.any()).optional(),
});

export const DocumentSchema = z.object({
  id: z.string().uuid(),
  filename: z.string(),
  content: z.string(),
  metadata: DocumentMetadataSchema,
  size: z.number(),
  mimeType: z.string(),
  uploadedAt: z.date(),
  processedAt: z.date().optional(),
  status: z.enum(['pending', 'processing', 'completed', 'failed']),
  error: z.string().optional(),
});

export const ChunkSchema = z.object({
  id: z.string().uuid(),
  documentId: z.string().uuid(),
  content: z.string(),
  chunkIndex: z.number(),
  startChar: z.number(),
  endChar: z.number(),
  tokens: z.number(),
  embedding: z.array(z.number()).optional(),
  metadata: z.record(z.string(), z.any()).optional(),
});

// Search schemas
export const SearchQuerySchema = z.object({
  query: z.string().min(1, 'Query cannot be empty'),
  limit: z.number().min(1).max(100).default(10),
  offset: z.number().min(0).default(0),
  filters: z.record(z.string(), z.any()).optional(),
  scoreThreshold: z.number().min(0).max(1).optional(),
  includeMetadata: z.boolean().default(true),
  searchType: z.enum(['semantic', 'hybrid', 'keyword']).default('semantic'),
});

export const SearchResultSchema = z.object({
  id: z.string().uuid(),
  documentId: z.string().uuid(),
  content: z.string(),
  score: z.number(),
  chunkIndex: z.number(),
  metadata: z.record(z.string(), z.any()).optional(),
  highlight: z.string().optional(),
});

export const SearchResponseSchema = z.object({
  query: z.string(),
  results: z.array(SearchResultSchema),
  total: z.number(),
  limit: z.number(),
  offset: z.number(),
  processingTimeMs: z.number(),
});

// Embedding schemas
export const EmbeddingRequestSchema = z.object({
  text: z.string().min(1, 'Text cannot be empty'),
  model: z.string().default('text-embedding-3-small'),
});

export const EmbeddingResponseSchema = z.object({
  embedding: z.array(z.number()),
  dimensions: z.number(),
  model: z.string(),
  tokens: z.number(),
});

// Upload schemas
export const DocumentUploadSchema = z.object({
  metadata: DocumentMetadataSchema.optional(),
  chunkSize: z.number().min(100).max(2000).default(500),
  chunkOverlap: z.number().min(0).max(500).default(50),
});

// Export types
export type DocumentMetadata = z.infer<typeof DocumentMetadataSchema>;
export type Document = z.infer<typeof DocumentSchema>;
export type Chunk = z.infer<typeof ChunkSchema>;
export type SearchQuery = z.infer<typeof SearchQuerySchema>;
export type SearchResult = z.infer<typeof SearchResultSchema>;
export type SearchResponse = z.infer<typeof SearchResponseSchema>;
export type EmbeddingRequest = z.infer<typeof EmbeddingRequestSchema>;
export type EmbeddingResponse = z.infer<typeof EmbeddingResponseSchema>;
export type DocumentUpload = z.infer<typeof DocumentUploadSchema>;

// Vector store types
export interface VectorPoint {
  id: string;
  vector: number[];
  payload: {
    documentId: string;
    chunkIndex: number;
    content: string;
    metadata?: Record<string, any>;
  };
}

export interface VectorSearchParams {
  vector: number[];
  limit: number;
  offset?: number;
  filter?: Record<string, any>;
  scoreThreshold?: number;
}

export interface VectorSearchResult {
  id: string;
  score: number;
  payload: {
    documentId: string;
    chunkIndex: number;
    content: string;
    metadata?: Record<string, any>;
  };
}

// Configuration types
export interface AppConfig {
  port: number;
  env: 'development' | 'production' | 'test';
  corsOrigins: string[];
  maxFileSize: number;
  uploadDir: string;
}

export interface QdrantConfig {
  url: string;
  apiKey?: string;
  collectionName: string;
  vectorSize: number;
  distance: 'Cosine' | 'Euclid' | 'Dot';
}

export interface OpenAIConfig {
  apiKey: string;
  embeddingModel: string;
  maxTokens: number;
  timeout: number;
}

export interface ObservatoryConfig {
  enabled: boolean;
  collectorUrl: string;
  serviceName: string;
  serviceVersion: string;
}

// Error types
export class DocumentNotFoundError extends Error {
  constructor(documentId: string) {
    super(`Document not found: ${documentId}`);
    this.name = 'DocumentNotFoundError';
  }
}

export class VectorStoreError extends Error {
  constructor(message: string, public originalError?: Error) {
    super(message);
    this.name = 'VectorStoreError';
  }
}

export class EmbeddingError extends Error {
  constructor(message: string, public originalError?: Error) {
    super(message);
    this.name = 'EmbeddingError';
  }
}

export class ChunkingError extends Error {
  constructor(message: string, public originalError?: Error) {
    super(message);
    this.name = 'ChunkingError';
  }
}

export class DocumentProcessingError extends Error {
  constructor(message: string, public originalError?: Error) {
    super(message);
    this.name = 'DocumentProcessingError';
  }
}

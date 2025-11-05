export interface Document {
  id: string;
  title: string;
  content: string;
  metadata: DocumentMetadata;
  chunks: DocumentChunk[];
  createdAt: Date;
  updatedAt: Date;
}

export interface DocumentMetadata {
  filename: string;
  mimeType: string;
  size: number;
  source?: string;
  author?: string;
  category?: string;
  tags?: string[];
  customFields?: Record<string, unknown>;
}

export interface DocumentChunk {
  id: string;
  documentId: string;
  content: string;
  chunkIndex: number;
  embedding?: number[];
  metadata: ChunkMetadata;
}

export interface ChunkMetadata {
  startPosition: number;
  endPosition: number;
  tokenCount: number;
  [key: string]: unknown;
}

export interface UploadDocumentRequest {
  title?: string;
  source?: string;
  author?: string;
  category?: string;
  tags?: string[];
  metadata?: Record<string, unknown>;
}

export interface UploadDocumentResponse {
  id: string;
  title: string;
  filename: string;
  size: number;
  chunksCreated: number;
  status: 'processing' | 'completed' | 'failed';
  message?: string;
}

export interface SearchRequest {
  query: string;
  limit?: number;
  scoreThreshold?: number;
  filter?: SearchFilter;
  includeContent?: boolean;
}

export interface SearchFilter {
  category?: string;
  tags?: string[];
  source?: string;
  author?: string;
  dateFrom?: string;
  dateTo?: string;
  customFilters?: Record<string, unknown>;
}

export interface SearchResult {
  id: string;
  documentId: string;
  score: number;
  content: string;
  metadata: SearchResultMetadata;
}

export interface SearchResultMetadata {
  documentTitle: string;
  filename: string;
  chunkIndex: number;
  category?: string;
  tags?: string[];
  source?: string;
  author?: string;
  createdAt: string;
  [key: string]: unknown;
}

export interface SearchResponse {
  results: SearchResult[];
  total: number;
  query: string;
  limit: number;
  scoreThreshold: number;
  took: number; // milliseconds
}

export interface EmbedRequest {
  texts: string[];
  model?: string;
}

export interface EmbedResponse {
  embeddings: number[][];
  model: string;
  dimensions: number;
  tokensUsed: number;
}

export interface ListDocumentsQuery {
  page?: number;
  limit?: number;
  category?: string;
  tags?: string[];
  search?: string;
  sortBy?: 'createdAt' | 'updatedAt' | 'title';
  sortOrder?: 'asc' | 'desc';
}

export interface ListDocumentsResponse {
  documents: DocumentSummary[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface DocumentSummary {
  id: string;
  title: string;
  filename: string;
  size: number;
  chunksCount: number;
  category?: string;
  tags?: string[];
  createdAt: string;
  updatedAt: string;
}

export interface ErrorResponse {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
  timestamp: string;
  path: string;
  requestId?: string;
}

// Qdrant-specific types
export interface QdrantPoint {
  id: string | number;
  vector: number[];
  payload: Record<string, unknown>;
}

export interface QdrantSearchResult {
  id: string | number;
  score: number;
  payload: Record<string, unknown>;
}

// Processing types
export interface ProcessingJob {
  id: string;
  documentId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  progress: number;
  error?: string;
  createdAt: Date;
  updatedAt: Date;
}

// Health check types
export interface HealthCheckResponse {
  status: 'healthy' | 'unhealthy' | 'degraded';
  version: string;
  timestamp: string;
  checks: {
    database: ComponentHealth;
    qdrant: ComponentHealth;
    redis: ComponentHealth;
  };
}

export interface ComponentHealth {
  status: 'up' | 'down';
  message?: string;
  latency?: number;
}

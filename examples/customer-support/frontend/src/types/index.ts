// Message types
export interface Message {
  id: string;
  conversationId: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: string;
  metadata?: {
    modelUsed?: string;
    tokensUsed?: number;
    cost?: number;
    latency?: number;
    citations?: Citation[];
  };
}

export interface Citation {
  documentId: string;
  documentTitle: string;
  relevanceScore: number;
  snippet: string;
}

// Conversation types
export interface Conversation {
  id: string;
  title: string;
  userId: string;
  status: 'active' | 'resolved' | 'archived';
  createdAt: string;
  updatedAt: string;
  lastMessageAt: string;
  messageCount: number;
  tags?: string[];
  metadata?: {
    customerSatisfaction?: number;
    resolvedBy?: 'ai' | 'human' | 'hybrid';
    escalated?: boolean;
  };
}

// Knowledge Base types
export interface KnowledgeBaseDocument {
  id: string;
  title: string;
  content: string;
  category: string;
  tags: string[];
  createdAt: string;
  updatedAt: string;
  metadata: {
    source?: string;
    author?: string;
    version?: string;
    status: 'draft' | 'published' | 'archived';
  };
  embedding?: number[];
  chunkCount?: number;
}

export interface DocumentChunk {
  id: string;
  documentId: string;
  content: string;
  chunkIndex: number;
  embedding?: number[];
  metadata?: Record<string, unknown>;
}

// Analytics types
export interface ConversationMetrics {
  totalConversations: number;
  activeConversations: number;
  resolvedConversations: number;
  averageResolutionTime: number;
  averageMessagesPerConversation: number;
  customerSatisfactionScore: number;
}

export interface CostMetrics {
  totalCost: number;
  costByModel: Record<string, number>;
  costByDay: Array<{
    date: string;
    cost: number;
  }>;
  averageCostPerConversation: number;
}

export interface PerformanceMetrics {
  averageLatency: number;
  p95Latency: number;
  p99Latency: number;
  totalTokensUsed: number;
  tokensByModel: Record<string, number>;
  cacheHitRate: number;
  errorRate: number;
}

export interface TimeSeriesDataPoint {
  timestamp: string;
  value: number;
  label?: string;
}

export interface ModelUsageStats {
  modelName: string;
  requestCount: number;
  totalTokens: number;
  totalCost: number;
  averageLatency: number;
  errorRate: number;
}

// User types
export interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'agent' | 'customer';
  createdAt: string;
  lastActive: string;
}

// Settings types
export interface SystemSettings {
  chatModel: string;
  temperature: number;
  maxTokens: number;
  enableRAG: boolean;
  ragTopK: number;
  ragThreshold: number;
  enableCaching: boolean;
  enableMonitoring: boolean;
  autoEscalationThreshold: number;
}

// WebSocket types
export interface WebSocketMessage {
  type: 'message' | 'typing' | 'error' | 'connection' | 'metadata';
  payload: unknown;
}

export interface TypingIndicator {
  conversationId: string;
  isTyping: boolean;
}

// API Response types
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

// Form types
export interface MessageFormData {
  content: string;
  attachments?: File[];
}

export interface DocumentFormData {
  title: string;
  content: string;
  category: string;
  tags: string[];
  metadata?: Record<string, unknown>;
}

// Error types
export interface ApiError {
  message: string;
  code: string;
  statusCode: number;
  details?: Record<string, unknown>;
}

// Chart types
export interface ChartDataPoint {
  name: string;
  value: number;
  [key: string]: string | number;
}

export interface ChartConfig {
  dataKey: string;
  color: string;
  label: string;
}

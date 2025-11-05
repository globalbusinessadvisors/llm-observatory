import axios, { AxiosInstance, AxiosError } from 'axios';
import {
  ApiResponse,
  PaginatedResponse,
  Message,
  Conversation,
  KnowledgeBaseDocument,
  ConversationMetrics,
  CostMetrics,
  PerformanceMetrics,
  ModelUsageStats,
  SystemSettings,
} from '@/types';

// API Base URLs
const CHAT_API_URL = import.meta.env.VITE_CHAT_API_URL || 'http://localhost:8000';
const KB_API_URL = import.meta.env.VITE_KB_API_URL || 'http://localhost:8001';
const ANALYTICS_API_URL = import.meta.env.VITE_ANALYTICS_API_URL || 'http://localhost:8002';

// Create axios instances
const createApiClient = (baseURL: string): AxiosInstance => {
  const client = axios.create({
    baseURL,
    timeout: 30000,
    headers: {
      'Content-Type': 'application/json',
    },
  });

  // Request interceptor
  client.interceptors.request.use(
    (config) => {
      // Add auth token if available
      const token = localStorage.getItem('auth_token');
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    },
    (error) => Promise.reject(error)
  );

  // Response interceptor
  client.interceptors.response.use(
    (response) => response,
    (error: AxiosError) => {
      if (error.response?.status === 401) {
        // Handle unauthorized
        localStorage.removeItem('auth_token');
        window.location.href = '/login';
      }
      return Promise.reject(error);
    }
  );

  return client;
};

const chatClient = createApiClient(CHAT_API_URL);
const kbClient = createApiClient(KB_API_URL);
const analyticsClient = createApiClient(ANALYTICS_API_URL);

// Chat API
export const chatApi = {
  // Conversations
  getConversations: async (
    page = 1,
    pageSize = 20
  ): Promise<PaginatedResponse<Conversation>> => {
    const response = await chatClient.get('/conversations', {
      params: { page, page_size: pageSize },
    });
    return response.data;
  },

  getConversation: async (conversationId: string): Promise<Conversation> => {
    const response = await chatClient.get(`/conversations/${conversationId}`);
    return response.data;
  },

  createConversation: async (
    title?: string,
    metadata?: Record<string, unknown>
  ): Promise<Conversation> => {
    const response = await chatClient.post('/conversations', { title, metadata });
    return response.data;
  },

  updateConversation: async (
    conversationId: string,
    updates: Partial<Conversation>
  ): Promise<Conversation> => {
    const response = await chatClient.patch(`/conversations/${conversationId}`, updates);
    return response.data;
  },

  deleteConversation: async (conversationId: string): Promise<void> => {
    await chatClient.delete(`/conversations/${conversationId}`);
  },

  // Messages
  getMessages: async (
    conversationId: string,
    page = 1,
    pageSize = 50
  ): Promise<PaginatedResponse<Message>> => {
    const response = await chatClient.get(`/conversations/${conversationId}/messages`, {
      params: { page, page_size: pageSize },
    });
    return response.data;
  },

  sendMessage: async (
    conversationId: string,
    content: string,
    metadata?: Record<string, unknown>
  ): Promise<Message> => {
    const response = await chatClient.post(`/conversations/${conversationId}/messages`, {
      content,
      metadata,
    });
    return response.data;
  },

  // Chat completion (streaming)
  streamChat: async (
    conversationId: string,
    message: string,
    onChunk: (chunk: string) => void,
    onComplete: (message: Message) => void,
    onError: (error: Error) => void
  ): Promise<void> => {
    try {
      const response = await chatClient.post(
        `/conversations/${conversationId}/stream`,
        { message },
        {
          responseType: 'stream',
          adapter: 'fetch',
        }
      );

      const reader = response.data.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6);
            if (data === '[DONE]') {
              continue;
            }
            try {
              const parsed = JSON.parse(data);
              if (parsed.type === 'chunk') {
                onChunk(parsed.content);
              } else if (parsed.type === 'complete') {
                onComplete(parsed.message);
              }
            } catch (e) {
              console.error('Error parsing SSE data:', e);
            }
          }
        }
      }
    } catch (error) {
      onError(error as Error);
    }
  },
};

// Knowledge Base API
export const knowledgeBaseApi = {
  // Documents
  getDocuments: async (
    page = 1,
    pageSize = 20,
    category?: string,
    tags?: string[]
  ): Promise<PaginatedResponse<KnowledgeBaseDocument>> => {
    const response = await kbClient.get('/documents', {
      params: { page, page_size: pageSize, category, tags: tags?.join(',') },
    });
    return response.data;
  },

  getDocument: async (documentId: string): Promise<KnowledgeBaseDocument> => {
    const response = await kbClient.get(`/documents/${documentId}`);
    return response.data;
  },

  createDocument: async (
    document: Partial<KnowledgeBaseDocument>
  ): Promise<KnowledgeBaseDocument> => {
    const response = await kbClient.post('/documents', document);
    return response.data;
  },

  updateDocument: async (
    documentId: string,
    updates: Partial<KnowledgeBaseDocument>
  ): Promise<KnowledgeBaseDocument> => {
    const response = await kbClient.patch(`/documents/${documentId}`, updates);
    return response.data;
  },

  deleteDocument: async (documentId: string): Promise<void> => {
    await kbClient.delete(`/documents/${documentId}`);
  },

  uploadDocument: async (file: File, metadata?: Record<string, unknown>): Promise<KnowledgeBaseDocument> => {
    const formData = new FormData();
    formData.append('file', file);
    if (metadata) {
      formData.append('metadata', JSON.stringify(metadata));
    }

    const response = await kbClient.post('/documents/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  },

  searchDocuments: async (query: string, topK = 5): Promise<KnowledgeBaseDocument[]> => {
    const response = await kbClient.post('/documents/search', { query, top_k: topK });
    return response.data;
  },

  // Categories
  getCategories: async (): Promise<string[]> => {
    const response = await kbClient.get('/categories');
    return response.data;
  },

  // Tags
  getTags: async (): Promise<string[]> => {
    const response = await kbClient.get('/tags');
    return response.data;
  },
};

// Analytics API
export const analyticsApi = {
  // Conversation metrics
  getConversationMetrics: async (
    startDate?: string,
    endDate?: string
  ): Promise<ConversationMetrics> => {
    const response = await analyticsClient.get('/metrics/conversations', {
      params: { start_date: startDate, end_date: endDate },
    });
    return response.data;
  },

  // Cost metrics
  getCostMetrics: async (
    startDate?: string,
    endDate?: string
  ): Promise<CostMetrics> => {
    const response = await analyticsClient.get('/metrics/costs', {
      params: { start_date: startDate, end_date: endDate },
    });
    return response.data;
  },

  // Performance metrics
  getPerformanceMetrics: async (
    startDate?: string,
    endDate?: string
  ): Promise<PerformanceMetrics> => {
    const response = await analyticsClient.get('/metrics/performance', {
      params: { start_date: startDate, end_date: endDate },
    });
    return response.data;
  },

  // Model usage
  getModelUsageStats: async (
    startDate?: string,
    endDate?: string
  ): Promise<ModelUsageStats[]> => {
    const response = await analyticsClient.get('/metrics/models', {
      params: { start_date: startDate, end_date: endDate },
    });
    return response.data;
  },

  // Time series data
  getTimeSeriesData: async (
    metric: string,
    startDate: string,
    endDate: string,
    granularity: 'hour' | 'day' | 'week' = 'day'
  ): Promise<Array<{ timestamp: string; value: number }>> => {
    const response = await analyticsClient.get('/metrics/timeseries', {
      params: { metric, start_date: startDate, end_date: endDate, granularity },
    });
    return response.data;
  },
};

// Settings API
export const settingsApi = {
  getSettings: async (): Promise<SystemSettings> => {
    const response = await chatClient.get('/settings');
    return response.data;
  },

  updateSettings: async (settings: Partial<SystemSettings>): Promise<SystemSettings> => {
    const response = await chatClient.patch('/settings', settings);
    return response.data;
  },
};

// Export all
export default {
  chat: chatApi,
  kb: knowledgeBaseApi,
  analytics: analyticsApi,
  settings: settingsApi,
};

// API Types based on OpenAPI spec
export interface Message {
  id: string
  conversation_id: string
  role: 'user' | 'assistant' | 'system'
  content: string
  timestamp: string
  model?: string
  tokens?: TokenUsage
  cost?: number
  latency_ms?: number
  feedback?: 'positive' | 'negative' | null
}

export interface TokenUsage {
  prompt_tokens: number
  completion_tokens: number
  total_tokens: number
}

export interface Conversation {
  id: string
  customer_id: string
  status: 'active' | 'resolved' | 'escalated'
  created_at: string
  updated_at: string
  messages: Message[]
  total_cost?: number
  total_tokens?: number
  metadata?: Record<string, any>
}

export interface SendMessageRequest {
  conversation_id?: string
  message: string
  customer_id: string
  use_streaming?: boolean
}

export interface SendMessageResponse {
  conversation_id: string
  message: Message
  streaming_url?: string
}

export interface FeedbackRequest {
  message_id: string
  feedback: 'positive' | 'negative'
  comment?: string
}

export interface AnalyticsData {
  total_conversations: number
  active_conversations: number
  total_messages: number
  total_cost: number
  average_cost_per_conversation: number
  average_tokens_per_message: number
  average_latency_ms: number
  model_usage: ModelUsage[]
  cost_over_time: CostDataPoint[]
  feedback_summary: FeedbackSummary
}

export interface ModelUsage {
  model: string
  count: number
  total_cost: number
  average_latency_ms: number
}

export interface CostDataPoint {
  date: string
  cost: number
  tokens: number
  message_count: number
}

export interface FeedbackSummary {
  positive: number
  negative: number
  total: number
  positive_percentage: number
}

export interface StreamChunk {
  type: 'content' | 'metadata' | 'error' | 'done'
  content?: string
  metadata?: {
    model?: string
    tokens?: TokenUsage
    cost?: number
    latency_ms?: number
  }
  error?: string
}

// UI State Types
export interface ChatState {
  conversations: Conversation[]
  currentConversationId: string | null
  isLoading: boolean
  error: string | null
  streamingMessage: string | null
}

export interface AnalyticsState {
  data: AnalyticsData | null
  isLoading: boolean
  error: string | null
  dateRange: {
    start: Date
    end: Date
  }
}

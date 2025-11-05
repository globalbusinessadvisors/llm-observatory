import axios, { AxiosInstance, AxiosError } from 'axios'
import type {
  Conversation,
  Message,
  SendMessageRequest,
  SendMessageResponse,
  FeedbackRequest,
  AnalyticsData,
  StreamChunk,
} from '../types'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080/api/v1'

class APIClient {
  private client: AxiosInstance

  constructor(baseURL: string = API_BASE_URL) {
    this.client = axios.create({
      baseURL,
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 30000,
    })

    // Request interceptor for adding auth tokens, etc.
    this.client.interceptors.request.use(
      (config) => {
        // Add auth token if available
        const token = localStorage.getItem('auth_token')
        if (token) {
          config.headers.Authorization = `Bearer ${token}`
        }
        return config
      },
      (error) => Promise.reject(error)
    )

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        const message = this.extractErrorMessage(error)
        console.error('API Error:', message)
        return Promise.reject(new Error(message))
      }
    )
  }

  private extractErrorMessage(error: AxiosError): string {
    if (error.response?.data) {
      const data = error.response.data as any
      return data.message || data.error || 'An error occurred'
    }
    if (error.request) {
      return 'No response from server. Please check your connection.'
    }
    return error.message || 'An unexpected error occurred'
  }

  // Conversations
  async getConversations(customerId?: string): Promise<Conversation[]> {
    const params = customerId ? { customer_id: customerId } : {}
    const response = await this.client.get<Conversation[]>('/conversations', { params })
    return response.data
  }

  async getConversation(conversationId: string): Promise<Conversation> {
    const response = await this.client.get<Conversation>(`/conversations/${conversationId}`)
    return response.data
  }

  async createConversation(customerId: string): Promise<Conversation> {
    const response = await this.client.post<Conversation>('/conversations', { customer_id: customerId })
    return response.data
  }

  // Messages
  async sendMessage(request: SendMessageRequest): Promise<SendMessageResponse> {
    const response = await this.client.post<SendMessageResponse>('/messages', request)
    return response.data
  }

  async getMessages(conversationId: string): Promise<Message[]> {
    const response = await this.client.get<Message[]>(`/conversations/${conversationId}/messages`)
    return response.data
  }

  // Streaming
  async *streamMessage(request: SendMessageRequest): AsyncGenerator<StreamChunk> {
    const response = await fetch(`${API_BASE_URL}/messages/stream`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${localStorage.getItem('auth_token') || ''}`,
      },
      body: JSON.stringify({ ...request, use_streaming: true }),
    })

    if (!response.ok) {
      throw new Error(`Stream request failed: ${response.statusText}`)
    }

    const reader = response.body?.getReader()
    if (!reader) {
      throw new Error('Response body is not readable')
    }

    const decoder = new TextDecoder()
    let buffer = ''

    try {
      while (true) {
        const { done, value } = await reader.read()

        if (done) break

        buffer += decoder.decode(value, { stream: true })
        const lines = buffer.split('\n')
        buffer = lines.pop() || ''

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6).trim()

            if (data === '[DONE]') {
              yield { type: 'done' }
              return
            }

            try {
              const chunk = JSON.parse(data) as StreamChunk
              yield chunk
            } catch (e) {
              console.error('Failed to parse SSE data:', data)
            }
          }
        }
      }
    } finally {
      reader.releaseLock()
    }
  }

  // Feedback
  async submitFeedback(request: FeedbackRequest): Promise<void> {
    await this.client.post('/feedback', request)
  }

  // Analytics
  async getAnalytics(startDate?: Date, endDate?: Date): Promise<AnalyticsData> {
    const params: any = {}
    if (startDate) params.start_date = startDate.toISOString()
    if (endDate) params.end_date = endDate.toISOString()

    const response = await this.client.get<AnalyticsData>('/analytics', { params })
    return response.data
  }

  async getModelUsage(): Promise<any> {
    const response = await this.client.get('/analytics/models')
    return response.data
  }

  async getCostBreakdown(startDate?: Date, endDate?: Date): Promise<any> {
    const params: any = {}
    if (startDate) params.start_date = startDate.toISOString()
    if (endDate) params.end_date = endDate.toISOString()

    const response = await this.client.get('/analytics/costs', { params })
    return response.data
  }
}

// Export singleton instance
export const apiClient = new APIClient()

// Export class for testing
export default APIClient

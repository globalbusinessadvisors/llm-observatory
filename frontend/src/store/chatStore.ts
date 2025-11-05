import { create } from 'zustand'
import { devtools } from 'zustand/middleware'
import type { Conversation, Message, SendMessageRequest } from '../types'
import { apiClient } from '../lib/api'

interface ChatState {
  conversations: Conversation[]
  currentConversationId: string | null
  isLoading: boolean
  error: string | null
  streamingMessage: string | null
  isStreaming: boolean

  // Actions
  setCurrentConversation: (id: string | null) => void
  fetchConversations: (customerId?: string) => Promise<void>
  fetchConversation: (id: string) => Promise<void>
  sendMessage: (request: SendMessageRequest) => Promise<void>
  sendStreamingMessage: (request: SendMessageRequest) => Promise<void>
  submitFeedback: (messageId: string, feedback: 'positive' | 'negative') => Promise<void>
  clearError: () => void
  resetChat: () => void
}

export const useChatStore = create<ChatState>()(
  devtools(
    (set, get) => ({
      conversations: [],
      currentConversationId: null,
      isLoading: false,
      error: null,
      streamingMessage: null,
      isStreaming: false,

      setCurrentConversation: (id) => {
        set({ currentConversationId: id, streamingMessage: null, error: null })
      },

      fetchConversations: async (customerId) => {
        set({ isLoading: true, error: null })
        try {
          const conversations = await apiClient.getConversations(customerId)
          set({ conversations, isLoading: false })
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch conversations',
            isLoading: false
          })
        }
      },

      fetchConversation: async (id) => {
        set({ isLoading: true, error: null })
        try {
          const conversation = await apiClient.getConversation(id)
          set((state) => ({
            conversations: [
              ...state.conversations.filter((c) => c.id !== id),
              conversation
            ],
            currentConversationId: id,
            isLoading: false
          }))
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch conversation',
            isLoading: false
          })
        }
      },

      sendMessage: async (request) => {
        set({ isLoading: true, error: null })
        try {
          const response = await apiClient.sendMessage(request)

          // Update conversations with the new message
          set((state) => {
            const conversations = state.conversations.map((conv) => {
              if (conv.id === response.conversation_id) {
                return {
                  ...conv,
                  messages: [...conv.messages, response.message],
                  updated_at: new Date().toISOString()
                }
              }
              return conv
            })

            // If conversation doesn't exist, fetch it
            if (!conversations.find((c) => c.id === response.conversation_id)) {
              get().fetchConversation(response.conversation_id)
            }

            return { conversations, isLoading: false }
          })
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to send message',
            isLoading: false
          })
        }
      },

      sendStreamingMessage: async (request) => {
        set({ isStreaming: true, streamingMessage: '', error: null })

        try {
          let fullContent = ''
          let metadata: any = null

          for await (const chunk of apiClient.streamMessage(request)) {
            if (chunk.type === 'content' && chunk.content) {
              fullContent += chunk.content
              set({ streamingMessage: fullContent })
            } else if (chunk.type === 'metadata') {
              metadata = chunk.metadata
            } else if (chunk.type === 'error') {
              throw new Error(chunk.error || 'Streaming error')
            } else if (chunk.type === 'done') {
              // Create complete message object
              const message: Message = {
                id: crypto.randomUUID(),
                conversation_id: request.conversation_id || 'new',
                role: 'assistant',
                content: fullContent,
                timestamp: new Date().toISOString(),
                ...metadata
              }

              // Update conversation with the complete message
              set((state) => {
                const conversations = state.conversations.map((conv) => {
                  if (conv.id === request.conversation_id) {
                    return {
                      ...conv,
                      messages: [...conv.messages, message],
                      updated_at: new Date().toISOString()
                    }
                  }
                  return conv
                })

                return {
                  conversations,
                  streamingMessage: null,
                  isStreaming: false
                }
              })
              break
            }
          }
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Streaming failed',
            streamingMessage: null,
            isStreaming: false
          })
        }
      },

      submitFeedback: async (messageId, feedback) => {
        try {
          await apiClient.submitFeedback({ message_id: messageId, feedback })

          // Update local message with feedback
          set((state) => ({
            conversations: state.conversations.map((conv) => ({
              ...conv,
              messages: conv.messages.map((msg) =>
                msg.id === messageId ? { ...msg, feedback } : msg
              )
            }))
          }))
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to submit feedback'
          })
        }
      },

      clearError: () => set({ error: null }),

      resetChat: () => set({
        conversations: [],
        currentConversationId: null,
        isLoading: false,
        error: null,
        streamingMessage: null,
        isStreaming: false
      })
    }),
    { name: 'chat-store' }
  )
)

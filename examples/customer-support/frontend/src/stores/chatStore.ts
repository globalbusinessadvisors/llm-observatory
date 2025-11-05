import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import { Message, Conversation, TypingIndicator } from '@/types';
import { chatApi } from '@/api/client';
import { wsClient } from '@/api/websocket';

interface ChatState {
  // State
  conversations: Conversation[];
  currentConversation: Conversation | null;
  messages: Record<string, Message[]>;
  isLoading: boolean;
  error: string | null;
  isTyping: Record<string, boolean>;
  wsConnected: boolean;

  // Actions
  fetchConversations: () => Promise<void>;
  fetchConversation: (conversationId: string) => Promise<void>;
  createConversation: (title?: string) => Promise<Conversation>;
  deleteConversation: (conversationId: string) => Promise<void>;
  setCurrentConversation: (conversation: Conversation | null) => void;

  fetchMessages: (conversationId: string) => Promise<void>;
  sendMessage: (conversationId: string, content: string) => Promise<void>;
  addMessage: (message: Message) => void;
  updateMessage: (messageId: string, updates: Partial<Message>) => void;

  setTyping: (conversationId: string, isTyping: boolean) => void;

  connectWebSocket: () => Promise<void>;
  disconnectWebSocket: () => void;

  clearError: () => void;
  reset: () => void;
}

const initialState = {
  conversations: [],
  currentConversation: null,
  messages: {},
  isLoading: false,
  error: null,
  isTyping: {},
  wsConnected: false,
};

export const useChatStore = create<ChatState>()(
  devtools(
    (set, get) => ({
      ...initialState,

      fetchConversations: async () => {
        set({ isLoading: true, error: null });
        try {
          const response = await chatApi.getConversations(1, 50);
          set({ conversations: response.items, isLoading: false });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch conversations',
            isLoading: false
          });
        }
      },

      fetchConversation: async (conversationId: string) => {
        set({ isLoading: true, error: null });
        try {
          const conversation = await chatApi.getConversation(conversationId);
          set({ currentConversation: conversation, isLoading: false });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch conversation',
            isLoading: false
          });
        }
      },

      createConversation: async (title?: string) => {
        set({ isLoading: true, error: null });
        try {
          const conversation = await chatApi.createConversation(title);
          set((state) => ({
            conversations: [conversation, ...state.conversations],
            currentConversation: conversation,
            isLoading: false,
          }));
          return conversation;
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to create conversation',
            isLoading: false
          });
          throw error;
        }
      },

      deleteConversation: async (conversationId: string) => {
        set({ isLoading: true, error: null });
        try {
          await chatApi.deleteConversation(conversationId);
          set((state) => ({
            conversations: state.conversations.filter(c => c.id !== conversationId),
            currentConversation: state.currentConversation?.id === conversationId
              ? null
              : state.currentConversation,
            isLoading: false,
          }));
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to delete conversation',
            isLoading: false
          });
        }
      },

      setCurrentConversation: (conversation: Conversation | null) => {
        set({ currentConversation: conversation });
        if (conversation && get().wsConnected) {
          wsClient.joinConversation(conversation.id);
        }
      },

      fetchMessages: async (conversationId: string) => {
        set({ isLoading: true, error: null });
        try {
          const response = await chatApi.getMessages(conversationId, 1, 100);
          set((state) => ({
            messages: {
              ...state.messages,
              [conversationId]: response.items,
            },
            isLoading: false,
          }));
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch messages',
            isLoading: false
          });
        }
      },

      sendMessage: async (conversationId: string, content: string) => {
        set({ error: null });
        try {
          // Optimistically add user message
          const tempMessage: Message = {
            id: `temp-${Date.now()}`,
            conversationId,
            role: 'user',
            content,
            timestamp: new Date().toISOString(),
          };

          set((state) => ({
            messages: {
              ...state.messages,
              [conversationId]: [...(state.messages[conversationId] || []), tempMessage],
            },
          }));

          // Send via WebSocket if connected, otherwise use HTTP
          if (get().wsConnected) {
            wsClient.sendMessage(conversationId, content);
          } else {
            const message = await chatApi.sendMessage(conversationId, content);
            // Replace temp message with actual message
            set((state) => ({
              messages: {
                ...state.messages,
                [conversationId]: state.messages[conversationId].map(m =>
                  m.id === tempMessage.id ? message : m
                ),
              },
            }));
          }
        } catch (error) {
          set({ error: error instanceof Error ? error.message : 'Failed to send message' });
        }
      },

      addMessage: (message: Message) => {
        set((state) => ({
          messages: {
            ...state.messages,
            [message.conversationId]: [
              ...(state.messages[message.conversationId] || []),
              message,
            ],
          },
        }));
      },

      updateMessage: (messageId: string, updates: Partial<Message>) => {
        set((state) => {
          const newMessages = { ...state.messages };
          Object.keys(newMessages).forEach((conversationId) => {
            newMessages[conversationId] = newMessages[conversationId].map((msg) =>
              msg.id === messageId ? { ...msg, ...updates } : msg
            );
          });
          return { messages: newMessages };
        });
      },

      setTyping: (conversationId: string, isTyping: boolean) => {
        set((state) => ({
          isTyping: {
            ...state.isTyping,
            [conversationId]: isTyping,
          },
        }));
      },

      connectWebSocket: async () => {
        try {
          await wsClient.connect();

          wsClient.onMessage((message: Message) => {
            get().addMessage(message);
          });

          wsClient.onTyping((data: TypingIndicator) => {
            get().setTyping(data.conversationId, data.isTyping);
          });

          wsClient.onMessageUpdate((message: Message) => {
            get().updateMessage(message.id, message);
          });

          set({ wsConnected: true });
        } catch (error) {
          console.error('Failed to connect WebSocket:', error);
          set({ wsConnected: false });
        }
      },

      disconnectWebSocket: () => {
        wsClient.disconnect();
        set({ wsConnected: false });
      },

      clearError: () => set({ error: null }),

      reset: () => set(initialState),
    }),
    { name: 'ChatStore' }
  )
);

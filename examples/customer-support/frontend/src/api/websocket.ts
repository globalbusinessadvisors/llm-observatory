import { io, Socket } from 'socket.io-client';
import { Message, WebSocketMessage, TypingIndicator } from '@/types';

class WebSocketClient {
  private socket: Socket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000;

  constructor(private url: string) {}

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        this.socket = io(this.url, {
          transports: ['websocket'],
          reconnection: true,
          reconnectionAttempts: this.maxReconnectAttempts,
          reconnectionDelay: this.reconnectDelay,
          auth: {
            token: localStorage.getItem('auth_token'),
          },
        });

        this.socket.on('connect', () => {
          console.log('WebSocket connected');
          this.reconnectAttempts = 0;
          resolve();
        });

        this.socket.on('connect_error', (error) => {
          console.error('WebSocket connection error:', error);
          this.reconnectAttempts++;
          if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            reject(new Error('Max reconnection attempts reached'));
          }
        });

        this.socket.on('disconnect', (reason) => {
          console.log('WebSocket disconnected:', reason);
        });
      } catch (error) {
        reject(error);
      }
    });
  }

  disconnect(): void {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }

  isConnected(): boolean {
    return this.socket?.connected || false;
  }

  // Join a conversation room
  joinConversation(conversationId: string): void {
    if (this.socket) {
      this.socket.emit('join_conversation', { conversationId });
    }
  }

  // Leave a conversation room
  leaveConversation(conversationId: string): void {
    if (this.socket) {
      this.socket.emit('leave_conversation', { conversationId });
    }
  }

  // Send a message
  sendMessage(conversationId: string, content: string): void {
    if (this.socket) {
      this.socket.emit('message', { conversationId, content });
    }
  }

  // Typing indicator
  sendTyping(conversationId: string, isTyping: boolean): void {
    if (this.socket) {
      this.socket.emit('typing', { conversationId, isTyping });
    }
  }

  // Listen for new messages
  onMessage(callback: (message: Message) => void): void {
    if (this.socket) {
      this.socket.on('message', callback);
    }
  }

  // Listen for typing indicators
  onTyping(callback: (data: TypingIndicator) => void): void {
    if (this.socket) {
      this.socket.on('typing', callback);
    }
  }

  // Listen for message updates
  onMessageUpdate(callback: (message: Message) => void): void {
    if (this.socket) {
      this.socket.on('message_update', callback);
    }
  }

  // Listen for errors
  onError(callback: (error: Error) => void): void {
    if (this.socket) {
      this.socket.on('error', (data) => {
        callback(new Error(data.message || 'WebSocket error'));
      });
    }
  }

  // Remove event listeners
  off(event: string, callback?: (...args: unknown[]) => void): void {
    if (this.socket) {
      this.socket.off(event, callback);
    }
  }

  // Remove all listeners
  removeAllListeners(): void {
    if (this.socket) {
      this.socket.removeAllListeners();
    }
  }
}

// Create singleton instance
const CHAT_WS_URL = import.meta.env.VITE_CHAT_WS_URL || 'ws://localhost:8000';
export const wsClient = new WebSocketClient(CHAT_WS_URL);

export default wsClient;

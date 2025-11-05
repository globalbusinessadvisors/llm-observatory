import { useEffect, useRef } from 'react';
import { useChatStore } from '@/stores/chatStore';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import { Loader2 } from 'lucide-react';

interface ChatInterfaceProps {
  conversationId: string;
}

export default function ChatInterface({ conversationId }: ChatInterfaceProps) {
  const {
    currentConversation,
    messages,
    isLoading,
    error,
    fetchConversation,
    fetchMessages,
    sendMessage,
    connectWebSocket,
    disconnectWebSocket,
    wsConnected,
  } = useChatStore();

  const isInitialized = useRef(false);

  useEffect(() => {
    if (!isInitialized.current) {
      isInitialized.current = true;

      // Fetch conversation details and messages
      fetchConversation(conversationId);
      fetchMessages(conversationId);

      // Connect WebSocket
      if (!wsConnected) {
        connectWebSocket();
      }
    }

    return () => {
      // Cleanup on unmount
      if (wsConnected) {
        disconnectWebSocket();
      }
    };
  }, []);

  const conversationMessages = messages[conversationId] || [];

  const handleSendMessage = async (content: string) => {
    await sendMessage(conversationId, content);
  };

  if (isLoading && conversationMessages.length === 0) {
    return (
      <div className="flex h-full items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary-500" />
      </div>
    );
  }

  return (
    <div className="flex h-full flex-col bg-gray-50">
      {/* Header */}
      <div className="border-b border-gray-200 bg-white px-6 py-4 shadow-sm">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">
              {currentConversation?.title || 'Chat'}
            </h2>
            <p className="text-sm text-gray-500">
              {wsConnected ? (
                <span className="flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-green-500"></span>
                  Connected
                </span>
              ) : (
                <span className="flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-gray-400"></span>
                  Disconnected
                </span>
              )}
            </p>
          </div>

          {currentConversation?.metadata && (
            <div className="flex items-center gap-4 text-sm text-gray-600">
              {currentConversation.metadata.customerSatisfaction && (
                <div className="flex items-center gap-1">
                  <span>Satisfaction:</span>
                  <span className="font-semibold">
                    {currentConversation.metadata.customerSatisfaction}/5
                  </span>
                </div>
              )}
              <div className="flex items-center gap-1">
                <span>Status:</span>
                <span className="font-semibold capitalize">
                  {currentConversation.status}
                </span>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Error Banner */}
      {error && (
        <div className="bg-red-50 px-6 py-3 text-sm text-red-700">
          <p>{error}</p>
        </div>
      )}

      {/* Messages */}
      <div className="flex-1 overflow-hidden">
        <MessageList messages={conversationMessages} conversationId={conversationId} />
      </div>

      {/* Input */}
      <div className="border-t border-gray-200 bg-white px-6 py-4">
        <MessageInput onSendMessage={handleSendMessage} disabled={!wsConnected && !isLoading} />
      </div>
    </div>
  );
}

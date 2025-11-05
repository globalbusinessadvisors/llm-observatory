import { useState, useEffect } from 'react';
import { useChatStore } from '@/stores/chatStore';
import ChatInterface from '@/components/Chat/ChatInterface';
import ConversationSidebar from '@/components/Chat/ConversationSidebar';

export default function ChatPage() {
  const { currentConversation, createConversation } = useChatStore();
  const [selectedConversationId, setSelectedConversationId] = useState<string | null>(null);

  useEffect(() => {
    // Create a new conversation if none exists
    if (!currentConversation && !selectedConversationId) {
      createConversation('New Conversation').then((conv) => {
        setSelectedConversationId(conv.id);
      });
    }
  }, []);

  return (
    <div className="flex h-full">
      <ConversationSidebar
        onSelectConversation={setSelectedConversationId}
        selectedConversationId={selectedConversationId || undefined}
      />
      <div className="flex-1">
        {selectedConversationId ? (
          <ChatInterface conversationId={selectedConversationId} />
        ) : (
          <div className="flex h-full items-center justify-center">
            <div className="text-center">
              <h2 className="text-xl font-semibold text-gray-900">
                Select or create a conversation
              </h2>
              <p className="mt-2 text-sm text-gray-500">
                Choose a conversation from the sidebar or create a new one
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

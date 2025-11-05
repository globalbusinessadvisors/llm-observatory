import { useEffect } from 'react';
import { useChatStore } from '@/stores/chatStore';
import { format } from 'date-fns';
import { MessageSquarePlus, Trash2, MoreVertical } from 'lucide-react';
import clsx from 'clsx';

interface ConversationSidebarProps {
  onSelectConversation: (conversationId: string) => void;
  selectedConversationId?: string;
}

export default function ConversationSidebar({
  onSelectConversation,
  selectedConversationId,
}: ConversationSidebarProps) {
  const {
    conversations,
    fetchConversations,
    createConversation,
    deleteConversation,
    isLoading,
  } = useChatStore();

  useEffect(() => {
    fetchConversations();
  }, []);

  const handleNewConversation = async () => {
    const conversation = await createConversation('New Conversation');
    onSelectConversation(conversation.id);
  };

  const handleDeleteConversation = async (conversationId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (confirm('Are you sure you want to delete this conversation?')) {
      await deleteConversation(conversationId);
    }
  };

  return (
    <div className="flex h-full w-80 flex-col border-r border-gray-200 bg-white">
      {/* Header */}
      <div className="border-b border-gray-200 p-4">
        <button
          onClick={handleNewConversation}
          disabled={isLoading}
          className="flex w-full items-center justify-center gap-2 rounded-lg bg-primary-600 px-4 py-3 text-sm font-medium text-white transition-colors hover:bg-primary-700 disabled:bg-gray-300"
        >
          <MessageSquarePlus className="h-5 w-5" />
          New Conversation
        </button>
      </div>

      {/* Conversations list */}
      <div className="flex-1 overflow-y-auto">
        {conversations.length === 0 ? (
          <div className="flex h-full items-center justify-center p-8 text-center">
            <div>
              <MessageSquarePlus className="mx-auto h-12 w-12 text-gray-300" />
              <p className="mt-4 text-sm text-gray-500">No conversations yet</p>
            </div>
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {conversations.map((conversation) => (
              <div
                key={conversation.id}
                onClick={() => onSelectConversation(conversation.id)}
                className={clsx(
                  'group relative cursor-pointer p-4 transition-colors hover:bg-gray-50',
                  {
                    'bg-primary-50 hover:bg-primary-50': conversation.id === selectedConversationId,
                  }
                )}
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="flex-1 overflow-hidden">
                    <h3 className="truncate text-sm font-medium text-gray-900">
                      {conversation.title}
                    </h3>
                    <p className="mt-1 text-xs text-gray-500">
                      {format(new Date(conversation.lastMessageAt), 'MMM d, HH:mm')}
                    </p>
                    <div className="mt-2 flex items-center gap-2">
                      <span
                        className={clsx(
                          'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
                          {
                            'bg-green-100 text-green-700': conversation.status === 'active',
                            'bg-blue-100 text-blue-700': conversation.status === 'resolved',
                            'bg-gray-100 text-gray-700': conversation.status === 'archived',
                          }
                        )}
                      >
                        {conversation.status}
                      </span>
                      <span className="text-xs text-gray-500">
                        {conversation.messageCount} messages
                      </span>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                    <button
                      onClick={(e) => handleDeleteConversation(conversation.id, e)}
                      className="rounded p-1 text-gray-400 transition-colors hover:bg-red-50 hover:text-red-600"
                      title="Delete conversation"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                    <button
                      className="rounded p-1 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600"
                      title="More options"
                    >
                      <MoreVertical className="h-4 w-4" />
                    </button>
                  </div>
                </div>

                {conversation.tags && conversation.tags.length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-1">
                    {conversation.tags.map((tag) => (
                      <span
                        key={tag}
                        className="inline-flex items-center rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-600"
                      >
                        {tag}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

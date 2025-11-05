import { MessageCircle, Clock } from 'lucide-react'
import { Conversation } from '../types'
import { cn, formatDate } from '../lib/utils'
import { Card } from './ui/Card'

interface ConversationListProps {
  conversations: Conversation[]
  currentConversationId: string | null
  onSelectConversation: (id: string) => void
  className?: string
}

export function ConversationList({
  conversations,
  currentConversationId,
  onSelectConversation,
  className
}: ConversationListProps) {
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'bg-green-500'
      case 'resolved':
        return 'bg-blue-500'
      case 'escalated':
        return 'bg-orange-500'
      default:
        return 'bg-gray-500'
    }
  }

  const getLastMessage = (conversation: Conversation) => {
    const messages = conversation.messages
    if (messages.length === 0) return 'No messages yet'

    const lastMessage = messages[messages.length - 1]
    const preview = lastMessage.content.substring(0, 60)
    return preview.length < lastMessage.content.length ? `${preview}...` : preview
  }

  if (conversations.length === 0) {
    return (
      <div className={cn('flex flex-col items-center justify-center h-full text-center p-8', className)}>
        <MessageCircle className="text-muted-foreground mb-4" size={48} />
        <h3 className="text-lg font-medium mb-2">No conversations yet</h3>
        <p className="text-sm text-muted-foreground">
          Start a new conversation to get started
        </p>
      </div>
    )
  }

  return (
    <div className={cn('space-y-2 overflow-y-auto', className)}>
      {conversations.map((conversation) => {
        const isSelected = conversation.id === currentConversationId
        const messageCount = conversation.messages.length

        return (
          <Card
            key={conversation.id}
            className={cn(
              'p-4 cursor-pointer transition-colors hover:bg-accent',
              isSelected && 'bg-accent border-primary'
            )}
            onClick={() => onSelectConversation(conversation.id)}
          >
            <div className="flex items-start justify-between gap-3">
              <div className="flex-1 min-w-0">
                {/* Header */}
                <div className="flex items-center gap-2 mb-1">
                  <div className={cn('w-2 h-2 rounded-full', getStatusColor(conversation.status))} />
                  <span className="text-sm font-medium capitalize">
                    {conversation.status}
                  </span>
                  <span className="text-xs text-muted-foreground">
                    {messageCount} {messageCount === 1 ? 'message' : 'messages'}
                  </span>
                </div>

                {/* Last message preview */}
                <p className="text-sm text-muted-foreground truncate mb-2">
                  {getLastMessage(conversation)}
                </p>

                {/* Metadata */}
                <div className="flex items-center gap-4 text-xs text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <Clock size={12} />
                    {formatDate(conversation.updated_at)}
                  </div>
                  {conversation.total_cost !== undefined && (
                    <span className="text-primary font-medium">
                      ${conversation.total_cost.toFixed(4)}
                    </span>
                  )}
                </div>
              </div>
            </div>
          </Card>
        )
      })}
    </div>
  )
}

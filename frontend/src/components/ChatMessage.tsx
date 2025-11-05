import { useState } from 'react'
import { ThumbsUp, ThumbsDown, User, Bot } from 'lucide-react'
import { Message } from '../types'
import { cn, formatTime, formatCost, formatTokenCount } from '../lib/utils'
import { useChatStore } from '../store/chatStore'
import { Button } from './ui/Button'

interface ChatMessageProps {
  message: Message
  isStreaming?: boolean
}

export function ChatMessage({ message, isStreaming = false }: ChatMessageProps) {
  const { submitFeedback } = useChatStore()
  const [isSubmittingFeedback, setIsSubmittingFeedback] = useState(false)

  const isAssistant = message.role === 'assistant'
  const isUser = message.role === 'user'

  const handleFeedback = async (feedback: 'positive' | 'negative') => {
    if (isSubmittingFeedback || message.feedback === feedback) return

    setIsSubmittingFeedback(true)
    try {
      await submitFeedback(message.id, feedback)
    } finally {
      setIsSubmittingFeedback(false)
    }
  }

  return (
    <div
      className={cn(
        'flex gap-3 p-4 rounded-lg animate-slide-in',
        isAssistant && 'bg-muted/50',
        isUser && 'bg-background'
      )}
    >
      {/* Avatar */}
      <div
        className={cn(
          'flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center',
          isAssistant && 'bg-primary text-primary-foreground',
          isUser && 'bg-secondary text-secondary-foreground'
        )}
      >
        {isAssistant ? <Bot size={18} /> : <User size={18} />}
      </div>

      {/* Content */}
      <div className="flex-1 space-y-2">
        {/* Header */}
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">
            {isAssistant ? 'AI Assistant' : 'You'}
          </span>
          <span className="text-xs text-muted-foreground">
            {formatTime(message.timestamp)}
          </span>
        </div>

        {/* Message content */}
        <div
          className={cn(
            'text-sm whitespace-pre-wrap',
            isStreaming && 'typing-indicator'
          )}
        >
          {message.content}
          {isStreaming && <span className="inline-block w-1 h-4 ml-1 bg-primary animate-pulse" />}
        </div>

        {/* Metadata for assistant messages */}
        {isAssistant && !isStreaming && (
          <div className="flex flex-wrap items-center gap-4 mt-2">
            {/* Model info */}
            {message.model && (
              <span className="text-xs text-muted-foreground">
                Model: {message.model}
              </span>
            )}

            {/* Token usage */}
            {message.tokens && (
              <span className="text-xs text-muted-foreground">
                Tokens: {formatTokenCount(message.tokens.total_tokens)}
              </span>
            )}

            {/* Cost */}
            {message.cost !== undefined && (
              <span className="text-xs font-medium text-primary">
                Cost: {formatCost(message.cost)}
              </span>
            )}

            {/* Latency */}
            {message.latency_ms && (
              <span className="text-xs text-muted-foreground">
                {message.latency_ms}ms
              </span>
            )}

            {/* Feedback buttons */}
            <div className="flex items-center gap-1 ml-auto">
              <Button
                variant="ghost"
                size="icon"
                className={cn(
                  'h-7 w-7',
                  message.feedback === 'positive' && 'text-green-600 bg-green-50'
                )}
                onClick={() => handleFeedback('positive')}
                disabled={isSubmittingFeedback}
              >
                <ThumbsUp size={14} />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                className={cn(
                  'h-7 w-7',
                  message.feedback === 'negative' && 'text-red-600 bg-red-50'
                )}
                onClick={() => handleFeedback('negative')}
                disabled={isSubmittingFeedback}
              >
                <ThumbsDown size={14} />
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

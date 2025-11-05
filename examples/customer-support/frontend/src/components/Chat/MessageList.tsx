import { useEffect, useRef } from 'react';
import { format } from 'date-fns';
import { Message } from '@/types';
import { useChatStore } from '@/stores/chatStore';
import { Bot, User, Sparkles, DollarSign, Clock } from 'lucide-react';
import clsx from 'clsx';

interface MessageListProps {
  messages: Message[];
  conversationId: string;
}

export default function MessageList({ messages, conversationId }: MessageListProps) {
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const { isTyping } = useChatStore();
  const isAssistantTyping = isTyping[conversationId];

  useEffect(() => {
    scrollToBottom();
  }, [messages, isAssistantTyping]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  if (messages.length === 0) {
    return (
      <div className="flex h-full items-center justify-center p-8">
        <div className="text-center">
          <Bot className="mx-auto h-16 w-16 text-gray-300" />
          <h3 className="mt-4 text-lg font-medium text-gray-900">No messages yet</h3>
          <p className="mt-2 text-sm text-gray-500">
            Start the conversation by sending a message below
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full overflow-y-auto px-6 py-4">
      <div className="space-y-6">
        {messages.map((message, index) => (
          <MessageBubble
            key={message.id}
            message={message}
            isFirst={index === 0 || messages[index - 1].role !== message.role}
          />
        ))}

        {isAssistantTyping && (
          <div className="flex items-start gap-3">
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary-100">
              <Bot className="h-5 w-5 text-primary-600" />
            </div>
            <div className="flex items-center gap-2 rounded-2xl rounded-tl-sm bg-white px-4 py-3 shadow-sm">
              <div className="flex gap-1">
                <span className="h-2 w-2 animate-bounce rounded-full bg-gray-400 [animation-delay:-0.3s]"></span>
                <span className="h-2 w-2 animate-bounce rounded-full bg-gray-400 [animation-delay:-0.15s]"></span>
                <span className="h-2 w-2 animate-bounce rounded-full bg-gray-400"></span>
              </div>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>
    </div>
  );
}

interface MessageBubbleProps {
  message: Message;
  isFirst: boolean;
}

function MessageBubble({ message, isFirst }: MessageBubbleProps) {
  const isUser = message.role === 'user';
  const isAssistant = message.role === 'assistant';
  const isSystem = message.role === 'system';

  if (isSystem) {
    return (
      <div className="flex justify-center">
        <div className="rounded-lg bg-gray-100 px-4 py-2 text-xs text-gray-600">
          {message.content}
        </div>
      </div>
    );
  }

  return (
    <div
      className={clsx('flex items-start gap-3', {
        'flex-row-reverse': isUser,
      })}
    >
      {/* Avatar */}
      {isFirst && (
        <div
          className={clsx('flex h-8 w-8 items-center justify-center rounded-full', {
            'bg-gray-700': isUser,
            'bg-primary-100': isAssistant,
          })}
        >
          {isUser ? (
            <User className="h-5 w-5 text-white" />
          ) : (
            <Bot className="h-5 w-5 text-primary-600" />
          )}
        </div>
      )}
      {!isFirst && <div className="h-8 w-8" />}

      <div className="flex-1 space-y-1">
        {/* Message bubble */}
        <div
          className={clsx('max-w-[80%] rounded-2xl px-4 py-3 shadow-sm', {
            'ml-auto bg-gray-700 text-white': isUser,
            'rounded-tr-sm': isUser && isFirst,
            'bg-white text-gray-900': isAssistant,
            'rounded-tl-sm': isAssistant && isFirst,
          })}
        >
          <div className="whitespace-pre-wrap break-words text-sm leading-relaxed">
            {message.content}
          </div>

          {/* Message metadata */}
          {message.metadata && isAssistant && (
            <div className="mt-3 space-y-2 border-t border-gray-100 pt-3">
              {message.metadata.citations && message.metadata.citations.length > 0 && (
                <div className="space-y-1">
                  <div className="flex items-center gap-1 text-xs font-medium text-gray-500">
                    <Sparkles className="h-3 w-3" />
                    <span>Sources</span>
                  </div>
                  <div className="space-y-1">
                    {message.metadata.citations.map((citation, idx) => (
                      <div
                        key={idx}
                        className="rounded-md bg-gray-50 p-2 text-xs text-gray-700"
                      >
                        <div className="font-medium">{citation.documentTitle}</div>
                        <div className="mt-1 text-gray-600">{citation.snippet}</div>
                        <div className="mt-1 text-gray-500">
                          Relevance: {(citation.relevanceScore * 100).toFixed(0)}%
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Timestamp and stats */}
        <div
          className={clsx('flex items-center gap-3 px-2 text-xs text-gray-500', {
            'justify-end': isUser,
          })}
        >
          <span>{format(new Date(message.timestamp), 'HH:mm')}</span>

          {message.metadata && isAssistant && (
            <>
              {message.metadata.latency && (
                <span className="flex items-center gap-1">
                  <Clock className="h-3 w-3" />
                  {message.metadata.latency.toFixed(0)}ms
                </span>
              )}
              {message.metadata.cost && (
                <span className="flex items-center gap-1">
                  <DollarSign className="h-3 w-3" />
                  ${message.metadata.cost.toFixed(4)}
                </span>
              )}
              {message.metadata.modelUsed && (
                <span className="font-mono text-[10px]">
                  {message.metadata.modelUsed}
                </span>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

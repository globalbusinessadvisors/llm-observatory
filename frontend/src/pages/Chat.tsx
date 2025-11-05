import { useEffect, useRef, useState } from 'react'
import { useChatStore } from '../store/chatStore'
import { ChatMessage } from '../components/ChatMessage'
import { MessageInput } from '../components/MessageInput'
import { ConversationList } from '../components/ConversationList'
import { Card } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { MessageCircle, Menu, X, Loader2 } from 'lucide-react'

export function Chat() {
  const {
    conversations,
    currentConversationId,
    isLoading,
    isStreaming,
    streamingMessage,
    error,
    setCurrentConversation,
    fetchConversations,
    sendStreamingMessage,
    clearError
  } = useChatStore()

  const [customerId] = useState('customer-123') // In production, get from auth
  const [showSidebar, setShowSidebar] = useState(true)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    fetchConversations(customerId)
  }, [fetchConversations, customerId])

  useEffect(() => {
    scrollToBottom()
  }, [currentConversationId, streamingMessage])

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const currentConversation = conversations.find(
    (c) => c.id === currentConversationId
  )

  const handleSendMessage = async (message: string) => {
    await sendStreamingMessage({
      conversation_id: currentConversationId || undefined,
      message,
      customer_id: customerId,
      use_streaming: true
    })
  }

  const handleNewConversation = () => {
    setCurrentConversation(null)
  }

  return (
    <div className="flex h-screen bg-background">
      {/* Sidebar */}
      <div
        className={`${
          showSidebar ? 'w-80' : 'w-0'
        } transition-all duration-300 border-r border-border overflow-hidden`}
      >
        <div className="h-full flex flex-col p-4">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold">Conversations</h2>
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setShowSidebar(false)}
              className="lg:hidden"
            >
              <X size={18} />
            </Button>
          </div>

          <Button
            onClick={handleNewConversation}
            className="mb-4"
            disabled={isLoading || isStreaming}
          >
            <MessageCircle size={18} className="mr-2" />
            New Conversation
          </Button>

          <ConversationList
            conversations={conversations}
            currentConversationId={currentConversationId}
            onSelectConversation={setCurrentConversation}
            className="flex-1"
          />
        </div>
      </div>

      {/* Main Chat Area */}
      <div className="flex-1 flex flex-col">
        {/* Header */}
        <div className="border-b border-border p-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            {!showSidebar && (
              <Button
                variant="ghost"
                size="icon"
                onClick={() => setShowSidebar(true)}
              >
                <Menu size={18} />
              </Button>
            )}
            <div>
              <h1 className="text-xl font-semibold">AI Customer Support</h1>
              {currentConversation && (
                <p className="text-sm text-muted-foreground">
                  {currentConversation.messages.length} messages
                  {currentConversation.total_cost !== undefined && (
                    <> • ${currentConversation.total_cost.toFixed(4)}</>
                  )}
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Error Banner */}
        {error && (
          <div className="bg-destructive/10 text-destructive px-4 py-3 flex items-center justify-between">
            <span className="text-sm">{error}</span>
            <Button
              variant="ghost"
              size="sm"
              onClick={clearError}
            >
              Dismiss
            </Button>
          </div>
        )}

        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {!currentConversation && !isStreaming ? (
            <div className="h-full flex items-center justify-center">
              <Card className="p-8 max-w-md text-center">
                <MessageCircle className="mx-auto mb-4 text-muted-foreground" size={48} />
                <h2 className="text-xl font-semibold mb-2">
                  Welcome to AI Customer Support
                </h2>
                <p className="text-muted-foreground mb-4">
                  Start a new conversation or select an existing one from the sidebar.
                </p>
                <Button onClick={handleNewConversation}>
                  Start Conversation
                </Button>
              </Card>
            </div>
          ) : (
            <>
              {currentConversation?.messages.map((message) => (
                <ChatMessage key={message.id} message={message} />
              ))}

              {isStreaming && streamingMessage && (
                <ChatMessage
                  message={{
                    id: 'streaming',
                    conversation_id: currentConversationId || 'new',
                    role: 'assistant',
                    content: streamingMessage,
                    timestamp: new Date().toISOString()
                  }}
                  isStreaming={true}
                />
              )}

              {isLoading && !isStreaming && (
                <div className="flex items-center justify-center p-4">
                  <Loader2 className="animate-spin text-muted-foreground" />
                </div>
              )}

              <div ref={messagesEndRef} />
            </>
          )}
        </div>

        {/* Input */}
        <div className="border-t border-border p-4">
          <MessageInput
            onSend={handleSendMessage}
            disabled={isLoading || isStreaming}
            placeholder={
              isStreaming
                ? 'Waiting for response...'
                : 'Type your message...'
            }
          />
        </div>
      </div>
    </div>
  )
}

import { useState, useRef, KeyboardEvent } from 'react';
import { Send, Paperclip } from 'lucide-react';
import clsx from 'clsx';

interface MessageInputProps {
  onSendMessage: (content: string) => void;
  disabled?: boolean;
  placeholder?: string;
}

export default function MessageInput({
  onSendMessage,
  disabled = false,
  placeholder = 'Type your message...',
}: MessageInputProps) {
  const [message, setMessage] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleSubmit = () => {
    if (message.trim() && !disabled) {
      onSendMessage(message.trim());
      setMessage('');
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto';
      }
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const handleInput = (e: React.FormEvent<HTMLTextAreaElement>) => {
    const target = e.target as HTMLTextAreaElement;
    setMessage(target.value);

    // Auto-resize textarea
    target.style.height = 'auto';
    target.style.height = `${Math.min(target.scrollHeight, 200)}px`;
  };

  return (
    <div className="flex items-end gap-3">
      {/* Attachment button */}
      <button
        type="button"
        className="flex h-10 w-10 items-center justify-center rounded-lg text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600 disabled:opacity-50"
        disabled={disabled}
        title="Attach file"
      >
        <Paperclip className="h-5 w-5" />
      </button>

      {/* Text input */}
      <div className="relative flex-1">
        <textarea
          ref={textareaRef}
          value={message}
          onChange={handleInput}
          onKeyDown={handleKeyDown}
          placeholder={placeholder}
          disabled={disabled}
          rows={1}
          className={clsx(
            'w-full resize-none rounded-lg border border-gray-300 px-4 py-3 pr-12',
            'text-sm placeholder-gray-400 transition-colors',
            'focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20',
            'disabled:bg-gray-50 disabled:text-gray-500',
            'max-h-[200px] overflow-y-auto'
          )}
        />
      </div>

      {/* Send button */}
      <button
        type="button"
        onClick={handleSubmit}
        disabled={disabled || !message.trim()}
        className={clsx(
          'flex h-10 w-10 items-center justify-center rounded-lg transition-colors',
          'bg-primary-600 text-white hover:bg-primary-700',
          'disabled:bg-gray-300 disabled:text-gray-500 disabled:cursor-not-allowed'
        )}
        title="Send message (Enter)"
      >
        <Send className="h-5 w-5" />
      </button>
    </div>
  );
}

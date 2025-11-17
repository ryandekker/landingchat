/**
 * Message input component
 */

import { useState, FormEvent } from 'react';

interface MessageInputProps {
  onSend: (message: string) => void;
  isLoading: boolean;
  isComplete: boolean;
}

export function MessageInput({ onSend, isLoading, isComplete }: MessageInputProps) {
  const [message, setMessage] = useState('');

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();

    if (message.trim() && !isLoading) {
      onSend(message.trim());
      setMessage('');
    }
  };

  const placeholder = isComplete
    ? 'You can ask follow-up questions...'
    : 'Type your message...';

  return (
    <form onSubmit={handleSubmit} className="flex gap-2">
      <input
        type="text"
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        placeholder={placeholder}
        disabled={isLoading}
        className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 disabled:bg-gray-100"
      />
      <button
        type="submit"
        disabled={isLoading || !message.trim()}
        className="px-6 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
      >
        {isLoading ? 'Sending...' : 'Send'}
      </button>
    </form>
  );
}

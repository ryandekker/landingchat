/**
 * Main App component
 */

import { useEffect, useRef } from 'react';
import { useSession } from './hooks/useSession';
import { useChat } from './hooks/useChat';
import { ChatMessage } from './components/ChatMessage';
import { MessageInput } from './components/MessageInput';
import { RadarChart } from './components/RadarChart';
import { ProfileSummary } from './components/ProfileSummary';
import { EmailCapture } from './components/EmailCapture';
import { Recommendations } from './components/Recommendations';

function App() {
  const { sessionId } = useSession();
  const {
    messages,
    profile,
    recommendations,
    isComplete,
    showRecommendations,
    sendMessage,
    submitEmail,
    isLoading,
    emailSubmitting,
    error
  } = useChat(sessionId);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const initialMessageSent = useRef(false);

  // Auto-scroll to bottom when messages change
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Send initial message on mount (only once)
  useEffect(() => {
    if (messages.length === 0 && !initialMessageSent.current) {
      initialMessageSent.current = true;
      sendMessage('Hello');
    }
  }, []);

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Left Panel - Chat */}
      <div className="flex-1 flex flex-col max-w-4xl">
        {/* Header */}
        <div className="bg-white border-b border-gray-200 px-6 py-4">
          <h1 className="text-2xl font-bold text-gray-900">
            Find Your Perfect Solution
          </h1>
          <p className="text-sm text-gray-600 mt-1">
            Tell us about your needs and we'll help you discover the right tools
          </p>
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto px-6 py-4">
          {error && (
            <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
              <p className="text-sm text-red-800">
                Error: {error instanceof Error ? error.message : 'Something went wrong'}
              </p>
            </div>
          )}

          {messages.map((msg, idx) => (
            <ChatMessage
              key={idx}
              role={msg.role}
              content={msg.content}
              timestamp={msg.timestamp}
            />
          ))}

          {isComplete && (
            <div className="my-4 p-4 bg-green-50 border border-green-200 rounded-lg">
              <p className="text-sm text-green-800 font-semibold">
                We have enough information to help you!
              </p>
              <p className="text-xs text-green-700 mt-1">
                Check out the recommendations on the right. You can still ask follow-up questions.
              </p>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {/* Input */}
        <div className="bg-white border-t border-gray-200 px-6 py-4">
          <MessageInput
            onSend={sendMessage}
            isLoading={isLoading}
            isComplete={isComplete}
          />
        </div>
      </div>

      {/* Right Panel - Info */}
      <div className="w-96 bg-white border-l border-gray-200 overflow-y-auto">
        <div className="p-6 space-y-6">
          {/* What this tool does */}
          <div>
            <h2 className="font-semibold text-lg mb-2">What this tool does</h2>
            <ul className="text-sm text-gray-700 space-y-1 list-disc list-inside">
              <li>Interviews you about your use case</li>
              <li>Tracks understanding and progress</li>
              <li>Finds relevant tools in our catalog</li>
            </ul>
          </div>

          {/* Radar Chart */}
          <div>
            <h2 className="font-semibold text-lg mb-2">Understanding</h2>
            <RadarChart dimensions={profile?.radar || []} />
          </div>

          {/* Profile Summary */}
          <div>
            <h2 className="font-semibold text-lg mb-2">What we've captured</h2>
            <ProfileSummary profile={profile} />
          </div>

          {/* Recommendations */}
          {showRecommendations && recommendations.length > 0 && (
            <div>
              <Recommendations recommendations={recommendations} />
            </div>
          )}

          {/* Email Capture */}
          <div>
            <EmailCapture
              onSubmit={submitEmail}
              isSubmitting={emailSubmitting}
              currentEmail={profile?.attributes.email}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;

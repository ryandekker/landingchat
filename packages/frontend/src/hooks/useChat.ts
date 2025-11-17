/**
 * Chat hook using React Query
 */

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import type {
  UserProfile,
  SearchResultSummary,
  ChatResponse
} from '@landingchat/shared';
import { sendChatMessage, captureEmail } from '../lib/api';

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
}

interface UseChatState {
  messages: ChatMessage[];
  profile: UserProfile | null;
  recommendations: SearchResultSummary[];
  isComplete: boolean;
  showRecommendations: boolean;
}

/**
 * Hook for managing chat state and API calls
 */
export function useChat(sessionId: string) {
  const [state, setState] = useState<UseChatState>({
    messages: [],
    profile: null,
    recommendations: [],
    isComplete: false,
    showRecommendations: false
  });

  const chatMutation = useMutation({
    mutationFn: (message: string) =>
      sendChatMessage({
        sessionId,
        channel: 'text',
        message
      }),
    onSuccess: (response: ChatResponse) => {
      setState(prev => ({
        ...prev,
        messages: [
          ...prev.messages,
          {
            role: 'assistant',
            content: response.assistantMessage,
            timestamp: new Date().toISOString()
          }
        ],
        profile: response.fullProfile,
        recommendations: response.searchRecommendations,
        isComplete: response.uiDirectives.conversation_complete,
        showRecommendations: response.uiDirectives.show_recommendations
      }));
    }
  });

  const emailMutation = useMutation({
    mutationFn: (email: string) =>
      captureEmail({
        sessionId,
        email
      }),
    onSuccess: (response) => {
      setState(prev => ({
        ...prev,
        profile: response.profile
      }));
    }
  });

  const sendMessage = (message: string) => {
    setState(prev => ({
      ...prev,
      messages: [
        ...prev.messages,
        {
          role: 'user',
          content: message,
          timestamp: new Date().toISOString()
        }
      ]
    }));

    chatMutation.mutate(message);
  };

  const submitEmail = (email: string) => {
    emailMutation.mutate(email);
  };

  return {
    messages: state.messages,
    profile: state.profile,
    recommendations: state.recommendations,
    isComplete: state.isComplete,
    showRecommendations: state.showRecommendations,
    sendMessage,
    submitEmail,
    isLoading: chatMutation.isPending,
    emailSubmitting: emailMutation.isPending,
    error: chatMutation.error || emailMutation.error
  };
}

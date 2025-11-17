/**
 * API client for communicating with the backend worker
 */

import type {
  ChatRequest,
  ChatResponse,
  EmailCaptureRequest,
  EmailCaptureResponse
} from '@landingchat/shared';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8787';

/**
 * Send a chat message
 */
export async function sendChatMessage(request: ChatRequest): Promise<ChatResponse> {
  const response = await fetch(`${API_URL}/api/chat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(request)
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to send message');
  }

  return await response.json();
}

/**
 * Capture email for a session
 */
export async function captureEmail(request: EmailCaptureRequest): Promise<EmailCaptureResponse> {
  const response = await fetch(`${API_URL}/api/profile/email`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(request)
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to capture email');
  }

  return await response.json();
}

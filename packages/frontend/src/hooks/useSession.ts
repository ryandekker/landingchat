/**
 * Session management hook
 */

import { useState, useEffect } from 'react';
import type { SessionId } from '@landingchat/shared';
import { generateSessionId } from '@landingchat/shared';

const SESSION_KEY = 'landingchat_session_id';

/**
 * Hook to manage session ID in localStorage
 */
export function useSession() {
  const [sessionId, setSessionId] = useState<SessionId>(() => {
    const stored = localStorage.getItem(SESSION_KEY);
    if (stored) {
      return stored;
    }

    const newId = generateSessionId();
    localStorage.setItem(SESSION_KEY, newId);
    return newId;
  });

  useEffect(() => {
    localStorage.setItem(SESSION_KEY, sessionId);
  }, [sessionId]);

  const resetSession = () => {
    const newId = generateSessionId();
    setSessionId(newId);
    localStorage.setItem(SESSION_KEY, newId);
  };

  return { sessionId, resetSession };
}

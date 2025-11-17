/**
 * Shared utility functions
 */

import type { SessionId, MessageId } from './types.js';

/**
 * Generate a UUID v4 session ID
 */
export function generateSessionId(): SessionId {
  return crypto.randomUUID();
}

/**
 * Generate a message ID
 */
export function generateMessageId(): MessageId {
  return crypto.randomUUID();
}

/**
 * Get current ISO timestamp
 */
export function getCurrentTimestamp(): string {
  return new Date().toISOString();
}

/**
 * Validate email format
 */
export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

/**
 * Create a DynamoDB sort key for messages (timestamp#messageId)
 */
export function createMessageSortKey(timestamp: string, messageId: MessageId): string {
  return `${timestamp}#${messageId}`;
}

/**
 * Parse a DynamoDB message sort key back into components
 */
export function parseMessageSortKey(sortKey: string): { timestamp: string; messageId: MessageId } {
  const [timestamp, messageId] = sortKey.split('#');
  return { timestamp, messageId };
}

/**
 * Merge radar dimensions by ID, preferring newer values
 */
export function mergeRadarDimensions(
  existing: Array<{ id: string; label: string; score: number; confidence: number }>,
  updates: Array<{ id: string; label: string; score: number; confidence: number }>
): Array<{ id: string; label: string; score: number; confidence: number }> {
  const merged = new Map(existing.map(dim => [dim.id, dim]));

  for (const update of updates) {
    merged.set(update.id, update);
  }

  return Array.from(merged.values());
}

/**
 * Deep clone an object (simple implementation for JSON-serializable objects)
 */
export function deepClone<T>(obj: T): T {
  return JSON.parse(JSON.stringify(obj));
}

/**
 * Check if conversation is complete based on remaining questions
 */
export function isConversationComplete(remainingQuestions: string[]): boolean {
  return remainingQuestions.length === 0;
}

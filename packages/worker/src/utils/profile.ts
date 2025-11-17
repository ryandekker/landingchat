/**
 * Profile merge and update utilities
 */

import type {
  UserProfile,
  LlmOrchestratorOutput,
  RadarDimension
} from '@landingchat/shared';
import { mergeRadarDimensions, getCurrentTimestamp } from '@landingchat/shared';

/**
 * Merge LLM output delta into existing profile
 */
export function mergeProfileDelta(
  profile: UserProfile,
  delta: LlmOrchestratorOutput
): UserProfile {
  const updated: UserProfile = {
    ...profile,
    lastUpdated: getCurrentTimestamp()
  };

  // Merge radar dimensions
  if (delta.profile_delta.radar && delta.profile_delta.radar.length > 0) {
    updated.radar = mergeRadarDimensions(profile.radar, delta.profile_delta.radar);
  }

  // Merge attributes (shallow merge)
  if (delta.profile_delta.attributes) {
    updated.attributes = {
      ...profile.attributes,
      ...delta.profile_delta.attributes
    };
  }

  // Merge intent tags (union)
  if (delta.profile_delta.inferred_intent_tags) {
    const existingTags = new Set(profile.inferred_intent_tags);
    delta.profile_delta.inferred_intent_tags.forEach(tag => existingTags.add(tag));
    updated.inferred_intent_tags = Array.from(existingTags);
  }

  // Merge conversation summary
  if (delta.conversation_summary_delta) {
    updated.conversation_summary = {
      answered_questions:
        delta.conversation_summary_delta.answered_questions ||
        profile.conversation_summary.answered_questions,
      remaining_questions:
        delta.conversation_summary_delta.remaining_questions ||
        profile.conversation_summary.remaining_questions,
      summary_text:
        delta.conversation_summary_delta.summary_text ||
        profile.conversation_summary.summary_text
    };
  }

  return updated;
}

/**
 * Extract profile delta for response (only changed fields)
 */
export function extractProfileDelta(delta: LlmOrchestratorOutput) {
  return {
    radar: delta.profile_delta.radar || [],
    attributes: delta.profile_delta.attributes || {},
    inferred_intent_tags: delta.profile_delta.inferred_intent_tags || []
  };
}

/**
 * Normalize UI directives with defaults
 */
export function normalizeUiDirectives(
  delta: LlmOrchestratorOutput,
  conversationComplete: boolean
) {
  return {
    show_recommendations: delta.ui_directives?.show_recommendations ?? false,
    highlight_dimensions: delta.ui_directives?.highlight_dimensions ?? [],
    ask_for_email: delta.ui_directives?.ask_for_email ?? false,
    conversation_complete: delta.ui_directives?.conversation_complete ?? conversationComplete
  };
}

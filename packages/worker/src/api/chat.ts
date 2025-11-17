/**
 * POST /api/chat endpoint handler
 */

import type {
  ChatRequest,
  ChatResponse,
  WorkerEnv,
  ChatMessage,
  UserProfile
} from '@landingchat/shared';
import {
  generateSessionId,
  generateMessageId,
  getCurrentTimestamp,
  isConversationComplete
} from '@landingchat/shared';
import { getDefaultInterviewerConfig } from '@landingchat/config';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { Client as OpenSearchClient } from '@opensearch-project/opensearch';

import {
  createDynamoDBClient,
  getProfile,
  saveProfile,
  createNewProfile,
  appendMessage,
  getRecentMessages
} from '../services/dynamodb.js';
import { createOpenSearchClient, searchApps } from '../services/opensearch.js';
import { generateNextTurn } from '../services/llm.js';
import { mergeProfileDelta, extractProfileDelta, normalizeUiDirectives } from '../utils/profile.js';
import { jsonResponse, errorResponse } from '../utils/cors.js';

/**
 * Handle POST /api/chat
 */
export async function handleChatRequest(
  request: Request,
  env: WorkerEnv
): Promise<Response> {
  try {
    // Parse request
    const body = await request.json() as ChatRequest;

    if (!body.message || typeof body.message !== 'string') {
      return errorResponse(request, env, 'Missing or invalid message', 400);
    }

    // Normalize session ID
    const sessionId = body.sessionId || generateSessionId();

    // Create clients
    const dynamoClient = createDynamoDBClient(env);
    const openSearchClient = createOpenSearchClient(env);

    // Get configuration
    const config = getDefaultInterviewerConfig();

    // Load or create profile
    let profile = await getProfile(dynamoClient, env, sessionId);

    if (!profile) {
      // Create new profile with full checklist
      const checklistIds = config.checklist.map(item => item.id);
      profile = createNewProfile(sessionId, checklistIds);
      await saveProfile(dynamoClient, env, profile);
    }

    // Append user message
    const userMessageId = generateMessageId();
    const userMessage: ChatMessage = {
      id: userMessageId,
      sessionId,
      role: 'user',
      content: body.message,
      timestamp: getCurrentTimestamp(),
      channel: body.channel || 'text'
    };

    await appendMessage(dynamoClient, env, userMessage);

    // Get recent messages (last 20)
    const recentMessages = await getRecentMessages(dynamoClient, env, sessionId, 20);

    // Generate next turn using LLM
    const llmOutput = await generateNextTurn(
      env,
      config,
      profile,
      recentMessages,
      body.message
    );

    // Merge LLM delta into profile
    const updatedProfile = mergeProfileDelta(profile, llmOutput);

    // Check if conversation is complete
    const conversationComplete = isConversationComplete(
      updatedProfile.conversation_summary.remaining_questions
    );

    // Search apps if queries provided
    let searchRecommendations = [];
    if (llmOutput.search_queries && llmOutput.search_queries.length > 0) {
      searchRecommendations = await searchApps(
        openSearchClient,
        env,
        updatedProfile,
        llmOutput.search_queries
      );

      // Store recommended app IDs in profile
      updatedProfile.recommended_apps = searchRecommendations.map(r => r.id);
    }

    // Save updated profile
    await saveProfile(dynamoClient, env, updatedProfile);

    // Append assistant message
    const assistantMessageId = generateMessageId();
    const assistantMessage: ChatMessage = {
      id: assistantMessageId,
      sessionId,
      role: 'assistant',
      content: llmOutput.assistant_message,
      timestamp: getCurrentTimestamp(),
      channel: 'text'
    };

    await appendMessage(dynamoClient, env, assistantMessage);

    // Build response
    const response: ChatResponse = {
      sessionId,
      assistantMessage: llmOutput.assistant_message,
      profileDelta: extractProfileDelta(llmOutput),
      fullProfile: updatedProfile,
      searchRecommendations,
      uiDirectives: normalizeUiDirectives(llmOutput, conversationComplete)
    };

    return jsonResponse(request, env, response);
  } catch (error) {
    console.error('Error handling chat request:', error);
    return errorResponse(
      request,
      env,
      error instanceof Error ? error.message : 'Internal server error',
      500
    );
  }
}

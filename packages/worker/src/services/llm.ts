/**
 * LLM service for calling Google's Gemini API
 */

import type {
  UserProfile,
  ChatMessage,
  LlmOrchestratorOutput,
  WorkerEnv,
  InterviewerConfig
} from '@landingchat/shared';
import { buildInterviewerPrompt } from '@landingchat/config';

interface GeminiMessage {
  role: 'user' | 'model';
  parts: Array<{ text: string }>;
}

interface GeminiRequest {
  contents: GeminiMessage[];
  systemInstruction?: {
    parts: Array<{ text: string }>;
  };
  generationConfig?: {
    temperature?: number;
    maxOutputTokens?: number;
    topP?: number;
    topK?: number;
  };
}

interface GeminiResponse {
  candidates: Array<{
    content: {
      parts: Array<{ text: string }>;
      role: string;
    };
    finishReason: string;
  }>;
  usageMetadata?: {
    promptTokenCount: number;
    candidatesTokenCount: number;
    totalTokenCount: number;
  };
}

/**
 * Build context message with current profile and conversation state
 */
function buildContextMessage(
  profile: UserProfile,
  recentMessages: ChatMessage[]
): string {
  const context = {
    current_profile: {
      radar: profile.radar,
      attributes: profile.attributes,
      inferred_intent_tags: profile.inferred_intent_tags,
      conversation_summary: profile.conversation_summary
    },
    recent_conversation: recentMessages.map(msg => ({
      role: msg.role,
      content: msg.content
    }))
  };

  return `## Current Context\n\n${JSON.stringify(context, null, 2)}`;
}

/**
 * Call Gemini API
 */
async function callGeminiAPI(
  env: WorkerEnv,
  model: string,
  request: GeminiRequest
): Promise<GeminiResponse> {
  const baseUrl = env.LLM_API_URL || 'https://generativelanguage.googleapis.com/v1beta';
  const apiUrl = `${baseUrl}/models/${model}:generateContent?key=${env.LLM_API_KEY}`;

  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(request)
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
  }

  return await response.json();
}

/**
 * Parse LLM response as JSON, with retry on malformed JSON
 */
async function parseLlmResponse(
  env: WorkerEnv,
  response: string,
  systemPrompt: string,
  messages: GeminiMessage[]
): Promise<LlmOrchestratorOutput> {
  try {
    // Try to extract JSON from response (in case there's extra text)
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('No JSON found in response');
    }

    return JSON.parse(jsonMatch[0]);
  } catch (error) {
    console.error('Failed to parse LLM response, retrying with fix instruction:', error);

    // Retry with instruction to fix the JSON
    const retryMessages: GeminiMessage[] = [
      ...messages,
      {
        role: 'model',
        parts: [{ text: response }]
      },
      {
        role: 'user',
        parts: [{ text: 'The JSON you provided was malformed. Please provide ONLY valid JSON matching the schema, with no extra text.' }]
      }
    ];

    const retryResponse = await callGeminiAPI(env, env.LLM_BASE_MODEL, {
      contents: retryMessages,
      systemInstruction: {
        parts: [{ text: systemPrompt }]
      },
      generationConfig: {
        temperature: 0,
        maxOutputTokens: 2048
      }
    });

    const retryText = retryResponse.candidates[0].content.parts[0].text;
    const retryJsonMatch = retryText.match(/\{[\s\S]*\}/);

    if (!retryJsonMatch) {
      throw new Error('Failed to get valid JSON after retry');
    }

    return JSON.parse(retryJsonMatch[0]);
  }
}

/**
 * Generate next turn using LLM orchestrator
 */
export async function generateNextTurn(
  env: WorkerEnv,
  config: InterviewerConfig,
  profile: UserProfile,
  recentMessages: ChatMessage[],
  userMessage: string
): Promise<LlmOrchestratorOutput> {
  // Build the system prompt
  const systemPrompt = buildInterviewerPrompt(config);

  // Build the context
  const contextMessage = buildContextMessage(profile, recentMessages);

  // Build messages array
  const messages: GeminiMessage[] = [
    {
      role: 'user',
      parts: [{ text: contextMessage }]
    },
    {
      role: 'model',
      parts: [{ text: 'I understand the current context. I will now respond to the user\'s message with valid JSON following the schema.' }]
    },
    {
      role: 'user',
      parts: [{ text: `User's message: ${userMessage}\n\nRespond with ONLY valid JSON matching the schema defined in the system prompt.` }]
    }
  ];

  // Call the API
  const response = await callGeminiAPI(env, env.LLM_BASE_MODEL, {
    contents: messages,
    systemInstruction: {
      parts: [{ text: systemPrompt }]
    },
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 2048
    }
  });

  const responseText = response.candidates[0].content.parts[0].text;

  // Parse and validate the response
  return await parseLlmResponse(env, responseText, systemPrompt, messages);
}

/**
 * Summarize a long conversation (using heavy model)
 */
export async function summarizeConversation(
  env: WorkerEnv,
  messages: ChatMessage[]
): Promise<string> {
  const conversationText = messages
    .map(msg => `${msg.role}: ${msg.content}`)
    .join('\n\n');

  const response = await callGeminiAPI(env, env.LLM_HEAVY_MODEL, {
    contents: [
      {
        role: 'user',
        parts: [{ text: `Summarize this conversation in 2-3 paragraphs, focusing on what we learned about the user's needs:\n\n${conversationText}` }]
      }
    ],
    generationConfig: {
      temperature: 0.3,
      maxOutputTokens: 1024
    }
  });

  return response.candidates[0].content.parts[0].text;
}

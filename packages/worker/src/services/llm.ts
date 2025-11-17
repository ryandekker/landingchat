/**
 * LLM service for calling Anthropic's Claude API
 */

import type {
  UserProfile,
  ChatMessage,
  LlmOrchestratorOutput,
  WorkerEnv,
  InterviewerConfig
} from '@landingchat/shared';
import { buildInterviewerPrompt } from '@landingchat/config';

interface AnthropicMessage {
  role: 'user' | 'assistant';
  content: string;
}

interface AnthropicRequest {
  model: string;
  max_tokens: number;
  messages: AnthropicMessage[];
  system?: string;
  temperature?: number;
}

interface AnthropicResponse {
  id: string;
  type: string;
  role: string;
  content: Array<{
    type: string;
    text: string;
  }>;
  model: string;
  stop_reason: string;
  usage: {
    input_tokens: number;
    output_tokens: number;
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
 * Call Anthropic API
 */
async function callAnthropicAPI(
  env: WorkerEnv,
  request: AnthropicRequest
): Promise<AnthropicResponse> {
  const apiUrl = env.LLM_API_URL || 'https://api.anthropic.com/v1/messages';

  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': env.LLM_API_KEY,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify(request)
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Anthropic API error: ${response.status} - ${errorText}`);
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
  messages: AnthropicMessage[]
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
    const retryMessages: AnthropicMessage[] = [
      ...messages,
      {
        role: 'assistant',
        content: response
      },
      {
        role: 'user',
        content: 'The JSON you provided was malformed. Please provide ONLY valid JSON matching the schema, with no extra text.'
      }
    ];

    const retryResponse = await callAnthropicAPI(env, {
      model: env.LLM_BASE_MODEL,
      max_tokens: 2048,
      messages: retryMessages,
      system: systemPrompt,
      temperature: 0
    });

    const retryText = retryResponse.content[0].text;
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
  const messages: AnthropicMessage[] = [
    {
      role: 'user',
      content: contextMessage
    },
    {
      role: 'assistant',
      content: 'I understand the current context. I will now respond to the user\'s message with valid JSON following the schema.'
    },
    {
      role: 'user',
      content: `User's message: ${userMessage}\n\nRespond with ONLY valid JSON matching the schema defined in the system prompt.`
    }
  ];

  // Call the API
  const response = await callAnthropicAPI(env, {
    model: env.LLM_BASE_MODEL,
    max_tokens: 2048,
    messages,
    system: systemPrompt,
    temperature: 0.7
  });

  const responseText = response.content[0].text;

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

  const response = await callAnthropicAPI(env, {
    model: env.LLM_HEAVY_MODEL,
    max_tokens: 1024,
    messages: [
      {
        role: 'user',
        content: `Summarize this conversation in 2-3 paragraphs, focusing on what we learned about the user's needs:\n\n${conversationText}`
      }
    ],
    temperature: 0.3
  });

  return response.content[0].text;
}

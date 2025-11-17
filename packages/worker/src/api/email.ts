/**
 * POST /api/profile/email endpoint handler
 */

import type {
  EmailCaptureRequest,
  EmailCaptureResponse,
  WorkerEnv
} from '@landingchat/shared';
import { isValidEmail } from '@landingchat/shared';
import { createDynamoDBClient, getProfile, saveProfile } from '../services/dynamodb.js';
import { jsonResponse, errorResponse } from '../utils/cors.js';

/**
 * Handle POST /api/profile/email
 */
export async function handleEmailCaptureRequest(
  request: Request,
  env: WorkerEnv
): Promise<Response> {
  try {
    // Parse request
    const body = await request.json() as EmailCaptureRequest;

    if (!body.sessionId) {
      return errorResponse(request, env, 'Missing sessionId', 400);
    }

    if (!body.email || !isValidEmail(body.email)) {
      return errorResponse(request, env, 'Missing or invalid email', 400);
    }

    // Create DynamoDB client
    const dynamoClient = createDynamoDBClient(env);

    // Load profile
    const profile = await getProfile(dynamoClient, env, body.sessionId);

    if (!profile) {
      return errorResponse(request, env, 'Session not found', 404);
    }

    // Update profile with email
    profile.attributes.email = body.email;

    // Optionally update summary text
    if (!profile.conversation_summary.summary_text.includes('email')) {
      profile.conversation_summary.summary_text += `\n\nEmail: ${body.email}`;
    }

    // Save updated profile
    await saveProfile(dynamoClient, env, profile);

    // Build response
    const response: EmailCaptureResponse = {
      profile
    };

    return jsonResponse(request, env, response);
  } catch (error) {
    console.error('Error handling email capture request:', error);
    return errorResponse(
      request,
      env,
      error instanceof Error ? error.message : 'Internal server error',
      500
    );
  }
}

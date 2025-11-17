/**
 * Cloudflare Worker - Main Entry Point
 *
 * This worker handles the backend API for the LandingChat application:
 * - POST /api/chat - Main conversation endpoint
 * - POST /api/profile/email - Email capture endpoint
 */

import type { WorkerEnv } from '@landingchat/shared';
import { handleChatRequest } from './api/chat.js';
import { handleEmailCaptureRequest } from './api/email.js';
import { handleOptions, errorResponse } from './utils/cors.js';

/**
 * Main request handler
 */
export default {
  async fetch(request: Request, env: WorkerEnv): Promise<Response> {
    const url = new URL(request.url);
    const { pathname } = url;
    const method = request.method;

    // Handle CORS preflight
    if (method === 'OPTIONS') {
      return handleOptions(request, env);
    }

    // Route requests
    try {
      // POST /api/chat
      if (method === 'POST' && pathname === '/api/chat') {
        return await handleChatRequest(request, env);
      }

      // POST /api/profile/email
      if (method === 'POST' && pathname === '/api/profile/email') {
        return await handleEmailCaptureRequest(request, env);
      }

      // Health check
      if (method === 'GET' && pathname === '/health') {
        return new Response(
          JSON.stringify({
            status: 'ok',
            timestamp: new Date().toISOString()
          }),
          {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // 404 for unknown routes
      return errorResponse(request, env, 'Not found', 404);
    } catch (error) {
      console.error('Unhandled error:', error);
      return errorResponse(
        request,
        env,
        error instanceof Error ? error.message : 'Internal server error',
        500
      );
    }
  }
};

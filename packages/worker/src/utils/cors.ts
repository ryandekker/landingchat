/**
 * CORS utilities for Cloudflare Worker
 */

import type { WorkerEnv } from '@landingchat/shared';

/**
 * Get allowed origins from environment
 */
function getAllowedOrigins(env: WorkerEnv): string[] {
  if (!env.ALLOWED_ORIGINS) {
    return ['http://localhost:5173', 'http://localhost:3000'];
  }

  return env.ALLOWED_ORIGINS.split(',').map(origin => origin.trim());
}

/**
 * Check if origin is allowed
 */
function isOriginAllowed(origin: string | null, allowedOrigins: string[]): boolean {
  if (!origin) {
    return false;
  }

  return allowedOrigins.includes(origin);
}

/**
 * Get CORS headers for a request
 */
export function getCorsHeaders(request: Request, env: WorkerEnv): Record<string, string> {
  const origin = request.headers.get('Origin');
  const allowedOrigins = getAllowedOrigins(env);

  const headers: Record<string, string> = {
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400'
  };

  if (origin && isOriginAllowed(origin, allowedOrigins)) {
    headers['Access-Control-Allow-Origin'] = origin;
    headers['Access-Control-Allow-Credentials'] = 'true';
  }

  return headers;
}

/**
 * Handle OPTIONS request for CORS preflight
 */
export function handleOptions(request: Request, env: WorkerEnv): Response {
  return new Response(null, {
    status: 204,
    headers: getCorsHeaders(request, env)
  });
}

/**
 * Create JSON response with CORS headers
 */
export function jsonResponse(
  request: Request,
  env: WorkerEnv,
  data: any,
  status: number = 200
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...getCorsHeaders(request, env)
    }
  });
}

/**
 * Create error response with CORS headers
 */
export function errorResponse(
  request: Request,
  env: WorkerEnv,
  message: string,
  status: number = 500
): Response {
  return jsonResponse(
    request,
    env,
    {
      error: message,
      status
    },
    status
  );
}

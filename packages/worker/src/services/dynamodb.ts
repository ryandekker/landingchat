/**
 * DynamoDB service for storing user profiles and chat messages
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  QueryCommand
} from '@aws-sdk/lib-dynamodb';
import type {
  SessionId,
  UserProfile,
  ChatMessage,
  ConversationSummary,
  WorkerEnv
} from '@landingchat/shared';
import {
  generateSessionId,
  getCurrentTimestamp,
  createMessageSortKey
} from '@landingchat/shared';

/**
 * Create DynamoDB client from environment
 */
export function createDynamoDBClient(env: WorkerEnv): DynamoDBDocumentClient {
  const client = new DynamoDBClient({
    region: env.AWS_REGION,
    credentials: {
      accessKeyId: env.AWS_ACCESS_KEY_ID,
      secretAccessKey: env.AWS_SECRET_ACCESS_KEY
    }
  });

  return DynamoDBDocumentClient.from(client, {
    marshallOptions: {
      removeUndefinedValues: true,
      convertClassInstanceToMap: true
    }
  });
}

/**
 * Get user profile from sessions table
 */
export async function getProfile(
  client: DynamoDBDocumentClient,
  env: WorkerEnv,
  sessionId: SessionId
): Promise<UserProfile | null> {
  const result = await client.send(
    new GetCommand({
      TableName: env.DDB_TABLE_SESSIONS,
      Key: { sessionId }
    })
  );

  if (!result.Item) {
    return null;
  }

  return result.Item.profile as UserProfile;
}

/**
 * Save user profile to sessions table
 */
export async function saveProfile(
  client: DynamoDBDocumentClient,
  env: WorkerEnv,
  profile: UserProfile
): Promise<void> {
  const now = getCurrentTimestamp();

  await client.send(
    new PutCommand({
      TableName: env.DDB_TABLE_SESSIONS,
      Item: {
        sessionId: profile.sessionId,
        profile: profile,
        createdAt: profile.createdAt || now,
        lastUpdated: now
      }
    })
  );
}

/**
 * Create a new profile with initial state
 */
export function createNewProfile(
  sessionId: SessionId,
  checklist: string[]
): UserProfile {
  const now = getCurrentTimestamp();

  return {
    sessionId,
    radar: [],
    attributes: {},
    inferred_intent_tags: [],
    recommended_apps: [],
    conversation_summary: {
      answered_questions: [],
      remaining_questions: checklist,
      summary_text: ''
    },
    createdAt: now,
    lastUpdated: now
  };
}

/**
 * Append a chat message to the messages table
 */
export async function appendMessage(
  client: DynamoDBDocumentClient,
  env: WorkerEnv,
  message: ChatMessage
): Promise<void> {
  const sortKey = createMessageSortKey(message.timestamp, message.id);

  await client.send(
    new PutCommand({
      TableName: env.DDB_TABLE_MESSAGES,
      Item: {
        sessionId: message.sessionId,
        sortKey,
        id: message.id,
        role: message.role,
        content: message.content,
        timestamp: message.timestamp,
        channel: message.channel,
        metadata: message.metadata
      }
    })
  );
}

/**
 * Get recent messages for a session
 */
export async function getRecentMessages(
  client: DynamoDBDocumentClient,
  env: WorkerEnv,
  sessionId: SessionId,
  limit: number = 20
): Promise<ChatMessage[]> {
  const result = await client.send(
    new QueryCommand({
      TableName: env.DDB_TABLE_MESSAGES,
      KeyConditionExpression: 'sessionId = :sessionId',
      ExpressionAttributeValues: {
        ':sessionId': sessionId
      },
      ScanIndexForward: false, // Most recent first
      Limit: limit
    })
  );

  if (!result.Items || result.Items.length === 0) {
    return [];
  }

  // Reverse to get chronological order
  return result.Items.reverse().map(item => ({
    id: item.id,
    sessionId: item.sessionId,
    role: item.role,
    content: item.content,
    timestamp: item.timestamp,
    channel: item.channel,
    metadata: item.metadata
  }));
}

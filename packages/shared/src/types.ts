/**
 * Core data types for the Conversational Intake Landing Page
 * These types are shared across frontend, backend, and configuration packages.
 */

// ============================================================================
// Identifiers
// ============================================================================

export type SessionId = string;  // UUID v4 or ULID
export type MessageId = string;

// ============================================================================
// Radar Configuration
// ============================================================================

export interface RadarDimension {
  id: string;        // e.g. 'goal_clarity'
  label: string;     // e.g. 'Goal clarity'
  score: number;     // 0–100
  confidence: number; // 0–1
}

// ============================================================================
// Profile Attributes
// ============================================================================

export interface UserProfileAttributes {
  industry?: string;
  company_size?: string;
  role?: string;
  main_pain_point?: string;
  budget_band?: string; // e.g. 'low', 'medium', 'high'
  technical_sophistication?: 'low' | 'medium' | 'high';
  timeframe?: string;
  email?: string; // populated once user provides it
  [key: string]: any;
}

// ============================================================================
// Conversation Checklist & Summary
// ============================================================================

export interface ConversationSummary {
  answered_questions: string[];   // IDs from config checklist
  remaining_questions: string[];  // IDs from config checklist
  summary_text: string;           // natural language summary of what we know
}

// ============================================================================
// User Profile
// ============================================================================

export interface UserProfile {
  sessionId: SessionId;
  radar: RadarDimension[];
  attributes: UserProfileAttributes;
  inferred_intent_tags: string[];
  recommended_apps?: string[]; // OpenSearch document IDs
  conversation_summary: ConversationSummary;
  createdAt: string;   // ISO timestamp
  lastUpdated: string; // ISO timestamp
}

// ============================================================================
// Chat Messages
// ============================================================================

export type ChatRole = 'user' | 'assistant' | 'system';

export interface ChatMessage {
  id: MessageId;
  sessionId: SessionId;
  role: ChatRole;
  content: string;
  timestamp: string;           // ISO timestamp
  channel?: 'text';            // future: 'voice'
  metadata?: Record<string, any>;
}

// ============================================================================
// Search Results
// ============================================================================

export interface SearchResultSummary {
  id: string;
  title: string;
  snippet: string;
  score: number;
  url?: string;
  appType?: string;
}

// ============================================================================
// Session State (View Model)
// ============================================================================

export interface SessionState {
  sessionId: SessionId;
  profile: UserProfile;
  lastSearch?: {
    query: string;
    results: SearchResultSummary[];
  };
}

// ============================================================================
// LLM Orchestrator Output Schema
// ============================================================================

export interface LlmOrchestratorOutput {
  assistant_message: string;  // message to show user

  profile_delta: {
    radar?: RadarDimension[];
    attributes?: Partial<UserProfileAttributes>;
    inferred_intent_tags?: string[];
  };

  conversation_summary_delta?: {
    // LLM can adjust checklist progress and summary
    answered_questions?: string[];
    remaining_questions?: string[];
    summary_text?: string;
  };

  search_queries?: string[]; // e.g. ['invoice automation for small agency']

  ui_directives?: {
    show_recommendations?: boolean;
    highlight_dimensions?: string[];
    ask_for_email?: boolean;
    conversation_complete?: boolean; // true when remaining_questions is empty
  };
}

// ============================================================================
// API Request/Response Types
// ============================================================================

export interface ChatRequest {
  sessionId?: SessionId | null;
  channel: 'text';
  message: string;
  clientProfileSnapshot?: {
    radar: RadarDimension[];
    attributes: UserProfileAttributes;
    inferred_intent_tags: string[];
    conversation_summary: ConversationSummary;
  };
}

export interface ChatResponse {
  sessionId: SessionId;
  assistantMessage: string;
  profileDelta: {
    radar?: RadarDimension[];
    attributes?: Partial<UserProfileAttributes>;
    inferred_intent_tags?: string[];
  };
  fullProfile: UserProfile;
  searchRecommendations: SearchResultSummary[];
  uiDirectives: {
    show_recommendations: boolean;
    highlight_dimensions: string[];
    ask_for_email: boolean;
    conversation_complete: boolean;
  };
}

export interface EmailCaptureRequest {
  sessionId: SessionId;
  email: string;
}

export interface EmailCaptureResponse {
  profile: UserProfile;
}

// ============================================================================
// Configuration Types
// ============================================================================

export interface RadarDimensionConfig {
  id: string;        // matches RadarDimension.id
  label: string;
  description: string;
}

export interface ChecklistItem {
  id: string;        // e.g. 'goal'
  label: string;     // e.g. 'User's primary goal'
  description: string; // what we need to know to mark it answered
}

export interface InterviewerConfig {
  radarDimensions: RadarDimensionConfig[]; // <= 6
  checklist: ChecklistItem[];
  goalText: string;                         // high-level product goal
}

// ============================================================================
// OpenSearch App Catalog Types
// ============================================================================

export interface AppCatalogDocument {
  id: string;
  title: string;
  description: string;
  use_case_tags: string[];
  industry_tags: string[];
  persona_tags: string[];
  complexity: 'low' | 'medium' | 'high';
  time_to_value: string; // e.g. '30_min', '1_hour', '1_day'
  cta_url: string;
  metadata: {
    internal_priority: number;
    [key: string]: any;
  };
}

// ============================================================================
// Environment Configuration Types
// ============================================================================

export interface WorkerEnv {
  // LLM Configuration
  LLM_API_KEY: string;
  LLM_BASE_MODEL: string;
  LLM_HEAVY_MODEL: string;
  LLM_API_URL?: string; // e.g., 'https://api.anthropic.com/v1/messages'

  // OpenSearch Configuration
  OPENSEARCH_URL: string;
  OPENSEARCH_USERNAME: string;
  OPENSEARCH_PASSWORD: string;
  OPENSEARCH_APPS_INDEX: string;

  // DynamoDB Configuration
  AWS_REGION: string;
  AWS_ACCESS_KEY_ID: string;
  AWS_SECRET_ACCESS_KEY: string;
  DDB_TABLE_SESSIONS: string;
  DDB_TABLE_MESSAGES: string;

  // Prompt Configuration
  PROMPT_INTERVIEWER_ID?: string;

  // Optional Configuration
  CONFIG_RADAR_ID?: string;
  CONFIG_CHECKLIST_ID?: string;

  // CORS
  ALLOWED_ORIGINS?: string; // comma-separated list
}

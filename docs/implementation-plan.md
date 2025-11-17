# Conversational Intake Landing Page – Implementation Plan

This document is intended to sit in your repo as the canonical design for the chat-based intake landing page.

It assumes:

* Frontend: React SPA on Cloudflare Pages or served via Worker.
* Backend: Cloudflare Worker orchestrating LLM, OpenSearch, DynamoDB.
* Storage:

  * DynamoDB (on-demand) for profiles and chat transcripts.
  * OpenSearch for an “apps”/solutions catalog.
* No TTS/STT for v1 (voice is future work).
* All configuration (models, radar dimensions, question list, etc.) must be dynamic/config-driven, not hard-coded.

A key constraint: the conversation **must terminate** when the configured “question checklist” has been answered. The LLM maintains a **conversation summary** that tracks which questions are answered and which remain. The backend re-injects that summary on every turn, avoiding overbuilding and endless loops.

---

## 0. Core Principles & Configuration

### 0.1 Configuration principles (non-negotiable)

Agents must keep things configurable:

* **Model configuration** (env or config file):

  * `LLM_BASE_MODEL`, `LLM_HEAVY_MODEL`, `LLM_API_KEY`.
* **OpenSearch configuration**:

  * `OPENSEARCH_URL`, `OPENSEARCH_USERNAME`, `OPENSEARCH_PASSWORD`, `OPENSEARCH_APPS_INDEX`.
* **DynamoDB configuration**:

  * `AWS_REGION`, `DDB_TABLE_SESSIONS`, `DDB_TABLE_MESSAGES`, optional prefixes.
* **Prompt configuration**:

  * Base prompts stored centrally (KV or static JSON in `config/prompts/`), referenced by ID (e.g. `PROMPT_INTERVIEWER_ID`).
* **Radar dimensions configuration**:

  * Defined as config (max 5–6 dimensions), not hard-coded in code.
* **Question checklist configuration**:

  * Explicit list of questions / information slots required to consider the conversation “complete” (see section 6).

---

## 1. Data Model (Shared Across Components)

All components must share these core interfaces.

```ts
// Identifiers
export type SessionId = string;  // UUID v4 or ULID
export type MessageId = string;

// Radar configuration
export interface RadarDimension {
  id: string;        // e.g. 'goal_clarity'
  label: string;     // e.g. 'Goal clarity'
  score: number;     // 0–100
  confidence: number; // 0–1
}

// Profile attributes (extendable)
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

// Conversation checklist & summary
export interface ConversationSummary {
  answered_questions: string[];   // IDs from config checklist
  remaining_questions: string[];  // IDs from config checklist
  summary_text: string;           // natural language summary of what we know
}

// Profile
export interface UserProfile {
  sessionId: SessionId;
  radar: RadarDimension[];
  attributes: UserProfileAttributes;
  inferred_intent_tags: string[];
  recommended_apps?: string[]; // OpenSearch document IDs
  conversation_summary: ConversationSummary;
  createdAt: string;   // ISO
  lastUpdated: string; // ISO
}

// Messages
export type ChatRole = 'user' | 'assistant' | 'system';

export interface ChatMessage {
  id: MessageId;
  sessionId: SessionId;
  role: ChatRole;
  content: string;
  timestamp: string;           // ISO
  channel?: 'text';            // future: 'voice'
  metadata?: Record<string, any>;
}

// Search results
export interface SearchResultSummary {
  id: string;
  title: string;
  snippet: string;
  score: number;
  url?: string;
  appType?: string;
}

// Session state (view model)
export interface SessionState {
  sessionId: SessionId;
  profile: UserProfile;
  lastSearch?: {
    query: string;
    results: SearchResultSummary[];
  };
}
```

### 1.1 LLM Orchestrator Output Schema

The LLM must output structured JSON:

```ts
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
```

The **conversation termination condition** is:

* Either `conversation_complete === true`, or
* `remaining_questions.length === 0`.

In that state, the assistant should move to a “wrap-up” response and stop asking new intake questions.

---

## 2. Frontend: Minimal Sleek Chat UI (Component 1)

### 2.1 Responsibilities

* Render chat (text only v1).
* Right-hand side panel:

  * Static “What this tool does” description.
  * Radar chart showing current understanding.
  * Summary of captured profile attributes.
  * Email capture (“Don’t lose your progress”) that the user can fill whenever.
* Communicate with backend:

  * `POST /api/chat`
  * `POST /api/profile/email` (or equivalent).

### 2.2 Layout

* **Left (≈70%)**:

  * Header with concise headline.
  * Scrollable chat history.
  * Input row:

    * Text input.
    * Send button.
* **Right (≈30%)**:

  * Card: “What this tool does”

    * Brief bullets:

      * Interviews you about your use case.
      * Tracks understanding and progress.
      * Finds relevant tools/flows in our catalog.
  * Radar chart:

    * Driven from `profile.radar` (max 5–6 dimensions).
  * “What we’ve captured so far”:

    * Bulleted summary built from `profile.attributes` and `profile.conversation_summary.summary_text`.
  * Email capture:

    * Label: **“Don’t lose your progress.”**
    * Description: “Add your email and we’ll send your summary and recommendations here.”
    * Input + submit button.

### 2.3 `/api/chat` contract

**Request:**

```json
{
  "sessionId": "optional-session-id-or-null",
  "channel": "text",
  "message": "User typed message",
  "clientProfileSnapshot": {
    "radar": [],
    "attributes": {},
    "inferred_intent_tags": [],
    "conversation_summary": {
      "answered_questions": [],
      "remaining_questions": [],
      "summary_text": ""
    }
  }
}
```

**Response:**

```json
{
  "sessionId": "normalized-session-id",
  "assistantMessage": "Assistant reply",
  "profileDelta": {
    "radar": [],
    "attributes": {},
    "inferred_intent_tags": []
  },
  "fullProfile": {
    "sessionId": "…",
    "radar": [],
    "attributes": {},
    "inferred_intent_tags": [],
    "recommended_apps": [],
    "conversation_summary": {
      "answered_questions": [],
      "remaining_questions": [],
      "summary_text": ""
    },
    "createdAt": "…",
    "lastUpdated": "…"
  },
  "searchRecommendations": [
    {
      "id": "app_invoice_automation_01",
      "title": "Invoice Upload & Auto-Categorization",
      "snippet": "Upload invoices and extract line items…",
      "score": 0.93,
      "url": "https://example.com"
    }
  ],
  "uiDirectives": {
    "show_recommendations": true,
    "highlight_dimensions": ["goal_clarity"],
    "ask_for_email": true,
    "conversation_complete": false
  }
}
```

The frontend:

* Updates `sessionId`.
* Appends `assistantMessage` to chat.
* Updates radar, summary, and recommendations from `fullProfile` and `searchRecommendations`.
* If `uiDirectives.conversation_complete === true`, it can:

  * Visually indicate “We’re done. Here’s your summary & recommendations.”
  * Optionally hide the input or change placeholder (“You can ask follow-up questions, but we have enough to recommend.”).

### 2.4 Email capture endpoint

**Request** (e.g. `POST /api/profile/email`):

```json
{
  "sessionId": "session-id",
  "email": "user@example.com"
}
```

**Response:**

```json
{
  "profile": { /* updated UserProfile */ }
}
```

Backend updates `profile.attributes.email` and `conversation_summary.summary_text` if needed.

### 2.5 Implementation steps for frontend agents

1. Set up React+TS app and layout.
2. Implement `useSessionId` hook:

   * Generate UUID on first load.
   * Store in `localStorage`, reuse on reload.
3. Implement components:

   * `ChatMessageList`
   * `MessageInput`
   * `SidePanel`
   * `RadarChart` (configurable axes)
   * `ProfileSummary`
   * `EmailCapture`
4. Implement `useChat` hook using React Query:

   * `sendMessage(message)` → `POST /api/chat`.
   * Merge updates into local state.
5. Implement email submission:

   * `POST /api/profile/email`.
   * Update local `profile`.
6. Keep configuration dynamic:

   * API base URL (`VITE_API_URL`).
   * Radar axis labels derived from `profile.radar`.

---

## 3. Backend Router Worker (Component 2)

### 3.1 Responsibilities

* Orchestrate the entire flow.
* Endpoints:

  * `POST /api/chat`
  * `POST /api/profile/email`
* Manage session state in DynamoDB:

  * `UserProfile` in sessions table.
  * `ChatMessage` in messages table.
* Build and send prompts to LLM using base and heavy models.
* Trigger OpenSearch queries when requested by LLM.
* Maintain and re-inject **conversation summary** each turn so the model:

  * Knows which checklist items are done.
  * Knows when to terminate the interview.

### 3.2 Environment variables

At minimum:

* `LLM_API_KEY`
* `LLM_BASE_MODEL`
* `LLM_HEAVY_MODEL`
* `OPENSEARCH_URL`
* `OPENSEARCH_USERNAME`
* `OPENSEARCH_PASSWORD`
* `OPENSEARCH_APPS_INDEX`
* `AWS_REGION`
* `DDB_TABLE_SESSIONS`
* `DDB_TABLE_MESSAGES`
* `PROMPT_INTERVIEWER_ID` (base prompt ID)
* Optional: `CONFIG_RADAR_ID`, `CONFIG_CHECKLIST_ID` if you externalize radar and question list.

### 3.3 DynamoDB design

**Sessions table (`DDB_TABLE_SESSIONS`)**

* PK: `sessionId` (string)
* Attributes:

  * `sessionId`
  * `profile` (map) – serialized `UserProfile`
  * `createdAt`
  * `lastUpdated`

**Messages table (`DDB_TABLE_MESSAGES`)**

* PK: `sessionId` (string)
* SK: `timestamp#messageId` (string)
* Attributes:

  * `role`
  * `content`
  * `channel`
  * `metadata`

Profiles and chats stored indefinitely for now; TTL can be added later.

### 3.4 `/api/chat` flow

1. Parse request (`sessionId`, `message`, `channel`).
2. Normalize `sessionId` (generate UUID if missing).
3. Load `UserProfile` from sessions table:

   * If none, create:

     * `sessionId`
     * `radar`: empty array
     * `attributes`: empty object
     * `inferred_intent_tags`: []
     * `conversation_summary`:

       * `answered_questions`: []
       * `remaining_questions`: initial full checklist from config.
       * `summary_text`: empty string
     * `createdAt` / `lastUpdated`.
4. Append user message to messages table.
5. Fetch recent messages:

   * e.g. last 12–20 messages.
   * If more exist, produce an internal summary (heavy model or cheaper summarization) and inject that instead of full history.
6. Fetch base prompt + configuration (radar + checklist) from prompt/config storage (see section 6).
7. Build prompt:

   * System: base interviewer prompt, including:

     * Radar dimensions and semantics.
     * Checklist of questions (IDs and descriptions).
     * JSON schema for `LlmOrchestratorOutput`.
   * Developer/context: includes:

     * Model/behavior constraints (short messages, one question at a time).
     * Current `profile` and `conversation_summary`.
     * Last search summary (if exists).
     * Recent chat messages / summary.
   * User: the new user message text.
8. Call LLM (base model):

   * Ask strictly for valid JSON.
9. Parse JSON as `LlmOrchestratorOutput`:

   * If invalid, one retry with “fix formatting only” instruction.
10. If `search_queries` present:

    * Call OpenSearch (see section 4).
    * Build `SearchResultSummary[]`.
    * Optional: call heavy model to compress results into 1–2 natural language bullets.
11. Merge `profile_delta` into profile:

    * Radar:

      * Merge by `id`.
    * Attributes:

      * Shallow merge.
    * Inferred tags:

      * Union with existing.
12. Merge `conversation_summary_delta`:

    * Overwrite `answered_questions`/`remaining_questions` if provided.
    * Update `summary_text` (append or overwrite).
    * If `conversation_summary_delta` is absent, optionally re-derive from existing summary.
13. Determine `conversation_complete`:

    * True if:

      * `ui_directives.conversation_complete === true`, OR
      * `conversation_summary.remaining_questions.length === 0`.
14. Generate/normalize `uiDirectives`:

    * Ensure `conversation_complete` is correctly set.
15. Persist:

    * Updated profile in sessions table.
    * Assistant message in messages table.
16. Return response to frontend with:

    * `assistantMessage`
    * `profileDelta`
    * `fullProfile`
    * `searchRecommendations`
    * `uiDirectives`.

### 3.5 `/api/profile/email` flow

1. Parse `{sessionId, email}`.
2. Load profile.
3. Set `profile.attributes.email = email`.
4. Optionally update `conversation_summary.summary_text` to mention report delivery.
5. Save profile.
6. Return updated `profile`.

---

## 4. OpenSearch Apps Catalog (Component 3)

### 4.1 Responsibilities

* Store and search “apps” that may help the user.
* Support text/keyword search only (no vector search required for v1).
* LLM builds the queries; backend executes them.

### 4.2 Index schema

Index name: configured by `OPENSEARCH_APPS_INDEX` (e.g. `apps_catalog`).

Example document:

```json
{
  "id": "app_invoice_automation_01",
  "title": "Invoice Upload & Auto-Categorization",
  "description": "Upload invoices, extract line items, and automatically sync to your accounting software.",
  "use_case_tags": ["invoice_automation", "bookkeeping", "smb"],
  "industry_tags": ["agency", "professional_services"],
  "persona_tags": ["owner", "ops_manager"],
  "complexity": "low",
  "time_to_value": "30_min",
  "cta_url": "https://example.com/app/invoice-automation",
  "metadata": {
    "internal_priority": 0.9
  }
}
```

Basic mapping:

* `title`, `description`: `text`.
* `use_case_tags`, `industry_tags`, `persona_tags`, `complexity`, `time_to_value`: `keyword`.
* `metadata.internal_priority`: `float`.

### 4.3 Search strategy

1. LLM returns `search_queries` array.
2. Backend constructs OpenSearch boolean queries:

   * `must`: text query on `title` + `description`.
   * `should`: boost matches where tags overlap:

     * `use_case_tags` in `profile.inferred_intent_tags`.
     * `industry_tags` in `profile.attributes.industry`.
     * etc.
3. Limit to top 3–5 results.
4. Normalize to `SearchResultSummary[]`.

### 4.4 Implementation tasks

* Define mapping and create index.
* Seed with initial set of apps.
* Implement Worker helper `searchApps({ profile, queries }): Promise<SearchResultSummary[]>`.
* Expose configuration (index name, URL, credentials) through environment variables.

---

## 5. DynamoDB Storage for Profiles & Chats (Component 4)

### 5.1 Responsibilities

* Persist `UserProfile` and all `ChatMessage` records.
* Use On-Demand capacity for flexibility.
* Store indefinitely for now (no TTL), but design to allow TTL later.

### 5.2 Tables

**Sessions table**

* Name from `DDB_TABLE_SESSIONS`.
* Key schema:

  * PK: `sessionId` (string).
* Attributes:

  * `sessionId`
  * `profile` (map) – serialized `UserProfile`
  * `createdAt`
  * `lastUpdated`

**Messages table**

* Name from `DDB_TABLE_MESSAGES`.
* Key schema:

  * PK: `sessionId` (string)
  * SK: `timestamp#messageId` (string)
* Attributes:

  * `role`
  * `content`
  * `channel`
  * `metadata`

### 5.3 Implementation tasks

* Create tables using IaC or AWS Console.

* Implement utility module for Worker:

  ```ts
  async function getProfile(sessionId: SessionId): Promise<UserProfile | null> { ... }
  async function saveProfile(profile: UserProfile): Promise<void> { ... }

  async function appendMessage(message: ChatMessage): Promise<void> { ... }
  async function getRecentMessages(sessionId: SessionId, limit: number): Promise<ChatMessage[]> { ... }
  ```

* Handle serialization/deserialization consistently.

* Keep table names and region dynamic via env.

---

## 6. Prompt Storage & Conversation Orchestration (Components 5 & 6)

This is where the overbuilding/endless-loop problem is solved: by defining a clear **question checklist** and a shared **conversation summary** that is always present in the prompt.

### 6.1 Configuration: Radar & Checklist

Define a config structure, either as JSON in `config/` or in KV.

```ts
export interface RadarDimensionConfig {
  id: string;        // matches RadarDimension.id
  label: string;
  description: string;
}

export interface ChecklistItem {
  id: string;        // e.g. 'goal'
  label: string;     // e.g. 'User’s primary goal'
  description: string; // what we need to know to mark it answered
}

export interface InterviewerConfig {
  radarDimensions: RadarDimensionConfig[]; // <= 6
  checklist: ChecklistItem[];
  goalText: string;                         // high-level product goal
}
```

The **checklist** defines the end of the intake: when all items’ IDs are present in `conversation_summary.answered_questions`, the interview is complete.

### 6.2 Prompt storage

* Store base interviewer prompt as a single object, referenced by `PROMPT_INTERVIEWER_ID`.
* Prompt must:

  * Explain:

    * The goal of the interview.
    * The radar dimensions.
    * The checklist items.
  * Instruct the model to:

    * Always try to progress the checklist (answer missing items).
    * Mark `answered_questions` and `remaining_questions` accordingly.
    * Avoid re-asking already answered questions.
    * When `remaining_questions` is empty:

      * Set `ui_directives.conversation_complete: true`.
      * Move to wrap-up summary and recommendations.
  * Specify JSON schema (`LlmOrchestratorOutput`) explicitly.

### 6.3 Orchestrator functions

Implement:

```ts
async function buildInterviewerPrompt(ctx: {
  config: InterviewerConfig;
  profile: UserProfile;
  messages: ChatMessage[];
  lastSearch?: SessionState['lastSearch'];
  userMessage: string;
}): Promise<{ system: string; messages: any[] }> {
  // system: base prompt text with radar & checklist descriptions and JSON schema
  // messages: developer/context + user messages
}
```

And:

```ts
async function generateNextTurn(ctx: {
  config: InterviewerConfig;
  profile: UserProfile;
  messages: ChatMessage[];
  lastSearch?: SessionState['lastSearch'];
  userMessage: string;
}): Promise<LlmOrchestratorOutput> {
  // 1. Build prompt
  // 2. Call base model
  // 3. Validate JSON, retry once if malformed
}
```

### 6.4 Checklist-enforced termination

The prompt should include instructions like:

* Given:

  * `conversation_summary.answered_questions` and `remaining_questions`.
  * The configured `checklist` items.
* The model must:

  * On each turn, update which items are answered.
  * Never ask questions targeting items whose IDs are already in `answered_questions`.
  * When `remaining_questions` is empty:

    * Set `ui_directives.conversation_complete` to `true`.
    * Focus response on:

      * Summarizing what was learned.
      * Presenting recommendations.
      * Optional closing question like “Any adjustments before we send your summary?” but no new intake questions.

This ensures there is **no chance for endless loops**, as long as the checklist is finite and the summary is always injected.

---

## 7. Voice (Component 7 – Future Work)

For v1:

* **No STT** (speech-to-text).
* **No TTS** (text-to-speech).
* **No streaming**.

The chat is text-only.

If voice is added later:

* Treat voice utterances as text messages in the same schema (`ChatMessage`).
* Use the same `generateNextTurn` orchestration and checklist logic.
* Inject transcripts and conversation summary as usual.

---

## 8. Implementation Order

1. **Define config**:

   * Radar dimensions.
   * Checklist items (what exactly you want the bot to know before it stops).
   * Goal text.
2. **Implement data model & DynamoDB tables**.
3. **Implement backend router Worker**:

   * `/api/chat` and `/api/profile/email`.
   * Stub LLM responses initially.
4. **Implement frontend**:

   * Chat UI, side panel, radar (with dummy data).
5. **Implement prompt storage & orchestrator**:

   * Base interviewer prompt with checklist and JSON schema.
   * `generateNextTurn`.
6. **Integrate real LLM**:

   * Wire base model and handle JSON outputs.
7. **Integrate OpenSearch**:

   * Hook up `search_queries` -> search -> recommendations.
8. **Refinement**:

   * Ensure that when `remaining_questions` is empty, the assistant cleanly transitions to wrap-up and stops asking intake questions.

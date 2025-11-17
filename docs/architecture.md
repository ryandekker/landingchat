# LandingChat Architecture

This document provides a comprehensive overview of the LandingChat system architecture, design decisions, and data flow.

## System Overview

LandingChat is a conversational intake system that uses an LLM to interview users about their needs and recommend relevant solutions from an app catalog.

### Key Components

1. **React Frontend** (Cloudflare Pages) - User interface
2. **Cloudflare Worker** - Backend API and orchestration
3. **DynamoDB** - Session and message storage
4. **OpenSearch** - App catalog search
5. **Anthropic Claude** - LLM for conversation

### Design Principles

1. **Configuration-Driven:** All behavior (prompts, radar dimensions, checklists) is configurable, not hard-coded
2. **Conversation Termination:** Explicit checklist ensures conversations complete when enough information is gathered
3. **Serverless:** Fully serverless architecture for automatic scaling and low operational overhead
4. **Type Safety:** TypeScript throughout with shared types across frontend and backend

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Browser                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              React Frontend (Cloudflare Pages)            │  │
│  │  • Chat UI                                                 │  │
│  │  • Radar Chart                                             │  │
│  │  • Profile Summary                                         │  │
│  │  • Email Capture                                           │  │
│  └────────────────┬──────────────────────────────────────────┘  │
└────────────────────┼──────────────────────────────────────────────┘
                     │
                     │ HTTPS/JSON
                     │
┌────────────────────▼──────────────────────────────────────────────┐
│              Cloudflare Worker (Backend API)                      │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  Router & Request Handlers                                   │ │
│  │  • POST /api/chat                                            │ │
│  │  • POST /api/profile/email                                   │ │
│  │  • GET /health                                               │ │
│  └───────┬──────────────────┬──────────────────┬───────────────┘ │
│          │                  │                  │                  │
│  ┌───────▼───────┐  ┌──────▼───────┐  ┌──────▼────────┐        │
│  │   DynamoDB    │  │  OpenSearch  │  │  Anthropic    │        │
│  │   Service     │  │   Service    │  │  LLM Service  │        │
│  └───────┬───────┘  └──────┬───────┘  └──────┬────────┘        │
└──────────┼──────────────────┼──────────────────┼─────────────────┘
           │                  │                  │
┌──────────▼────────┐  ┌──────▼───────┐  ┌──────▼────────┐
│    DynamoDB       │  │  OpenSearch  │  │  Anthropic    │
│   • Sessions      │  │   • Apps     │  │     API       │
│   • Messages      │  │   Catalog    │  │               │
└───────────────────┘  └──────────────┘  └───────────────┘
```

---

## Data Flow

### Chat Message Flow

```
1. User sends message
   ↓
2. Frontend appends to local state
   ↓
3. POST /api/chat → Worker
   ↓
4. Worker loads/creates session from DynamoDB
   ↓
5. Worker fetches recent messages from DynamoDB
   ↓
6. Worker builds prompt with:
   - System prompt (from config)
   - Context (current profile + conversation summary)
   - Recent messages
   - User's new message
   ↓
7. Worker calls Anthropic API
   ↓
8. LLM returns structured JSON:
   - assistant_message
   - profile_delta (radar, attributes, tags)
   - conversation_summary_delta
   - search_queries
   - ui_directives
   ↓
9. If search_queries present:
   Worker queries OpenSearch → gets recommendations
   ↓
10. Worker merges profile_delta into profile
    ↓
11. Worker saves updated profile to DynamoDB
    ↓
12. Worker saves user + assistant messages to DynamoDB
    ↓
13. Worker returns response to frontend
    ↓
14. Frontend updates UI:
    - Displays assistant message
    - Updates radar chart
    - Updates profile summary
    - Shows recommendations
    - Checks if conversation complete
```

---

## Data Models

### UserProfile

```typescript
interface UserProfile {
  sessionId: string;
  radar: RadarDimension[];
  attributes: UserProfileAttributes;
  inferred_intent_tags: string[];
  recommended_apps?: string[];
  conversation_summary: ConversationSummary;
  createdAt: string;
  lastUpdated: string;
}
```

**Storage:** DynamoDB Sessions table
**Key:** `sessionId`

### ChatMessage

```typescript
interface ChatMessage {
  id: string;
  sessionId: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: string;
  channel?: 'text';
  metadata?: Record<string, any>;
}
```

**Storage:** DynamoDB Messages table
**Key:** `sessionId` (PK), `timestamp#messageId` (SK)

### ConversationSummary

```typescript
interface ConversationSummary {
  answered_questions: string[];   // Checklist IDs answered
  remaining_questions: string[];  // Checklist IDs not yet answered
  summary_text: string;           // Natural language summary
}
```

**Purpose:** Tracks conversation progress against checklist. When `remaining_questions` is empty, conversation is complete.

---

## LLM Orchestration

### Prompt Structure

The LLM receives a carefully structured prompt:

**System Message:**
- Mission and goal
- Radar dimension definitions
- Checklist items and descriptions
- JSON output schema
- Behavioral guidelines

**Context Message:**
- Current profile state
- Conversation summary (answered/remaining questions)
- Recent message history
- Last search results (if any)

**User Message:**
- The user's latest input

### Output Schema

The LLM must return valid JSON:

```typescript
{
  "assistant_message": "Response to show user",
  "profile_delta": {
    "radar": [/* updated dimensions */],
    "attributes": {/* new/updated attributes */},
    "inferred_intent_tags": [/* tags */]
  },
  "conversation_summary_delta": {
    "answered_questions": [/* checklist IDs */],
    "remaining_questions": [/* checklist IDs */],
    "summary_text": "Updated summary"
  },
  "search_queries": [/* optional search strings */],
  "ui_directives": {
    "show_recommendations": false,
    "highlight_dimensions": [],
    "ask_for_email": false,
    "conversation_complete": false
  }
}
```

### Conversation Termination

The conversation terminates when:
1. `conversation_summary.remaining_questions.length === 0`, OR
2. `ui_directives.conversation_complete === true`

The prompt explicitly instructs the LLM to:
- Track which checklist items are answered
- Never re-ask answered questions
- Transition to wrap-up when all questions answered
- Set `conversation_complete: true` at end

This prevents endless loops and ensures efficient conversations.

---

## Search and Recommendations

### OpenSearch Integration

**Index:** `apps_catalog`

**Document Schema:**
```json
{
  "id": "app_id",
  "title": "App Title",
  "description": "Detailed description",
  "use_case_tags": ["tag1", "tag2"],
  "industry_tags": ["industry1"],
  "persona_tags": ["role1"],
  "complexity": "low|medium|high",
  "time_to_value": "30_min",
  "cta_url": "https://...",
  "metadata": {
    "internal_priority": 0.9
  }
}
```

### Search Strategy

When LLM provides `search_queries`:

1. Build boolean query combining:
   - Text match on title + description
   - Boosted match on use_case_tags
   - Boosted match on industry_tags
   - Boosted match on complexity (if technical sophistication known)

2. Sort by:
   - Relevance score
   - Internal priority

3. Return top 3-5 results

---

## State Management

### Frontend State

**Session ID:**
- Stored in localStorage
- Generated on first visit
- Persists across page refreshes
- Can be reset by clearing localStorage

**Chat Messages:**
- Stored in component state
- Not persisted (intentional - server is source of truth)
- Rebuilt from API responses

**Profile:**
- Received from API after each turn
- Displayed in UI
- Not modified client-side

### Backend State

**DynamoDB Sessions Table:**
- One record per session
- Contains full `UserProfile`
- Updated after each conversation turn

**DynamoDB Messages Table:**
- One record per message
- Chronologically ordered via sort key
- Queryable by session

**Stateless Worker:**
- No in-memory state
- Each request is independent
- Loads session from DynamoDB

---

## Security Considerations

### Authentication

Current implementation:
- No authentication (demo/prototype)
- Sessions identified by client-provided UUID

For production:
- Add authentication (Cloudflare Access, Auth0, etc.)
- Validate session ownership
- Implement rate limiting

### Secrets Management

**Development:**
- `.dev.vars` for local development (gitignored)

**Production:**
- Wrangler secrets for sensitive values
- Cloudflare Pages environment variables for frontend config

### CORS

Worker implements CORS:
- Checks `Origin` header
- Compares against `ALLOWED_ORIGINS`
- Returns appropriate headers
- Handles OPTIONS preflight

### Data Privacy

Considerations:
- User data stored in DynamoDB
- No encryption at rest by default (enable if needed)
- Messages contain PII (email, business details)
- Implement data retention policy for production

---

## Scalability

### Cloudflare Worker

- Automatically scales to handle load
- No cold starts
- Global edge deployment
- CPU time limits: 50ms (free), 50s (paid)

### DynamoDB

**On-Demand Billing:**
- Automatically scales
- Pay per request
- No capacity planning needed

**For high volume:**
- Switch to provisioned capacity
- Enable auto-scaling
- Add GSI for additional query patterns

### OpenSearch

**Single-Node Development:**
- t3.small sufficient for testing

**Production Scaling:**
- t3.medium or larger
- Multi-AZ deployment
- Add replica nodes
- Monitor cluster health

### LLM API

**Rate Limits:**
- Anthropic has tier-based limits
- Implement queueing if needed
- Cache common responses

**Cost Optimization:**
- Use Haiku (fast model) for primary responses
- Use Sonnet (heavy model) only for summarization
- Monitor token usage

---

## Error Handling

### Frontend

**Network Errors:**
- Display error message in UI
- Allow retry
- Don't lose user's message

**Invalid Responses:**
- Handle gracefully
- Log to console
- Show user-friendly error

### Backend

**LLM Errors:**
- Retry once on malformed JSON
- Log errors
- Return generic error to user

**Database Errors:**
- Retry transient failures
- Log persistent errors
- Return 500 with generic message

**OpenSearch Errors:**
- Continue without recommendations
- Log error
- Don't block conversation

---

## Monitoring and Observability

### Metrics to Track

**Frontend:**
- Page load time
- API response time
- Error rates
- Conversation completion rate

**Worker:**
- Request count
- Error rate
- CPU time
- Duration
- DynamoDB query latency
- OpenSearch query latency
- LLM API latency

**Business Metrics:**
- Sessions created
- Messages per session
- Conversations completed
- Emails captured
- Recommendations shown
- Recommendation click-through rate

### Logging

**Worker Logs:**
```typescript
console.log('Chat request', { sessionId, messageLength });
console.error('LLM error', { error, sessionId });
```

Access via:
```bash
wrangler tail
```

**DynamoDB Metrics:**
- Monitor via CloudWatch
- Set alarms for throttling

**OpenSearch Metrics:**
- Cluster health
- Query performance
- Index size

---

## Configuration Management

### Radar Dimensions

Defined in `packages/config/src/defaults/radar.ts`:
- Maximum 6 dimensions recommended
- Each has id, label, description
- Rendered as radar chart in UI

### Checklist

Defined in `packages/config/src/defaults/checklist.ts`:
- List of required information
- Each has id, label, description
- Conversation completes when all answered

### Prompts

Defined in `packages/config/src/prompts/interviewer.ts`:
- System prompt builder
- Includes radar, checklist, schema
- Customizable tone and behavior

### Environment Variables

**Worker:**
- `LLM_API_KEY` - Anthropic API key
- `LLM_BASE_MODEL` - Fast model for responses
- `LLM_HEAVY_MODEL` - Heavy model for summarization
- `OPENSEARCH_URL` - OpenSearch endpoint
- `OPENSEARCH_USERNAME` - Username
- `OPENSEARCH_PASSWORD` - Password
- `AWS_ACCESS_KEY_ID` - AWS credentials
- `AWS_SECRET_ACCESS_KEY` - AWS credentials
- `DDB_TABLE_SESSIONS` - Sessions table name
- `DDB_TABLE_MESSAGES` - Messages table name
- `ALLOWED_ORIGINS` - CORS allowed origins

**Frontend:**
- `VITE_API_URL` - Worker API endpoint

---

## Future Enhancements

### Voice Support

From implementation plan:
- Add STT (speech-to-text) for voice input
- Add TTS (text-to-speech) for voice output
- Streaming responses
- Same data model and checklist logic

### Advanced Features

- **Multi-language support:** Detect and respond in user's language
- **Sentiment analysis:** Track user sentiment
- **A/B testing:** Test different prompts/flows
- **Analytics dashboard:** Track conversation metrics
- **Admin panel:** Manage apps catalog
- **Email notifications:** Send summary and recommendations
- **CRM integration:** Sync captured leads
- **Webhook support:** Trigger actions on events

### Technical Improvements

- **Caching:** Cache LLM responses for common queries
- **Streaming:** Stream LLM responses for better UX
- **Offline support:** PWA with offline capabilities
- **Mobile apps:** Native mobile clients
- **WebSocket:** Real-time updates
- **GraphQL:** More flexible API

---

## Design Decisions

### Why Cloudflare Workers?

- **Global edge deployment:** Low latency worldwide
- **Serverless:** No infrastructure management
- **Automatic scaling:** Handle traffic spikes
- **Integrated with Pages:** Easy full-stack deployment
- **Cost-effective:** Free tier generous, paid tier cheap

### Why DynamoDB?

- **Serverless:** No provisioning
- **On-demand billing:** Pay for what you use
- **Fast:** Single-digit millisecond latency
- **Flexible schema:** Easy to extend profile attributes
- **Well-supported:** AWS SDK works in Workers

### Why OpenSearch?

- **Full-text search:** Better than DynamoDB for search
- **Relevance scoring:** Boost by tags and priority
- **Flexible queries:** Boolean, fuzzy, filters
- **Open source:** No vendor lock-in
- **AWS managed:** Easy to deploy and scale

### Why Anthropic Claude?

- **Instruction following:** Excellent at following structured prompts
- **JSON mode:** Can reliably output structured data
- **Context window:** Large enough for conversation history
- **Quality:** High-quality, helpful responses
- **Pricing:** Haiku is cost-effective for high volume

### Why React + Vite?

- **Fast development:** HMR, instant feedback
- **Modern:** Latest React features
- **TypeScript:** Type safety
- **Cloudflare Pages compatible:** Easy deployment
- **Ecosystem:** Rich library ecosystem

---

## Constraints and Limitations

### Current Limitations

1. **No authentication:** Anyone with session ID can access
2. **No rate limiting:** Could be abused
3. **Single language:** English only
4. **Text only:** No voice in v1
5. **No streaming:** Responses arrive all at once
6. **No conversation export:** Can't download transcript

### Operational Constraints

1. **Worker CPU time:** 50ms free tier, 50s paid
2. **DynamoDB item size:** 400KB max
3. **OpenSearch query size:** Usually not an issue
4. **LLM context window:** Limited to model's window
5. **Cold start:** Minimal but exists

### Cost Constraints

Monitor and set budgets for:
- OpenSearch instance (largest cost)
- LLM API calls (variable based on usage)
- DynamoDB (usually minimal)
- Cloudflare (usually free tier sufficient)

---

## Deployment Architecture

### Development

```
Developer Machine
├── packages/worker → Wrangler Dev Server (localhost:8787)
└── packages/frontend → Vite Dev Server (localhost:5173)
     ↓
AWS Services (shared dev environment)
├── DynamoDB Tables (dev-)
└── OpenSearch Domain (dev-)
```

### Production

```
User → Cloudflare CDN
         ↓
    Cloudflare Pages (Frontend)
         ↓
    Cloudflare Worker (API)
         ↓
    ├── DynamoDB (prod-)
    ├── OpenSearch (prod-)
    └── Anthropic API
```

---

## Summary

LandingChat is a serverless, configuration-driven conversational intake system that:

1. Uses LLM to interview users naturally
2. Tracks understanding via radar chart
3. Completes when checklist is answered
4. Searches catalog for recommendations
5. Captures email for follow-up

The architecture is designed to be:
- **Scalable:** Serverless components auto-scale
- **Maintainable:** TypeScript, shared types, modular
- **Configurable:** No hard-coded behavior
- **Cost-effective:** Pay only for what you use
- **Deployable:** Cloudflare makes deployment easy

For detailed setup and deployment, see the [Setup Guides](./setup/).

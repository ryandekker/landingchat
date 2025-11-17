# Getting Started Guide

This guide will get you up and running with LandingChat in development mode.

## Quick Start

Follow these steps to run LandingChat locally.

### Prerequisites

- Node.js 18+ installed
- pnpm installed (`npm install -g pnpm`)
- AWS account with DynamoDB tables set up
- OpenSearch instance running
- Anthropic API key

---

## Step-by-Step Setup

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd landingchat
```

### 2. Install Dependencies

```bash
pnpm install
```

This installs all dependencies for all packages in the monorepo.

### 3. Set Up Infrastructure

If you haven't already, follow the [Infrastructure Setup Guide](./01-infrastructure.md) to create:
- DynamoDB tables
- OpenSearch domain
- Seed sample apps

### 4. Configure Environment Variables

#### Backend (Worker)

```bash
cd packages/worker
cp .dev.vars.example .dev.vars
```

Edit `.dev.vars` with your credentials:
```bash
LLM_API_KEY=your-anthropic-api-key
LLM_BASE_MODEL=claude-3-haiku-20240307
LLM_HEAVY_MODEL=claude-3-sonnet-20240229
LLM_API_URL=https://api.anthropic.com/v1/messages

OPENSEARCH_URL=your-opensearch-endpoint
OPENSEARCH_USERNAME=admin
OPENSEARCH_PASSWORD=your-password
OPENSEARCH_APPS_INDEX=apps_catalog

AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
DDB_TABLE_SESSIONS=landingchat-sessions
DDB_TABLE_MESSAGES=landingchat-messages

ALLOWED_ORIGINS=http://localhost:5173
```

#### Frontend

```bash
cd packages/frontend
cp .env.example .env
```

Edit `.env`:
```bash
VITE_API_URL=http://localhost:8787
```

### 5. Start Development Servers

Open two terminal windows:

**Terminal 1 - Backend:**
```bash
cd packages/worker
pnpm dev
```

The worker will start on `http://localhost:8787`.

**Terminal 2 - Frontend:**
```bash
cd packages/frontend
pnpm dev
```

The frontend will start on `http://localhost:5173`.

### 6. Test the Application

1. Open browser to `http://localhost:5173`
2. You should see the chat interface
3. Type "Hello" and press Send
4. The assistant should respond

Congratulations! LandingChat is now running locally.

---

## Understanding the Project Structure

```
landingchat/
├── packages/
│   ├── shared/          # Shared TypeScript types
│   │   └── src/
│   │       ├── types.ts     # All shared interfaces
│   │       └── utils.ts     # Shared utilities
│   │
│   ├── config/          # Configuration (prompts, radar, checklist)
│   │   └── src/
│   │       ├── defaults/
│   │       │   ├── radar.ts      # Radar dimensions config
│   │       │   └── checklist.ts  # Question checklist config
│   │       └── prompts/
│   │           └── interviewer.ts # LLM prompt template
│   │
│   ├── worker/          # Cloudflare Worker backend
│   │   └── src/
│   │       ├── api/
│   │       │   ├── chat.ts       # POST /api/chat handler
│   │       │   └── email.ts      # POST /api/profile/email handler
│   │       ├── services/
│   │       │   ├── dynamodb.ts   # DynamoDB operations
│   │       │   ├── opensearch.ts # OpenSearch operations
│   │       │   └── llm.ts        # LLM API calls
│   │       ├── utils/
│   │       │   ├── cors.ts       # CORS utilities
│   │       │   └── profile.ts    # Profile merge utilities
│   │       └── index.ts          # Worker entry point
│   │
│   └── frontend/        # React frontend
│       └── src/
│           ├── components/
│           │   ├── ChatMessage.tsx
│           │   ├── MessageInput.tsx
│           │   ├── RadarChart.tsx
│           │   ├── ProfileSummary.tsx
│           │   ├── EmailCapture.tsx
│           │   └── Recommendations.tsx
│           ├── hooks/
│           │   ├── useSession.ts  # Session ID management
│           │   └── useChat.ts     # Chat state & API calls
│           ├── lib/
│           │   └── api.ts         # API client
│           ├── App.tsx            # Main component
│           └── main.tsx           # Entry point
│
├── docs/
│   ├── setup/
│   │   ├── 01-infrastructure.md
│   │   ├── 02-backend-deployment.md
│   │   ├── 03-frontend-deployment.md
│   │   └── 04-getting-started.md
│   ├── architecture.md
│   └── implementation-plan.md
│
├── package.json         # Root package.json
├── pnpm-workspace.yaml  # Workspace configuration
└── tsconfig.json        # Base TypeScript config
```

---

## Development Workflow

### Making Changes

1. **Shared Types:**
   - Edit `packages/shared/src/types.ts`
   - Rebuild: `cd packages/shared && pnpm build`
   - Changes automatically picked up by worker and frontend

2. **Configuration:**
   - Edit radar dimensions: `packages/config/src/defaults/radar.ts`
   - Edit checklist: `packages/config/src/defaults/checklist.ts`
   - Edit prompt: `packages/config/src/prompts/interviewer.ts`
   - Rebuild: `cd packages/config && pnpm build`
   - Restart worker to pick up changes

3. **Backend:**
   - Edit files in `packages/worker/src/`
   - Changes hot-reload automatically
   - For service changes, restart with `pnpm dev`

4. **Frontend:**
   - Edit files in `packages/frontend/src/`
   - Changes hot-reload automatically via Vite

### Building All Packages

From repository root:
```bash
pnpm build
```

This builds all packages in dependency order.

### Type Checking

```bash
# Check all packages
pnpm typecheck

# Check specific package
pnpm --filter @landingchat/worker typecheck
pnpm --filter @landingchat/frontend typecheck
```

### Cleaning

```bash
# Clean all packages
pnpm clean

# Clean specific package
pnpm --filter @landingchat/worker clean
```

---

## Customizing the Configuration

### Changing Radar Dimensions

Edit `packages/config/src/defaults/radar.ts`:

```typescript
export const defaultRadarDimensions: RadarDimensionConfig[] = [
  {
    id: 'your_dimension',
    label: 'Your Dimension',
    description: 'What this dimension measures'
  },
  // Add more (max 6 recommended)
];
```

### Changing the Question Checklist

Edit `packages/config/src/defaults/checklist.ts`:

```typescript
export const defaultChecklist: ChecklistItem[] = [
  {
    id: 'your_question',
    label: 'Your Question',
    description: 'What information you need to collect'
  },
  // Add more items
];
```

The conversation completes when all checklist items are answered.

### Customizing the Prompt

Edit `packages/config/src/prompts/interviewer.ts`:

- Modify `buildInterviewerPrompt()` to change LLM behavior
- Update `defaultGoalText` to change the mission
- Adjust tone, style, and instructions

### Adding Sample Apps

To add apps to the catalog:

1. Create a JSON file with app data
2. Index using curl or the OpenSearch client
3. See [Infrastructure Setup](./01-infrastructure.md) for examples

---

## Common Tasks

### View DynamoDB Data

```bash
# View sessions
aws dynamodb scan --table-name landingchat-sessions --max-items 5

# View messages for a session
aws dynamodb query \
  --table-name landingchat-messages \
  --key-condition-expression "sessionId = :sid" \
  --expression-attribute-values '{":sid":{"S":"your-session-id"}}'
```

### Query OpenSearch

```bash
# Search apps
curl -u admin:password \
  "https://your-opensearch-endpoint/apps_catalog/_search?q=invoice&pretty"

# Get all apps
curl -u admin:password \
  "https://your-opensearch-endpoint/apps_catalog/_search?size=100&pretty"
```

### Reset Session

In browser:
1. Open DevTools (F12)
2. Go to Application > Local Storage
3. Delete `landingchat_session_id`
4. Refresh page

Or clear all localStorage:
```javascript
localStorage.clear();
```

### Monitor LLM Token Usage

Check worker logs:
```bash
cd packages/worker
wrangler tail
```

Look for token usage in responses.

---

## Testing

### Manual Testing Checklist

**First Conversation:**
- [ ] Start new session
- [ ] Send initial message
- [ ] Receive response
- [ ] Radar chart shows initial data
- [ ] Profile summary updates

**Multi-Turn Conversation:**
- [ ] Continue conversation
- [ ] Radar dimensions update
- [ ] Profile attributes populate
- [ ] Checklist progress shows

**Conversation Completion:**
- [ ] Answer all checklist questions
- [ ] Conversation marked complete
- [ ] Recommendations appear
- [ ] Can still send messages

**Email Capture:**
- [ ] Enter valid email
- [ ] Email saves to profile
- [ ] Confirmation shows

**Session Persistence:**
- [ ] Refresh page
- [ ] Session continues
- [ ] Message history preserved

### End-to-End Test Script

```bash
#!/bin/bash
# test-e2e.sh

SESSION_ID=$(uuidgen)
API_URL="http://localhost:8787"

echo "Testing chat endpoint..."
RESPONSE=$(curl -s -X POST "$API_URL/api/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "'$SESSION_ID'",
    "channel": "text",
    "message": "I need help with invoice automation"
  }')

echo $RESPONSE | jq .

echo "Testing email capture..."
curl -s -X POST "$API_URL/api/profile/email" \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "'$SESSION_ID'",
    "email": "test@example.com"
  }' | jq .
```

---

## Troubleshooting

### Worker Won't Start

**Error: Missing environment variables**
- Ensure `.dev.vars` exists in `packages/worker/`
- Check all required variables are set
- Verify no typos in variable names

**Error: Cannot connect to DynamoDB**
- Check AWS credentials are valid
- Verify tables exist: `aws dynamodb list-tables`
- Check region matches

**Error: Cannot connect to OpenSearch**
- Verify domain is running
- Test connection: `curl -u admin:password https://endpoint/_cluster/health`
- Check credentials

### Frontend Won't Start

**Error: Cannot find module**
- Run `pnpm install` from root
- Clear node_modules: `rm -rf node_modules && pnpm install`

**Error: Failed to fetch**
- Ensure worker is running on port 8787
- Check `VITE_API_URL` in `.env`
- Check browser console for CORS errors

### No LLM Response

**Error: API key invalid**
- Verify Anthropic API key is correct
- Check you have credits

**Error: Model not found**
- Verify model names match Anthropic's current models
- Update `LLM_BASE_MODEL` if needed

---

## Next Steps

Now that you have LandingChat running:

1. **Customize the configuration** to match your use case
2. **Add your apps** to the OpenSearch catalog
3. **Test the conversation flow** thoroughly
4. **Deploy to production** following the deployment guides

### Recommended Reading

- [Architecture Documentation](../architecture.md)
- [Backend Deployment](./02-backend-deployment.md)
- [Frontend Deployment](./03-frontend-deployment.md)

### Get Help

- Review error logs in worker console
- Check browser DevTools for frontend errors
- Review AWS CloudWatch for DynamoDB/OpenSearch issues

---

## Additional Resources

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Cloudflare Pages Docs](https://developers.cloudflare.com/pages/)
- [Anthropic API Docs](https://docs.anthropic.com/)
- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/)
- [OpenSearch Documentation](https://opensearch.org/docs/)

# LandingChat

> A conversational intake landing page powered by LLM orchestration, designed to understand user needs and recommend relevant solutions.

LandingChat is a modern, serverless chat application that interviews users about their needs, tracks understanding through a visual radar chart, and provides intelligent recommendations from a searchable app catalog.

## Features

- **Intelligent Conversation:** LLM-powered chat that naturally interviews users
- **Visual Understanding:** Real-time radar chart showing conversation progress
- **Smart Recommendations:** Searches catalog based on user needs
- **Conversation Termination:** Automatically completes when enough information is gathered
- **Email Capture:** Save progress and receive recommendations via email
- **Fully Serverless:** Deploys to Cloudflare with zero infrastructure management
- **Type-Safe:** Full TypeScript implementation with shared types
- **Configuration-Driven:** Customize prompts, radar dimensions, and question checklists

## Architecture

```
┌─────────────┐
│   React     │  → Cloudflare Pages
│  Frontend   │
└──────┬──────┘
       │
       │ REST API
       │
┌──────▼──────┐
│  Cloudflare │  → Cloudflare Workers
│   Worker    │
└──────┬──────┘
       │
       ├──────→ DynamoDB (Sessions + Messages)
       ├──────→ OpenSearch (App Catalog)
       └──────→ Anthropic Claude (LLM)
```

## Tech Stack

- **Frontend:** React + TypeScript + Vite + Tailwind CSS
- **Backend:** Cloudflare Workers + TypeScript
- **Database:** AWS DynamoDB
- **Search:** AWS OpenSearch Service
- **LLM:** Anthropic Claude (Haiku + Sonnet)
- **Deployment:** Cloudflare Pages + Workers

## Project Structure

```
landingchat/
├── packages/
│   ├── shared/          # Shared TypeScript types and utilities
│   ├── config/          # Configuration (prompts, radar, checklist)
│   ├── worker/          # Cloudflare Worker backend
│   └── frontend/        # React frontend
├── docs/
│   ├── setup/           # Detailed setup guides
│   ├── architecture.md  # Architecture documentation
│   └── implementation-plan.md
├── package.json
├── pnpm-workspace.yaml
└── tsconfig.json
```

## Quick Start

### 🚀 Automated Setup (Recommended)

We provide scripts that automate the entire setup process:

```bash
# Clone the repository
git clone <your-repo-url>
cd landingchat

# Run the automated setup script
./scripts/setup.sh
```

This single script will:
- ✅ Check prerequisites
- ✅ Install dependencies
- ✅ Create AWS infrastructure (DynamoDB, OpenSearch, IAM)
- ✅ Seed sample apps
- ✅ Configure environment variables
- ✅ Build packages

**Then start development:**
```bash
# Terminal 1 - Backend
cd packages/worker && pnpm dev

# Terminal 2 - Frontend
cd packages/frontend && pnpm dev

# Open http://localhost:5173
```

**Estimated time:** 5-10 minutes (+ 15-20 minutes if creating OpenSearch)

See [scripts/README.md](./scripts/README.md) for details on individual scripts.

---

### 📝 Manual Setup

If you prefer manual setup:

**Prerequisites:**
- Node.js 18+
- pnpm (`npm install -g pnpm`)
- AWS Account (for DynamoDB and OpenSearch)
- Cloudflare Account
- Anthropic API Key

**Installation:**

1. **Clone and install:**
   ```bash
   git clone <your-repo-url>
   cd landingchat
   pnpm install
   ```

2. **Set up infrastructure:**

   Follow the [Infrastructure Setup Guide](./docs/setup/01-infrastructure.md) to create:
   - DynamoDB tables
   - OpenSearch domain
   - Seed sample apps

3. **Configure environment:**

   ```bash
   cd packages/worker
   cp .dev.vars.example .dev.vars
   # Edit with your credentials

   cd ../frontend
   cp .env.example .env
   # Edit API URL (default is fine for local dev)
   ```

4. **Start development:**

   ```bash
   # Terminal 1 - Backend
   cd packages/worker && pnpm dev

   # Terminal 2 - Frontend
   cd packages/frontend && pnpm dev
   ```

5. **Open browser:**

   Navigate to `http://localhost:5173` and start chatting!

## Documentation

### Setup Guides

- [**Infrastructure Setup**](./docs/setup/01-infrastructure.md) - Set up DynamoDB, OpenSearch, and AWS credentials
- [**Backend Deployment**](./docs/setup/02-backend-deployment.md) - Deploy Cloudflare Worker to production
- [**Frontend Deployment**](./docs/setup/03-frontend-deployment.md) - Deploy React app to Cloudflare Pages
- [**Getting Started**](./docs/setup/04-getting-started.md) - Quick start guide for development

### Additional Documentation

- [**Architecture Overview**](./docs/architecture.md) - System design, data flow, and technical decisions
- [**Implementation Plan**](./docs/implementation-plan.md) - Original design specification

## Configuration

### Customize Radar Dimensions

Edit `packages/config/src/defaults/radar.ts`:

```typescript
export const defaultRadarDimensions: RadarDimensionConfig[] = [
  {
    id: 'goal_clarity',
    label: 'Goal Clarity',
    description: 'How well we understand the user\'s primary objective'
  },
  // Add up to 6 dimensions
];
```

### Customize Question Checklist

Edit `packages/config/src/defaults/checklist.ts`:

```typescript
export const defaultChecklist: ChecklistItem[] = [
  {
    id: 'primary_goal',
    label: 'Primary Goal',
    description: 'What is the user trying to accomplish?'
  },
  // Add more questions
];
```

The conversation completes when all checklist items are answered.

### Customize Prompt

Edit `packages/config/src/prompts/interviewer.ts` to modify:
- LLM behavior and tone
- System instructions
- Goal text

## Development

### Build All Packages

```bash
pnpm build
```

### Type Check

```bash
pnpm typecheck
```

### Clean Build Artifacts

```bash
pnpm clean
```

### Package Commands

Each package has its own commands:

```bash
# Worker
cd packages/worker
pnpm dev      # Start dev server
pnpm build    # Build for production
pnpm deploy   # Deploy to Cloudflare

# Frontend
cd packages/frontend
pnpm dev      # Start dev server
pnpm build    # Build for production
pnpm deploy   # Deploy to Cloudflare Pages
```

## Deployment

### 🚀 Automated Deployment (Recommended)

Deploy to Cloudflare with one command:

```bash
./scripts/deploy.sh
```

This interactive script will:
- ✅ Check Cloudflare authentication
- ✅ Set production secrets (can use .dev.vars)
- ✅ Build and deploy worker
- ✅ Build and deploy frontend
- ✅ Test deployment health
- ✅ Provide deployment URLs

**Options:**
1. Deploy worker only
2. Deploy frontend only
3. Deploy both

---

### 📝 Manual Deployment

**Deploy Backend:**

```bash
cd packages/worker

# Set production secrets
wrangler secret put LLM_API_KEY
wrangler secret put AWS_ACCESS_KEY_ID
wrangler secret put AWS_SECRET_ACCESS_KEY
wrangler secret put OPENSEARCH_PASSWORD

# Deploy
pnpm deploy
```

See [Backend Deployment Guide](./docs/setup/02-backend-deployment.md) for details.

**Deploy Frontend:**

```bash
cd packages/frontend
pnpm deploy
```

Or connect your Git repository to Cloudflare Pages for automatic deployments.

See [Frontend Deployment Guide](./docs/setup/03-frontend-deployment.md) for details.

## How It Works

### Conversation Flow

1. **User sends message** → Frontend sends to `/api/chat`
2. **Worker loads session** from DynamoDB
3. **Worker builds prompt** with:
   - System instructions (from config)
   - Current profile and conversation summary
   - Recent message history
   - User's new message
4. **LLM responds** with structured JSON:
   - Assistant message
   - Profile updates (radar scores, attributes)
   - Conversation summary updates
   - Optional search queries
5. **Worker searches catalog** (if queries provided)
6. **Worker saves** updated profile and messages
7. **Frontend receives** response and updates UI

### Conversation Termination

The system uses a **question checklist** to ensure conversations complete efficiently:

- Each question has an ID (e.g., `primary_goal`, `timeline`)
- LLM tracks which questions are answered
- When `remaining_questions` is empty, conversation is complete
- User receives summary and recommendations

This prevents endless loops and ensures focused conversations.

## API Endpoints

### POST /api/chat

Send a chat message.

**Request:**
```json
{
  "sessionId": "optional-uuid",
  "channel": "text",
  "message": "I need help automating invoices"
}
```

**Response:**
```json
{
  "sessionId": "uuid",
  "assistantMessage": "I'd be happy to help...",
  "fullProfile": { ... },
  "searchRecommendations": [ ... ],
  "uiDirectives": {
    "conversation_complete": false,
    "show_recommendations": false
  }
}
```

### POST /api/profile/email

Capture user email.

**Request:**
```json
{
  "sessionId": "uuid",
  "email": "user@example.com"
}
```

### GET /health

Health check endpoint.

## Customization Examples

### Add a New App to Catalog

```bash
curl -XPOST "https://your-opensearch-endpoint/apps_catalog/_doc" \
  -u admin:password \
  -H 'Content-Type: application/json' \
  -d '{
    "id": "app_custom_workflow",
    "title": "Custom Workflow Automation",
    "description": "Build custom workflows...",
    "use_case_tags": ["workflow", "automation"],
    "industry_tags": ["any"],
    "persona_tags": ["ops_manager"],
    "complexity": "medium",
    "time_to_value": "1_hour",
    "cta_url": "https://example.com/workflows",
    "metadata": {
      "internal_priority": 0.75
    }
  }'
```

### Change LLM Model

Edit `packages/worker/.dev.vars`:

```bash
LLM_BASE_MODEL=claude-3-opus-20240229  # Use Opus instead of Haiku
```

Note: Opus is more expensive but higher quality.

### Add New Profile Attribute

1. Add to `packages/shared/src/types.ts`:
   ```typescript
   export interface UserProfileAttributes {
     industry?: string;
     company_size?: string;
     role?: string;
     your_new_field?: string;  // Add here
   }
   ```

2. Update checklist in `packages/config/src/defaults/checklist.ts`

3. LLM will automatically start populating it

## Troubleshooting

### Common Issues

**Worker won't start:**
- Check `.dev.vars` exists and has all required variables
- Verify AWS credentials are valid
- Ensure DynamoDB tables exist

**Frontend can't connect to backend:**
- Ensure worker is running on port 8787
- Check `VITE_API_URL` in `.env`
- Verify CORS is configured correctly

**No LLM responses:**
- Verify Anthropic API key is valid
- Check you have API credits
- Review worker logs: `wrangler tail`

**OpenSearch errors:**
- Verify domain is running: `aws opensearch describe-domain`
- Check credentials
- Test connection: `curl -u admin:password https://endpoint/_cluster/health`

See [Getting Started Guide](./docs/setup/04-getting-started.md) for more troubleshooting.

## Cost Estimates

**Development:**
- DynamoDB: Free tier (likely $0)
- OpenSearch: ~$35/month (t3.small)
- Cloudflare: Free tier
- Anthropic: ~$0.25 per 1M tokens (Haiku)

**Production:**
- Scale OpenSearch to t3.medium+ (~$70-140/month)
- Monitor token usage
- Set AWS Budgets alerts

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT

## Support

- Review [documentation](./docs/)
- Check [issues](https://github.com/your-org/landingchat/issues)
- Read [architecture docs](./docs/architecture.md)

## Acknowledgments

Built with:
- [Anthropic Claude](https://www.anthropic.com/)
- [Cloudflare Workers](https://workers.cloudflare.com/)
- [AWS DynamoDB](https://aws.amazon.com/dynamodb/)
- [OpenSearch](https://opensearch.org/)
- [React](https://react.dev/)
- [Vite](https://vitejs.dev/)

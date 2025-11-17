# Backend Deployment Guide

This guide covers deploying the Cloudflare Worker backend for LandingChat.

## Prerequisites

- Completed [Infrastructure Setup](./01-infrastructure.md)
- Cloudflare account
- Wrangler CLI installed (`pnpm add -g wrangler`)
- All infrastructure credentials ready

---

## Step 1: Install Dependencies

From the repository root:

```bash
# Install all dependencies
pnpm install
```

This will install dependencies for all packages in the monorepo.

---

## Step 2: Configure Environment Variables

### 2.1 Development Environment

Create `.dev.vars` file in `packages/worker/`:

```bash
cd packages/worker
cp .dev.vars.example .dev.vars
```

Edit `.dev.vars` with your actual credentials:

```bash
# LLM Configuration
LLM_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxx
LLM_BASE_MODEL=claude-3-haiku-20240307
LLM_HEAVY_MODEL=claude-3-sonnet-20240229
LLM_API_URL=https://api.anthropic.com/v1/messages

# OpenSearch Configuration
OPENSEARCH_URL=https://search-landingchat-apps-xxxxx.us-east-1.es.amazonaws.com
OPENSEARCH_USERNAME=admin
OPENSEARCH_PASSWORD=your-opensearch-password
OPENSEARCH_APPS_INDEX=apps_catalog

# AWS/DynamoDB Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DDB_TABLE_SESSIONS=landingchat-sessions
DDB_TABLE_MESSAGES=landingchat-messages

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000
```

**Security Note:** Never commit `.dev.vars` to git. It's already in `.gitignore`.

### 2.2 Production Environment

For production, you'll use Wrangler secrets instead of `.dev.vars`.

---

## Step 3: Build the Worker

```bash
# From packages/worker/
pnpm build
```

This compiles TypeScript to JavaScript.

---

## Step 4: Test Locally

### 4.1 Start Development Server

```bash
# From packages/worker/
pnpm dev
```

This starts the worker locally on `http://localhost:8787`.

### 4.2 Test Endpoints

**Health Check:**
```bash
curl http://localhost:8787/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

**Test Chat Endpoint:**
```bash
curl -X POST http://localhost:8787/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": null,
    "channel": "text",
    "message": "Hello, I need help automating my invoicing process"
  }'
```

You should receive a JSON response with:
- `sessionId`
- `assistantMessage`
- `fullProfile`
- `uiDirectives`

**Test Email Capture:**
```bash
curl -X POST http://localhost:8787/api/profile/email \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "your-session-id-from-above",
    "email": "test@example.com"
  }'
```

### 4.3 Verify Data Storage

Check DynamoDB to verify data is being stored:

```bash
# Check sessions
aws dynamodb scan \
  --table-name landingchat-sessions \
  --max-items 5 \
  --region us-east-1

# Check messages
aws dynamodb scan \
  --table-name landingchat-messages \
  --max-items 10 \
  --region us-east-1
```

---

## Step 5: Deploy to Production

### 5.1 Authenticate with Cloudflare

```bash
wrangler login
```

This opens a browser for authentication.

### 5.2 Update wrangler.toml

Edit `packages/worker/wrangler.toml`:

```toml
name = "landingchat-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

# Update for production
workers_dev = false
route = "api.yourdomain.com/*"
zone_id = "your-cloudflare-zone-id"

[vars]
LLM_BASE_MODEL = "claude-3-haiku-20240307"
LLM_HEAVY_MODEL = "claude-3-sonnet-20240229"
LLM_API_URL = "https://api.anthropic.com/v1/messages"
OPENSEARCH_APPS_INDEX = "apps_catalog"
AWS_REGION = "us-east-1"
DDB_TABLE_SESSIONS = "landingchat-sessions"
DDB_TABLE_MESSAGES = "landingchat-messages"
ALLOWED_ORIGINS = "https://yourdomain.com"

[build]
command = "pnpm build"
```

**Note:** Non-sensitive config goes in `[vars]`, secrets use Wrangler secrets (next step).

### 5.3 Set Production Secrets

```bash
cd packages/worker

# Set secrets (one at a time)
wrangler secret put LLM_API_KEY
# Enter your Anthropic API key when prompted

wrangler secret put OPENSEARCH_URL
# Enter your OpenSearch endpoint

wrangler secret put OPENSEARCH_USERNAME
# Enter: admin

wrangler secret put OPENSEARCH_PASSWORD
# Enter your OpenSearch password

wrangler secret put AWS_ACCESS_KEY_ID
# Enter your AWS access key

wrangler secret put AWS_SECRET_ACCESS_KEY
# Enter your AWS secret key
```

### 5.4 Deploy

```bash
pnpm deploy
```

This builds and deploys your worker to Cloudflare.

### 5.5 Verify Deployment

```bash
# Test production endpoint
curl https://api.yourdomain.com/health
```

---

## Step 6: Configure Custom Domain (Optional)

### 6.1 Add Worker Route

In Cloudflare dashboard:
1. Go to Workers & Pages
2. Select your worker
3. Go to Triggers tab
4. Add Route: `api.yourdomain.com/*`
5. Select your zone

### 6.2 Update DNS

Add a DNS record:
- Type: `CNAME`
- Name: `api`
- Target: `your-worker.workers.dev`
- Proxy: Enabled (orange cloud)

---

## Step 7: Monitor and Debug

### 7.1 View Logs

```bash
wrangler tail
```

This streams live logs from your worker.

### 7.2 Check Metrics

In Cloudflare dashboard:
1. Go to Workers & Pages
2. Select your worker
3. View Metrics tab for:
   - Request count
   - Error rate
   - CPU time
   - Duration

### 7.3 Common Issues

**Error: AWS Credentials Invalid**
- Verify secrets are set correctly: `wrangler secret list`
- Check IAM user has correct permissions
- Ensure region matches your DynamoDB tables

**Error: OpenSearch Connection Failed**
- Verify domain is accessible
- Check credentials are correct
- Ensure OpenSearch domain allows access from Cloudflare IPs

**Error: LLM API Failed**
- Verify API key is valid
- Check you have credits/billing set up
- Review model names are correct

**Error: CORS Issues**
- Update `ALLOWED_ORIGINS` to include your frontend domain
- Ensure protocol (http/https) matches

---

## Step 8: Performance Optimization

### 8.1 Enable Caching

For static responses, you can add caching headers:

```typescript
return new Response(data, {
  headers: {
    'Cache-Control': 'public, max-age=3600'
  }
});
```

### 8.2 Monitor Token Usage

Track LLM API costs:
```bash
# Add logging in services/llm.ts
console.log('Tokens used:', response.usage);
```

### 8.3 Optimize DynamoDB Queries

- Use `Limit` parameter to reduce data transfer
- Consider using GSI if you need additional query patterns
- Monitor consumed capacity

---

## API Endpoints Reference

### POST /api/chat

**Request:**
```json
{
  "sessionId": "optional-uuid",
  "channel": "text",
  "message": "user message here"
}
```

**Response:**
```json
{
  "sessionId": "uuid",
  "assistantMessage": "response text",
  "profileDelta": {
    "radar": [...],
    "attributes": {...},
    "inferred_intent_tags": [...]
  },
  "fullProfile": {...},
  "searchRecommendations": [...],
  "uiDirectives": {
    "show_recommendations": false,
    "highlight_dimensions": [],
    "ask_for_email": false,
    "conversation_complete": false
  }
}
```

### POST /api/profile/email

**Request:**
```json
{
  "sessionId": "uuid",
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "profile": {...}
}
```

### GET /health

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

---

## Scaling Considerations

### For High Traffic

1. **DynamoDB:**
   - Switch to provisioned capacity if you have predictable load
   - Enable auto-scaling
   - Consider Global Tables for multi-region

2. **OpenSearch:**
   - Upgrade instance type
   - Add more nodes for redundancy
   - Enable Multi-AZ

3. **Worker:**
   - Workers automatically scale
   - Monitor CPU time and adjust timeout if needed
   - Consider using Durable Objects for session state

4. **LLM API:**
   - Implement request queuing for rate limits
   - Consider caching common responses
   - Monitor and alert on token costs

---

## Rollback Procedure

If deployment has issues:

```bash
# List deployments
wrangler deployments list

# Rollback to previous version
wrangler rollback --message "Rolling back due to issue"
```

---

## Next Steps

- [Frontend Deployment Guide](./03-frontend-deployment.md)
- [Getting Started Guide](./04-getting-started.md)

## Support

For issues:
- Check Wrangler logs: `wrangler tail`
- Review CloudWatch logs for AWS services
- Check OpenSearch cluster health
- Verify all secrets are set correctly

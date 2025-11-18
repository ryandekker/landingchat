# LandingChat Setup Scripts

This directory contains automation scripts to help you set up and deploy LandingChat.

## Quick Start

### Option 1: Local Testing (No AWS Required)

For quick local testing with Docker:

```bash
./scripts/setup-local.sh
```

This sets up everything locally using Docker - no AWS account needed!

### Option 2: Full AWS Setup

For complete setup with AWS infrastructure:

```bash
./scripts/setup.sh
```

This master script will guide you through the entire setup process with real AWS services.

## Individual Scripts

### 🚀 setup.sh (Master Script)

**Purpose:** Complete automated setup from scratch to running locally.

**What it does:**
- Checks prerequisites (Node.js, pnpm, AWS CLI, etc.)
- Installs project dependencies
- Runs infrastructure setup
- Seeds OpenSearch with sample apps
- Configures environment variables
- Builds all packages

**Usage:**
```bash
./scripts/setup.sh
```

**When to use:** First time setup or complete reset.

---

### 🐳 setup-local.sh (Local Testing)

**Purpose:** Set up complete local testing environment using Docker - no AWS required!

**What it does:**
- Checks prerequisites (Node.js, pnpm, Docker)
- Installs project dependencies
- Starts local DynamoDB (via Docker)
- Starts local OpenSearch (via Docker)
- Creates local DynamoDB tables
- Seeds local OpenSearch with sample apps
- Configures environment variables for local development
- Builds all packages

**Prerequisites:**
- Docker and docker-compose installed
- Node.js 18+ and pnpm installed
- Anthropic API key (for LLM functionality)

**Usage:**
```bash
./scripts/setup-local.sh
```

**What you get:**
- DynamoDB Local at `http://localhost:8000`
- OpenSearch Local at `https://localhost:9200`
  - Username: `admin`
  - Password: `Admin123!`
- Pre-configured `.dev.vars` and `.env` files
- 3 sample apps seeded in catalog

**Managing local services:**
```bash
# Start services
./scripts/local-services.sh start

# Stop services
./scripts/local-services.sh stop

# View status
./scripts/local-services.sh status

# View logs
./scripts/local-services.sh logs

# Reset everything
./scripts/local-services.sh reset
```

**Advantages:**
- ✅ No AWS account needed
- ✅ No monthly costs
- ✅ Fast setup (2-3 minutes)
- ✅ Full feature parity for testing
- ✅ Easy to reset and start fresh

**Limitations:**
- ⚠️ Data is ephemeral (lost on container restart unless using volumes)
- ⚠️ Not suitable for production
- ⚠️ Still requires Anthropic API key for LLM

**Estimated time:** 2-3 minutes

---

### 🏗️ setup-infrastructure.sh

**Purpose:** Create AWS infrastructure (DynamoDB, OpenSearch, IAM).

**What it creates:**
- DynamoDB tables (sessions and messages)
- IAM user with appropriate permissions
- IAM access keys (saved to file)
- OpenSearch domain (optional)

**Prerequisites:**
- AWS CLI installed and configured
- AWS account with appropriate permissions
- jq installed

**Usage:**
```bash
./scripts/setup-infrastructure.sh
```

**Environment Variables:**
- `AWS_REGION` (default: us-east-1)
- `SESSIONS_TABLE_NAME` (default: landingchat-sessions)
- `MESSAGES_TABLE_NAME` (default: landingchat-messages)
- `OPENSEARCH_DOMAIN` (default: landingchat-apps)
- `IAM_USER_NAME` (default: landingchat-worker)

**Outputs:**
- `aws-credentials-landingchat-worker.txt` - AWS access keys (⚠️ store securely!)
- `opensearch-credentials.txt` - OpenSearch password (⚠️ store securely!)

**Estimated time:** 2-3 minutes (+ 15-20 minutes if creating OpenSearch)

---

### 🌱 seed-opensearch.sh

**Purpose:** Seed OpenSearch with sample applications.

**What it does:**
- Creates the apps catalog index
- Indexes 10 sample applications
- Verifies indexing was successful
- Tests search functionality

**Prerequisites:**
- OpenSearch domain must be active
- curl and jq installed

**Usage:**
```bash
./scripts/seed-opensearch.sh
```

**Sample Apps Included:**
1. Invoice Upload & Auto-Categorization
2. CRM Integration Suite
3. No-Code Workflow Builder
4. Data Warehouse & Analytics
5. AI-Powered Customer Support
6. Email Marketing Automation
7. Agile Project Management
8. Inventory & Order Management
9. Employee Onboarding Platform
10. Digital Document Signing

**Customization:**
Edit the `BULK_DATA` variable in the script to add/modify apps.

**Estimated time:** 30 seconds

---

### ⚙️ configure-env.sh

**Purpose:** Set up environment variables for local development.

**What it creates:**
- `packages/worker/.dev.vars` - Backend environment variables
- `packages/frontend/.env` - Frontend environment variables

**What it prompts for:**

**Backend (.dev.vars):**
- Anthropic API key
- LLM model names
- OpenSearch URL and credentials
- AWS credentials
- DynamoDB table names
- CORS allowed origins

**Frontend (.env):**
- API URL (worker endpoint)

**Usage:**
```bash
./scripts/configure-env.sh
```

**Smart Features:**
- Auto-detects OpenSearch endpoint from AWS
- Can load AWS credentials from saved file
- Validates existing configs before overwriting

**Security:**
- ✅ Both files are in .gitignore
- ✅ Never committed to git
- ✅ Used only for local development

**Estimated time:** 2-3 minutes

---

### 🚢 deploy.sh

**Purpose:** Deploy to Cloudflare production.

**What it deploys:**
- Backend Worker (Cloudflare Workers)
- Frontend (Cloudflare Pages)

**Prerequisites:**
- Wrangler CLI installed
- Cloudflare account
- Logged in to Wrangler (`wrangler login`)

**Usage:**
```bash
./scripts/deploy.sh
```

**Interactive Options:**
1. Deploy worker only
2. Deploy frontend only
3. Deploy both

**What it does:**

**For Worker:**
- Checks/sets production secrets
- Builds worker
- Deploys to Cloudflare Workers
- Tests health endpoint

**For Frontend:**
- Prompts for production API URL
- Builds with production env vars
- Deploys to Cloudflare Pages

**Smart Features:**
- Can use .dev.vars to set production secrets
- Auto-detects worker URL for frontend
- Creates Pages project if doesn't exist

**Estimated time:** 3-5 minutes

---

### 🔧 local-services.sh (Service Manager)

**Purpose:** Manage local Docker services for testing.

**Usage:**
```bash
./scripts/local-services.sh {command}
```

**Commands:**

```bash
# Start all services
./scripts/local-services.sh start

# Stop all services
./scripts/local-services.sh stop

# Restart all services
./scripts/local-services.sh restart

# Show service status and health
./scripts/local-services.sh status

# View live logs (Ctrl+C to exit)
./scripts/local-services.sh logs

# Reset everything (deletes all data)
./scripts/local-services.sh reset

# List DynamoDB tables
./scripts/local-services.sh tables

# Query a DynamoDB table
./scripts/local-services.sh query landingchat-sessions-local

# Search OpenSearch catalog
./scripts/local-services.sh search invoice
```

**Examples:**

```bash
# Morning routine - start services
./scripts/local-services.sh start

# Check everything is running
./scripts/local-services.sh status

# View what's in DynamoDB
./scripts/local-services.sh tables
./scripts/local-services.sh query landingchat-sessions-local

# Search for apps
./scripts/local-services.sh search crm

# Evening routine - stop services
./scripts/local-services.sh stop
```

**When to use:**
- Daily development workflow
- Debugging local services
- Inspecting local data
- Resetting test environment

---

## Common Workflows

### Local Testing (Quickest)

```bash
# 1. Set up local environment with Docker
./scripts/setup-local.sh

# 2. Start development (in separate terminals)
cd packages/worker && pnpm dev
cd packages/frontend && pnpm dev

# 3. When done, stop services
./scripts/local-services.sh stop
```

### First Time Setup (AWS)

```bash
# 1. Run master setup script
./scripts/setup.sh

# 2. Start development (in separate terminals)
cd packages/worker && pnpm dev
cd packages/frontend && pnpm dev
```

### Deploy to Production

```bash
# Deploy everything
./scripts/deploy.sh

# Or deploy individually
cd packages/worker && pnpm deploy
cd packages/frontend && pnpm deploy
```

### Reset Environment

```bash
# Clean everything
pnpm clean
rm -rf node_modules pnpm-lock.yaml

# Reconfigure
./scripts/configure-env.sh

# Reinstall
pnpm install
```

### Add More Apps to Catalog

```bash
# Edit the script to add your apps
vim scripts/seed-opensearch.sh

# Re-run seeding
./scripts/seed-opensearch.sh
```

## Troubleshooting

### "Permission denied" when running scripts

Make scripts executable:
```bash
chmod +x scripts/*.sh
```

### AWS CLI not configured

Configure AWS credentials:
```bash
aws configure
```

### OpenSearch domain not ready

Check status:
```bash
aws opensearch describe-domain --domain-name landingchat-apps --region us-east-1
```

Wait until `Processing: false` and `UpgradeProcessing: false`.

### Wrangler not logged in

Login to Cloudflare:
```bash
wrangler login
```

### Script fails midway

Most scripts are idempotent and can be re-run safely. They check for existing resources before creating new ones.

## Security Best Practices

### Credentials Files

After setup, you'll have sensitive files:
- `aws-credentials-landingchat-worker.txt`
- `opensearch-credentials.txt`

**⚠️ IMPORTANT:**
1. Store these in a secure password manager
2. Delete from repository after saving
3. Never commit to git
4. Rotate keys regularly

### Environment Files

These files contain secrets:
- `packages/worker/.dev.vars`
- `packages/frontend/.env`

**Already in .gitignore** - but verify they're never committed!

### Production Secrets

For production, use Wrangler secrets instead of .dev.vars:

```bash
wrangler secret put SECRET_NAME
```

Never store production secrets in files.

## Script Maintenance

### Adding New Infrastructure

1. Edit `setup-infrastructure.sh`
2. Add resource creation logic
3. Update summary output
4. Test thoroughly

### Updating Sample Apps

1. Edit `BULK_DATA` in `seed-opensearch.sh`
2. Follow existing JSON format
3. Ensure unique IDs
4. Re-seed to test

### Environment Variables

When adding new env vars:
1. Update `configure-env.sh`
2. Update `.dev.vars.example`
3. Update `.env.example`
4. Update documentation

## Additional Resources

- [Infrastructure Setup Guide](../docs/setup/01-infrastructure.md)
- [Backend Deployment Guide](../docs/setup/02-backend-deployment.md)
- [Frontend Deployment Guide](../docs/setup/03-frontend-deployment.md)
- [Getting Started Guide](../docs/setup/04-getting-started.md)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review the detailed setup documentation
3. Ensure all prerequisites are installed
4. Check AWS/Cloudflare service status

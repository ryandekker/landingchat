#!/bin/bash

# LandingChat Local Testing Setup Script
# Sets up a complete local testing environment using Docker

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              LandingChat Local Testing Setup                ║
║                                                              ║
║         Run everything locally with Docker - No AWS!         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

# Check if in correct directory
if [ ! -f "pnpm-workspace.yaml" ]; then
    echo -e "${RED}Error: This script must be run from the repository root${NC}"
    exit 1
fi

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
echo ""

MISSING_DEPS=()

# Check Node.js
if ! command -v node &> /dev/null; then
    MISSING_DEPS+=("Node.js 18+")
else
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        echo -e "${YELLOW}⚠ Node.js version is $NODE_VERSION, but 18+ is recommended${NC}"
    else
        echo -e "${GREEN}✓ Node.js $(node --version)${NC}"
    fi
fi

# Check pnpm
if ! command -v pnpm &> /dev/null; then
    MISSING_DEPS+=("pnpm")
else
    echo -e "${GREEN}✓ pnpm $(pnpm --version)${NC}"
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    MISSING_DEPS+=("Docker")
else
    echo -e "${GREEN}✓ Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1)${NC}"
fi

# Check docker-compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    MISSING_DEPS+=("docker-compose")
else
    echo -e "${GREEN}✓ docker-compose${NC}"
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Missing dependencies:${NC}"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  - $dep"
    done
    echo ""
    echo "Please install these dependencies and run this script again."
    exit 1
fi

echo -e "${GREEN}All prerequisites met!${NC}"
echo ""

# Check for Anthropic API key
echo -e "${YELLOW}Note:${NC} You'll need an Anthropic API key for the LLM functionality."
echo "If you don't have one, you can get it from: https://console.anthropic.com/"
echo ""
read -p "Do you have an Anthropic API key? (y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠ You'll need an API key to test the conversation functionality.${NC}"
    echo "The setup will continue, but you'll need to add the key later."
    echo ""
fi

# Step 1: Install dependencies
echo -e "${YELLOW}Step 1: Installing project dependencies...${NC}"
echo ""

if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    pnpm install
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi

echo ""

# Step 2: Create Docker Compose file
echo -e "${YELLOW}Step 2: Creating Docker Compose configuration...${NC}"
echo ""

cat > docker-compose.local.yml <<'EOF'
version: '3.8'

services:
  dynamodb-local:
    image: amazon/dynamodb-local:latest
    container_name: landingchat-dynamodb-local
    ports:
      - "8000:8000"
    command: "-jar DynamoDBLocal.jar -sharedDb -inMemory"
    networks:
      - landingchat-local

  opensearch-local:
    image: opensearchproject/opensearch:2.11.0
    container_name: landingchat-opensearch-local
    environment:
      - discovery.type=single-node
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=Admin123!
      - plugins.security.disabled=false
      - DISABLE_INSTALL_DEMO_CONFIG=false
    ports:
      - "9200:9200"
      - "9600:9600"
    networks:
      - landingchat-local
    healthcheck:
      test: ["CMD-SHELL", "curl -k -u admin:Admin123! https://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 30

networks:
  landingchat-local:
    driver: bridge
EOF

echo -e "${GREEN}✓ Docker Compose file created${NC}"
echo ""

# Step 3: Start Docker services
echo -e "${YELLOW}Step 3: Starting local services...${NC}"
echo ""

echo "Starting DynamoDB and OpenSearch..."
docker compose -f docker-compose.local.yml up -d

echo "Waiting for services to be ready..."
echo -n "Waiting for DynamoDB..."
for i in {1..30}; do
    if curl -s http://localhost:8000 > /dev/null 2>&1; then
        echo " ready!"
        break
    fi
    echo -n "."
    sleep 1
done

echo -n "Waiting for OpenSearch..."
for i in {1..60}; do
    if curl -k -s -u admin:Admin123! https://localhost:9200/_cluster/health > /dev/null 2>&1; then
        echo " ready!"
        break
    fi
    echo -n "."
    sleep 2
done

echo -e "${GREEN}✓ Services started${NC}"
echo ""

# Step 4: Create DynamoDB tables
echo -e "${YELLOW}Step 4: Creating DynamoDB tables...${NC}"
echo ""

# Create sessions table
echo "Creating sessions table..."
aws dynamodb create-table \
    --table-name landingchat-sessions-local \
    --attribute-definitions AttributeName=sessionId,AttributeType=S \
    --key-schema AttributeName=sessionId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --endpoint-url http://localhost:8000 \
    --region us-east-1 > /dev/null 2>&1 || echo "Table may already exist"

# Create messages table
echo "Creating messages table..."
aws dynamodb create-table \
    --table-name landingchat-messages-local \
    --attribute-definitions \
        AttributeName=sessionId,AttributeType=S \
        AttributeName=sortKey,AttributeType=S \
    --key-schema \
        AttributeName=sessionId,KeyType=HASH \
        AttributeName=sortKey,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --endpoint-url http://localhost:8000 \
    --region us-east-1 > /dev/null 2>&1 || echo "Table may already exist"

echo -e "${GREEN}✓ DynamoDB tables created${NC}"
echo ""

# Step 5: Set up OpenSearch
echo -e "${YELLOW}Step 5: Setting up OpenSearch index...${NC}"
echo ""

# Wait a bit more for OpenSearch to fully initialize
sleep 5

echo "Creating apps catalog index..."
curl -k -s -X PUT "https://localhost:9200/apps_catalog" \
    -u admin:Admin123! \
    -H 'Content-Type: application/json' \
    -d '{
      "mappings": {
        "properties": {
          "id": { "type": "keyword" },
          "title": { "type": "text" },
          "description": { "type": "text" },
          "use_case_tags": { "type": "keyword" },
          "industry_tags": { "type": "keyword" },
          "persona_tags": { "type": "keyword" },
          "complexity": { "type": "keyword" },
          "time_to_value": { "type": "keyword" },
          "cta_url": { "type": "keyword" },
          "metadata": {
            "properties": {
              "internal_priority": { "type": "float" }
            }
          }
        }
      }
    }' > /dev/null

echo "Seeding sample apps..."
curl -k -s -X POST "https://localhost:9200/_bulk" \
    -u admin:Admin123! \
    -H 'Content-Type: application/x-ndjson' \
    --data-binary @- <<'EOFDATA' > /dev/null
{"index":{"_index":"apps_catalog","_id":"app_invoice_automation_01"}}
{"id":"app_invoice_automation_01","title":"Invoice Upload & Auto-Categorization","description":"Upload invoices, extract line items, and automatically sync to your accounting software. Perfect for small agencies and professional services firms.","use_case_tags":["invoice_automation","bookkeeping","document_processing"],"industry_tags":["agency","professional_services","accounting"],"persona_tags":["owner","ops_manager","bookkeeper"],"complexity":"low","time_to_value":"30_min","cta_url":"https://example.com/apps/invoice-automation","metadata":{"internal_priority":0.9}}
{"index":{"_index":"apps_catalog","_id":"app_crm_integration_01"}}
{"id":"app_crm_integration_01","title":"CRM Integration Suite","description":"Connect your CRM with 100+ tools. Sync contacts, deals, and activities automatically. Built for growing sales teams.","use_case_tags":["crm","integration","sales_automation"],"industry_tags":["saas","sales","marketing"],"persona_tags":["sales_manager","sales_ops","cto"],"complexity":"medium","time_to_value":"1_hour","cta_url":"https://example.com/apps/crm-integration","metadata":{"internal_priority":0.85}}
{"index":{"_index":"apps_catalog","_id":"app_workflow_builder_01"}}
{"id":"app_workflow_builder_01","title":"No-Code Workflow Builder","description":"Build custom workflows without code. Automate repetitive tasks across your business. Ideal for operations teams.","use_case_tags":["workflow","automation","no_code"],"industry_tags":["any","operations","it"],"persona_tags":["ops_manager","business_analyst","admin"],"complexity":"low","time_to_value":"1_hour","cta_url":"https://example.com/apps/workflow-builder","metadata":{"internal_priority":0.8}}
EOFDATA

echo -e "${GREEN}✓ OpenSearch configured and seeded${NC}"
echo ""

# Step 6: Configure environment variables
echo -e "${YELLOW}Step 6: Configuring environment variables...${NC}"
echo ""

# Prompt for Anthropic API key
read -p "Enter your Anthropic API key (or press Enter to skip): " ANTHROPIC_API_KEY

if [ -z "$ANTHROPIC_API_KEY" ]; then
    ANTHROPIC_API_KEY="sk-ant-REPLACE-WITH-YOUR-KEY"
    echo -e "${YELLOW}⚠ Using placeholder API key - you'll need to update this later${NC}"
fi

# Create worker .dev.vars
cat > packages/worker/.dev.vars <<EOF
# LLM Configuration
LLM_API_KEY=$ANTHROPIC_API_KEY
LLM_BASE_MODEL=claude-3-haiku-20240307
LLM_HEAVY_MODEL=claude-3-sonnet-20240229
LLM_API_URL=https://api.anthropic.com/v1/messages

# OpenSearch Configuration (Local)
OPENSEARCH_URL=https://localhost:9200
OPENSEARCH_USERNAME=admin
OPENSEARCH_PASSWORD=Admin123!
OPENSEARCH_APPS_INDEX=apps_catalog

# AWS/DynamoDB Configuration (Local)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=local
AWS_SECRET_ACCESS_KEY=local
DDB_TABLE_SESSIONS=landingchat-sessions-local
DDB_TABLE_MESSAGES=landingchat-messages-local
DYNAMODB_ENDPOINT=http://localhost:8000

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000
EOF

# Create frontend .env
cat > packages/frontend/.env <<EOF
# API Configuration (Local)
VITE_API_URL=http://localhost:8787
EOF

echo -e "${GREEN}✓ Environment variables configured${NC}"
echo ""

# Step 7: Build packages
echo -e "${YELLOW}Step 7: Building packages...${NC}"
echo ""

pnpm build

echo -e "${GREEN}✓ Packages built${NC}"
echo ""

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║            Local Testing Environment Ready! 🎉               ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Services Running:${NC}"
echo "  ✓ DynamoDB Local - http://localhost:8000"
echo "  ✓ OpenSearch Local - https://localhost:9200"
echo ""

echo -e "${CYAN}To Start Development:${NC}"
echo ""
echo "  # Terminal 1 - Start Worker"
echo "  cd packages/worker"
echo "  pnpm dev"
echo ""
echo "  # Terminal 2 - Start Frontend"
echo "  cd packages/frontend"
echo "  pnpm dev"
echo ""
echo "  # Open browser"
echo "  http://localhost:5173"
echo ""

echo -e "${CYAN}To Stop Local Services:${NC}"
echo "  docker-compose -f docker-compose.local.yml down"
echo ""

echo -e "${CYAN}To View Service Logs:${NC}"
echo "  docker-compose -f docker-compose.local.yml logs -f"
echo ""

echo -e "${CYAN}To Reset Everything:${NC}"
echo "  docker-compose -f docker-compose.local.yml down -v"
echo "  ./scripts/setup-local.sh"
echo ""

if [ "$ANTHROPIC_API_KEY" == "sk-ant-REPLACE-WITH-YOUR-KEY" ]; then
    echo -e "${YELLOW}⚠ IMPORTANT: Update your Anthropic API key${NC}"
    echo "  Edit packages/worker/.dev.vars and replace the placeholder LLM_API_KEY"
    echo ""
fi

echo -e "${CYAN}Useful Commands:${NC}"
echo ""
echo "  # Check DynamoDB tables"
echo "  aws dynamodb list-tables --endpoint-url http://localhost:8000 --region us-east-1"
echo ""
echo "  # Query OpenSearch"
echo "  curl -k -u admin:Admin123! https://localhost:9200/apps_catalog/_search?pretty"
echo ""
echo "  # View DynamoDB data"
echo "  aws dynamodb scan --table-name landingchat-sessions-local --endpoint-url http://localhost:8000 --region us-east-1"
echo ""

echo -e "${GREEN}Happy testing! 🚀${NC}"
echo ""

#!/bin/bash

# LandingChat Environment Configuration Script
# Helps set up environment variables for worker and frontend

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  LandingChat Environment Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
WORKER_DIR="./packages/worker"
FRONTEND_DIR="./packages/frontend"

# Check if we're in the right directory
if [ ! -f "pnpm-workspace.yaml" ]; then
    echo -e "${RED}Error: This script must be run from the repository root${NC}"
    exit 1
fi

echo "This script will help you configure environment variables for:"
echo "  1. Backend Worker (.dev.vars)"
echo "  2. Frontend (.env)"
echo ""

# Backend Configuration
echo -e "${YELLOW}=== Backend Worker Configuration ===${NC}"
echo ""

WORKER_ENV_FILE="$WORKER_DIR/.dev.vars"

if [ -f "$WORKER_ENV_FILE" ]; then
    echo -e "${YELLOW}⚠ .dev.vars already exists${NC}"
    read -p "Do you want to overwrite it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing .dev.vars"
        SKIP_WORKER=true
    fi
fi

if [ "$SKIP_WORKER" != "true" ]; then
    echo "Let's configure your worker environment variables..."
    echo ""

    # Anthropic API
    echo -e "${BLUE}1. Anthropic API Configuration${NC}"
    read -p "Anthropic API Key (starts with sk-ant-): " LLM_API_KEY
    read -p "Base Model (default: claude-3-haiku-20240307): " LLM_BASE_MODEL
    LLM_BASE_MODEL=${LLM_BASE_MODEL:-claude-3-haiku-20240307}
    read -p "Heavy Model (default: claude-3-sonnet-20240229): " LLM_HEAVY_MODEL
    LLM_HEAVY_MODEL=${LLM_HEAVY_MODEL:-claude-3-sonnet-20240229}
    LLM_API_URL=${LLM_API_URL:-https://api.anthropic.com/v1/messages}
    echo ""

    # OpenSearch
    echo -e "${BLUE}2. OpenSearch Configuration${NC}"

    # Try to get from AWS
    AWS_REGION_DEFAULT="us-east-1"
    read -p "AWS Region (default: $AWS_REGION_DEFAULT): " AWS_REGION
    AWS_REGION=${AWS_REGION:-$AWS_REGION_DEFAULT}

    OPENSEARCH_DOMAIN_DEFAULT="landingchat-apps"
    read -p "OpenSearch Domain Name (default: $OPENSEARCH_DOMAIN_DEFAULT): " OPENSEARCH_DOMAIN
    OPENSEARCH_DOMAIN=${OPENSEARCH_DOMAIN:-$OPENSEARCH_DOMAIN_DEFAULT}

    # Try to get endpoint from AWS
    if command -v aws &> /dev/null; then
        echo "Fetching OpenSearch endpoint from AWS..."
        if OPENSEARCH_ENDPOINT=$(aws opensearch describe-domain --domain-name "$OPENSEARCH_DOMAIN" --region "$AWS_REGION" --query 'DomainStatus.Endpoint' --output text 2>/dev/null); then
            OPENSEARCH_URL="https://$OPENSEARCH_ENDPOINT"
            echo -e "${GREEN}✓ Found endpoint: $OPENSEARCH_URL${NC}"
        else
            echo -e "${YELLOW}⚠ Could not auto-detect endpoint${NC}"
            read -p "OpenSearch URL (https://...): " OPENSEARCH_URL
        fi
    else
        read -p "OpenSearch URL (https://...): " OPENSEARCH_URL
    fi

    read -p "OpenSearch Username (default: admin): " OPENSEARCH_USERNAME
    OPENSEARCH_USERNAME=${OPENSEARCH_USERNAME:-admin}
    read -s -p "OpenSearch Password: " OPENSEARCH_PASSWORD
    echo ""
    read -p "OpenSearch Index Name (default: apps_catalog): " OPENSEARCH_APPS_INDEX
    OPENSEARCH_APPS_INDEX=${OPENSEARCH_APPS_INDEX:-apps_catalog}
    echo ""

    # AWS/DynamoDB
    echo -e "${BLUE}3. AWS/DynamoDB Configuration${NC}"

    # Check for saved credentials
    if [ -f "./aws-credentials-landingchat-worker.txt" ]; then
        echo -e "${GREEN}Found saved AWS credentials file${NC}"
        read -p "Use credentials from aws-credentials-landingchat-worker.txt? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            AWS_ACCESS_KEY_ID=$(grep "Access Key ID:" ./aws-credentials-landingchat-worker.txt | cut -d: -f2 | xargs)
            AWS_SECRET_ACCESS_KEY=$(grep "Secret Access Key:" ./aws-credentials-landingchat-worker.txt | cut -d: -f2 | xargs)
            echo -e "${GREEN}✓ Loaded credentials from file${NC}"
        fi
    fi

    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
        read -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
        echo ""
    fi

    read -p "DynamoDB Sessions Table (default: landingchat-sessions): " DDB_TABLE_SESSIONS
    DDB_TABLE_SESSIONS=${DDB_TABLE_SESSIONS:-landingchat-sessions}
    read -p "DynamoDB Messages Table (default: landingchat-messages): " DDB_TABLE_MESSAGES
    DDB_TABLE_MESSAGES=${DDB_TABLE_MESSAGES:-landingchat-messages}
    echo ""

    # CORS
    echo -e "${BLUE}4. CORS Configuration${NC}"
    read -p "Allowed Origins (default: http://localhost:5173,http://localhost:3000): " ALLOWED_ORIGINS
    ALLOWED_ORIGINS=${ALLOWED_ORIGINS:-http://localhost:5173,http://localhost:3000}
    echo ""

    # Write .dev.vars
    cat > "$WORKER_ENV_FILE" <<EOF
# LLM Configuration
LLM_API_KEY=$LLM_API_KEY
LLM_BASE_MODEL=$LLM_BASE_MODEL
LLM_HEAVY_MODEL=$LLM_HEAVY_MODEL
LLM_API_URL=$LLM_API_URL

# OpenSearch Configuration
OPENSEARCH_URL=$OPENSEARCH_URL
OPENSEARCH_USERNAME=$OPENSEARCH_USERNAME
OPENSEARCH_PASSWORD=$OPENSEARCH_PASSWORD
OPENSEARCH_APPS_INDEX=$OPENSEARCH_APPS_INDEX

# AWS/DynamoDB Configuration
AWS_REGION=$AWS_REGION
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
DDB_TABLE_SESSIONS=$DDB_TABLE_SESSIONS
DDB_TABLE_MESSAGES=$DDB_TABLE_MESSAGES

# CORS Configuration
ALLOWED_ORIGINS=$ALLOWED_ORIGINS
EOF

    echo -e "${GREEN}✓ Worker .dev.vars created at $WORKER_ENV_FILE${NC}"
fi

echo ""

# Frontend Configuration
echo -e "${YELLOW}=== Frontend Configuration ===${NC}"
echo ""

FRONTEND_ENV_FILE="$FRONTEND_DIR/.env"

if [ -f "$FRONTEND_ENV_FILE" ]; then
    echo -e "${YELLOW}⚠ .env already exists${NC}"
    read -p "Do you want to overwrite it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing .env"
        SKIP_FRONTEND=true
    fi
fi

if [ "$SKIP_FRONTEND" != "true" ]; then
    read -p "API URL (default: http://localhost:8787): " VITE_API_URL
    VITE_API_URL=${VITE_API_URL:-http://localhost:8787}

    cat > "$FRONTEND_ENV_FILE" <<EOF
# API Configuration
VITE_API_URL=$VITE_API_URL
EOF

    echo -e "${GREEN}✓ Frontend .env created at $FRONTEND_ENV_FILE${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Files created:"
if [ "$SKIP_WORKER" != "true" ]; then
    echo "  ✓ $WORKER_ENV_FILE"
fi
if [ "$SKIP_FRONTEND" != "true" ]; then
    echo "  ✓ $FRONTEND_ENV_FILE"
fi
echo ""
echo -e "${RED}IMPORTANT SECURITY NOTES:${NC}"
echo "  • Never commit .dev.vars or .env files to git"
echo "  • These files are already in .gitignore"
echo "  • For production, use Wrangler secrets instead"
echo ""
echo "Next steps:"
echo "  1. Install dependencies: pnpm install"
echo "  2. Start worker: cd packages/worker && pnpm dev"
echo "  3. Start frontend: cd packages/frontend && pnpm dev"
echo "  4. Open http://localhost:5173 in your browser"
echo ""

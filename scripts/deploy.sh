#!/bin/bash

# LandingChat Deployment Script
# Helps deploy worker and frontend to Cloudflare

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
║                  LandingChat Deployment                      ║
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

# Check for wrangler
if ! command -v wrangler &> /dev/null; then
    echo -e "${RED}Error: Wrangler is not installed${NC}"
    echo "Install with: pnpm add -g wrangler"
    exit 1
fi

echo "What would you like to deploy?"
echo "  1) Backend Worker only"
echo "  2) Frontend only"
echo "  3) Both (Worker then Frontend)"
echo ""
read -p "Choose (1-3): " CHOICE

case $CHOICE in
    1)
        DEPLOY_WORKER=true
        ;;
    2)
        DEPLOY_FRONTEND=true
        ;;
    3)
        DEPLOY_WORKER=true
        DEPLOY_FRONTEND=true
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""

# Deploy Worker
if [ "$DEPLOY_WORKER" = true ]; then
    echo -e "${YELLOW}=== Deploying Backend Worker ===${NC}"
    echo ""

    # Check if logged in
    if ! wrangler whoami &> /dev/null; then
        echo "You need to login to Cloudflare first."
        wrangler login
    fi

    echo "Checking required secrets..."
    REQUIRED_SECRETS=(
        "LLM_API_KEY"
        "OPENSEARCH_URL"
        "OPENSEARCH_PASSWORD"
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
    )

    echo ""
    echo -e "${BLUE}You'll need to set the following secrets:${NC}"
    for secret in "${REQUIRED_SECRETS[@]}"; do
        echo "  - $secret"
    done
    echo ""

    read -p "Have you already set these secrets? (y/n) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Setting secrets now..."
        echo ""

        cd packages/worker

        # Check if .dev.vars exists for default values
        if [ -f ".dev.vars" ]; then
            echo -e "${YELLOW}Found .dev.vars file. We can use these values for secrets.${NC}"
            read -p "Use values from .dev.vars? (y/n) " -n 1 -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Read from .dev.vars and set secrets
                source .dev.vars

                echo "$LLM_API_KEY" | wrangler secret put LLM_API_KEY
                echo "$OPENSEARCH_URL" | wrangler secret put OPENSEARCH_URL
                echo "$OPENSEARCH_USERNAME" | wrangler secret put OPENSEARCH_USERNAME
                echo "$OPENSEARCH_PASSWORD" | wrangler secret put OPENSEARCH_PASSWORD
                echo "$AWS_ACCESS_KEY_ID" | wrangler secret put AWS_ACCESS_KEY_ID
                echo "$AWS_SECRET_ACCESS_KEY" | wrangler secret put AWS_SECRET_ACCESS_KEY
            else
                # Manual entry
                for secret in "${REQUIRED_SECRETS[@]}"; do
                    echo "Setting $secret..."
                    wrangler secret put "$secret"
                done

                # Additional secrets
                wrangler secret put OPENSEARCH_USERNAME
            fi
        else
            # Manual entry
            for secret in "${REQUIRED_SECRETS[@]}"; do
                echo "Setting $secret..."
                wrangler secret put "$secret"
            done

            wrangler secret put OPENSEARCH_USERNAME
        fi

        cd ../..
    fi

    echo ""
    echo "Building worker..."
    cd packages/worker
    pnpm build

    echo ""
    echo "Deploying worker..."
    pnpm deploy

    echo ""
    echo -e "${GREEN}✓ Worker deployed successfully!${NC}"

    # Get worker URL
    WORKER_URL=$(wrangler deployments list --name landingchat-worker 2>/dev/null | grep -o 'https://.*workers.dev' | head -1 || echo "")

    if [ -n "$WORKER_URL" ]; then
        echo ""
        echo "Worker URL: $WORKER_URL"
        echo ""
        echo "Testing worker..."
        if curl -s "$WORKER_URL/health" | grep -q "ok"; then
            echo -e "${GREEN}✓ Worker is healthy!${NC}"
        else
            echo -e "${YELLOW}⚠ Could not verify worker health${NC}"
        fi
    fi

    cd ../..
fi

# Deploy Frontend
if [ "$DEPLOY_FRONTEND" = true ]; then
    echo ""
    echo -e "${YELLOW}=== Deploying Frontend ===${NC}"
    echo ""

    # Check if logged in
    if ! wrangler whoami &> /dev/null; then
        echo "You need to login to Cloudflare first."
        wrangler login
    fi

    cd packages/frontend

    # Check for production environment variables
    echo "Frontend deployment requires VITE_API_URL to be set."
    echo ""

    if [ -n "$WORKER_URL" ]; then
        echo "Detected worker URL from previous deployment: $WORKER_URL"
        read -p "Use this URL for VITE_API_URL? (y/n) " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            export VITE_API_URL="$WORKER_URL"
        fi
    fi

    if [ -z "$VITE_API_URL" ]; then
        read -p "Enter your worker API URL (e.g., https://api.yourdomain.com): " VITE_API_URL
        export VITE_API_URL
    fi

    echo ""
    echo "Building frontend with VITE_API_URL=$VITE_API_URL..."
    pnpm build

    echo ""
    echo "Deploying frontend to Cloudflare Pages..."

    # Check if pages project exists
    PROJECT_NAME="landingchat"

    if wrangler pages project list 2>/dev/null | grep -q "$PROJECT_NAME"; then
        echo "Deploying to existing project: $PROJECT_NAME"
        wrangler pages deploy dist --project-name="$PROJECT_NAME"
    else
        echo "Creating new Pages project: $PROJECT_NAME"
        wrangler pages deploy dist --project-name="$PROJECT_NAME"
    fi

    echo ""
    echo -e "${GREEN}✓ Frontend deployed successfully!${NC}"

    cd ../..
fi

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║                Deployment Complete! 🎉                       ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DEPLOY_WORKER" = true ]; then
    echo -e "${CYAN}Backend Worker:${NC}"
    if [ -n "$WORKER_URL" ]; then
        echo "  URL: $WORKER_URL"
        echo "  Health: $WORKER_URL/health"
    fi
    echo "  View logs: cd packages/worker && wrangler tail"
    echo ""
fi

if [ "$DEPLOY_FRONTEND" = true ]; then
    echo -e "${CYAN}Frontend:${NC}"
    echo "  Check Cloudflare Pages dashboard for URL"
    echo "  Or run: wrangler pages deployment list --project-name=landingchat"
    echo ""
fi

echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Test your deployment"
echo "  2. Set up custom domains (optional)"
echo "  3. Configure production environment variables in Cloudflare dashboard"
echo "  4. Monitor logs and metrics"
echo ""

echo -e "${YELLOW}Documentation:${NC}"
echo "  - Backend Deployment: docs/setup/02-backend-deployment.md"
echo "  - Frontend Deployment: docs/setup/03-frontend-deployment.md"
echo ""

echo -e "${GREEN}Your LandingChat is now live! 🚀${NC}"
echo ""

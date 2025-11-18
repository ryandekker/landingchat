#!/bin/bash

# LandingChat Master Setup Script
# Orchestrates the complete setup process

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                      LandingChat Setup                       ║
║                                                              ║
║          Conversational Intake with LLM Orchestration        ║
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

# Make scripts executable
chmod +x scripts/*.sh

echo -e "${BLUE}This script will guide you through setting up LandingChat.${NC}"
echo ""
echo "The setup process includes:"
echo "  1. Installing dependencies"
echo "  2. Setting up AWS infrastructure (DynamoDB, OpenSearch, IAM)"
echo "  3. Seeding OpenSearch with sample apps"
echo "  4. Configuring environment variables"
echo "  5. Running initial tests"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Step 1: Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"
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

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    MISSING_DEPS+=("AWS CLI")
else
    echo -e "${GREEN}✓ AWS CLI $(aws --version | cut -d' ' -f1 | cut -d'/' -f2)${NC}"
fi

# Check jq
if ! command -v jq &> /dev/null; then
    MISSING_DEPS+=("jq")
else
    echo -e "${GREEN}✓ jq$(NC}"
fi

# Check curl
if ! command -v curl &> /dev/null; then
    MISSING_DEPS+=("curl")
else
    echo -e "${GREEN}✓ curl${NC}"
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

# Step 2: Install project dependencies
echo -e "${YELLOW}Step 2: Installing project dependencies...${NC}"
echo ""

if [ -d "node_modules" ]; then
    echo -e "${YELLOW}⚠ node_modules already exists${NC}"
    read -p "Do you want to clean install? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleaning..."
        pnpm clean || true
        rm -rf node_modules pnpm-lock.yaml
    fi
fi

echo "Installing dependencies (this may take a few minutes)..."
pnpm install

echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Step 3: AWS Infrastructure
echo -e "${YELLOW}Step 3: AWS Infrastructure Setup${NC}"
echo ""
echo "This will create:"
echo "  - DynamoDB tables (Sessions, Messages)"
echo "  - IAM user and policy"
echo "  - OpenSearch domain (optional, costs ~\$35/month)"
echo ""
read -p "Do you want to set up AWS infrastructure now? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/setup-infrastructure.sh
    echo ""
    echo -e "${GREEN}✓ AWS infrastructure setup complete${NC}"
    echo ""

    # Wait for OpenSearch
    if [ -f "./opensearch-credentials.txt" ]; then
        echo -e "${YELLOW}OpenSearch domain is being created...${NC}"
        echo "This takes 15-20 minutes. You can:"
        echo "  a) Wait now and continue with seeding"
        echo "  b) Continue setup and come back to seed later"
        echo ""
        read -p "Wait for OpenSearch to be ready? (y/n) " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            OPENSEARCH_DOMAIN="${OPENSEARCH_DOMAIN:-landingchat-apps}"
            AWS_REGION="${AWS_REGION:-us-east-1}"

            echo "Waiting for OpenSearch domain to be active..."
            echo "(This may take 15-20 minutes)"

            while true; do
                STATUS=$(aws opensearch describe-domain --domain-name "$OPENSEARCH_DOMAIN" --region "$AWS_REGION" --query 'DomainStatus.Processing' --output text 2>/dev/null || echo "true")

                if [ "$STATUS" == "false" ]; then
                    echo -e "${GREEN}✓ OpenSearch domain is ready!${NC}"
                    break
                fi

                echo "Still creating... (checking again in 60 seconds)"
                sleep 60
            done
        else
            echo -e "${YELLOW}Skipping OpenSearch seeding for now.${NC}"
            echo "Run ./scripts/seed-opensearch.sh when the domain is ready."
            SKIP_SEED=true
        fi
    fi
else
    echo -e "${YELLOW}Skipping AWS infrastructure setup.${NC}"
    echo "You can run ./scripts/setup-infrastructure.sh later."
    SKIP_SEED=true
fi

echo ""

# Step 4: Seed OpenSearch
if [ "$SKIP_SEED" != "true" ]; then
    echo -e "${YELLOW}Step 4: Seeding OpenSearch with sample apps...${NC}"
    echo ""
    read -p "Do you want to seed OpenSearch with sample apps now? (y/n) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./scripts/seed-opensearch.sh
        echo -e "${GREEN}✓ OpenSearch seeded${NC}"
    else
        echo -e "${YELLOW}Skipping OpenSearch seeding.${NC}"
        echo "Run ./scripts/seed-opensearch.sh later."
    fi
else
    echo -e "${YELLOW}Step 4: Skipping OpenSearch seeding (not ready yet)${NC}"
fi

echo ""

# Step 5: Configure environment variables
echo -e "${YELLOW}Step 5: Configuring environment variables...${NC}"
echo ""

if [ -f "packages/worker/.dev.vars" ] && [ -f "packages/frontend/.env" ]; then
    echo -e "${YELLOW}⚠ Environment files already exist${NC}"
    read -p "Do you want to reconfigure? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./scripts/configure-env.sh
    else
        echo "Keeping existing configuration."
    fi
else
    ./scripts/configure-env.sh
fi

echo -e "${GREEN}✓ Environment configured${NC}"
echo ""

# Step 6: Build packages
echo -e "${YELLOW}Step 6: Building packages...${NC}"
echo ""

echo "Building shared packages..."
pnpm build

echo -e "${GREEN}✓ Packages built${NC}"
echo ""

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║                   Setup Complete! 🎉                         ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}What's been set up:${NC}"
if [ -f "./aws-credentials-landingchat-worker.txt" ]; then
    echo "  ✓ AWS Infrastructure (DynamoDB, IAM)"
fi
if [ -f "./opensearch-credentials.txt" ]; then
    echo "  ✓ OpenSearch Domain"
fi
if [ -f "packages/worker/.dev.vars" ]; then
    echo "  ✓ Worker environment variables"
fi
if [ -f "packages/frontend/.env" ]; then
    echo "  ✓ Frontend environment variables"
fi
echo "  ✓ Project dependencies"
echo "  ✓ Package builds"
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo -e "${YELLOW}To start development:${NC}"
echo ""
echo "  # Terminal 1 - Start backend"
echo "  cd packages/worker"
echo "  pnpm dev"
echo ""
echo "  # Terminal 2 - Start frontend"
echo "  cd packages/frontend"
echo "  pnpm dev"
echo ""
echo "  # Open browser to http://localhost:5173"
echo ""

echo -e "${YELLOW}To deploy to production:${NC}"
echo ""
echo "  See: docs/setup/02-backend-deployment.md"
echo "  See: docs/setup/03-frontend-deployment.md"
echo ""

if [ -f "./aws-credentials-landingchat-worker.txt" ]; then
    echo -e "${RED}⚠ IMPORTANT: Secure your credentials!${NC}"
    echo "  - AWS credentials: ./aws-credentials-landingchat-worker.txt"
    if [ -f "./opensearch-credentials.txt" ]; then
        echo "  - OpenSearch credentials: ./opensearch-credentials.txt"
    fi
    echo "  - Store these files securely and delete them from the repo"
    echo ""
fi

echo -e "${CYAN}Documentation:${NC}"
echo "  - Getting Started: docs/setup/04-getting-started.md"
echo "  - Architecture: docs/architecture.md"
echo "  - README: README.md"
echo ""

echo -e "${GREEN}Happy building! 🚀${NC}"
echo ""

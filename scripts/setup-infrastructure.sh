#!/bin/bash

# LandingChat Infrastructure Setup Script
# This script automates the creation of AWS infrastructure for LandingChat

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
SESSIONS_TABLE_NAME="${SESSIONS_TABLE_NAME:-landingchat-sessions}"
MESSAGES_TABLE_NAME="${MESSAGES_TABLE_NAME:-landingchat-messages}"
OPENSEARCH_DOMAIN="${OPENSEARCH_DOMAIN:-landingchat-apps}"
OPENSEARCH_INDEX="${OPENSEARCH_INDEX:-apps_catalog}"
IAM_USER_NAME="${IAM_USER_NAME:-landingchat-worker}"
IAM_POLICY_NAME="${IAM_POLICY_NAME:-LandingChatWorkerPolicy}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  LandingChat Infrastructure Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Please install jq: https://stedolan.github.io/jq/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Please run: aws configure"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS credentials configured (Account: $AWS_ACCOUNT_ID)${NC}"
echo ""

# Display configuration
echo -e "${BLUE}Configuration:${NC}"
echo "  AWS Region: $AWS_REGION"
echo "  Sessions Table: $SESSIONS_TABLE_NAME"
echo "  Messages Table: $MESSAGES_TABLE_NAME"
echo "  OpenSearch Domain: $OPENSEARCH_DOMAIN"
echo "  OpenSearch Index: $OPENSEARCH_INDEX"
echo "  IAM User: $IAM_USER_NAME"
echo ""

read -p "Continue with this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Step 1: Create DynamoDB Tables
echo ""
echo -e "${YELLOW}Step 1: Creating DynamoDB tables...${NC}"

# Create Sessions table
if aws dynamodb describe-table --table-name "$SESSIONS_TABLE_NAME" --region "$AWS_REGION" &> /dev/null; then
    echo -e "${GREEN}✓ Sessions table already exists${NC}"
else
    echo "Creating sessions table..."
    aws dynamodb create-table \
        --table-name "$SESSIONS_TABLE_NAME" \
        --attribute-definitions AttributeName=sessionId,AttributeType=S \
        --key-schema AttributeName=sessionId,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" > /dev/null

    echo "Waiting for sessions table to be active..."
    aws dynamodb wait table-exists --table-name "$SESSIONS_TABLE_NAME" --region "$AWS_REGION"
    echo -e "${GREEN}✓ Sessions table created${NC}"
fi

# Create Messages table
if aws dynamodb describe-table --table-name "$MESSAGES_TABLE_NAME" --region "$AWS_REGION" &> /dev/null; then
    echo -e "${GREEN}✓ Messages table already exists${NC}"
else
    echo "Creating messages table..."
    aws dynamodb create-table \
        --table-name "$MESSAGES_TABLE_NAME" \
        --attribute-definitions \
            AttributeName=sessionId,AttributeType=S \
            AttributeName=sortKey,AttributeType=S \
        --key-schema \
            AttributeName=sessionId,KeyType=HASH \
            AttributeName=sortKey,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" > /dev/null

    echo "Waiting for messages table to be active..."
    aws dynamodb wait table-exists --table-name "$MESSAGES_TABLE_NAME" --region "$AWS_REGION"
    echo -e "${GREEN}✓ Messages table created${NC}"
fi

# Step 2: Create IAM Policy and User
echo ""
echo -e "${YELLOW}Step 2: Creating IAM user and policy...${NC}"

# Create policy
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"

if aws iam get-policy --policy-arn "$POLICY_ARN" &> /dev/null; then
    echo -e "${GREEN}✓ IAM policy already exists${NC}"
else
    echo "Creating IAM policy..."

    POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${SESSIONS_TABLE_NAME}",
        "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${MESSAGES_TABLE_NAME}"
      ]
    }
  ]
}
EOF
    )

    aws iam create-policy \
        --policy-name "$IAM_POLICY_NAME" \
        --policy-document "$POLICY_DOCUMENT" > /dev/null

    echo -e "${GREEN}✓ IAM policy created${NC}"
fi

# Create user
if aws iam get-user --user-name "$IAM_USER_NAME" &> /dev/null; then
    echo -e "${GREEN}✓ IAM user already exists${NC}"
else
    echo "Creating IAM user..."
    aws iam create-user --user-name "$IAM_USER_NAME" > /dev/null
    echo -e "${GREEN}✓ IAM user created${NC}"
fi

# Attach policy to user
echo "Attaching policy to user..."
aws iam attach-user-policy \
    --user-name "$IAM_USER_NAME" \
    --policy-arn "$POLICY_ARN" 2>/dev/null || echo -e "${GREEN}✓ Policy already attached${NC}"

# Create access key (only if doesn't exist)
ACCESS_KEY_FILE="./aws-credentials-${IAM_USER_NAME}.txt"

if [ -f "$ACCESS_KEY_FILE" ]; then
    echo -e "${YELLOW}⚠ Access key file already exists: $ACCESS_KEY_FILE${NC}"
    echo "Using existing credentials. Delete this file to generate new ones."
else
    # Check if user already has access keys
    EXISTING_KEYS=$(aws iam list-access-keys --user-name "$IAM_USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)

    if [ -z "$EXISTING_KEYS" ]; then
        echo "Creating access key..."
        ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$IAM_USER_NAME")

        ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
        SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')

        # Save credentials
        cat > "$ACCESS_KEY_FILE" <<EOF
AWS Access Credentials for $IAM_USER_NAME
========================================
Access Key ID: $ACCESS_KEY_ID
Secret Access Key: $SECRET_ACCESS_KEY

IMPORTANT: Store these credentials securely!
These will be needed for the worker configuration.
EOF

        echo -e "${GREEN}✓ Access key created and saved to $ACCESS_KEY_FILE${NC}"
        echo -e "${RED}⚠ IMPORTANT: Save these credentials securely!${NC}"
    else
        echo -e "${YELLOW}⚠ User already has access keys. Skipping access key creation.${NC}"
        echo "If you need new credentials, delete existing keys first."
    fi
fi

# Step 3: Create OpenSearch Domain (optional - this takes 15+ minutes)
echo ""
echo -e "${YELLOW}Step 3: OpenSearch Domain Setup${NC}"
echo -e "${YELLOW}⚠ Note: Creating an OpenSearch domain takes 15-20 minutes and costs ~\$35/month${NC}"
echo ""
read -p "Do you want to create an OpenSearch domain now? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if aws opensearch describe-domain --domain-name "$OPENSEARCH_DOMAIN" --region "$AWS_REGION" &> /dev/null; then
        echo -e "${GREEN}✓ OpenSearch domain already exists${NC}"
        OPENSEARCH_ENDPOINT=$(aws opensearch describe-domain --domain-name "$OPENSEARCH_DOMAIN" --region "$AWS_REGION" --query 'DomainStatus.Endpoint' --output text)
        echo "Endpoint: https://$OPENSEARCH_ENDPOINT"
    else
        echo "Creating OpenSearch domain (this will take 15-20 minutes)..."

        # Prompt for master password
        echo ""
        echo "Enter a master password for OpenSearch (min 8 chars, must include uppercase, lowercase, number, special char):"
        read -s OPENSEARCH_PASSWORD
        echo ""

        aws opensearch create-domain \
            --domain-name "$OPENSEARCH_DOMAIN" \
            --engine-version "OpenSearch_2.11" \
            --cluster-config \
                InstanceType=t3.small.search,InstanceCount=1 \
            --ebs-options \
                EBSEnabled=true,VolumeType=gp3,VolumeSize=10 \
            --advanced-security-options \
                Enabled=true,InternalUserDatabaseEnabled=true,MasterUserOptions="{MasterUserName=admin,MasterUserPassword=$OPENSEARCH_PASSWORD}" \
            --node-to-node-encryption-options Enabled=true \
            --encryption-at-rest-options Enabled=true \
            --domain-endpoint-options EnforceHTTPS=true \
            --region "$AWS_REGION" > /dev/null

        echo "Waiting for OpenSearch domain to be created (this may take 15-20 minutes)..."
        echo "You can check status with: aws opensearch describe-domain --domain-name $OPENSEARCH_DOMAIN --region $AWS_REGION"
        echo ""
        echo -e "${YELLOW}The script will continue, but you'll need to wait for OpenSearch to be ready before seeding data.${NC}"

        # Save password
        cat > "./opensearch-credentials.txt" <<EOF
OpenSearch Credentials
======================
Domain: $OPENSEARCH_DOMAIN
Username: admin
Password: $OPENSEARCH_PASSWORD

IMPORTANT: Store these credentials securely!
EOF
        echo -e "${GREEN}✓ OpenSearch domain creation initiated${NC}"
        echo -e "${GREEN}✓ Credentials saved to ./opensearch-credentials.txt${NC}"
    fi
else
    echo -e "${YELLOW}Skipping OpenSearch domain creation.${NC}"
    echo "You can create it manually later using the AWS Console or CLI."
    echo "See docs/setup/01-infrastructure.md for instructions."
fi

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Resources created:"
echo "  ✓ DynamoDB table: $SESSIONS_TABLE_NAME"
echo "  ✓ DynamoDB table: $MESSAGES_TABLE_NAME"
echo "  ✓ IAM user: $IAM_USER_NAME"
echo "  ✓ IAM policy: $IAM_POLICY_NAME"

if [ -f "$ACCESS_KEY_FILE" ]; then
    echo ""
    echo -e "${RED}IMPORTANT: AWS credentials saved to: $ACCESS_KEY_FILE${NC}"
    echo -e "${RED}Store these credentials securely!${NC}"
fi

if [ -f "./opensearch-credentials.txt" ]; then
    echo ""
    echo -e "${RED}IMPORTANT: OpenSearch credentials saved to: ./opensearch-credentials.txt${NC}"
    echo -e "${RED}Store these credentials securely!${NC}"
fi

echo ""
echo "Next steps:"
echo "  1. Wait for OpenSearch domain to be ready (if created)"
echo "  2. Run: ./scripts/seed-opensearch.sh (to add sample apps)"
echo "  3. Run: ./scripts/configure-env.sh (to set up environment variables)"
echo "  4. Follow docs/setup/04-getting-started.md for local development"
echo ""

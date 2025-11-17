# Infrastructure Setup Guide

This guide walks you through setting up the required infrastructure for LandingChat.

## Prerequisites

- AWS Account with appropriate permissions
- Cloudflare Account
- Node.js 18+ and pnpm installed
- AWS CLI configured
- Basic knowledge of DynamoDB and OpenSearch

## Components Overview

LandingChat requires the following infrastructure:

1. **DynamoDB Tables** - For storing user profiles and chat messages
2. **OpenSearch Service** - For searching the apps catalog
3. **Cloudflare Worker** - For the backend API
4. **Cloudflare Pages** - For the frontend

---

## Step 1: Set Up DynamoDB Tables

### 1.1 Create Sessions Table

This table stores user profiles and conversation state.

```bash
aws dynamodb create-table \
  --table-name landingchat-sessions \
  --attribute-definitions \
    AttributeName=sessionId,AttributeType=S \
  --key-schema \
    AttributeName=sessionId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Table Schema:**
- **Primary Key:** `sessionId` (String)
- **Attributes:**
  - `sessionId`: Session identifier (UUID)
  - `profile`: User profile object (Map)
  - `createdAt`: ISO timestamp
  - `lastUpdated`: ISO timestamp

### 1.2 Create Messages Table

This table stores all chat messages.

```bash
aws dynamodb create-table \
  --table-name landingchat-messages \
  --attribute-definitions \
    AttributeName=sessionId,AttributeType=S \
    AttributeName=sortKey,AttributeType=S \
  --key-schema \
    AttributeName=sessionId,KeyType=HASH \
    AttributeName=sortKey,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Table Schema:**
- **Primary Key:** `sessionId` (String)
- **Sort Key:** `sortKey` (String) - Format: `timestamp#messageId`
- **Attributes:**
  - `id`: Message ID
  - `role`: user | assistant | system
  - `content`: Message content
  - `timestamp`: ISO timestamp
  - `channel`: text (future: voice)
  - `metadata`: Additional data (Map)

### 1.3 Verify Tables

```bash
# Check sessions table
aws dynamodb describe-table --table-name landingchat-sessions --region us-east-1

# Check messages table
aws dynamodb describe-table --table-name landingchat-messages --region us-east-1
```

---

## Step 2: Set Up OpenSearch Service

### 2.1 Create OpenSearch Domain

You can create an OpenSearch domain via AWS Console or CLI. For development, a small instance is sufficient.

**Console Method:**
1. Go to AWS OpenSearch Service
2. Click "Create domain"
3. Choose "Development and testing" deployment type
4. Set domain name: `landingchat-apps`
5. Choose instance type: `t3.small.search`
6. Enable fine-grained access control
7. Set master user: `admin` with a strong password
8. Enable HTTPS
9. Create domain (takes 10-15 minutes)

**CLI Method:**

```bash
aws opensearch create-domain \
  --domain-name landingchat-apps \
  --engine-version OpenSearch_2.11 \
  --cluster-config InstanceType=t3.small.search,InstanceCount=1 \
  --ebs-options EBSEnabled=true,VolumeType=gp3,VolumeSize=10 \
  --access-policies '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "*"
        },
        "Action": "es:*",
        "Resource": "arn:aws:es:us-east-1:YOUR_ACCOUNT_ID:domain/landingchat-apps/*"
      }
    ]
  }' \
  --region us-east-1
```

### 2.2 Configure OpenSearch

Once the domain is ready, note the endpoint URL (e.g., `https://search-landingchat-apps-xxxxx.us-east-1.es.amazonaws.com`).

### 2.3 Create Apps Index

You'll create the index programmatically when seeding data (see next section), but you can also create it manually:

```bash
curl -XPUT "https://YOUR_OPENSEARCH_ENDPOINT/apps_catalog" \
  -u admin:YOUR_PASSWORD \
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
  }'
```

### 2.4 Seed Sample Apps

Create a file `sample-apps.json`:

```json
[
  {
    "id": "app_invoice_automation_01",
    "title": "Invoice Upload & Auto-Categorization",
    "description": "Upload invoices, extract line items, and automatically sync to your accounting software. Perfect for small agencies and professional services firms.",
    "use_case_tags": ["invoice_automation", "bookkeeping", "document_processing"],
    "industry_tags": ["agency", "professional_services", "accounting"],
    "persona_tags": ["owner", "ops_manager", "bookkeeper"],
    "complexity": "low",
    "time_to_value": "30_min",
    "cta_url": "https://example.com/apps/invoice-automation",
    "metadata": {
      "internal_priority": 0.9
    }
  },
  {
    "id": "app_crm_integration_01",
    "title": "CRM Integration Suite",
    "description": "Connect your CRM with 100+ tools. Sync contacts, deals, and activities automatically. Built for growing sales teams.",
    "use_case_tags": ["crm", "integration", "sales_automation"],
    "industry_tags": ["saas", "sales", "marketing"],
    "persona_tags": ["sales_manager", "sales_ops", "cto"],
    "complexity": "medium",
    "time_to_value": "1_hour",
    "cta_url": "https://example.com/apps/crm-integration",
    "metadata": {
      "internal_priority": 0.85
    }
  },
  {
    "id": "app_workflow_builder_01",
    "title": "No-Code Workflow Builder",
    "description": "Build custom workflows without code. Automate repetitive tasks across your business. Ideal for operations teams.",
    "use_case_tags": ["workflow", "automation", "no_code"],
    "industry_tags": ["any", "operations", "it"],
    "persona_tags": ["ops_manager", "business_analyst", "admin"],
    "complexity": "low",
    "time_to_value": "1_hour",
    "cta_url": "https://example.com/apps/workflow-builder",
    "metadata": {
      "internal_priority": 0.8
    }
  }
]
```

Bulk index the apps:

```bash
# Create a bulk import file
cat sample-apps.json | jq -c '.[]' | while read app; do
  echo '{"index":{"_index":"apps_catalog","_id":"'$(echo $app | jq -r '.id')'"}}';
  echo $app;
done > bulk-apps.ndjson

# Import
curl -XPOST "https://YOUR_OPENSEARCH_ENDPOINT/_bulk" \
  -u admin:YOUR_PASSWORD \
  -H 'Content-Type: application/x-ndjson' \
  --data-binary @bulk-apps.ndjson
```

---

## Step 3: Set Up Anthropic API

### 3.1 Get API Key

1. Sign up at https://console.anthropic.com/
2. Create an API key
3. Note the key (starts with `sk-ant-`)

### 3.2 Choose Models

The default configuration uses:
- **Base Model:** `claude-3-haiku-20240307` (fast, cost-effective)
- **Heavy Model:** `claude-3-sonnet-20240229` (for summarization)

You can adjust these in your environment configuration.

---

## Step 4: Create AWS IAM User for Worker

Create an IAM user with programmatic access for the Cloudflare Worker to access DynamoDB.

### 4.1 Create IAM Policy

Create a file `landingchat-policy.json`:

```json
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
        "arn:aws:dynamodb:us-east-1:YOUR_ACCOUNT_ID:table/landingchat-sessions",
        "arn:aws:dynamodb:us-east-1:YOUR_ACCOUNT_ID:table/landingchat-messages"
      ]
    }
  ]
}
```

Create the policy:

```bash
aws iam create-policy \
  --policy-name LandingChatWorkerPolicy \
  --policy-document file://landingchat-policy.json
```

### 4.2 Create IAM User

```bash
# Create user
aws iam create-user --user-name landingchat-worker

# Attach policy
aws iam attach-user-policy \
  --user-name landingchat-worker \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/LandingChatWorkerPolicy

# Create access key
aws iam create-access-key --user-name landingchat-worker
```

Save the `AccessKeyId` and `SecretAccessKey` from the output.

---

## Step 5: Verify Infrastructure

### 5.1 Checklist

- [ ] DynamoDB `landingchat-sessions` table created
- [ ] DynamoDB `landingchat-messages` table created
- [ ] OpenSearch domain `landingchat-apps` running
- [ ] OpenSearch `apps_catalog` index created and seeded
- [ ] Anthropic API key obtained
- [ ] IAM user `landingchat-worker` created with access keys

### 5.2 Test DynamoDB Access

```bash
# Test write to sessions table
aws dynamodb put-item \
  --table-name landingchat-sessions \
  --item '{
    "sessionId": {"S": "test-123"},
    "profile": {"M": {"test": {"S": "data"}}},
    "createdAt": {"S": "2024-01-01T00:00:00Z"},
    "lastUpdated": {"S": "2024-01-01T00:00:00Z"}
  }' \
  --region us-east-1

# Test read
aws dynamodb get-item \
  --table-name landingchat-sessions \
  --key '{"sessionId": {"S": "test-123"}}' \
  --region us-east-1

# Clean up test data
aws dynamodb delete-item \
  --table-name landingchat-sessions \
  --key '{"sessionId": {"S": "test-123"}}' \
  --region us-east-1
```

### 5.3 Test OpenSearch Access

```bash
# Check cluster health
curl -u admin:YOUR_PASSWORD "https://YOUR_OPENSEARCH_ENDPOINT/_cluster/health?pretty"

# Query apps
curl -u admin:YOUR_PASSWORD \
  "https://YOUR_OPENSEARCH_ENDPOINT/apps_catalog/_search?q=invoice&pretty"
```

---

## Cost Estimates

**Development Environment:**
- DynamoDB: ~$0 (Free tier covers development usage)
- OpenSearch t3.small: ~$35/month
- Cloudflare Worker: Free tier (100k requests/day)
- Cloudflare Pages: Free tier
- Anthropic API: Pay-per-use (~$0.25 per 1M input tokens for Haiku)

**Production Environment:**
- Scale OpenSearch to t3.medium or larger
- Consider Reserved Instances for OpenSearch
- Monitor and optimize token usage for LLM calls

---

## Next Steps

Once infrastructure is set up, proceed to:
- [Backend Deployment Guide](./02-backend-deployment.md)
- [Frontend Deployment Guide](./03-frontend-deployment.md)

## Troubleshooting

### DynamoDB Access Issues
- Verify IAM user has correct permissions
- Check AWS credentials are properly configured
- Ensure region matches your tables

### OpenSearch Connection Issues
- Verify domain is in "Active" state
- Check security group / access policies
- Test credentials with curl first

### Cost Management
- Set up AWS Budgets alerts
- Monitor OpenSearch domain metrics
- Review DynamoDB capacity settings

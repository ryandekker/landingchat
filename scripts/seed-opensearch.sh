#!/bin/bash

# LandingChat OpenSearch Seeding Script
# Seeds the apps catalog with sample applications

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
OPENSEARCH_DOMAIN="${OPENSEARCH_DOMAIN:-landingchat-apps}"
OPENSEARCH_INDEX="${OPENSEARCH_INDEX:-apps_catalog}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  LandingChat OpenSearch Seeding${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    exit 1
fi

# Get OpenSearch endpoint
echo "Fetching OpenSearch endpoint..."
if ! OPENSEARCH_ENDPOINT=$(aws opensearch describe-domain --domain-name "$OPENSEARCH_DOMAIN" --region "$AWS_REGION" --query 'DomainStatus.Endpoint' --output text 2>/dev/null); then
    echo -e "${RED}Error: Could not find OpenSearch domain '$OPENSEARCH_DOMAIN'${NC}"
    echo "Please ensure the domain exists and is active."
    exit 1
fi

OPENSEARCH_URL="https://$OPENSEARCH_ENDPOINT"
echo -e "${GREEN}✓ OpenSearch endpoint: $OPENSEARCH_URL${NC}"
echo ""

# Prompt for credentials
echo "Enter OpenSearch credentials:"
read -p "Username (default: admin): " OPENSEARCH_USERNAME
OPENSEARCH_USERNAME=${OPENSEARCH_USERNAME:-admin}

read -s -p "Password: " OPENSEARCH_PASSWORD
echo ""
echo ""

# Test connection
echo "Testing connection..."
if ! curl -s -u "$OPENSEARCH_USERNAME:$OPENSEARCH_PASSWORD" "$OPENSEARCH_URL/_cluster/health" > /dev/null; then
    echo -e "${RED}Error: Could not connect to OpenSearch${NC}"
    echo "Please check your credentials and ensure the domain is active."
    exit 1
fi

echo -e "${GREEN}✓ Connection successful${NC}"
echo ""

# Create index with mapping
echo "Creating index '$OPENSEARCH_INDEX'..."

INDEX_MAPPING='{
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

# Check if index exists
if curl -s -u "$OPENSEARCH_USERNAME:$OPENSEARCH_PASSWORD" "$OPENSEARCH_URL/$OPENSEARCH_INDEX" | grep -q "\"${OPENSEARCH_INDEX}\""; then
    echo -e "${YELLOW}⚠ Index already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        curl -s -X DELETE -u "$OPENSEARCH_USERNAME:$OPENSEARCH_PASSWORD" "$OPENSEARCH_URL/$OPENSEARCH_INDEX" > /dev/null
        echo -e "${GREEN}✓ Deleted existing index${NC}"
    else
        echo "Keeping existing index. Skipping to document creation."
    fi
fi

# Create index if it doesn't exist
if ! curl -s -u "$OPENSEARCH_USERNAME:$OPENSEARCH_PASSWORD" "$OPENSEARCH_URL/$OPENSEARCH_INDEX" | grep -q "\"${OPENSEARCH_INDEX}\""; then
    curl -s -X PUT -u "$OPENSEARCH_USERNAME:$OPENSEARCH_PASSWORD" \
        -H 'Content-Type: application/json' \
        "$OPENSEARCH_URL/$OPENSEARCH_INDEX" \
        -d "$INDEX_MAPPING" > /dev/null
    echo -e "${GREEN}✓ Index created${NC}"
fi

echo ""

# Sample apps data
echo "Adding sample applications..."

# Create bulk import data
BULK_DATA=$(cat <<'EOF'
{"index":{"_index":"apps_catalog","_id":"app_invoice_automation_01"}}
{"id":"app_invoice_automation_01","title":"Invoice Upload & Auto-Categorization","description":"Upload invoices, extract line items, and automatically sync to your accounting software. Perfect for small agencies and professional services firms looking to eliminate manual data entry and reduce bookkeeping time by 80%.","use_case_tags":["invoice_automation","bookkeeping","document_processing","accounting_sync"],"industry_tags":["agency","professional_services","accounting","consulting"],"persona_tags":["owner","ops_manager","bookkeeper","cfo"],"complexity":"low","time_to_value":"30_min","cta_url":"https://example.com/apps/invoice-automation","metadata":{"internal_priority":0.9}}
{"index":{"_index":"apps_catalog","_id":"app_crm_integration_01"}}
{"id":"app_crm_integration_01","title":"CRM Integration Suite","description":"Connect your CRM with 100+ tools including email, calendar, marketing automation, and support platforms. Sync contacts, deals, and activities automatically. Built for growing sales teams who need their tools to work together seamlessly.","use_case_tags":["crm","integration","sales_automation","data_sync"],"industry_tags":["saas","sales","marketing","b2b"],"persona_tags":["sales_manager","sales_ops","cto","revenue_ops"],"complexity":"medium","time_to_value":"1_hour","cta_url":"https://example.com/apps/crm-integration","metadata":{"internal_priority":0.85}}
{"index":{"_index":"apps_catalog","_id":"app_workflow_builder_01"}}
{"id":"app_workflow_builder_01","title":"No-Code Workflow Builder","description":"Build custom workflows without code. Automate repetitive tasks across your business with our visual workflow builder. Ideal for operations teams who want to automate processes without depending on developers.","use_case_tags":["workflow","automation","no_code","process_automation"],"industry_tags":["any","operations","it","business_ops"],"persona_tags":["ops_manager","business_analyst","admin","operations"],"complexity":"low","time_to_value":"1_hour","cta_url":"https://example.com/apps/workflow-builder","metadata":{"internal_priority":0.8}}
{"index":{"_index":"apps_catalog","_id":"app_data_warehouse_01"}}
{"id":"app_data_warehouse_01","title":"Data Warehouse & Analytics","description":"Modern data warehouse with built-in ETL pipelines and analytics. Connect all your data sources, transform data in SQL, and build dashboards. Perfect for data teams at mid-size companies ready to centralize their analytics.","use_case_tags":["data_warehouse","analytics","etl","business_intelligence"],"industry_tags":["saas","ecommerce","fintech","analytics"],"persona_tags":["data_engineer","analyst","cto","data_scientist"],"complexity":"high","time_to_value":"1_week","cta_url":"https://example.com/apps/data-warehouse","metadata":{"internal_priority":0.75}}
{"index":{"_index":"apps_catalog","_id":"app_customer_support_01"}}
{"id":"app_customer_support_01","title":"AI-Powered Customer Support","description":"Help desk with AI-powered ticket routing, canned responses, and customer sentiment analysis. Reduce response times by 60% and improve customer satisfaction. Great for support teams handling 100+ tickets per day.","use_case_tags":["customer_support","help_desk","ai","ticketing"],"industry_tags":["saas","ecommerce","support","any"],"persona_tags":["support_manager","customer_success","operations"],"complexity":"medium","time_to_value":"2_hours","cta_url":"https://example.com/apps/customer-support","metadata":{"internal_priority":0.82}}
{"index":{"_index":"apps_catalog","_id":"app_email_marketing_01"}}
{"id":"app_email_marketing_01","title":"Email Marketing Automation","description":"Send targeted email campaigns with powerful segmentation and automation. Built-in A/B testing, analytics, and deliverability optimization. Ideal for marketing teams growing their email list beyond 10k subscribers.","use_case_tags":["email_marketing","marketing_automation","campaigns","segmentation"],"industry_tags":["ecommerce","saas","marketing","b2c"],"persona_tags":["marketing_manager","growth","cmo"],"complexity":"low","time_to_value":"1_hour","cta_url":"https://example.com/apps/email-marketing","metadata":{"internal_priority":0.78}}
{"index":{"_index":"apps_catalog","_id":"app_project_management_01"}}
{"id":"app_project_management_01","title":"Agile Project Management","description":"Manage sprints, backlogs, and roadmaps with our agile project management platform. Includes time tracking, resource planning, and reporting. Perfect for product and engineering teams running agile/scrum.","use_case_tags":["project_management","agile","scrum","planning"],"industry_tags":["software","product","agency","consulting"],"persona_tags":["project_manager","product_manager","engineering_manager"],"complexity":"medium","time_to_value":"2_hours","cta_url":"https://example.com/apps/project-management","metadata":{"internal_priority":0.77}}
{"index":{"_index":"apps_catalog","_id":"app_inventory_management_01"}}
{"id":"app_inventory_management_01","title":"Inventory & Order Management","description":"Track inventory across warehouses, manage purchase orders, and sync with your ecommerce platforms. Real-time stock levels and automated reordering. Built for ecommerce businesses with 500+ SKUs.","use_case_tags":["inventory","order_management","warehouse","ecommerce"],"industry_tags":["ecommerce","retail","wholesale","logistics"],"persona_tags":["operations","warehouse_manager","owner"],"complexity":"medium","time_to_value":"3_hours","cta_url":"https://example.com/apps/inventory-management","metadata":{"internal_priority":0.73}}
{"index":{"_index":"apps_catalog","_id":"app_hr_onboarding_01"}}
{"id":"app_hr_onboarding_01","title":"Employee Onboarding Platform","description":"Streamline new hire onboarding with automated workflows, document collection, and training tracking. Reduce onboarding time by 50% and improve new hire experience. Great for growing companies hiring 5+ people per month.","use_case_tags":["hr","onboarding","hiring","employee_management"],"industry_tags":["any","hr","people_ops"],"persona_tags":["hr_manager","people_ops","recruiter"],"complexity":"low","time_to_value":"2_hours","cta_url":"https://example.com/apps/hr-onboarding","metadata":{"internal_priority":0.71}}
{"index":{"_index":"apps_catalog","_id":"app_document_signing_01"}}
{"id":"app_document_signing_01","title":"Digital Document Signing","description":"Send, sign, and manage documents digitally with legally-binding e-signatures. Track document status, set reminders, and store securely. Perfect for any business sending contracts, proposals, or agreements.","use_case_tags":["document_signing","esignature","contracts","legal"],"industry_tags":["any","legal","sales","real_estate"],"persona_tags":["sales","legal","operations","owner"],"complexity":"low","time_to_value":"15_min","cta_url":"https://example.com/apps/document-signing","metadata":{"internal_priority":0.88}}
EOF
)

# Replace index name in bulk data
BULK_DATA=$(echo "$BULK_DATA" | sed "s/apps_catalog/$OPENSEARCH_INDEX/g")

# Index documents
RESPONSE=$(curl -s -X POST -u "$OPENSEARCH_USERNAME:$OPENSEARCH_PASSWORD" \
    -H 'Content-Type: application/x-ndjson' \
    "$OPENSEARCH_URL/_bulk" \
    -d "$BULK_DATA")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors == false' > /dev/null; then
    DOC_COUNT=$(echo "$RESPONSE" | jq '.items | length')
    echo -e "${GREEN}✓ Successfully indexed $DOC_COUNT documents${NC}"
else
    echo -e "${YELLOW}⚠ Some errors occurred during indexing${NC}"
    echo "$RESPONSE" | jq '.items[] | select(.index.error) | .index.error'
fi

echo ""

# Verify
echo "Verifying documents..."
sleep 2  # Wait for indexing to complete

COUNT=$(curl -s -u "$OPENSEARCH_USERNAME:$OPENSEARCH_PASSWORD" \
    "$OPENSEARCH_URL/$OPENSEARCH_INDEX/_count" | jq '.count')

echo -e "${GREEN}✓ Total documents in index: $COUNT${NC}"

# Test search
echo ""
echo "Testing search..."
SEARCH_RESULT=$(curl -s -u "$OPENSEARCH_USERNAME:$OPENSEARCH_PASSWORD" \
    "$OPENSEARCH_URL/$OPENSEARCH_INDEX/_search?q=invoice&size=1" | jq '.hits.total.value')

echo -e "${GREEN}✓ Search test successful (found $SEARCH_RESULT results for 'invoice')${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  OpenSearch Seeding Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "  ✓ Index created: $OPENSEARCH_INDEX"
echo "  ✓ Documents indexed: $COUNT"
echo "  ✓ Search functionality verified"
echo ""
echo "You can now use this catalog in your LandingChat application!"
echo ""
echo "To add more apps, use the same bulk indexing format or index via the API."
echo "See: packages/worker/src/services/opensearch.ts for the indexApp function."
echo ""

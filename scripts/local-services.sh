#!/bin/bash

# LandingChat Local Services Management Script
# Quick commands to manage local Docker services

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

COMPOSE_FILE="docker-compose.local.yml"

case "$1" in
    start)
        echo -e "${BLUE}Starting local services...${NC}"
        docker-compose -f $COMPOSE_FILE up -d
        echo -e "${GREEN}✓ Services started${NC}"
        echo ""
        echo "DynamoDB: http://localhost:8000"
        echo "OpenSearch: https://localhost:9200"
        ;;

    stop)
        echo -e "${BLUE}Stopping local services...${NC}"
        docker-compose -f $COMPOSE_FILE down
        echo -e "${GREEN}✓ Services stopped${NC}"
        ;;

    restart)
        echo -e "${BLUE}Restarting local services...${NC}"
        docker-compose -f $COMPOSE_FILE restart
        echo -e "${GREEN}✓ Services restarted${NC}"
        ;;

    logs)
        docker-compose -f $COMPOSE_FILE logs -f
        ;;

    status)
        echo -e "${CYAN}Service Status:${NC}"
        echo ""
        docker-compose -f $COMPOSE_FILE ps
        echo ""

        # Check DynamoDB
        if curl -s http://localhost:8000 > /dev/null 2>&1; then
            echo -e "DynamoDB: ${GREEN}✓ Running${NC} - http://localhost:8000"
        else
            echo -e "DynamoDB: ${YELLOW}✗ Not running${NC}"
        fi

        # Check OpenSearch
        if curl -k -s -u admin:Admin123! https://localhost:9200/_cluster/health > /dev/null 2>&1; then
            echo -e "OpenSearch: ${GREEN}✓ Running${NC} - https://localhost:9200"
            HEALTH=$(curl -k -s -u admin:Admin123! https://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            echo -e "  Cluster Health: $HEALTH"
        else
            echo -e "OpenSearch: ${YELLOW}✗ Not running${NC}"
        fi
        ;;

    reset)
        echo -e "${YELLOW}⚠ This will delete all data in local services${NC}"
        read -p "Are you sure? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Resetting local services...${NC}"
            docker-compose -f $COMPOSE_FILE down -v
            docker-compose -f $COMPOSE_FILE up -d
            sleep 10
            echo -e "${GREEN}✓ Services reset${NC}"
            echo ""
            echo "You may need to recreate tables and seed data:"
            echo "  ./scripts/setup-local.sh"
        fi
        ;;

    tables)
        echo -e "${CYAN}DynamoDB Tables:${NC}"
        aws dynamodb list-tables \
            --endpoint-url http://localhost:8000 \
            --region us-east-1 \
            --output table
        ;;

    query)
        if [ -z "$2" ]; then
            echo "Usage: $0 query <table-name>"
            echo ""
            echo "Available tables:"
            aws dynamodb list-tables \
                --endpoint-url http://localhost:8000 \
                --region us-east-1 \
                --output text | grep "TABLENAMES" | awk '{print "  -", $2}'
            exit 1
        fi

        echo -e "${CYAN}Scanning table: $2${NC}"
        aws dynamodb scan \
            --table-name "$2" \
            --endpoint-url http://localhost:8000 \
            --region us-east-1 \
            --output json | jq .
        ;;

    search)
        if [ -z "$2" ]; then
            QUERY=""
        else
            QUERY="?q=$2"
        fi

        echo -e "${CYAN}Searching apps catalog:${NC}"
        curl -k -s -u admin:Admin123! \
            "https://localhost:9200/apps_catalog/_search${QUERY}&pretty" | jq .
        ;;

    *)
        echo -e "${CYAN}LandingChat Local Services Manager${NC}"
        echo ""
        echo "Usage: $0 {command}"
        echo ""
        echo "Commands:"
        echo "  start     - Start local services"
        echo "  stop      - Stop local services"
        echo "  restart   - Restart local services"
        echo "  status    - Show service status"
        echo "  logs      - View service logs (Ctrl+C to exit)"
        echo "  reset     - Reset services (deletes all data)"
        echo "  tables    - List DynamoDB tables"
        echo "  query     - Query a DynamoDB table"
        echo "  search    - Search OpenSearch apps catalog"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 status"
        echo "  $0 query landingchat-sessions-local"
        echo "  $0 search invoice"
        echo ""
        exit 1
        ;;
esac

#!/bin/bash
# SubForge Health Check Script
# Run this to verify deployment status

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

INSTALL_DIR="/opt/subforge"

# Source .env to get PORT if not passed as argument
if [ -z "$1" ] && [ -f "$INSTALL_DIR/.env" ]; then
    PORT=$(grep -E '^PORT=' "$INSTALL_DIR/.env" | cut -d'=' -f2 | tr -d '[:space:]')
fi
PORT=${1:-${PORT:-8080}}
BASE_URL="http://localhost:${PORT}"

echo -e "${CYAN}SubForge Health Check${NC}"
echo "========================"
echo ""

# Check if services are running
echo -e "${YELLOW}[1/5] Checking Docker containers...${NC}"
if docker compose ps | grep -q "Up"; then
    echo -e "  ${GREEN}✓ Containers are running${NC}"
else
    echo -e "  ${RED}✗ Containers are not running${NC}"
    exit 1
fi

# Check API health
echo -e "${YELLOW}[2/5] Checking API health...${NC}"
HEALTH=$(curl -s "${BASE_URL}/api/health" 2>/dev/null || echo '{"status":"error"}')
if echo "$HEALTH" | grep -q '"status":"ok"'; then
    echo -e "  ${GREEN}✓ API is healthy${NC}"
else
    echo -e "  ${RED}✗ API is not responding${NC}"
    exit 1
fi

# Check frontend
echo -e "${YELLOW}[3/5] Checking frontend...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "  ${GREEN}✓ Frontend is accessible${NC}"
else
    echo -e "  ${RED}✗ Frontend returned ${HTTP_CODE}${NC}"
fi

# Check database
echo -e "${YELLOW}[4/5] Checking database...${NC}"
DB_STATUS=$(docker compose exec -T postgres pg_isready -U subforge 2>/dev/null || echo "error")
if echo "$DB_STATUS" | grep -q "accepting connections"; then
    echo -e "  ${GREEN}✓ Database is ready${NC}"
else
    echo -e "  ${RED}✗ Database is not ready${NC}"
fi

# Check metrics
echo -e "${YELLOW}[5/5] Checking metrics...${NC}"
METRICS=$(curl -s "${BASE_URL}/api/metrics" 2>/dev/null || echo '{}')
if echo "$METRICS" | grep -q "uptime_seconds"; then
    UPTIME=$(echo "$METRICS" | grep -o '"uptime_seconds":[0-9]*' | cut -d: -f2)
    USERS=$(echo "$METRICS" | grep -o '"users":[0-9]*' | cut -d: -f2)
    SUBS=$(echo "$METRICS" | grep -o '"subscriptions":[0-9]*' | cut -d: -f2)
    NODES=$(echo "$METRICS" | grep -o '"nodes":[0-9]*' | cut -d: -f2)
    echo -e "  ${GREEN}✓ Metrics available${NC}"
    echo -e "    Uptime: ${UPTIME}s | Users: ${USERS} | Subs: ${SUBS} | Nodes: ${NODES}"
else
    echo -e "  ${YELLOW}⚠ Metrics not available${NC}"
fi

echo ""
echo -e "${GREEN}========================${NC}"
echo -e "${GREEN}Health check complete!${NC}"
echo ""
echo -e "URL: ${CYAN}${BASE_URL}${NC}"
echo ""

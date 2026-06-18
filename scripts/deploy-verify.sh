#!/bin/bash
# SubForge Deployment Verification Script
# Run this after deployment to verify everything works

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

INSTALL_DIR="/opt/subforge"

# Read port and admin password from .env
if [ -f "$INSTALL_DIR/.env" ]; then
    PORT=$(grep -E '^FRONTEND_PORT=' "$INSTALL_DIR/.env" | cut -d'=' -f2 | tr -d '[:space:]')
    ADMIN_PASSWORD=$(grep -E '^ADMIN_PASSWORD=' "$INSTALL_DIR/.env" | cut -d'=' -f2 | tr -d '[:space:]')
fi
PORT=${PORT:-3001}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin123}
BASE_URL="http://localhost:${PORT}"
PASS=0
FAIL=0

echo -e "${CYAN}SubForge Deployment Verification${NC}"
echo "=================================="
echo ""

check() {
    local name=$1
    local result=$2
    if [ "$result" = "ok" ]; then
        echo -e "  ${GREEN}✓ ${name}${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗ ${name}: ${result}${NC}"
        FAIL=$((FAIL + 1))
    fi
}

# Test 1: Health endpoint
echo -e "${YELLOW}[1/8] Health endpoint...${NC}"
HEALTH=$(curl -s "${BASE_URL}/api/health" 2>/dev/null || echo "error")
echo "$HEALTH" | grep -q '"status":"ok"' && check "Health endpoint" "ok" || check "Health endpoint" "$HEALTH"

# Test 2: Frontend
echo -e "${YELLOW}[2/8] Frontend...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/" 2>/dev/null || echo "000")
[ "$HTTP_CODE" = "200" ] && check "Frontend" "ok" || check "Frontend" "HTTP $HTTP_CODE"

# Test 3: Login
echo -e "${YELLOW}[3/8] Login...${NC}"
LOGIN=$(curl -s -X POST "${BASE_URL}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null || echo "error")
TOKEN=$(echo "$LOGIN" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
[ -n "$TOKEN" ] && check "Login" "ok" || check "Login" "no token received"

# Test 4: Protected endpoint
echo -e "${YELLOW}[4/8] Protected endpoint...${NC}"
ME=$(curl -s "${BASE_URL}/api/me" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "error")
echo "$ME" | grep -q '"username"' && check "Protected endpoint" "ok" || check "Protected endpoint" "$ME"

# Test 5: Create subscription
echo -e "${YELLOW}[5/8] Create subscription...${NC}"
SUB=$(curl -s -X POST "${BASE_URL}/api/subscriptions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"Test Sub","url":"https://example.com/subscribe","auto_refresh":3600}' 2>/dev/null || echo "error")
SUB_ID=$(echo "$SUB" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$SUB_ID" ] && check "Create subscription" "ok" || check "Create subscription" "no id returned"

# Test 6: List subscriptions
echo -e "${YELLOW}[6/8] List subscriptions...${NC}"
LIST=$(curl -s "${BASE_URL}/api/subscriptions?page=1&page_size=10" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "error")
echo "$LIST" | grep -q '"items"' && check "List subscriptions" "ok" || check "List subscriptions" "$LIST"

# Test 7: Metrics
echo -e "${YELLOW}[7/8] Metrics...${NC}"
METRICS=$(curl -s "${BASE_URL}/api/metrics" 2>/dev/null || echo "error")
echo "$METRICS" | grep -q '"uptime_seconds"' && check "Metrics" "ok" || check "Metrics" "$METRICS"

# Test 8: Formats
echo -e "${YELLOW}[8/8] Formats...${NC}"
FORMATS=$(curl -s "${BASE_URL}/api/formats" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "error")
echo "$FORMATS" | grep -q '"formats"' && check "Formats" "ok" || check "Formats" "$FORMATS"

# Cleanup test subscription
if [ -n "$SUB_ID" ]; then
    curl -s -X DELETE "${BASE_URL}/api/subscriptions/${SUB_ID}" \
        -H "Authorization: Bearer $TOKEN" > /dev/null 2>&1
fi

echo ""
echo -e "${GREEN}==================================${NC}"
echo -e "${GREEN}Verification complete!${NC}"
echo -e "  Passed: ${GREEN}${PASS}${NC}"
echo -e "  Failed: ${RED}${FAIL}${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Some checks failed. Review the output above.${NC}"
    exit 1
else
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
fi

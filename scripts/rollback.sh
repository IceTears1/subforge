#!/bin/bash
# SubForge Rollback Script
# Rollback to a previous version

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

INSTALL_DIR="/opt/subforge"

# Read port from .env or use default
if [ -f "$INSTALL_DIR/.env" ]; then
    PORT=$(grep -E '^FRONTEND_PORT=' "$INSTALL_DIR/.env" | cut -d'=' -f2- | tr -d '[:space:]')
fi
PORT=${PORT:-3001}

echo -e "${CYAN}SubForge Rollback${NC}"
echo "=================="
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo bash rollback.sh${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

# Show recent commits
echo -e "${YELLOW}Recent versions:${NC}"
git log --oneline -10
echo ""

# Get target version
if [ -n "$1" ]; then
    TARGET="$1"
else
    read -p "$(echo -e ${CYAN}Enter commit hash to rollback to: ${NC})" TARGET
fi

if [ -z "$TARGET" ]; then
    echo -e "${RED}No version specified${NC}"
    exit 1
fi

# Verify commit exists
if ! git cat-file -e "$TARGET" 2>/dev/null; then
    echo -e "${RED}Commit ${TARGET} not found${NC}"
    exit 1
fi

CURRENT=$(git rev-parse --short HEAD)
echo -e "Current: ${CYAN}${CURRENT}${NC}"
echo -e "Target:  ${CYAN}${TARGET}${NC}"
echo ""

read -p "$(echo -e ${YELLOW}Confirm rollback? [y/N]: ${NC})" CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled"
    exit 0
fi

# Backup current state
echo -e "${YELLOW}Creating backup of current state...${NC}"
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
git tag -f "backup-before-rollback" HEAD 2>/dev/null || true
echo -e "  Current commit: ${CYAN}${CURRENT_COMMIT}${NC}"

# Rollback
echo -e "${YELLOW}[1/3] Rolling back to ${TARGET}...${NC}"
git checkout -B main "$TARGET"

echo -e "${YELLOW}[2/3] Rebuilding...${NC}"
docker compose down --remove-orphans
docker compose up -d --build

echo -e "${YELLOW}[3/3] Verifying...${NC}"
sleep 5

HEALTH=$(curl -s "http://localhost:${PORT}/api/health" 2>/dev/null || echo '{"status":"error"}')
if echo "$HEALTH" | grep -q '"status":"ok"'; then
    echo -e "  ${GREEN}✓ Health check passed${NC}"
else
    echo -e "  ${RED}✗ Health check failed${NC}"
fi

echo ""
echo -e "${GREEN}Rollback complete!${NC}"
echo -e "  Version: ${CYAN}${TARGET}${NC}"
echo ""

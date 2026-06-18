#!/bin/bash
# SubForge Update Script
# Safe update with backup and rollback support

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

INSTALL_DIR="/opt/subforge"
BACKUP_DIR="/opt/subforge-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${CYAN}SubForge Update${NC}"
echo "================"
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo bash scripts/update.sh${NC}"
    exit 1
fi

# Check if installed
if [ ! -d "$INSTALL_DIR/.git" ]; then
    echo -e "${RED}SubForge not found at $INSTALL_DIR${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

# Read port from .env or use default
if [ -f .env ]; then
    PORT=$(grep -E '^FRONTEND_PORT=' .env | cut -d'=' -f2 | tr -d '[:space:]')
fi
PORT=${PORT:-3001}

# Get current version
CURRENT_COMMIT=$(git rev-parse --short HEAD)
echo -e "Current version: ${CYAN}${CURRENT_COMMIT}${NC}"

# Step 1: Backup .env and docker-compose overrides
echo -e "${YELLOW}[1/6] Creating backup...${NC}"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.tar.gz"
tar -czf "$BACKUP_FILE" \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='frontend/dist' \
    -C / opt/subforge 2>/dev/null || true
echo -e "  ${GREEN}Backup: ${BACKUP_FILE}${NC}"

# Step 2: Pull latest
echo -e "${YELLOW}[2/6] Pulling latest code...${NC}"
git fetch origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo -e "  ${GREEN}Already up to date!${NC}"
    exit 0
fi

OLD_COMMIT=$(git rev-parse --short HEAD)
git reset --hard origin/main
NEW_COMMIT=$(git rev-parse --short HEAD)
echo -e "  ${GREEN}Updated: ${OLD_COMMIT} → ${NEW_COMMIT}${NC}"

# Step 3: Show changes
echo -e "${YELLOW}[3/6] Changes:${NC}"
git log --oneline "${LOCAL}..${REMOTE}" | head -10
echo ""

# Step 4: Rebuild
echo -e "${YELLOW}[4/6] Rebuilding containers...${NC}"
docker compose build --no-cache 2>&1 | tail -5

# Step 5: Restart
echo -e "${YELLOW}[5/6] Restarting services...${NC}"
docker compose down --remove-orphans
docker compose up -d

# Step 6: Verify
echo -e "${YELLOW}[6/6] Verifying deployment...${NC}"
WAIT_COUNT=0
WAIT_MAX=30
HEALTH_OK=false
while [ $WAIT_COUNT -lt $WAIT_MAX ]; do
    HEALTH=$(curl -s "http://localhost:${PORT}/api/health" 2>/dev/null || echo '{"status":"error"}')
    if echo "$HEALTH" | grep -q '"status":"ok"'; then
        HEALTH_OK=true
        break
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ "$HEALTH_OK" = true ]; then
    echo -e "  ${GREEN}✓ Health check passed ($((WAIT_COUNT * 2))s)${NC}"
else
    echo -e "  ${RED}✗ Health check failed${NC}"
    echo -e "  ${YELLOW}Rolling back...${NC}"
    docker compose down --remove-orphans
    git checkout "$LOCAL"
    docker compose up -d
    echo -e "  ${GREEN}Rolled back to ${CURRENT_COMMIT}${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}================${NC}"
echo -e "${GREEN}Update complete!${NC}"
echo -e "  Version: ${CYAN}${NEW_COMMIT}${NC}"
echo -e "  Backup:  ${CYAN}${BACKUP_FILE}${NC}"
echo ""
echo -e "  ${YELLOW}Rollback command:${NC}"
echo -e "    cd $INSTALL_DIR && git checkout ${OLD_COMMIT} && docker compose up -d --build"
echo ""

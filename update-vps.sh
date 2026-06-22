#!/bin/bash

# ── Ensure we can read from the terminal even when piped ──
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

echo -e "${CYAN}SubForge VPS Update${NC}"
echo ""

read -p "$(echo -e "${CYAN}VPS IP: ${NC}")" VPS_IP
read -p "$(echo -e "${CYAN}SSH User [root]: ${NC}")" VPS_USER
VPS_USER=${VPS_USER:-root}
read -p "$(echo -e "${CYAN}SSH Port [22]: ${NC}")" VPS_PORT
VPS_PORT=${VPS_PORT:-22}

if [ -z "$VPS_IP" ]; then
    echo -e "${RED}VPS IP is required${NC}"
    exit 1
fi

SSH_OPTS="-p ${VPS_PORT} -o StrictHostKeyChecking=no -o ConnectTimeout=10"
INSTALL_DIR="/opt/subforge"

echo -e "${YELLOW}[1/4] Connecting to ${VPS_IP}...${NC}"
if ! ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP} "echo ok" &>/dev/null; then
    echo -e "${RED}SSH connection failed${NC}"
    exit 1
fi
echo -e "${GREEN}  Connected${NC}"

echo -e "${YELLOW}[2/4] Pulling latest code...${NC}"
ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP} "cd ${INSTALL_DIR} && git fetch origin main && git reset --hard origin/main"

echo -e "${YELLOW}[3/4] Rebuilding and restarting...${NC}"
ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP} "cd ${INSTALL_DIR} && APP_VERSION=\$(cat VERSION 2>/dev/null || echo unknown) && APP_COMMIT=\$(git rev-parse --short HEAD 2>/dev/null || echo unknown) && docker compose down --remove-orphans && VERSION=\$APP_VERSION COMMIT=\$APP_COMMIT docker compose up -d --build"

echo -e "${YELLOW}[4/4] Verifying...${NC}"
sleep 5

if ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP} "curl -sf http://localhost:3001/api/health" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Health check passed${NC}"
else
    echo -e "  ${YELLOW}⚠ Health check not passed yet, check logs:${NC}"
    echo -e "  ${DIM}ssh -p ${VPS_PORT} ${VPS_USER}@${VPS_IP} 'cd ${INSTALL_DIR} && docker compose logs'${NC}"
fi

echo ""
echo -e "${GREEN}Update complete!${NC}"
echo -e "URL: ${CYAN}http://${VPS_IP}:3001${NC}"

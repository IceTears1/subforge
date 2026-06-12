#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}SubForge VPS Update${NC}"
echo ""

read -p "$(echo -e ${CYAN}VPS IP: ${NC})" VPS_IP
read -p "$(echo -e ${CYAN}SSH User [root]: ${NC})" VPS_USER
VPS_USER=${VPS_USER:-root}
read -p "$(echo -e ${CYAN}SSH Port [22]: ${NC})" VPS_PORT
VPS_PORT=${VPS_PORT:-22}

SSH_OPTS="-p ${VPS_PORT} -o StrictHostKeyChecking=no"
INSTALL_DIR="/opt/subforge"

echo -e "${YELLOW}[1/3] Connecting to ${VPS_IP}...${NC}"

echo -e "${YELLOW}[2/3] Pulling latest code...${NC}"
ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP} "cd ${INSTALL_DIR} && git pull origin main"

echo -e "${YELLOW}[3/3] Rebuilding and restarting...${NC}"
ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP} "cd ${INSTALL_DIR} && docker compose down && docker compose up -d --build"

echo ""
echo -e "${GREEN}Update complete!${NC}"
echo -e "URL: ${CYAN}http://${VPS_IP}:$(ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP} "grep PORT ${INSTALL_DIR}/.env | cut -d'=' -f2")${NC}"

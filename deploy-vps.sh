#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  ____        _   _____                   "
echo " / ___| _   _| | |  ___|___  _ __ ___    "
echo " \___ \| | | | | | |_ / _ \| '__/ _ \   "
echo "  ___) | |_| | | |  _| (_) | | |  __/   "
echo " |____/ \__,_|_| |_|  \___/|_|  \___|   "
echo ""
echo "  VPS One-Click Deploy"
echo -e "${NC}"

# ─────────────────────────────────────
# Configuration
# ─────────────────────────────────────
REPO_URL="git@github.com:IceTears1/subforge.git"
INSTALL_DIR="/opt/subforge"
DEFAULT_PORT="8080"

# ─────────────────────────────────────
# Input
# ─────────────────────────────────────
read -p "$(echo -e ${CYAN}VPS IP Address: ${NC})" VPS_IP
read -p "$(echo -e ${CYAN}SSH User [root]: ${NC})" VPS_USER
VPS_USER=${VPS_USER:-root}
read -p "$(echo -e ${CYAN}SSH Port [22]: ${NC})" VPS_PORT
VPS_PORT=${VPS_PORT:-22}
read -p "$(echo -e ${CYAN}Service Port [${DEFAULT_PORT}]: ${NC})" SERVICE_PORT
SERVICE_PORT=${SERVICE_PORT:-$DEFAULT_PORT}
read -s -p "$(echo -e ${CYAN}SSH Password (press Enter if using key): ${NC})" VPS_PASS
echo ""

SSH_OPTS="-p ${VPS_PORT} -o StrictHostKeyChecking=no -o ConnectTimeout=10"
SSH_CMD="ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP}"

# If password provided, use sshpass
if [ -n "$VPS_PASS" ]; then
    if ! command -v sshpass &>/dev/null; then
        echo -e "${YELLOW}Installing sshpass...${NC}"
        brew install hudochenkov/sshpass/sshpass 2>/dev/null || brew install sshpass 2>/dev/null || true
    fi
    SSH_CMD="sshpass -p '${VPS_PASS}' ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP}"
fi

echo ""
echo -e "${YELLOW}[1/6] Testing SSH connection to ${VPS_IP}...${NC}"
if ! eval "${SSH_CMD} 'echo ok'" &>/dev/null; then
    echo -e "${RED}SSH connection failed. Please check:${NC}"
    echo -e "  - VPS IP: ${VPS_IP}"
    echo -e "  - SSH User: ${VPS_USER}"
    echo -e "  - SSH Port: ${VPS_PORT}"
    echo -e "  - SSH Key or Password"
    exit 1
fi
echo -e "${GREEN}  SSH connection OK${NC}"

# ─────────────────────────────────────
# Remote deploy script
# ─────────────────────────────────────
REMOTE_SCRIPT=$(cat <<'REMOTE_EOF'
#!/bin/bash
set -e

INSTALL_DIR="__INSTALL_DIR__"
REPO_URL="__REPO_URL__"
SERVICE_PORT="__SERVICE_PORT__"

echo "[2/6] Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
    echo "  Docker installed"
else
    echo "  Docker already installed: $(docker --version)"
fi

echo "[3/6] Installing Docker Compose..."
if ! docker compose version &>/dev/null; then
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    echo "  Docker Compose installed"
else
    echo "  Docker Compose already installed"
fi

echo "[4/6] Cloning repository..."
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git pull origin main
    echo "  Repository updated"
else
    rm -rf "$INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo "  Repository cloned"
fi

echo "[5/6] Configuring..."
cd "$INSTALL_DIR"

# Generate .env if not exists
if [ ! -f .env ]; then
    DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
    JWT_SECRET=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
    ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

    cat > .env <<EOF
PORT=${SERVICE_PORT}
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=${DB_PASSWORD}
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRY=24h
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF
    echo "  .env created"
    echo ""
    echo "  ========================================"
    echo "  Default credentials:"
    echo "    Username: admin"
    echo "    Password: ${ADMIN_PASSWORD}"
    echo "  ========================================"
else
    # Update port if changed
    sed -i "s/^PORT=.*/PORT=${SERVICE_PORT}/" .env
    ADMIN_PASSWORD=$(grep ADMIN_PASSWORD .env | cut -d'=' -f2)
    echo "  .env exists, port updated to ${SERVICE_PORT}"
fi

echo "[6/6] Starting services..."
docker compose down 2>/dev/null || true
docker compose up -d --build

# Wait for services
echo "  Waiting for services..."
sleep 10

# Check status
if docker compose ps | grep -q "Up"; then
    echo ""
    echo "  ========================================"
    echo "  SubForge deployed successfully!"
    echo "  ========================================"
    echo ""
    echo "  URL:      http://$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):${SERVICE_PORT}"
    echo "  Username: admin"
    echo "  Password: ${ADMIN_PASSWORD}"
    echo ""
else
    echo "  ERROR: Services failed to start"
    docker compose logs --tail=20
    exit 1
fi
REMOTE_EOF
)

# Replace placeholders
REMOTE_SCRIPT="${REMOTE_SCRIPT/__INSTALL_DIR__/$INSTALL_DIR}"
REMOTE_SCRIPT="${REMOTE_SCRIPT/__REPO_URL__/$REPO_URL}"
REMOTE_SCRIPT="${REMOTE_SCRIPT/__SERVICE_PORT__/$SERVICE_PORT}"

# ─────────────────────────────────────
# Execute remote deploy
# ─────────────────────────────────────
echo -e "${YELLOW}Deploying to ${VPS_IP}...${NC}"
echo ""

eval "${SSH_CMD} 'bash -s'" <<< "$REMOTE_SCRIPT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  VPS Deploy Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  URL:  ${CYAN}http://${VPS_IP}:${SERVICE_PORT}${NC}"
echo ""
echo -e "  ${YELLOW}Manage:${NC}"
echo -e "    SSH:    ${CYAN}ssh ${VPS_USER}@${VPS_IP}${NC}"
echo -e "    Logs:   ${CYAN}ssh ${VPS_USER}@${VPS_IP} 'cd ${INSTALL_DIR} && docker compose logs -f'${NC}"
echo -e "    Stop:   ${CYAN}ssh ${VPS_USER}@${VPS_IP} 'cd ${INSTALL_DIR} && docker compose down'${NC}"
echo -e "    Update: ${CYAN}ssh ${VPS_USER}@${VPS_IP} 'cd ${INSTALL_DIR} && git pull && docker compose up -d --build'${NC}"
echo ""

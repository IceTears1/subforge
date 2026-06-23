#!/bin/bash

# ── Ensure we can read from the terminal even when piped ──
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
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
REPO_URL="https://github.com/IceTears1/subforge.git"
INSTALL_DIR="/opt/subforge"
DEFAULT_PORT="3001"

# ─────────────────────────────────────
# Input
# ─────────────────────────────────────
read -p "$(echo -e "${CYAN}VPS IP Address: ${NC}")" VPS_IP
read -p "$(echo -e "${CYAN}SSH User [root]: ${NC}")" VPS_USER
VPS_USER=${VPS_USER:-root}
read -p "$(echo -e "${CYAN}SSH Port [22]: ${NC}")" VPS_PORT
VPS_PORT=${VPS_PORT:-22}
read -p "$(echo -e "${CYAN}Service Port [${DEFAULT_PORT}]: ${NC}")" SERVICE_PORT
SERVICE_PORT=${SERVICE_PORT:-$DEFAULT_PORT}
read -s -p "$(echo -e "${CYAN}SSH Password (press Enter if using key): ${NC}")" VPS_PASS
echo ""

if [ -z "$VPS_IP" ]; then
    echo -e "${RED}VPS IP is required${NC}"
    exit 1
fi

SSH_OPTS="-p ${VPS_PORT} -o ConnectTimeout=10 -o BatchMode=yes"
SSH_CMD="ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP}"

# If password provided, use sshpass
if [ -n "$VPS_PASS" ]; then
    if ! command -v sshpass &>/dev/null; then
        echo -e "${YELLOW}Installing sshpass...${NC}"
        if command -v brew &>/dev/null; then
            brew install hudochenkov/sshpass/sshpass 2>/dev/null || brew install sshpass 2>/dev/null || true
        elif command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y -qq sshpass
        elif command -v dnf &>/dev/null; then
            dnf install -y -q sshpass
        elif command -v yum &>/dev/null; then
            yum install -y -q sshpass
        elif command -v pacman &>/dev/null; then
            pacman -S --noconfirm sshpass
        fi
    fi

    if ! command -v sshpass &>/dev/null; then
        echo -e "${RED}sshpass not found. Install it or use SSH key authentication.${NC}"
        exit 1
    fi
    # Use SSHPASS env var to avoid exposing password in process list
    export SSHPASS="${VPS_PASS}"
    SSH_CMD="sshpass -e ssh ${SSH_OPTS} ${VPS_USER}@${VPS_IP}"
fi

echo ""
echo -e "${YELLOW}[1/6] Testing SSH connection to ${VPS_IP}...${NC}"
if ! ${SSH_CMD} 'echo ok' &>/dev/null; then
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
    # Try official install script
    if curl -fsSL https://get.docker.com | bash 2>/dev/null; then
        echo "  Docker installed via script"
    elif command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq docker.io
    elif command -v dnf &>/dev/null; then
        dnf install -y -q docker
    elif command -v yum &>/dev/null; then
        yum install -y -q docker
    elif command -v apk &>/dev/null; then
        apk add --no-cache docker
    fi
    if command -v systemctl &>/dev/null; then
        systemctl enable docker 2>/dev/null || true
        systemctl start docker 2>/dev/null || true
    fi
    echo "  Docker installed"
else
    echo "  Docker already installed: $(docker --version)"
fi

echo "[3/6] Installing Docker Compose..."
if ! docker compose version &>/dev/null; then
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL --connect-timeout 15 --retry 3 \
        "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    echo "  Docker Compose installed"
else
    echo "  Docker Compose already installed"
fi

echo "[4/6] Cloning repository..."
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git fetch origin main
    git reset --hard origin/main
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
FRONTEND_PORT=3001
BACKEND_PORT=3002
DB_PORT=45000
SSL_PORT=3003
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=${DB_PASSWORD}
DB_SSL_MODE=disable
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRY=24h
ADMIN_PASSWORD=${ADMIN_PASSWORD}
CORS_ORIGINS=
ADMIN_IP_WHITELIST=
GIN_MODE=release
EOF
    echo "  .env created"
    echo ""
    echo "  ========================================"
    echo "  Default credentials:"
    echo "    Username: admin"
    echo "    Password: ${ADMIN_PASSWORD}"
    echo "  ========================================"
else
    ADMIN_PASSWORD=$(grep ADMIN_PASSWORD .env | cut -d'=' -f2-)
    echo "  .env exists"
fi

echo "[6/6] Starting services..."
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d --build

# Wait for health
echo "  Waiting for services..."
WAIT_COUNT=0
WAIT_MAX=30
while [ $WAIT_COUNT -lt $WAIT_MAX ]; do
    if curl -sf "http://localhost:${SERVICE_PORT:-3001}/api/health" >/dev/null 2>&1; then
        break
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if curl -sf "http://localhost:${SERVICE_PORT:-3001}/api/health" >/dev/null 2>&1; then
    PUBLIC_IP=$(curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || \
                curl -s --connect-timeout 5 https://ipinfo.io/ip 2>/dev/null || \
                hostname -I | awk '{print $1}')
    echo ""
    echo "  ========================================"
    echo "  SubForge deployed successfully!"
    echo "  ========================================"
    echo ""
    echo "  URL:      http://${PUBLIC_IP}:${SERVICE_PORT:-3001}"
    echo "  Username: admin"
    echo "  Password: ${ADMIN_PASSWORD}"
    echo ""
else
    echo "  WARNING: Health check not passed yet. Check logs:"
    echo "  cd ${INSTALL_DIR} && docker compose logs"
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

${SSH_CMD} 'bash -s' <<< "$REMOTE_SCRIPT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  VPS Deploy Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  URL:  ${CYAN}http://${VPS_IP}:${SERVICE_PORT:-3001}${NC}"
echo ""
echo -e "  ${YELLOW}Manage:${NC}"
echo -e "    SSH:    ${CYAN}ssh -p ${VPS_PORT} ${VPS_USER}@${VPS_IP}${NC}"
echo -e "    Logs:   ${CYAN}ssh -p ${VPS_PORT} ${VPS_USER}@${VPS_IP} 'cd ${INSTALL_DIR} && docker compose logs -f'${NC}"
echo -e "    Stop:   ${CYAN}ssh -p ${VPS_PORT} ${VPS_USER}@${VPS_IP} 'cd ${INSTALL_DIR} && docker compose down'${NC}"
echo -e "    Update: ${CYAN}ssh -p ${VPS_PORT} ${VPS_USER}@${VPS_IP} 'cd ${INSTALL_DIR} && git fetch origin main && git reset --hard origin/main && docker compose up -d --build'${NC}"
echo ""

#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Config
REPO="git@github.com:IceTears1/subforge.git"
INSTALL_DIR="/opt/subforge"
DEFAULT_PORT="8080"

echo -e "${CYAN}${BOLD}"
cat << 'EOF'
  ____        _   _____
 / ___| _   _| | |  ___|___  _ __ ___
 \___ \| | | | | | |_ / _ \| '__/ _ \
  ___) | |_| | | |  _| (_) | | |  __/
 |____/ \__,_|_| |_|  \___/|_|  \___|
EOF
echo -e "${NC}"
echo -e "  ${BOLD}VPN Subscription Universal Converter${NC}"
echo -e "  One-Click Installer"
echo ""

# ─────────────────────────────────────
# Check root
# ─────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root${NC}"
    echo -e "  Usage: sudo bash install.sh"
    exit 1
fi

# ─────────────────────────────────────
# Input port
# ─────────────────────────────────────
read -p "$(echo -e ${CYAN}Service Port [${DEFAULT_PORT}]: ${NC})" SERVICE_PORT
SERVICE_PORT=${SERVICE_PORT:-$DEFAULT_PORT}

echo ""
echo -e "${YELLOW}[1/5] Installing Docker...${NC}"

if command -v docker &>/dev/null; then
    echo -e "  ${GREEN}Docker already installed: $(docker --version)${NC}"
else
    # Detect OS
    if [ -f /etc/debian_version ]; then
        apt-get update -qq
        apt-get install -y -qq ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    elif [ -f /etc/redhat-release ]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        curl -fsSL https://get.docker.com | bash
    fi

    systemctl enable docker
    systemctl start docker
    echo -e "  ${GREEN}Docker installed${NC}"
fi

# Check docker compose
echo -e "${YELLOW}[2/5] Checking Docker Compose...${NC}"
if docker compose version &>/dev/null; then
    echo -e "  ${GREEN}Docker Compose OK${NC}"
else
    echo -e "  ${YELLOW}Installing Docker Compose plugin...${NC}"
    mkdir -p /usr/local/lib/docker/cli-plugins
    ARCH=$(uname -m)
    [ "$ARCH" = "x86_64" ] && ARCH="x86_64"
    [ "$ARCH" = "aarch64" ] && ARCH="aarch64"
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    echo -e "  ${GREEN}Docker Compose installed${NC}"
fi

# ─────────────────────────────────────
# Clone repo
# ─────────────────────────────────────
echo -e "${YELLOW}[3/5] Downloading SubForge...${NC}"

if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git pull origin main 2>/dev/null || true
    echo -e "  ${GREEN}Updated to latest version${NC}"
else
    rm -rf "$INSTALL_DIR"
    # Try SSH first, fallback to HTTPS
    git clone "$REPO" "$INSTALL_DIR" 2>/dev/null || \
    git clone "https://github.com/IceTears1/subforge.git" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo -e "  ${GREEN}Downloaded to ${INSTALL_DIR}${NC}"
fi

# ─────────────────────────────────────
# Generate config
# ─────────────────────────────────────
echo -e "${YELLOW}[4/5] Configuring...${NC}"

gen_pass() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "$1"
}

if [ ! -f .env ]; then
    DB_PASSWORD=$(gen_pass 24)
    JWT_SECRET=$(gen_pass 32)
    ADMIN_PASSWORD=$(gen_pass 16)

    cat > .env <<EOF
PORT=${SERVICE_PORT}
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=${DB_PASSWORD}
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRY=24h
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF
    echo -e "  ${GREEN}Configuration generated${NC}"
else
    sed -i "s/^PORT=.*/PORT=${SERVICE_PORT}/" .env
    ADMIN_PASSWORD=$(grep ADMIN_PASSWORD .env | cut -d'=' -f2)
    echo -e "  ${GREEN}Configuration updated (port: ${SERVICE_PORT})${NC}"
fi

# ─────────────────────────────────────
# Firewall
# ─────────────────────────────────────
if command -v ufw &>/dev/null; then
    ufw allow "$SERVICE_PORT"/tcp 2>/dev/null || true
    echo -e "  ${GREEN}Firewall: port ${SERVICE_PORT} opened (ufw)${NC}"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port="$SERVICE_PORT"/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo -e "  ${GREEN}Firewall: port ${SERVICE_PORT} opened (firewalld)${NC}"
fi

# ─────────────────────────────────────
# Start services
# ─────────────────────────────────────
echo -e "${YELLOW}[5/5] Starting SubForge...${NC}"

docker compose down 2>/dev/null || true
docker compose up -d --build

# Wait for healthy
echo -e "  ${YELLOW}Waiting for services to be ready...${NC}"
RETRIES=0
MAX_RETRIES=30
while [ $RETRIES -lt $MAX_RETRIES ]; do
    if docker compose ps 2>/dev/null | grep -q "Up"; then
        break
    fi
    sleep 2
    RETRIES=$((RETRIES + 1))
done

# Get public IP
PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || \
            curl -s --connect-timeout 3 ip.sb 2>/dev/null || \
            hostname -I | awk '{print $1}')

# ─────────────────────────────────────
# Done
# ─────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}============================================${NC}"
echo -e "${GREEN}${BOLD}  ✅ SubForge installed successfully!${NC}"
echo -e "${GREEN}${BOLD}============================================${NC}"
echo ""
echo -e "  ${BOLD}URL:${NC}      ${CYAN}http://${PUBLIC_IP}:${SERVICE_PORT}${NC}"
echo -e "  ${BOLD}Username:${NC} ${CYAN}admin${NC}"
echo -e "  ${BOLD}Password:${NC} ${CYAN}${ADMIN_PASSWORD}${NC}"
echo ""
echo -e "  ${YELLOW}Commands:${NC}"
echo -e "    View logs:   ${CYAN}cd ${INSTALL_DIR} && docker compose logs -f${NC}"
echo -e "    Restart:     ${CYAN}cd ${INSTALL_DIR} && docker compose restart${NC}"
echo -e "    Stop:        ${CYAN}cd ${INSTALL_DIR} && docker compose down${NC}"
echo -e "    Update:      ${CYAN}cd ${INSTALL_DIR} && git pull && docker compose up -d --build${NC}"
echo -e "    Uninstall:   ${CYAN}cd ${INSTALL_DIR} && docker compose down -v && rm -rf ${INSTALL_DIR}${NC}"
echo ""
echo -e "  ${YELLOW}Config file: ${INSTALL_DIR}/.env${NC}"
echo ""

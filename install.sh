#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

REPO="https://github.com/IceTears1/subforge.git"
INSTALL_DIR="/opt/subforge"

echo -e "${CYAN}${BOLD}"
echo "  ____        _   _____                   "
echo " / ___| _   _| | |  ___|___  _ __ ___    "
echo " \___ \| | | | | | |_ / _ \| '__/ _ \   "
echo "  ___) | |_| | | |  _| (_) | | |  __/   "
echo " |____/ \__,_|_| |_|  \___/|_|  \___|   "
echo -e "${NC}"
echo -e "  ${BOLD}VPN Subscription Universal Converter${NC}"
echo -e "  ${DIM}One-Click Interactive Installer${NC}"
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root${NC}"
    exit 1
fi

gen_pass() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "$1"
}

# Always try to read from /dev/tty for interactive input
ask_input() {
    local prompt="$1"
    local default="$2"
    local result=""
    if [ -e /dev/tty ]; then
        read -p "$(echo -e ${CYAN}${prompt} [${default}]: ${NC})" result < /dev/tty
    fi
    echo "${result:-$default}"
}

ask_secret() {
    local prompt="$1"
    local result=""
    if [ -e /dev/tty ]; then
        read -s -p "$(echo -e ${CYAN}${prompt}: ${NC})" result < /dev/tty
        echo "" >&2
    fi
    echo "$result"
}

ask_yes_no() {
    local prompt="$1"
    local default="$2"
    local choice="$default"
    if [ -e /dev/tty ]; then
        read -p "$(echo -e ${CYAN}${prompt} [${default}]: ${NC})" choice < /dev/tty
        choice=${choice:-$default}
    fi
    [[ "$choice" =~ ^[Yy]$ ]]
}

echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}${BOLD}         配置向导 Configuration${NC}"
echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
echo ""

# Port
echo -e "${CYAN}[1/5] 服务端口${NC}"
PORT=$(ask_input "  端口" "8080")
echo -e "  ${GREEN}✓ 端口: ${PORT}${NC}"
echo ""

# Admin password
echo -e "${CYAN}[2/5] 管理员密码${NC}"
ADMIN_PASSWORD=$(ask_secret "  密码 (留空自动生成)")
if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(gen_pass 16)
    echo -e "  ${GREEN}✓ 已生成随机密码${NC}"
else
    echo -e "  ${GREEN}✓ 已设置密码${NC}"
fi
echo ""

# DB password
echo -e "${CYAN}[3/5] 数据库密码${NC}"
if ask_yes_no "  自动生成?" "y"; then
    DB_PASSWORD=$(gen_pass 24)
    echo -e "  ${GREEN}✓ 已生成${NC}"
else
    DB_PASSWORD=$(ask_secret "  密码")
    [ -z "$DB_PASSWORD" ] && DB_PASSWORD=$(gen_pass 24)
    echo -e "  ${GREEN}✓ 已设置${NC}"
fi
echo ""

# JWT
echo -e "${CYAN}[4/5] JWT 密钥${NC}"
if ask_yes_no "  自动生成?" "y"; then
    JWT_SECRET=$(gen_pass 32)
    echo -e "  ${GREEN}✓ 已生成${NC}"
else
    JWT_SECRET=$(ask_secret "  密钥")
    [ -z "$JWT_SECRET" ] && JWT_SECRET=$(gen_pass 32)
    echo -e "  ${GREEN}✓ 已设置${NC}"
fi
echo ""

# Domain
echo -e "${CYAN}[5/5] 域名 (可选)${NC}"
DOMAIN=$(ask_input "  域名" "")
if [ -n "$DOMAIN" ]; then
    echo -e "  ${GREEN}✓ ${DOMAIN}${NC}"
else
    echo -e "  ${DIM}跳过${NC}"
fi
echo ""

# Summary
echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}${BOLD}         确认配置${NC}"
echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}端口:${NC}   ${PORT}"
echo -e "  ${CYAN}用户:${NC}   admin"
echo -e "  ${CYAN}密码:${NC}   ${ADMIN_PASSWORD}"
echo ""

if ! ask_yes_no "  确认安装?" "y"; then
    echo -e "${RED}已取消${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}[1/5] 检查 Docker...${NC}"
if command -v docker &>/dev/null; then
    echo -e "  ${GREEN}✓ $(docker --version | head -1)${NC}"
else
    echo -e "  ${YELLOW}安装中...${NC}"
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker && systemctl start docker
    echo -e "  ${GREEN}✓ 完成${NC}"
fi

echo -e "${GREEN}[2/5] 检查 Compose...${NC}"
if docker compose version &>/dev/null; then
    echo -e "  ${GREEN}✓ OK${NC}"
else
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    echo -e "  ${GREEN}✓ 安装完成${NC}"
fi

echo -e "${GREEN}[3/5] 下载代码...${NC}"
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR" && git pull origin main
else
    rm -rf "$INSTALL_DIR"
    git clone "$REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi
echo -e "  ${GREEN}✓ 完成${NC}"

echo -e "${GREEN}[4/5] 生成配置...${NC}"
cat > .env <<ENVEOF
PORT=${PORT}
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
ENVEOF
echo -e "  ${GREEN}✓ .env 已生成${NC}"

echo -e "${GREEN}[5/5] 启动服务...${NC}"
docker compose down 2>/dev/null || true
docker compose up -d --build
echo -e "  ${YELLOW}等待启动...${NC}"
sleep 15

# Firewall
ufw allow "$PORT"/tcp 2>/dev/null || true

PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ 安装成功!${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
echo ""
echo -e "  URL:      ${CYAN}http://${PUBLIC_IP}:${PORT}${NC}"
echo -e "  用户名:   ${CYAN}admin${NC}"
echo -e "  密码:     ${CYAN}${ADMIN_PASSWORD}${NC}"
echo ""
echo -e "  ${DIM}日志: cd ${INSTALL_DIR} && docker compose logs -f${NC}"
echo -e "  ${DIM}重启: cd ${INSTALL_DIR} && docker compose restart${NC}"
echo -e "  ${DIM}更新: cd ${INSTALL_DIR} && git pull && docker compose up -d --build${NC}"
echo ""

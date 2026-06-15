#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Config
REPO="https://github.com/IceTears1/subforge.git"
INSTALL_DIR="/opt/subforge"

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
echo -e "  ${DIM}One-Click Interactive Installer${NC}"
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
# Helper functions
# ─────────────────────────────────────
gen_pass() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "$1"
}

# Read from terminal (works with curl | bash)
ask() {
    local prompt="$1"
    local default="$2"
    local result
    read -p "$(echo -e ${CYAN}${prompt} [${default}]: ${NC})" result < /dev/tty
    echo "${result:-$default}"
}

ask_secret() {
    local prompt="$1"
    local result
    read -s -p "$(echo -e ${CYAN}${prompt}: ${NC})" result < /dev/tty
    echo ""
    echo "$result"
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local choice
    read -p "$(echo -e ${CYAN}${prompt} [${default}]: ${NC})" choice < /dev/tty
    choice=${choice:-$default}
    [[ "$choice" =~ ^[Yy]$ ]]
}

# ─────────────────────────────────────
# Check if piped (curl | bash)
# ─────────────────────────────────────
if [ -t 0 ]; then
    # Direct execution, stdin is terminal
    INTERACTIVE=true
else
    # Piped (curl | bash), need to read from /dev/tty
    if [ -e /dev/tty ]; then
        INTERACTIVE=true
    else
        INTERACTIVE=false
        echo -e "${YELLOW}非交互模式，使用默认配置${NC}"
    fi
fi

# ─────────────────────────────────────
# Configuration
# ─────────────────────────────────────
echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}${BOLD}         配置向导 Configuration${NC}"
echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
echo ""

if [ "$INTERACTIVE" = true ]; then
    # Port
    echo -e "${CYAN}[1/5] 服务端口${NC}"
    echo -e "  ${DIM}SubForge Web 服务监听的端口${NC}"
    PORT=$(ask "  端口" "8080")
    echo -e "  ${GREEN}✓ 端口: ${PORT}${NC}"
    echo ""

    # Admin password
    echo -e "${CYAN}[2/5] 管理员密码${NC}"
    echo -e "  ${DIM}admin 账户的登录密码 (留空自动生成)${NC}"
    INPUT_ADMIN=$(ask_secret "  密码")
    if [ -z "$INPUT_ADMIN" ]; then
        ADMIN_PASSWORD=$(gen_pass 16)
        echo -e "  ${GREEN}✓ 已生成随机密码${NC}"
    else
        ADMIN_PASSWORD="$INPUT_ADMIN"
        echo -e "  ${GREEN}✓ 已设置自定义密码${NC}"
    fi
    echo ""

    # Database password
    echo -e "${CYAN}[3/5] 数据库密码${NC}"
    echo -e "  ${DIM}PostgreSQL 数据库密码${NC}"
    if confirm "  自动生成? (推荐)" "y"; then
        DB_PASSWORD=$(gen_pass 24)
        echo -e "  ${GREEN}✓ 已生成随机密码${NC}"
    else
        DB_PASSWORD=$(ask_secret "  密码")
        echo -e "  ${GREEN}✓ 已设置自定义密码${NC}"
    fi
    echo ""

    # JWT Secret
    echo -e "${CYAN}[4/5] JWT 密钥${NC}"
    echo -e "  ${DIM}用于生成登录 Token，建议 32 位以上${NC}"
    if confirm "  自动生成? (推荐)" "y"; then
        JWT_SECRET=$(gen_pass 32)
        echo -e "  ${GREEN}✓ 已生成随机密钥${NC}"
    else
        JWT_SECRET=$(ask_secret "  密钥")
        echo -e "  ${GREEN}✓ 已设置自定义密钥${NC}"
    fi
    echo ""

    # Domain (optional)
    echo -e "${CYAN}[5/5] 域名 (可选)${NC}"
    echo -e "  ${DIM}用于 HTTPS 配置，留空跳过${NC}"
    DOMAIN=$(ask "  域名" "")
    if [ -n "$DOMAIN" ]; then
        echo -e "  ${GREEN}✓ 域名: ${DOMAIN}${NC}"
    else
        echo -e "  ${DIM}  跳过 HTTPS 配置${NC}"
    fi
    echo ""

    # ─────────────────────────────────────
    # Confirm
    # ─────────────────────────────────────
    echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BOLD}         确认配置 Summary${NC}"
    echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}端口:${NC}     ${PORT}"
    echo -e "  ${CYAN}用户名:${NC}   admin"
    echo -e "  ${CYAN}密码:${NC}     ${ADMIN_PASSWORD}"
    echo -e "  ${CYAN}数据库:${NC}   subforge (${DB_PASSWORD:0:8}...)"
    echo -e "  ${CYAN}JWT:${NC}      ${JWT_SECRET:0:8}..."
    if [ -n "$DOMAIN" ]; then
        echo -e "  ${CYAN}域名:${NC}     ${DOMAIN}"
    fi
    echo ""
    echo -e "  ${DIM}安装目录: ${INSTALL_DIR}${NC}"
    echo ""

    if ! confirm "  确认安装?" "y"; then
        echo -e "${RED}安装已取消${NC}"
        exit 0
    fi
else
    # Non-interactive mode: use defaults or environment variables
    PORT=${PORT:-8080}
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-$(gen_pass 16)}
    DB_PASSWORD=${DB_PASSWORD:-$(gen_pass 24)}
    JWT_SECRET=${JWT_SECRET:-$(gen_pass 32)}
    DOMAIN=${DOMAIN:-}
    echo -e "  ${DIM}使用默认配置或环境变量${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}开始安装...${NC}"
echo ""

# ─────────────────────────────────────
# Step 1: Install Docker
# ─────────────────────────────────────
echo -e "${YELLOW}[1/5] 检查 Docker...${NC}"

if command -v docker &>/dev/null; then
    echo -e "  ${GREEN}✓ Docker 已安装: $(docker --version | head -1)${NC}"
else
    echo -e "  ${YELLOW}正在安装 Docker...${NC}"
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
    echo -e "  ${GREEN}✓ Docker 安装完成${NC}"
fi

# ─────────────────────────────────────
# Step 2: Check Docker Compose
# ─────────────────────────────────────
echo -e "${YELLOW}[2/5] 检查 Docker Compose...${NC}"

if docker compose version &>/dev/null; then
    echo -e "  ${GREEN}✓ Docker Compose 已安装${NC}"
else
    echo -e "  ${YELLOW}正在安装 Docker Compose...${NC}"
    mkdir -p /usr/local/lib/docker/cli-plugins
    ARCH=$(uname -m)
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    echo -e "  ${GREEN}✓ Docker Compose 安装完成${NC}"
fi

# ─────────────────────────────────────
# Step 3: Download SubForge
# ─────────────────────────────────────
echo -e "${YELLOW}[3/5] 下载 SubForge...${NC}"

if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    git pull origin main 2>/dev/null || true
    echo -e "  ${GREEN}✓ 已更新到最新版本${NC}"
else
    rm -rf "$INSTALL_DIR"
    git clone "$REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo -e "  ${GREEN}✓ 下载完成${NC}"
fi

# ─────────────────────────────────────
# Step 4: Generate Config
# ─────────────────────────────────────
echo -e "${YELLOW}[4/5] 生成配置文件...${NC}"

cat > .env <<EOF
# SubForge Configuration
# Generated at $(date)

# Server port
PORT=${PORT}

# Database
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=${DB_PASSWORD}
DB_SSL_MODE=disable

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRY=24h

# Admin
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# CORS (comma-separated origins, empty = same-origin only)
CORS_ORIGINS=

# Admin IP whitelist (comma-separated IPs, empty = no restriction)
ADMIN_IP_WHITELIST=

# Gin mode
GIN_MODE=release
EOF

echo -e "  ${GREEN}✓ 配置文件已生成${NC}"

# ─────────────────────────────────────
# Step 5: Start Services
# ─────────────────────────────────────
echo -e "${YELLOW}[5/5] 启动服务...${NC}"

docker compose down 2>/dev/null || true
docker compose up -d --build

echo -e "  ${YELLOW}等待服务启动...${NC}"
sleep 10

# Check status
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
# Firewall
# ─────────────────────────────────────
if command -v ufw &>/dev/null; then
    ufw allow "$PORT"/tcp 2>/dev/null || true
    echo -e "  ${GREEN}✓ 防火墙: 端口 ${PORT} 已开放${NC}"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port="$PORT"/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo -e "  ${GREEN}✓ 防火墙: 端口 ${PORT} 已开放${NC}"
fi

# ─────────────────────────────────────
# Done
# ─────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ SubForge 安装成功!${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}访问地址:${NC}  ${CYAN}http://${PUBLIC_IP}:${PORT}${NC}"
echo -e "  ${BOLD}用户名:${NC}    ${CYAN}admin${NC}"
echo -e "  ${BOLD}密码:${NC}      ${CYAN}${ADMIN_PASSWORD}${NC}"
echo ""
if [ -n "$DOMAIN" ]; then
    echo -e "  ${YELLOW}HTTPS 配置:${NC}"
    echo -e "    运行 ${CYAN}cd ${INSTALL_DIR} && sudo bash setup-ssl.sh${NC}"
    echo ""
fi
echo -e "  ${YELLOW}常用命令:${NC}"
echo -e "    查看日志:   ${CYAN}cd ${INSTALL_DIR} && docker compose logs -f${NC}"
echo -e "    重启服务:   ${CYAN}cd ${INSTALL_DIR} && docker compose restart${NC}"
echo -e "    停止服务:   ${CYAN}cd ${INSTALL_DIR} && docker compose down${NC}"
echo -e "    更新版本:   ${CYAN}cd ${INSTALL_DIR} && git pull && docker compose up -d --build${NC}"
echo -e "    卸载:       ${CYAN}cd ${INSTALL_DIR} && docker compose down -v && rm -rf ${INSTALL_DIR}${NC}"
echo ""
echo -e "  ${DIM}配置文件: ${INSTALL_DIR}/.env${NC}"
echo ""

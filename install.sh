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
CACHE_DIR="/opt/subforge-cache"

# Detect if running interactively
if [ -t 0 ]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
    # Try to open tty for interactive prompts
    if [ -e /dev/tty ]; then
        exec < /dev/tty
        INTERACTIVE=true
    fi
fi

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

# ─────────────────────────────────────
# Root check
# ─────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root${NC}"
    exit 1
fi

# ─────────────────────────────────────
# OS & package manager detection
# ─────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID}"
        OS_LIKE="${ID_LIKE:-$ID}"
    elif [ -f /etc/redhat-release ]; then
        OS_ID="centos"
        OS_LIKE="rhel"
    else
        OS_ID="unknown"
        OS_LIKE="unknown"
    fi

    case "$OS_ID" in
        ubuntu|debian|linuxmint|pop)
            PKG_MANAGER="apt"
            PKG_INSTALL="apt-get install -y -qq"
            PKG_UPDATE="apt-get update -qq"
            ;;
        centos|rhel|rocky|alma|fedora)
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
                PKG_INSTALL="dnf install -y -q"
                PKG_UPDATE="dnf makecache -q"
            else
                PKG_MANAGER="yum"
                PKG_INSTALL="yum install -y -q"
                PKG_UPDATE="yum makecache -q"
            fi
            ;;
        alpine)
            PKG_MANAGER="apk"
            PKG_INSTALL="apk add --no-cache"
            PKG_UPDATE="apk update -q"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            PKG_INSTALL="pacman -S --noconfirm --needed"
            PKG_UPDATE="pacman -Sy"
            ;;
        *)
            case "$OS_LIKE" in
                *debian*|*ubuntu*)
                    PKG_MANAGER="apt"
                    PKG_INSTALL="apt-get install -y -qq"
                    PKG_UPDATE="apt-get update -qq"
                    ;;
                *rhel*|*centos*|*fedora*)
                    if command -v dnf &>/dev/null; then
                        PKG_MANAGER="dnf"
                        PKG_INSTALL="dnf install -y -q"
                        PKG_UPDATE="dnf makecache -q"
                    else
                        PKG_MANAGER="yum"
                        PKG_INSTALL="yum install -y -q"
                        PKG_UPDATE="yum makecache -q"
                    fi
                    ;;
                *)
                    PKG_MANAGER="unknown"
                    ;;
            esac
            ;;
    esac

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l)        ARCH="armv7" ;;
    esac
}

detect_os
echo -e "  ${DIM}OS: ${OS_ID} | Arch: ${ARCH} | Pkg: ${PKG_MANAGER}${NC}"
echo ""

# ─────────────────────────────────────
# Helper functions
# ─────────────────────────────────────
gen_pass() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "$1"
}

ask_input() {
    local prompt="$1"
    local default="$2"
    local result=""

    if [ "$INTERACTIVE" = true ]; then
        read -p "$(echo -e "${CYAN}${prompt} [${default}]: ${NC}")" result
    fi
    echo "${result:-$default}"
}

ask_secret() {
    local prompt="$1"
    local result=""

    if [ "$INTERACTIVE" = true ]; then
        read -s -p "$(echo -e "${CYAN}${prompt}: ${NC}")" result
        echo "" >&2
    fi
    echo "$result"
}

ask_yes_no() {
    local prompt="$1"
    local default="$2"
    local choice="$default"

    if [ "$INTERACTIVE" = true ]; then
        read -p "$(echo -e "${CYAN}${prompt} [${default}]: ${NC}")" choice
    fi
    choice=${choice:-$default}
    [[ "$choice" =~ ^[Yy]$ ]]
}

# ─────────────────────────────────────
# Cache management functions
# ─────────────────────────────────────
clean_docker_cache() {
    echo -e "${YELLOW}  清理 Docker 缓存...${NC}"
    docker container prune -f 2>/dev/null || true
    docker image prune -f 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
    echo -e "  ${GREEN}✓ Docker 缓存已清理${NC}"
}

clean_build_cache() {
    echo -e "${YELLOW}  清理构建缓存...${NC}"
    docker builder prune -f --filter "until=168h" 2>/dev/null || true
    echo -e "  ${GREEN}✓ 构建缓存已清理${NC}"
}

optimize_docker_daemon() {
    echo -e "${YELLOW}  优化 Docker 守护进程配置...${NC}"

    DAEMON_JSON="/etc/docker/daemon.json"
    BACKUP_JSON="${DAEMON_JSON}.backup.$(date +%Y%m%d%H%M%S)"

    if [ -f "$DAEMON_JSON" ]; then
        cp "$DAEMON_JSON" "$BACKUP_JSON"
    fi

    cat > "$DAEMON_JSON" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF

    if command -v systemctl &>/dev/null; then
        systemctl restart docker 2>/dev/null || true
    fi

    echo -e "  ${GREEN}✓ Docker 守护进程已优化${NC}"
}

setup_build_cache() {
    echo -e "${YELLOW}  配置构建缓存...${NC}"
    mkdir -p "$CACHE_DIR"
    mkdir -p /var/lib/buildkit/cache
    export DOCKER_BUILDKIT=1
    export BUILDKIT_STEP_LOG_MAX_SIZE=-1
    echo -e "  ${GREEN}✓ 构建缓存已配置${NC}"
}

# ─────────────────────────────────────
# Configuration wizard
# ─────────────────────────────────────
echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}${BOLD}         配置向导 Configuration${NC}"
echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
echo ""

# Port
echo -e "${CYAN}[1/6] 服务端口${NC}"
PORT=$(ask_input "  端口" "8080")
echo -e "  ${GREEN}✓ 端口: ${PORT}${NC}"
echo ""

# Admin password
echo -e "${CYAN}[2/6] 管理员密码${NC}"
ADMIN_PASSWORD=$(ask_secret "  密码 (留空自动生成)")
if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(gen_pass 16)
    echo -e "  ${GREEN}✓ 已生成随机密码${NC}"
else
    echo -e "  ${GREEN}✓ 已设置密码${NC}"
fi
echo ""

# DB password
echo -e "${CYAN}[3/6] 数据库密码${NC}"
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
echo -e "${CYAN}[4/6] JWT 密钥${NC}"
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
echo -e "${CYAN}[5/6] 域名 (可选)${NC}"
DOMAIN=$(ask_input "  域名" "")
if [ -n "$DOMAIN" ]; then
    echo -e "  ${GREEN}✓ ${DOMAIN}${NC}"
else
    echo -e "  ${DIM}跳过${NC}"
fi
echo ""

# Cache options
echo -e "${CYAN}[6/6] 缓存选项${NC}"
CLEAN_CACHE=false
if ask_yes_no "  清理旧 Docker 缓存?" "y"; then
    CLEAN_CACHE=true
    echo -e "  ${GREEN}✓ 将清理旧缓存${NC}"
else
    echo -e "  ${DIM}保留现有缓存${NC}"
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
echo -e "  ${CYAN}缓存:${NC}   $([ "$CLEAN_CACHE" = true ] && echo "清理旧缓存" || echo "保留现有")"
echo ""

if ! ask_yes_no "  确认安装?" "y"; then
    echo -e "${RED}已取消${NC}"
    exit 0
fi

# ─────────────────────────────────────
# Step 0: Clean cache if requested
# ─────────────────────────────────────
if [ "$CLEAN_CACHE" = true ]; then
    echo ""
    echo -e "${GREEN}[0/6] 清理缓存...${NC}"
    clean_docker_cache
    clean_build_cache
fi

# ─────────────────────────────────────
# Step 1: Install Docker
# ─────────────────────────────────────
echo ""
echo -e "${GREEN}[1/6] 检查 Docker...${NC}"
if command -v docker &>/dev/null; then
    echo -e "  ${GREEN}✓ $(docker --version | head -1)${NC}"
else
    echo -e "  ${YELLOW}安装 Docker...${NC}"

    if curl -fsSL https://get.docker.com | bash 2>/dev/null; then
        echo -e "  ${GREEN}✓ Docker 已安装${NC}"
    else
        echo -e "  ${YELLOW}尝试通过包管理器安装...${NC}"
        case "$PKG_MANAGER" in
            apt)
                $PKG_UPDATE
                $PKG_INSTALL docker.io
                ;;
            dnf|yum)
                $PKG_INSTALL docker
                ;;
            apk)
                $PKG_INSTALL docker
                ;;
            pacman)
                $PKG_INSTALL docker
                ;;
            *)
                echo -e "  ${RED}✗ 无法自动安装 Docker，请手动安装${NC}"
                echo -e "  ${DIM}参考: https://docs.docker.com/engine/install/${NC}"
                exit 1
                ;;
        esac
    fi

    if command -v systemctl &>/dev/null; then
        systemctl enable docker 2>/dev/null || true
        systemctl start docker 2>/dev/null || true
    elif command -v rc-update &>/dev/null; then
        rc-update add docker boot 2>/dev/null || true
        service docker start 2>/dev/null || true
    fi
    echo -e "  ${GREEN}✓ Docker 服务已启动${NC}"
fi

# ─────────────────────────────────────
# Step 2: Install Docker Compose
# ─────────────────────────────────────
echo -e "${GREEN}[2/6] 检查 Compose...${NC}"
if docker compose version &>/dev/null; then
    echo -e "  ${GREEN}✓ $(docker compose version --short 2>/dev/null || echo 'OK')${NC}"
else
    echo -e "  ${YELLOW}安装 Docker Compose...${NC}"

    COMPOSE_DIR="/usr/local/lib/docker/cli-plugins"
    mkdir -p "$COMPOSE_DIR"

    COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}"
    if curl -SL --connect-timeout 15 --retry 3 "$COMPOSE_URL" \
        -o "$COMPOSE_DIR/docker-compose" 2>/dev/null; then
        chmod +x "$COMPOSE_DIR/docker-compose"
    else
        echo -e "  ${YELLOW}GitHub 下载失败，尝试包管理器...${NC}"
        case "$PKG_MANAGER" in
            apt)
                $PKG_INSTALL docker-compose-plugin 2>/dev/null || \
                $PKG_INSTALL docker-compose 2>/dev/null
                ;;
            dnf|yum)
                $PKG_INSTALL docker-compose-plugin 2>/dev/null || \
                $PKG_INSTALL docker-compose 2>/dev/null
                ;;
            apk)
                $PKG_INSTALL docker-compose 2>/dev/null
                ;;
            *)
                echo -e "  ${RED}✗ 无法自动安装 Docker Compose${NC}"
                exit 1
                ;;
        esac
    fi

    if docker compose version &>/dev/null; then
        echo -e "  ${GREEN}✓ Docker Compose 已安装${NC}"
    else
        echo -e "  ${RED}✗ Docker Compose 安装失败${NC}"
        exit 1
    fi
fi

# ─────────────────────────────────────
# Step 3: Optimize Docker & Setup Cache
# ─────────────────────────────────────
echo -e "${GREEN}[3/6] 优化 Docker 配置...${NC}"
optimize_docker_daemon
setup_build_cache
echo -e "  ${GREEN}✓ Docker 已优化${NC}"

# ─────────────────────────────────────
# Step 4: Download code
# ─────────────────────────────────────
echo -e "${GREEN}[4/6] 下载代码...${NC}"
if [ -d "$INSTALL_DIR/.git" ]; then
    cd "$INSTALL_DIR"
    OLD_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    git fetch origin main
    git reset --hard origin/main
    echo -e "  ${GREEN}✓ 已更新 (${OLD_COMMIT} → $(git rev-parse --short HEAD))${NC}"
else
    rm -rf "$INSTALL_DIR"
    git clone "$REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo -e "  ${GREEN}✓ 已克隆${NC}"
fi

# ─────────────────────────────────────
# Step 5: Generate config
# ─────────────────────────────────────
echo -e "${GREEN}[5/6] 生成配置...${NC}"
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

# ─────────────────────────────────────
# Step 6: Start services with cache
# ─────────────────────────────────────
echo -e "${GREEN}[6/6] 启动服务...${NC}"

docker compose down --remove-orphans 2>/dev/null || true

echo -e "  ${DIM}构建 Docker 镜像（使用缓存）...${NC}"
docker compose build --parallel 2>&1 | tail -5

docker compose up -d

echo -e "  ${YELLOW}等待服务就绪...${NC}"

WAIT_COUNT=0
WAIT_MAX=60
while [ $WAIT_COUNT -lt $WAIT_MAX ]; do
    if curl -sf "http://localhost:${PORT}/api/health" >/dev/null 2>&1; then
        break
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $((WAIT_COUNT % 5)) -eq 0 ]; then
        echo -e "  ${DIM}等待中... ($((WAIT_COUNT * 2))s)${NC}"
    fi
done

if [ $WAIT_COUNT -ge $WAIT_MAX ]; then
    echo -e "  ${YELLOW}⚠ 服务启动较慢，请检查日志: docker compose logs${NC}"
else
    echo -e "  ${GREEN}✓ 服务已就绪 ($((WAIT_COUNT * 2))s)${NC}"
fi

# ─────────────────────────────────────
# Firewall
# ─────────────────────────────────────
echo -e "${DIM}配置防火墙...${NC}"
if command -v ufw &>/dev/null; then
    ufw allow "$PORT"/tcp 2>/dev/null || true
    echo -e "  ${GREEN}✓ ufw: 端口 ${PORT} 已开放${NC}"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port="${PORT}/tcp" 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo -e "  ${GREEN}✓ firewalld: 端口 ${PORT} 已开放${NC}"
elif command -v iptables &>/dev/null; then
    iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || true
    if command -v iptables-save &>/dev/null; then
        iptables-save > /etc/iptables.rules 2>/dev/null || true
    fi
    echo -e "  ${GREEN}✓ iptables: 端口 ${PORT} 已开放${NC}"
fi

# ─────────────────────────────────────
# Show cache stats
# ─────────────────────────────────────
echo ""
echo -e "${DIM}缓存统计:${NC}"
if command -v docker &>/dev/null; then
    IMAGE_COUNT=$(docker images | wc -l)
    IMAGE_SIZE=$(docker system df 2>/dev/null | grep "Images" | awk '{print $4}' || echo "N/A")
    echo -e "  ${DIM}镜像数量: ${IMAGE_COUNT}${NC}"
    echo -e "  ${DIM}镜像大小: ${IMAGE_SIZE}${NC}"
fi

# Get public IP
PUBLIC_IP=""
for ip_service in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "api.ipify.org"; do
    PUBLIC_IP=$(curl -s --connect-timeout 5 "https://${ip_service}" 2>/dev/null)
    if [ -n "$PUBLIC_IP" ] && echo "$PUBLIC_IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        break
    fi
done
[ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$PUBLIC_IP" ] && PUBLIC_IP="<server-ip>"

echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ 安装成功!${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
echo ""
echo -e "  URL:      ${CYAN}http://${PUBLIC_IP}:${PORT}${NC}"
echo -e "  用户名:   ${CYAN}admin${NC}"
echo -e "  密码:     ${CYAN}${ADMIN_PASSWORD}${NC}"
if [ -n "$DOMAIN" ]; then
    echo -e "  域名:     ${CYAN}${DOMAIN}${NC}"
    echo -e "  ${DIM}配置 SSL: sudo bash setup-ssl.sh${NC}"
fi
echo ""
echo -e "  ${DIM}日志:     cd ${INSTALL_DIR} && docker compose logs -f${NC}"
echo -e "  ${DIM}重启:     cd ${INSTALL_DIR} && docker compose restart${NC}"
echo -e "  ${DIM}更新:     cd ${INSTALL_DIR} && git pull && docker compose up -d --build${NC}"
echo -e "  ${DIM}健康检查: cd ${INSTALL_DIR} && bash scripts/health-check.sh${NC}"
echo -e "  ${DIM}清理缓存: docker system prune -f && docker builder prune -f${NC}"
echo ""

#!/bin/bash
# SubForge One-Click Installer (Japan ECS Compatible)
# Usage: curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh | sudo bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

REPO="https://github.com/IceTears1/subforge.git"
INSTALL_DIR="/opt/subforge"
PORT=8080
ADMIN_PASSWORD=""
DB_PASSWORD=""
JWT_SECRET=""

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()  { echo -e "${CYAN}[i]${NC} $1"; }

gen_pass() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "$1"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "请使用 root 运行: sudo bash install.sh"
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID:-unknown}"
    else
        OS_ID="unknown"
    fi

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)  GOARCH="amd64" ;;
        aarch64|arm64) GOARCH="arm64" ;;
        armv7l)        GOARCH="arm" ;;
        *)             GOARCH="amd64" ;;
    esac

    info "系统: $OS_ID ($ARCH)"
}

install_docker() {
    info "检查 Docker..."
    if command -v docker &>/dev/null; then
        log "Docker 已安装"
        return
    fi
    warn "安装 Docker..."

    # 使用国内镜像安装 Docker
    if [ "$OS_ID" = "centos" ] || [ "$OS_ID" = "rhel" ]; then
        yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
    else
        curl -fsSL https://get.docker.com | bash 2>/dev/null || error "Docker 安装失败"
    fi

    systemctl enable docker 2>/dev/null || true
    systemctl start docker 2>/dev/null || true
    log "Docker 安装完成"
}

install_compose() {
    info "检查 Docker Compose..."
    if docker compose version &>/dev/null; then
        log "Docker Compose 已安装"
        return
    fi
    warn "安装 Docker Compose..."
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${GOARCH}" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    log "Docker Compose 安装完成"
}

clone_repo() {
    info "下载代码..."
    if [ -d "$INSTALL_DIR/.git" ]; then
        cd "$INSTALL_DIR"
        OLD=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        git fetch origin main 2>/dev/null
        git reset --hard origin/main 2>/dev/null
        NEW=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        log "代码已更新: $OLD → $NEW"
    else
        rm -rf "$INSTALL_DIR"
        git clone "$REPO" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        log "代码已克隆"
    fi
}

load_images() {
    info "加载预构建镜像..."

    # Load backend image
    if [ -f "$INSTALL_DIR/images/subforge-backend.tar.gz" ]; then
        docker load < "$INSTALL_DIR/images/subforge-backend.tar.gz"
        log "后端镜像已加载"
    else
        warn "后端镜像不存在，将使用本地构建"
    fi
}

generate_config() {
    info "生成配置..."
    cd "$INSTALL_DIR"

    [ -z "$DB_PASSWORD" ] && DB_PASSWORD=$(gen_pass 24)
    [ -z "$JWT_SECRET" ] && JWT_SECRET=$(gen_pass 32)
    [ -z "$ADMIN_PASSWORD" ] && ADMIN_PASSWORD=$(gen_pass 16)

    cat > .env <<EOF
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
EOF

    log "配置已生成"
}

build_frontend() {
    info "编译前端..."
    cd "$INSTALL_DIR/frontend"

    # 使用国内 npm 镜像
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        node:20-alpine \
        sh -c "npm config set registry https://registry.npmmirror.com && npm ci --legacy-peer-deps 2>/dev/null || npm install --legacy-peer-deps && npm run build"

    log "前端编译完成"
}

start_services() {
    info "启动服务..."
    cd "$INSTALL_DIR"

    docker compose down --remove-orphans 2>/dev/null || true
    docker compose up -d

    log "服务已启动"
}

wait_health() {
    info "等待服务就绪..."

    local max=60
    local count=0

    while [ $count -lt $max ]; do
        if curl -sf "http://localhost:${PORT}/api/health" >/dev/null 2>&1; then
            log "服务就绪 (${count}s)"
            return
        fi
        sleep 2
        count=$((count + 2))
    done

    warn "服务启动较慢，请检查日志: docker compose logs"
}

get_public_ip() {
    local ip=""
    for svc in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "api.ipify.org"; do
        ip=$(curl -s --connect-timeout 5 "https://${svc}" 2>/dev/null)
        if echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            echo "$ip"
            return
        fi
    done
    hostname -I 2>/dev/null | awk '{print $1}' || echo "<server-ip>"
}

main() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ____        _   _____                   "
    echo " / ___| _   _| | |  ___|___  _ __ ___    "
    echo " \___ \ | | | | | |_ / _ \| '__/ _ \   "
    echo "  ___) | |_| | | |  _| (_) | | |  __/   "
    echo " |____/ \__,_|_| |_|  \___/|_|  \___|   "
    echo -e "${NC}"
    echo -e "  ${BOLD}一键安装脚本 (日本 ECS 兼容版)${NC}"
    echo ""

    check_root
    detect_os

    # Install dependencies
    install_docker
    install_compose

    # Setup project
    clone_repo
    load_images
    generate_config

    # Build frontend
    build_frontend

    # Start services
    start_services
    wait_health

    PUBLIC_IP=$(get_public_ip)

    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  ✅ 安装成功!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "  URL:      ${CYAN}http://${PUBLIC_IP}:${PORT}${NC}"
    echo -e "  用户名:   ${CYAN}admin${NC}"
    echo -e "  密码:     ${CYAN}${ADMIN_PASSWORD}${NC}"
    echo ""
    echo -e "  ${DIM}查看日志: cd ${INSTALL_DIR} && docker compose logs -f${NC}"
    echo -e "  ${DIM}重启服务: cd ${INSTALL_DIR} && docker compose restart${NC}"
    echo ""
}

main "$@"

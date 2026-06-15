#!/bin/bash
# SubForge One-Click Installer (Fast Version)
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
BACKEND_PORT=8081
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

detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)  GOARCH="amd64" ;;
        aarch64|arm64) GOARCH="arm64" ;;
        armv7l)        GOARCH="arm" ;;
        *)             GOARCH="amd64" ;;
    esac
    info "架构: $ARCH → $GOARCH"
}

install_docker() {
    info "检查 Docker..."
    if command -v docker &>/dev/null; then
        log "Docker 已安装"
        return
    fi
    warn "安装 Docker..."
    curl -fsSL https://get.docker.com | bash 2>/dev/null || error "Docker 安装失败"
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

install_go() {
    info "检查 Go..."
    if command -v go &>/dev/null; then
        log "Go 已安装: $(go version | awk '{print $3}')"
        return
    fi
    warn "安装 Go..."
    GO_VERSION="1.23.0"
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" | tar -C /usr/local -xzf -
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    log "Go 安装完成"
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

build_backend() {
    info "编译后端..."
    cd "$INSTALL_DIR/backend"

    # Use Docker to build (no need to install Go locally)
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        -e GOPROXY=https://goproxy.cn,direct \
        -e GONOSUMCHECK="*" \
        -e GOFLAGS="-mod=mod" \
        golang:1.21-alpine \
        sh -c "CGO_ENABLED=0 GOOS=linux GOARCH=${GOARCH} go build -ldflags='-s -w' -o /app/subforge ./cmd/server"

    chmod +x subforge
    log "后端编译完成"
}

build_frontend() {
    info "编译前端..."
    cd "$INSTALL_DIR/frontend"

    # Use Docker to build
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        node:20-alpine \
        sh -c "npm config set registry https://registry.npmmirror.com && npm ci --legacy-peer-deps 2>/dev/null || npm install --legacy-peer-deps && npm run build"

    log "前端编译完成"
}

generate_config() {
    info "生成配置..."
    cd "$INSTALL_DIR"

    [ -z "$DB_PASSWORD" ] && DB_PASSWORD=$(gen_pass 24)
    [ -z "$JWT_SECRET" ] && JWT_SECRET=$(gen_pass 32)
    [ -z "$ADMIN_PASSWORD" ] && ADMIN_PASSWORD=$(gen_pass 16)

    cat > .env <<EOF
PORT=${BACKEND_PORT}
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

    # Also save the main port for reference
    echo "NGINX_PORT=${PORT}" >> .env

    log "配置已生成"
}

start_services() {
    info "启动服务..."
    cd "$INSTALL_DIR"

    # Start only PostgreSQL and Nginx via Docker
    docker compose up -d postgres nginx

    # Wait for PostgreSQL
    info "等待数据库就绪..."
    sleep 5

    # Start backend directly
    info "启动后端服务..."
    pkill -f "./subforge" 2>/dev/null || true
    nohup ./subforge > /var/log/subforge.log 2>&1 &

    log "服务已启动"
}

wait_health() {
    info "等待服务就绪..."

    local max=30
    local count=0

    while [ $count -lt $max ]; do
        if curl -sf "http://localhost:${BACKEND_PORT}/api/health" >/dev/null 2>&1; then
            log "服务就绪 (${count}s)"
            return
        fi
        sleep 2
        count=$((count + 2))
    done

    warn "服务启动较慢，请检查日志: tail -f /var/log/subforge.log"
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
    echo -e "  ${BOLD}一键安装脚本 (快速版)${NC}"
    echo ""

    check_root
    detect_arch

    # Install dependencies
    install_docker
    install_compose

    # Setup project
    clone_repo
    generate_config

    # Build (using Docker for compilation only)
    build_backend
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
    echo -e "  ${DIM}查看日志: tail -f /var/log/subforge.log${NC}"
    echo -e "  ${DIM}重启后端: cd ${INSTALL_DIR} && ./subforge${NC}"
    echo ""
}

main "$@"

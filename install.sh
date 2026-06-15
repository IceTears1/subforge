#!/bin/bash
# SubForge One-Click Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh | sudo bash

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Config ───────────────────────────────────────────────────────────────────
REPO="https://github.com/IceTears1/subforge.git"
INSTALL_DIR="/opt/subforge"
PORT=8080
ADMIN_PASSWORD=""
DB_PASSWORD=""
JWT_SECRET=""

# ─── Functions ────────────────────────────────────────────────────────────────
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

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_LIKE="${ID_LIKE:-$OS_ID}"
    else
        OS_ID="unknown"
        OS_LIKE="unknown"
    fi

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l)        ARCH="armv7" ;;
    esac

    info "系统: $OS_ID ($ARCH)"
}

get_pkg_manager() {
    case "$OS_ID" in
        ubuntu|debian|linuxmint|pop|*debian*|*ubuntu*)
            PKG_UPDATE="apt-get update -qq"
            PKG_INSTALL="apt-get install -y -qq"
            ;;
        centos|rhel|rocky|alma|fedora|*rhel*|*centos*|*fedora*)
            if command -v dnf &>/dev/null; then
                PKG_UPDATE="dnf makecache -q"
                PKG_INSTALL="dnf install -y -q"
            else
                PKG_UPDATE="yum makecache -q"
                PKG_INSTALL="yum install -y -q"
            fi
            ;;
        alpine)
            PKG_UPDATE="apk update -q"
            PKG_INSTALL="apk add --no-cache"
            ;;
        arch|manjaro)
            PKG_UPDATE="pacman -Sy"
            PKG_INSTALL="pacman -S --noconfirm --needed"
            ;;
        *)
            PKG_UPDATE=""
            PKG_INSTALL=""
            ;;
    esac
}

install_docker() {
    info "检查 Docker..."

    if command -v docker &>/dev/null; then
        log "Docker 已安装: $(docker --version | head -1)"
        return
    fi

    warn "正在安装 Docker..."

    # Try official script
    if curl -fsSL https://get.docker.com | bash 2>/dev/null; then
        log "Docker 安装完成"
    elif [ -n "$PKG_INSTALL" ]; then
        # Fallback to package manager
        $PKG_UPDATE 2>/dev/null || true
        case "$OS_ID" in
            ubuntu|debian|linuxmint|pop) $PKG_INSTALL docker.io ;;
            *) $PKG_INSTALL docker ;;
        esac
        log "Docker 安装完成"
    else
        error "无法安装 Docker，请手动安装: https://docs.docker.com/engine/install/"
    fi

    # Enable and start
    if command -v systemctl &>/dev/null; then
        systemctl enable docker 2>/dev/null || true
        systemctl start docker 2>/dev/null || true
    fi
}

install_compose() {
    info "检查 Docker Compose..."

    if docker compose version &>/dev/null; then
        log "Docker Compose 已安装"
        return
    fi

    warn "正在安装 Docker Compose..."

    COMPOSE_DIR="/usr/local/lib/docker/cli-plugins"
    mkdir -p "$COMPOSE_DIR"

    # Try GitHub
    COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}"
    if curl -fsSL --connect-timeout 15 --retry 3 "$COMPOSE_URL" -o "$COMPOSE_DIR/docker-compose" 2>/dev/null; then
        chmod +x "$COMPOSE_DIR/docker-compose"
        log "Docker Compose 安装完成"
        return
    fi

    # Fallback
    if [ -n "$PKG_INSTALL" ]; then
        $PKG_INSTALL docker-compose-plugin 2>/dev/null || \
        $PKG_INSTALL docker-compose 2>/dev/null || true
        log "Docker Compose 安装完成"
    else
        error "无法安装 Docker Compose"
    fi
}

optimize_docker() {
    info "优化 Docker 配置..."

    DAEMON_JSON="/etc/docker/daemon.json"
    if [ -f "$DAEMON_JSON" ]; then
        cp "$DAEMON_JSON" "${DAEMON_JSON}.bak.$(date +%s)"
    fi

    cat > "$DAEMON_JSON" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "storage-driver": "overlay2",
  "live-restore": true
}
EOF

    command -v systemctl &>/dev/null && systemctl restart docker 2>/dev/null || true
    log "Docker 优化完成"
}

clean_cache() {
    info "清理缓存..."
    docker container prune -f 2>/dev/null || true
    docker image prune -f 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
    docker builder prune -f --filter "until=168h" 2>/dev/null || true
    log "缓存清理完成"
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

generate_config() {
    info "生成配置..."

    # Generate secrets
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

start_services() {
    info "启动服务..."

    docker compose down --remove-orphans 2>/dev/null || true
    docker compose build --parallel 2>/dev/null || docker compose build
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
        [ $((count % 10)) -eq 0 ] && info "等待中... ${count}s"
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

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ____        _   _____                   "
    echo " / ___| _   _| | |  ___|___  _ __ ___    "
    echo " \___ \ | | | | | |_ / _ \| '__/ _ \   "
    echo "  ___) | |_| | | |  _| (_) | | |  __/   "
    echo " |____/ \__,_|_| |_|  \___/|_|  \___|   "
    echo -e "${NC}"
    echo -e "  ${BOLD}一键安装脚本${NC}"
    echo ""

    check_root
    check_os
    get_pkg_manager

    # Clean cache
    clean_cache

    # Install dependencies
    install_docker
    install_compose
    optimize_docker

    # Setup project
    clone_repo
    generate_config
    start_services
    wait_health

    # Get IP
    PUBLIC_IP=$(get_public_ip)

    # Done
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
    echo -e "  ${DIM}更新版本: cd ${INSTALL_DIR} && git pull && docker compose up -d --build${NC}"
    echo ""
}

main "$@"

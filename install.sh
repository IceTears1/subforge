#!/bin/bash
# SubForge One-Click Installer v1.3.0
# Usage: curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh | sudo bash
#    or: sudo bash install.sh
#    or: sudo bash install.sh -v 1.3.0  (指定版本安装)

set -euo pipefail

# Support piped execution (curl | bash)
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

REPO="https://github.com/IceTears1/subforge.git"
INSTALL_DIR="/opt/subforge"
INSTALL_VERSION=""

# Parse command line arguments
while getopts "v:" opt; do
    case $opt in
        v) INSTALL_VERSION="$OPTARG" ;;
        *) echo "用法: $0 [-v 版本号]"; exit 1 ;;
    esac
done

# Default ports (configurable via interactive prompts)
FRONTEND_PORT=3001
BACKEND_PORT=3002
DB_PORT=45000
SSL_PORT=3003

# Other config
ADMIN_USERNAME="admin"
ADMIN_PASSWORD=""
DOMAIN=""
EMAIL=""
SSL_PROVIDER=""
ALI_AK=""
ALI_SK=""
USE_EXISTING_DATA=false

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
    info "系统: $OS_ID ($(uname -m))"
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
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)  GOARCH="amd64" ;;
        aarch64|arm64) GOARCH="arm64" ;;
        *)             GOARCH="amd64" ;;
    esac
    curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${GOARCH}" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    log "Docker Compose 安装完成"
}

clone_repo() {
    info "下载代码..."
    IS_UPGRADE=false

    # Determine which version/tag to use
    if [ -n "$INSTALL_VERSION" ]; then
        TARGET_TAG="v${INSTALL_VERSION#v}"  # Ensure v prefix
        info "指定安装版本: $TARGET_TAG"
    else
        TARGET_TAG="main"
    fi

    if [ -d "$INSTALL_DIR/.git" ]; then
        cd "$INSTALL_DIR"
        OLD=$(cat VERSION 2>/dev/null || echo "unknown")

        if [ -n "$INSTALL_VERSION" ]; then
            # Fetch specific tag
            git fetch --depth 1 origin tag "$TARGET_TAG" 2>/dev/null || error "版本 $TARGET_TAG 不存在"
            git checkout "$TARGET_TAG" 2>/dev/null || error "切换到版本 $TARGET_TAG 失败"
            log "已切换到版本: $TARGET_TAG"
        else
            # Pull latest from main (shallow)
            git fetch --depth 1 origin main 2>/dev/null
            git reset --hard origin/main 2>/dev/null
        fi

        NEW=$(cat VERSION 2>/dev/null || echo "unknown")
        if [ "$OLD" != "$NEW" ]; then
            IS_UPGRADE=true
            log "版本更新: $OLD → $NEW"
        else
            log "已是版本: $NEW"
        fi
    else
        rm -rf "$INSTALL_DIR"
        # 浅克隆，跳过 images 目录（从 Releases 下载）
        info "下载代码..."
        if [ -n "$INSTALL_VERSION" ]; then
            git clone --depth 1 --branch "$TARGET_TAG" --sparse "$REPO" "$INSTALL_DIR" || error "克隆版本 $TARGET_TAG 失败"
        else
            git clone --depth 1 --sparse "$REPO" "$INSTALL_DIR"
        fi
        cd "$INSTALL_DIR"
        # Sparse checkout: 只需要代码，不需要 images 目录
        git sparse-checkout init --cone 2>/dev/null || true
        git sparse-checkout set backend-python frontend nginx scripts docs proxy 2>/dev/null || true
        log "代码已克隆 ($(cat VERSION 2>/dev/null || echo 'unknown'))"
    fi
}

download_images() {
    info "下载预构建镜像..."
    mkdir -p images

    # Determine version for image download
    local img_version=""
    if [ -n "$INSTALL_VERSION" ]; then
        img_version="v${INSTALL_VERSION#v}"
    else
        img_version="v$(cat VERSION 2>/dev/null || echo 'latest')"
    fi

    # Check if images already exist
    local backend_img="images/subforge-backend-${img_version}.tar.gz"
    local frontend_img="images/subforge-frontend-${img_version}.tar.gz"

    if [ -f "$backend_img" ] && [ -f "$frontend_img" ]; then
        log "镜像已存在: $img_version"
        return
    fi

    # Try to download from GitHub Releases
    local release_url="https://github.com/IceTears1/subforge/releases/download/${img_version}"

    if [ ! -f "$backend_img" ]; then
        info "下载后端镜像..."
        if curl -fsSL "${release_url}/subforge-backend-${img_version}.tar.gz" -o "$backend_img" 2>/dev/null; then
            log "后端镜像下载完成"
        else
            warn "后端镜像下载失败，将使用本地构建"
            rm -f "$backend_img"
        fi
    fi

    if [ ! -f "$frontend_img" ]; then
        info "下载前端镜像..."
        if curl -fsSL "${release_url}/subforge-frontend-${img_version}.tar.gz" -o "$frontend_img" 2>/dev/null; then
            log "前端镜像下载完成"
        else
            warn "前端镜像下载失败，将使用本地构建"
            rm -f "$frontend_img"
        fi
    fi
}

load_images() {
    info "加载预构建镜像..."

    # 优先加载最新版本镜像，回退到无版本号镜像
    local backend_image=""
    if ls images/subforge-backend-v*.tar.gz 1> /dev/null 2>&1; then
        backend_image=$(ls -t images/subforge-backend-v*.tar.gz | head -1)
    elif [ -f "images/subforge-backend.tar.gz" ]; then
        backend_image="images/subforge-backend.tar.gz"
    fi

    if [ -n "$backend_image" ]; then
        docker load < "$backend_image"
        log "后端镜像已加载: $(basename "$backend_image")"
    else
        warn "后端镜像不存在，将使用本地构建"
    fi

    local frontend_image=""
    if ls images/subforge-frontend-v*.tar.gz 1> /dev/null 2>&1; then
        frontend_image=$(ls -t images/subforge-frontend-v*.tar.gz | head -1)
    elif [ -f "images/subforge-frontend.tar.gz" ]; then
        frontend_image="images/subforge-frontend.tar.gz"
    fi

    if [ -n "$frontend_image" ]; then
        docker load < "$frontend_image"
        log "前端镜像已加载: $(basename "$frontend_image")"
    else
        warn "前端镜像不存在，将使用本地构建"
    fi
}

generate_config() {
    info "生成配置..."
    cd "$INSTALL_DIR"

    if [ "$USE_EXISTING_DATA" = true ]; then
        # Use existing config
        source .env 2>/dev/null || true
    else
        # Generate new config
        [ -z "${DB_PASSWORD:-}" ] && DB_PASSWORD=$(gen_pass 24)
        [ -z "${JWT_SECRET:-}" ] && JWT_SECRET=$(gen_pass 32)
        [ -z "${ADMIN_PASSWORD:-}" ] && ADMIN_PASSWORD=$(gen_pass 16)

        cat > .env <<EOF
# 端口配置
FRONTEND_PORT=${FRONTEND_PORT}
BACKEND_PORT=${BACKEND_PORT}
DB_PORT=${DB_PORT}
SSL_PORT=${SSL_PORT}

# 域名/SSL
DOMAIN=${DOMAIN:-}

# 数据库
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=${DB_PASSWORD}
DB_SSL_MODE=disable

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRY=24h

# 管理员
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# 其他
CORS_ORIGINS=
ADMIN_IP_WHITELIST=
GIN_MODE=release
EOF
    fi

    log "配置已生成"
}

build_frontend() {
    if docker image inspect subforge-frontend:latest >/dev/null 2>&1; then
        log "前端镜像已存在"
        return
    fi

    info "构建前端镜像..."
    cd "$INSTALL_DIR/frontend"
    docker build -t subforge-frontend:latest .
    cd "$INSTALL_DIR"
    log "前端镜像构建完成"
}

check_existing_install() {
    if [ -f "$INSTALL_DIR/.env" ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
        echo -e "${YELLOW}${BOLD}  📋 检测到已有安装${NC}"
        echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"

        # Load existing config
        source "$INSTALL_DIR/.env" 2>/dev/null || true

        # Set defaults from existing config
        FRONTEND_PORT="${FRONTEND_PORT:-3001}"
        BACKEND_PORT="${BACKEND_PORT:-3002}"
        DB_PORT="${DB_PORT:-45000}"
        SSL_PORT="${SSL_PORT:-3003}"
        ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
        ADMIN_PASSWORD="${ADMIN_PASSWORD:-****}"
        DOMAIN="${DOMAIN:-}"
        EMAIL="${EMAIL:-}"
        ALI_AK="${ALI_AK:-}"
        ALI_SK="${ALI_SK:-}"

        echo -e "  前端端口:     ${CYAN}${FRONTEND_PORT}${NC}"
        echo -e "  后端端口:     ${CYAN}${BACKEND_PORT}${NC}"
        echo -e "  数据库端口:   ${CYAN}${DB_PORT}${NC}"
        echo -e "  HTTPS 端口:   ${CYAN}${SSL_PORT}${NC}"
        echo -e "  管理员账户:   ${CYAN}${ADMIN_USERNAME}${NC}"
        echo -e "  管理员密码:   ${CYAN}${ADMIN_PASSWORD}${NC}"
        [ -n "${DB_PASSWORD:-}" ] && echo -e "  数据库密码:   ${CYAN}${DB_PASSWORD}${NC}"
        [ -n "$DOMAIN" ] && echo -e "  域名:         ${CYAN}${DOMAIN}${NC}"
        [ -n "$EMAIL" ] && echo -e "  邮箱:         ${CYAN}${EMAIL}${NC}"
        [ -n "$ALI_AK" ] && echo -e "  阿里云 AK:    ${CYAN}${ALI_AK:0:8}****${NC}"
        [ -n "$ALI_SK" ] && echo -e "  阿里云 SK:    ${CYAN}${ALI_SK:0:4}****${NC}"
        echo ""

        # 端口冲突检测
        if [ "$BACKEND_PORT" = "$SSL_PORT" ] || [ "$BACKEND_PORT" = "$FRONTEND_PORT" ]; then
            warn "端口冲突！后端端口不能与前端或 HTTPS 端口相同"
            warn "已自动修正: BACKEND_PORT=3002"
            BACKEND_PORT=3002
        fi

        echo -e "${YELLOW}是否使用已有配置和数据? [Y/n]${NC}"
        read -p "> " use_existing
        if [[ ! "$use_existing" =~ ^[Nn]$ ]]; then
            USE_EXISTING_DATA=true
            log "将使用已有配置和数据"
            return
        fi

        echo -e "${YELLOW}是否备份数据库? [Y/n]${NC}"
        read -p "> " backup_db
        if [[ ! "$backup_db" =~ ^[Nn]$ ]]; then
            backup_database
        fi
    fi
}

backup_database() {
    if docker ps | grep -q subforge-db; then
        info "备份数据库..."
        BACKUP_DIR="$INSTALL_DIR/backups"
        mkdir -p "$BACKUP_DIR"
        BACKUP_FILE="$BACKUP_DIR/subforge-$(date +%Y%m%d_%H%M%S).sql"

        if docker exec subforge-db pg_dump -U subforge subforge > "$BACKUP_FILE" 2>/dev/null; then
            BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
            log "数据库已备份: $BACKUP_FILE ($BACKUP_SIZE)"
        else
            warn "数据库备份失败"
        fi
    fi
}

interactive_config() {
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  ⚙️  配置安装参数${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo ""

    # Load existing config if available
    if [ -f "$INSTALL_DIR/.env" ]; then
        source "$INSTALL_DIR/.env" 2>/dev/null || true
        FRONTEND_PORT="${FRONTEND_PORT:-3001}"
        BACKEND_PORT="${BACKEND_PORT:-3002}"
        DB_PORT="${DB_PORT:-45000}"
        SSL_PORT="${SSL_PORT:-3003}"
        ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
        ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
        DOMAIN="${DOMAIN:-}"
        EMAIL="${EMAIL:-}"
        ALI_AK="${ALI_AK:-}"
        ALI_SK="${ALI_SK:-}"
    fi

    if [ "$USE_EXISTING_DATA" = true ]; then
        log "使用已有配置"
        return
    fi

    # Port configuration
    echo -e "${DIM}--- 端口配置 ---${NC}"
    echo -e "${YELLOW}前端端口 [${FRONTEND_PORT}]${NC}"
    read -p "> " input
    FRONTEND_PORT="${input:-$FRONTEND_PORT}"

    echo -e "${YELLOW}后端端口 [${BACKEND_PORT}]${NC}"
    read -p "> " input
    BACKEND_PORT="${input:-$BACKEND_PORT}"

    echo -e "${YELLOW}数据库端口 [${DB_PORT}]${NC}"
    read -p "> " input
    DB_PORT="${input:-$DB_PORT}"

    echo -e "${YELLOW}HTTPS 端口 [${SSL_PORT}]${NC}"
    read -p "> " input
    SSL_PORT="${input:-$SSL_PORT}"

    # 端口冲突检测
    if [ "$BACKEND_PORT" = "$SSL_PORT" ] || [ "$BACKEND_PORT" = "$FRONTEND_PORT" ]; then
        warn "端口冲突！后端端口不能与前端或 HTTPS 端口相同"
        warn "已自动修正: BACKEND_PORT=3002"
        BACKEND_PORT=3002
    fi
    if [ "$FRONTEND_PORT" = "$SSL_PORT" ]; then
        warn "端口冲突！前端端口不能与 HTTPS 端口相同"
        warn "已自动修正: FRONTEND_PORT=3001"
        FRONTEND_PORT=3001
    fi

    echo ""

    # Admin credentials
    echo -e "${DIM}--- 管理员账户 ---${NC}"
    echo -e "${YELLOW}管理员用户名 [${ADMIN_USERNAME}]${NC}"
    read -p "> " input
    ADMIN_USERNAME="${input:-$ADMIN_USERNAME}"

    echo -e "${YELLOW}管理员密码 (留空随机生成)${NC}"
    read -p "> " input
    ADMIN_PASSWORD="${input:-$ADMIN_PASSWORD}"

    echo ""

    # Domain/SSL
    echo -e "${DIM}--- 域名/SSL 配置 (留空跳过) ---${NC}"
    echo -e "${YELLOW}域名 例: example.com${NC}"
    read -p "> " input
    DOMAIN="${input:-$DOMAIN}"

    if [ -n "$DOMAIN" ]; then
        echo -e "${YELLOW}SSL 证书来源:${NC}"
        echo "  1) Let's Encrypt (免费)"
        echo "  2) 阿里云 SSL 证书"
        echo "  3) 跳过 SSL 配置"
        read -p "> " ssl_choice
        SSL_PROVIDER="${ssl_choice:-3}"

        if [ "$SSL_PROVIDER" = "2" ]; then
            echo -e "${YELLOW}阿里云 AccessKey ID${NC}"
            read -p "> " input
            ALI_AK="${input:-$ALI_AK}"
            echo -e "${YELLOW}阿里云 AccessKey Secret${NC}"
        else
            # Let's Encrypt
            if [ -n "$EMAIL" ]; then
                echo -e "${YELLOW}邮箱 [${EMAIL}]${NC}"
            else
                echo -e "${YELLOW}邮箱 用于SSL证书${NC}"
            fi
            read -p "> " input
            EMAIL="${input:-$EMAIL}"
        fi
    fi

    # Confirm
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  📋 配置确认${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "  前端端口:     ${CYAN}${FRONTEND_PORT}${NC}"
    echo -e "  后端端口:     ${CYAN}${BACKEND_PORT}${NC}"
    echo -e "  数据库端口:   ${CYAN}${DB_PORT}${NC}"
    echo -e "  HTTPS 端口:   ${CYAN}${SSL_PORT}${NC}"
    echo -e "  管理员账户:   ${CYAN}${ADMIN_USERNAME}${NC}"
    echo -e "  管理员密码:   ${CYAN}${ADMIN_PASSWORD:-随机生成}${NC}"
    if [ -n "$DOMAIN" ]; then
        echo -e "  域名:         ${CYAN}${DOMAIN}${NC}"
        case "${SSL_PROVIDER:-}" in
            1) echo -e "  SSL:          ${CYAN}Let's Encrypt${NC}" ;;
            2) echo -e "  SSL:          ${CYAN}阿里云证书${NC}" ;;
            *) echo -e "  SSL:          ${CYAN}跳过${NC}" ;;
        esac
    fi
    [ -n "$EMAIL" ] && echo -e "  邮箱:         ${CYAN}${EMAIL}${NC}"
    echo ""

    echo -e "${YELLOW}确认开始安装? [Y/n]${NC}"
    read -p "> " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        error "安装已取消"
    fi
}

ensure_nginx_config() {
    info "检查 Nginx 配置..."

    # Create nginx directory if not exists
    mkdir -p "$INSTALL_DIR/nginx"

    # Check if nginx config template exists
    if [ ! -f "$INSTALL_DIR/nginx/nginx-python.conf.template" ]; then
        warn "Nginx 配置模板不存在，将使用默认配置"
    fi
}

setup_ssl() {
    if [ -z "${DOMAIN:-}" ]; then
        return
    fi

    echo ""
    info "配置域名访问..."

    # Create proxy directory and config
    cd "$INSTALL_DIR"
    mkdir -p proxy

    cat > proxy/nginx.conf <<'EOF'
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    upstream backend {
        server host.docker.internal:__BACKEND_PORT__;
    }

    server {
        listen 443 ssl http2;
        server_name __DOMAIN__;

        ssl_certificate /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
EOF

    # Replace placeholders
    sed -i "s/__DOMAIN__/$DOMAIN/g" proxy/nginx.conf
    sed -i "s/__BACKEND_PORT__/$BACKEND_PORT/g" proxy/nginx.conf

    # Create certs directory
    mkdir -p certs

    # Install acme.sh if not exists
    if [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
        info "安装 acme.sh..."
        curl -fsSL https://get.acme.sh | sh
    fi

    ACME_SH="$HOME/.acme.sh/acme.sh"

    # Issue certificate
    info "申请 SSL 证书..."
    mkdir -p "$INSTALL_DIR/certs"

    if [ "${SSL_PROVIDER:-}" = "2" ] && [ -n "$ALI_AK" ] && [ -n "$ALI_SK" ]; then
        # Aliyun DNS API
        $ACME_SH --issue --dns dns_ali -d "$DOMAIN" --home "$HOME/.acme.sh" 2>/dev/null || {
            warn "证书申请失败"
            return
        }
    elif [ "${SSL_PROVIDER:-}" = "1" ] && [ -n "$EMAIL" ]; then
        # Let's Encrypt with webroot
        $ACME_SH --issue -d "$DOMAIN" --webroot "$INSTALL_DIR/nginx" -k ec-256 --home "$HOME/.acme.sh" 2>/dev/null || {
            warn "证书申请失败"
            return
        }
    else
        warn "跳过 SSL 配置"
        return
    fi

    # Install certificate
    $ACME_SH --install-cert -d "$DOMAIN" --key-file "$INSTALL_DIR/certs/privkey.pem" --fullchain-file "$INSTALL_DIR/certs/fullchain.pem" --reloadcmd "docker restart subforge-proxy" 2>/dev/null

    if [ -f "$INSTALL_DIR/certs/fullchain.pem" ]; then
        log "SSL 证书安装完成"
    else
        warn "证书安装失败"
    fi

    # Setup auto-renewal
    info "配置自动续期..."
    CRON_LINE="0 3 * * * $ACME_SH --cron --home $HOME/.acme.sh > /dev/null 2>&1"
    if ! crontab -l 2>/dev/null | grep -q "acme.sh"; then
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
        log "已配置自动续期"
    fi
}

start_services() {
    info "启动服务..."

    # Force change to install directory
    cd "$INSTALL_DIR" || error "无法进入目录: $INSTALL_DIR"

    # Verify docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        error "docker-compose.yml 不存在于 $(pwd)"
    fi

    # Get version info from VERSION file
    APP_VERSION=$(cat VERSION 2>/dev/null || echo "unknown")
    APP_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    # Run docker compose with version args
    docker compose down --remove-orphans 2>/dev/null || true
    VERSION=$APP_VERSION COMMIT=$APP_COMMIT docker compose up -d

    log "服务已启动 (版本: $APP_VERSION)"
}

install_cli() {
    info "安装命令行工具..."

    # Create /usr/local/bin/subforge symlink
    if [ -f "$INSTALL_DIR/scripts/subforge" ]; then
        ln -sf "$INSTALL_DIR/scripts/subforge" /usr/local/bin/subforge
        chmod +x /usr/local/bin/subforge
        log "命令行工具已安装: subforge"
    fi
}

get_public_ip() {
    curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || \
    curl -s --connect-timeout 5 https://ipinfo.io/ip 2>/dev/null || \
    hostname -I | awk '{print $1}'
}

main() {
    echo -e "${CYAN}"
    echo "  ____        _   _____                   "
    echo " / ___| _   _| | |  ___|___  _ __ ___    "
    echo " \___ \ | | | | | |_ / _ \| '__/ _ \   "
    echo "  ___) | |_| | | |  _| (_) | | |  __/   "
    echo " |____/ \__,_|_| |_|  \___/|_|  \___|   "
    echo ""
    echo -e "  一键安装脚本 v${VERSION:-unknown}"
    echo -e "${NC}"

    check_root
    detect_os

    # Check for existing installation
    check_existing_install

    # Interactive configuration
    interactive_config

    # Install dependencies
    install_docker
    install_compose

    # Setup project
    clone_repo
    download_images
    ensure_nginx_config
    load_images
    generate_config
    build_frontend

    # Start services
    start_services

    # Install CLI tool
    install_cli

    PUBLIC_IP=$(get_public_ip)

    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  ✅ 安装完成!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}访问地址:${NC}"
    if [ -n "$DOMAIN" ]; then
        echo -e "    ${CYAN}https://${DOMAIN}:${SSL_PORT}${NC}"
    fi
    echo -e "    ${CYAN}http://${PUBLIC_IP}:${FRONTEND_PORT}${NC}"
    echo ""
    echo -e "  ${BOLD}登录信息:${NC}"
    echo -e "    用户名: ${CYAN}${ADMIN_USERNAME}${NC}"
    echo -e "    密  码: ${CYAN}${ADMIN_PASSWORD}${NC}"
    echo ""
    echo -e "  ${BOLD}订阅格式:${NC}"
    echo -e "    ${DIM}登录后在订阅列表中获取 token，然后替换下方 {token}${NC}"
    echo ""

    # ClashMeta 订阅
    echo -e "    ${GREEN}${BOLD}---------- ClashMeta 订阅 ----------${NC}"
    if [ -n "$DOMAIN" ]; then
        echo -e "    ${CYAN}https://${DOMAIN}:${SSL_PORT}/sub/{token}/export?target=clash${NC}"
        echo -e "    ${DIM}在线二维码:${NC}"
        echo -e "    ${DIM}https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${DOMAIN}:${SSL_PORT}/sub/{token}/export?target=clash${NC}"
    fi
    echo -e "    ${CYAN}http://${PUBLIC_IP}:${FRONTEND_PORT}/sub/{token}/export?target=clash${NC}"
    echo ""

    # 默认订阅 (base64)
    echo -e "    ${GREEN}${BOLD}---------- 默认订阅 (base64) ----------${NC}"
    if [ -n "$DOMAIN" ]; then
        echo -e "    ${CYAN}https://${DOMAIN}:${SSL_PORT}/sub/{token}/export?target=base64${NC}"
        echo -e "    ${DIM}在线二维码:${NC}"
        echo -e "    ${DIM}https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://${DOMAIN}:${SSL_PORT}/sub/{token}/export?target=base64${NC}"
    fi
    echo -e "    ${CYAN}http://${PUBLIC_IP}:${FRONTEND_PORT}/sub/{token}/export?target=base64${NC}"
    echo ""
    echo -e "  ${BOLD}快捷管理:${NC}"
    echo -e "    ${CYAN}subforge${NC}  ${DIM}# 输入此命令打开交互式管理菜单${NC}"
    echo ""
    echo -e "  ${BOLD}其他命令:${NC}"
    echo -e "    ${DIM}cd ${INSTALL_DIR} && docker compose logs -f${NC}"
    echo -e "    ${DIM}cd ${INSTALL_DIR} && docker compose restart${NC}"
    if [ -n "$DOMAIN" ]; then
        echo -e "    ${DIM}cd ${INSTALL_DIR} && docker compose --profile proxy up -d  # 启动域名代理${NC}"
    fi
    echo ""
}

main "$@"

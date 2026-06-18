#!/bin/bash
# SubForge One-Click Installer v1.0.1
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
VERSION="1.0.1"

# Default values
PORT=8080
ADMIN_USERNAME="admin"
ADMIN_PASSWORD=""
DOMAIN=""
EMAIL=""
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

    if [ -d "$INSTALL_DIR/.git" ]; then
        cd "$INSTALL_DIR"
        OLD=$(cat VERSION 2>/dev/null || echo "unknown")
        git fetch origin main 2>/dev/null
        git reset --hard origin/main 2>/dev/null
        NEW=$(cat VERSION 2>/dev/null || echo "unknown")
        if [ "$OLD" != "$NEW" ]; then
            IS_UPGRADE=true
            log "检测到新版本: $OLD → $NEW"
        else
            log "已是最新版本"
        fi
    else
        rm -rf "$INSTALL_DIR"
        git clone "$REPO" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        log "代码已克隆"
    fi
}

check_existing_install() {
    if [ -f "$INSTALL_DIR/.env" ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"
        echo -e "${YELLOW}${BOLD}  📋 检测到已有安装${NC}"
        echo -e "${YELLOW}${BOLD}═══════════════════════════════════════${NC}"

        # Load existing config
        source "$INSTALL_DIR/.env" 2>/dev/null || true

        echo -e "  端口:         ${CYAN}${PORT:-8080}${NC}"
        echo -e "  管理员账户:   ${CYAN}${ADMIN_USERNAME:-admin}${NC}"
        echo -e "  管理员密码:   ${CYAN}${ADMIN_PASSWORD:-****}${NC}"
        [ -n "${DB_PASSWORD:-}" ] && echo -e "  数据库密码:   ${CYAN}${DB_PASSWORD}${NC}"
        echo ""

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

    if [ "$USE_EXISTING_DATA" = true ]; then
        log "使用已有配置"
        return
    fi

    # Port
    echo -e "${YELLOW}访问端口 [${PORT}]${NC}"
    read -p "> " input
    PORT="${input:-$PORT}"

    # Admin username
    echo -e "${YELLOW}管理员账户 [${ADMIN_USERNAME}]${NC}"
    read -p "> " input
    ADMIN_USERNAME="${input:-$ADMIN_USERNAME}"

    # Admin password
    echo -e "${YELLOW}管理员密码 随机生成${NC}"
    read -p "> " input
    ADMIN_PASSWORD="${input:-$(gen_pass 16)}"

    # Domain (optional)
    echo ""
    echo -e "${DIM}--- 可选: 域名/SSL 配置 留空跳过 ---${NC}"
    echo -e "${YELLOW}域名 例: example.com${NC}"
    read -p "> " input
    DOMAIN="${input:-}"
    if [ -n "$DOMAIN" ]; then
        echo -e "${YELLOW}邮箱 用于SSL证书${NC}"
        read -p "> " input
        EMAIL="${input:-}"
    fi

    # Confirm
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  📋 配置确认${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "  端口:         ${CYAN}${PORT}${NC}"
    echo -e "  管理员账户:   ${CYAN}${ADMIN_USERNAME}${NC}"
    echo -e "  管理员密码:   ${CYAN}${ADMIN_PASSWORD}${NC}"
    [ -n "$DOMAIN" ] && echo -e "  域名:         ${CYAN}${DOMAIN}${NC}"
    [ -n "$EMAIL" ] && echo -e "  邮箱:         ${CYAN}${EMAIL}${NC}"
    echo ""

    echo -e "${YELLOW}确认开始安装? [Y/n]${NC}"
    read -p "> " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        error "安装已取消"
    fi
}

load_images() {
    info "加载预构建镜像..."

    if [ -f "$INSTALL_DIR/images/subforge-backend.tar.gz" ]; then
        docker load < "$INSTALL_DIR/images/subforge-backend.tar.gz"
        log "后端镜像已加载"
    else
        warn "后端镜像不存在，将使用本地构建"
    fi

    if [ -f "$INSTALL_DIR/images/subforge-frontend.tar.gz" ]; then
        docker load < "$INSTALL_DIR/images/subforge-frontend.tar.gz"
        log "前端镜像已加载"
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
        [ -z "$DB_PASSWORD" ] && DB_PASSWORD=$(gen_pass 24)
        [ -z "$JWT_SECRET" ] && JWT_SECRET=$(gen_pass 32)
        [ -z "$ADMIN_PASSWORD" ] && ADMIN_PASSWORD=$(gen_pass 16)

        cat > .env <<EOF
PORT=${PORT}
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=${DB_PASSWORD}
JWT_SECRET=${JWT_SECRET}
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF
    fi

    log "配置已生成"
}

build_frontend() {
    if docker image inspect subforge-frontend:latest >/dev/null 2>&1; then
        log "使用预构建前端镜像，跳过编译"
        return
    fi

    info "编译前端..."
    cd "$INSTALL_DIR/frontend"
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        node:20-alpine \
        sh -c "npm config set registry https://registry.npmmirror.com && npm ci --legacy-peer-deps 2>/dev/null || npm install --legacy-peer-deps && npm run build"
    log "前端编译完成"
}

setup_ssl() {
    if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
        return
    fi

    echo ""
    info "配置域名和 SSL..."

    # Install certbot
    if ! command -v certbot &>/dev/null; then
        warn "安装 certbot..."
        if command -v apt-get &>/dev/null; then
            apt-get update -qq
            apt-get install -y -qq certbot python3-certbot-nginx
        elif command -v yum &>/dev/null; then
            yum install -y -q epel-release 2>/dev/null || true
            yum install -y -q certbot python3-certbot-nginx
        else
            warn "无法自动安装 certbot，请手动安装后运行: setup-ssl.sh"
            return
        fi
    fi

    # Update nginx config
    cd "$INSTALL_DIR"
    if [ -f nginx/nginx-ssl.conf ]; then
        cp nginx/nginx-ssl.conf nginx/nginx.conf
        sed -i "s#your-domain\.com#${DOMAIN}#g" nginx/nginx.conf 2>/dev/null || \
            sed -i '' "s#your-domain\.com#${DOMAIN}#g" nginx/nginx.conf
    fi

    # Get SSL certificate
    info "申请 SSL 证书..."
    docker compose stop nginx 2>/dev/null || true
    sleep 2

    if certbot certonly --standalone \
        -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive; then
        log "SSL 证书申请成功"
    else
        warn "SSL 证书申请失败，请确保域名已解析到本机 IP"
        docker compose start nginx 2>/dev/null || true
        return
    fi

    # Setup auto-renewal
    HOOK_DIR="/etc/letsencrypt/renewal-hooks/deploy"
    mkdir -p "$HOOK_DIR"
    cat > "$HOOK_DIR/restart-nginx.sh" <<'EOF'
#!/bin/bash
cd /opt/subforge && docker compose restart nginx 2>/dev/null || true
EOF
    chmod +x "$HOOK_DIR/restart-nginx.sh"

    CRON_LINE="0 3,15 * * * certbot renew --quiet --deploy-hook '/etc/letsencrypt/renewal-hooks/deploy/restart-nginx.sh'"
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    fi

    docker compose start nginx 2>/dev/null || true
    log "SSL 配置完成"
}

start_services() {
    info "启动服务..."
    cd "$INSTALL_DIR" || error "无法进入安装目录"

    docker compose down --remove-orphans 2>/dev/null || true
    docker compose up -d

    log "服务已启动"
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
    echo -e "  ${BOLD}一键安装脚本 v${VERSION}${NC}"
    echo ""

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
    load_images
    generate_config
    build_frontend

    # Start services
    start_services
    wait_health

    # Setup SSL if domain provided
    setup_ssl

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
        echo -e "    ${CYAN}https://${DOMAIN}${NC}"
    else
        echo -e "    ${CYAN}http://${PUBLIC_IP}:${PORT}${NC}"
    fi
    echo ""
    echo -e "  ${BOLD}登录信息:${NC}"
    echo -e "    用户名: ${CYAN}${ADMIN_USERNAME}${NC}"
    echo -e "    密  码: ${CYAN}${ADMIN_PASSWORD}${NC}"
    echo ""
    echo -e "  ${BOLD}快捷管理:${NC}"
    echo -e "    ${CYAN}subforge${NC}  ${DIM}# 输入此命令打开交互式管理菜单${NC}"
    echo ""
    echo -e "  ${BOLD}其他命令:${NC}"
    echo -e "    ${DIM}cd ${INSTALL_DIR} && docker compose logs -f${NC}"
    echo -e "    ${DIM}cd ${INSTALL_DIR} && docker compose restart${NC}"
    if [ -n "$DOMAIN" ]; then
        echo -e "    ${DIM}certbot renew  # SSL 续期${NC}"
    fi
    echo ""
}

main "$@"

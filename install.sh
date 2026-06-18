#!/bin/bash
# SubForge One-Click Installer v1.0.1
# Usage: curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh | sudo bash
#    or: sudo bash install.sh

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
VERSION="1.0.2"

# Default values
FRONTEND_PORT=8080
BACKEND_PORT=8081
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

        # Set defaults from existing config
        FRONTEND_PORT="${FRONTEND_PORT:-8080}"
        BACKEND_PORT="${BACKEND_PORT:-8081}"
        ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
        ADMIN_PASSWORD="${ADMIN_PASSWORD:-****}"
        DOMAIN="${DOMAIN:-}"
        EMAIL="${EMAIL:-}"
        ALI_AK="${ALI_AK:-}"
        ALI_SK="${ALI_SK:-}"

        echo -e "  前端端口:     ${CYAN}${FRONTEND_PORT}${NC}"
        echo -e "  后端端口:     ${CYAN}${BACKEND_PORT}${NC}"
        echo -e "  管理员账户:   ${CYAN}${ADMIN_USERNAME}${NC}"
        echo -e "  管理员密码:   ${CYAN}${ADMIN_PASSWORD}${NC}"
        [ -n "${DB_PASSWORD:-}" ] && echo -e "  数据库密码:   ${CYAN}${DB_PASSWORD}${NC}"
        [ -n "$DOMAIN" ] && echo -e "  域名:         ${CYAN}${DOMAIN}${NC}"
        [ -n "$EMAIL" ] && echo -e "  邮箱:         ${CYAN}${EMAIL}${NC}"
        [ -n "$ALI_AK" ] && echo -e "  阿里云 AK:    ${CYAN}${ALI_AK:0:8}****${NC}"
        [ -n "$ALI_SK" ] && echo -e "  阿里云 SK:    ${CYAN}${ALI_SK:0:4}****${NC}"
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

    # Load existing config if available
    if [ -f "$INSTALL_DIR/.env" ]; then
        source "$INSTALL_DIR/.env" 2>/dev/null || true
        FRONTEND_PORT="${FRONTEND_PORT:-8080}"
        BACKEND_PORT="${BACKEND_PORT:-8081}"
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

    # Frontend port
    echo -e "${YELLOW}前端访问端口 [${FRONTEND_PORT}]${NC}"
    read -p "> " input
    FRONTEND_PORT="${input:-$FRONTEND_PORT}"

    # Backend port
    echo -e "${YELLOW}后端 API 端口 [${BACKEND_PORT}]${NC}"
    read -p "> " input
    BACKEND_PORT="${input:-$BACKEND_PORT}"

    # Admin username
    echo -e "${YELLOW}管理员账户 [${ADMIN_USERNAME}]${NC}"
    read -p "> " input
    ADMIN_USERNAME="${input:-$ADMIN_USERNAME}"

    # Admin password
    echo -e "${YELLOW}管理员密码 随机生成${NC}"
    read -p "> " input
    ADMIN_PASSWORD="${input:-$(gen_pass 16)}"

    # Domain configuration
    echo ""
    echo -e "${DIM}--- 域名/SSL 配置 留空跳过 ---${NC}"

    # Domain
    if [ -n "$DOMAIN" ]; then
        echo -e "${YELLOW}域名 [${DOMAIN}]${NC}"
    else
        echo -e "${YELLOW}域名 例: example.com${NC}"
    fi
    read -p "> " input
    DOMAIN="${input:-$DOMAIN}"

    if [ -n "$DOMAIN" ]; then
        # SSL provider selection
        echo ""
        echo -e "${YELLOW}SSL 证书来源:${NC}"
        echo -e "  1) Let's Encrypt (免费)"
        echo -e "  2) 阿里云 SSL 证书"
        echo -e "  3) 跳过 SSL 配置"
        read -p "> " ssl_choice
        SSL_PROVIDER="${ssl_choice:-1}"

        if [ "$SSL_PROVIDER" = "2" ]; then
            # Alibaba Cloud SSL
            if [ -n "$ALI_AK" ]; then
                echo -e "${YELLOW}阿里云 AccessKey ID [${ALI_AK:0:8}****]${NC}"
            else
                echo -e "${YELLOW}阿里云 AccessKey ID${NC}"
            fi
            read -p "> " input
            ALI_AK="${input:-$ALI_AK}"

            if [ -n "$ALI_SK" ]; then
                echo -e "${YELLOW}阿里云 AccessKey Secret [${ALI_SK:0:4}****]${NC}"
            else
                echo -e "${YELLOW}阿里云 AccessKey Secret${NC}"
            fi
            read -p "> " input
            ALI_SK="${input:-$ALI_SK}"
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
    echo -e "  管理员账户:   ${CYAN}${ADMIN_USERNAME}${NC}"
    echo -e "  管理员密码:   ${CYAN}${ADMIN_PASSWORD}${NC}"
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
FRONTEND_PORT=${FRONTEND_PORT}
BACKEND_PORT=${BACKEND_PORT}
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=${DB_PASSWORD}
JWT_SECRET=${JWT_SECRET}
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
DOMAIN=${DOMAIN:-}
EMAIL=${EMAIL:-}
ALI_AK=${ALI_AK:-}
ALI_SK=${ALI_SK:-}
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
    if [ -z "$DOMAIN" ]; then
        return
    fi

    echo ""
    info "配置域名访问..."

    # First, configure nginx to accept domain (HTTP)
    cd "$INSTALL_DIR"
    cat > nginx/nginx.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;

    # API reverse proxy
    location /api/ {
        proxy_pass http://172.17.0.1:${BACKEND_PORT:-8081};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }

    # Client subscription endpoint
    location /sub/ {
        proxy_pass http://172.17.0.1:${BACKEND_PORT:-8081};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Frontend
    location / {
        root /usr/share/nginx/html;
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

    # Restart nginx to apply domain config
    cd "$INSTALL_DIR"
    docker compose restart nginx
    sleep 2

    # Test domain access
    if curl -sf "http://${DOMAIN}" >/dev/null 2>&1; then
        log "域名访问正常: http://${DOMAIN}"
    else
        warn "域名访问失败，请检查 DNS 解析"
    fi

    # Now setup SSL
    if [ "$SSL_PROVIDER" = "2" ] && [ -n "$ALI_AK" ] && [ -n "$ALI_SK" ]; then
        setup_aliyun_ssl
    elif [ "$SSL_PROVIDER" = "1" ] && [ -n "$EMAIL" ]; then
        setup_letsencrypt_ssl
    else
        warn "跳过 SSL 配置"
    fi

    # Final restart
    cd "$INSTALL_DIR"
    docker compose up -d
}

setup_letsencrypt_ssl() {
    info "使用 Let's Encrypt..."

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
            warn "无法自动安装 certbot"
            return
        fi
    fi

    # Stop services
    docker compose down 2>/dev/null || true
    sleep 3

    # Free port 80
    if lsof -i :80 >/dev/null 2>&1; then
        fuser -k 80/tcp 2>/dev/null || true
        sleep 2
    fi

    if certbot certonly --standalone \
        -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive; then
        log "SSL 证书申请成功"

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
    else
        warn "SSL 证书申请失败，请确保域名已解析到本机 IP"
    fi
}

setup_aliyun_ssl() {
    info "使用阿里云 DNS API 自动申请 SSL 证书..."

    # Create certificate directory
    CERT_DIR="$INSTALL_DIR/ssl/${DOMAIN}"
    mkdir -p "$CERT_DIR"

    # Install acme.sh if not present
    if ! command -v acme.sh &>/dev/null && [ ! -f ~/.acme.sh/acme.sh ]; then
        info "安装 acme.sh..."
        curl -fsSL https://get.acme.sh | sh -s email="$EMAIL"
        source ~/.acme.sh/acme.sh.env 2>/dev/null || true
    fi

    ACME_SH="$HOME/.acme.sh/acme.sh"
    if [ ! -f "$ACME_SH" ]; then
        ACME_SH="acme.sh"
    fi

    # Configure Alibaba Cloud DNS API
    info "配置阿里云 DNS API..."
    export Ali_Key="$ALI_AK"
    export Ali_Secret="$ALI_SK"

    # Issue certificate using DNS API
    info "申请 SSL 证书..."
    $ACME_SH --issue \
        --dns dns_ali \
        -d "$DOMAIN" \
        --force 2>&1 | tee /tmp/acme.log

    if [ $? -eq 0 ] || grep -q "Success" /tmp/acme.log 2>/dev/null; then
        log "SSL 证书申请成功!"

        # Install certificate
        info "安装证书..."
        $ACME_SH --install-cert -d "$DOMAIN" \
            --key-file "$CERT_DIR/${DOMAIN}.key" \
            --fullchain-file "$CERT_DIR/${DOMAIN}.pem" \
            --reloadcmd "cd $INSTALL_DIR && docker compose restart nginx" 2>&1

        if [ -f "$CERT_DIR/${DOMAIN}.pem" ] && [ -f "$CERT_DIR/${DOMAIN}.key" ]; then
            log "证书已安装到: $CERT_DIR"

            # Update nginx config with SSL
            cat > "$INSTALL_DIR/nginx/nginx.conf" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/nginx/certs/${DOMAIN}.pem;
    ssl_certificate_key /etc/nginx/certs/${DOMAIN}.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;

    # API reverse proxy
    location /api/ {
        proxy_pass http://172.17.0.1:${BACKEND_PORT:-8081};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }

    # Client subscription endpoint
    location /sub/ {
        proxy_pass http://172.17.0.1:${BACKEND_PORT:-8081};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Frontend
    location / {
        root /usr/share/nginx/html;
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

            # Mount certs directory
            mkdir -p "$INSTALL_DIR/certs"
            ln -sf "$CERT_DIR" "$INSTALL_DIR/certs/$DOMAIN"

            # Restart nginx
            cd "$INSTALL_DIR"
            docker compose restart nginx

            log "SSL 配置完成!"
        else
            warn "证书安装失败"
        fi
    else
        warn "SSL 证书申请失败"
        cat /tmp/acme.log 2>/dev/null
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

    # Run docker compose
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

ensure_nginx_config() {
    info "检查 Nginx 配置..."

    # Create nginx directory if not exists
    mkdir -p "$INSTALL_DIR/nginx"

    # Create default nginx config if not exists
    if [ ! -f "$INSTALL_DIR/nginx/nginx-python.conf" ]; then
        cat > "$INSTALL_DIR/nginx/nginx-python.conf" <<EOF
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;
    client_max_body_size 10m;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=30r/s;

    # Gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 1000;

    server {
        listen 80;
        server_name _;

        # Security headers
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Hide server info
        server_tokens off;

        # API reverse proxy
        location /api/ {
            limit_req zone=api burst=50 nodelay;
            proxy_pass http://172.17.0.1:8081;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_read_timeout 300s;
        }

        # Client subscription endpoint
        location /sub/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://172.17.0.1:8081;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }

        # Frontend (static files)
        location / {
            root /usr/share/nginx/html;
            try_files \$uri \$uri/ /index.html;
        }
    }
}
EOF
        log "Nginx 配置已创建"
    fi

    # Always update nginx config with current BACKEND_PORT
    # Match both numeric ports and shell variable expressions like ${BACKEND_PORT:-8081}
    sed -i "s|proxy_pass http://172.17.0.1:[^;]*;|proxy_pass http://172.17.0.1:${BACKEND_PORT:-8081};|g" "$INSTALL_DIR/nginx/nginx-python.conf" 2>/dev/null || true
}

check_containers() {
    info "检查容器状态..."

    # Check each container
    local containers=("subforge-db" "subforge-backend" "subforge-nginx")
    local all_healthy=true

    for container in "${containers[@]}"; do
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not found")
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")

        if [ "$status" = "running" ]; then
            if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
                log "$container: 运行正常"
            else
                warn "$container: 运行中但健康检查失败 ($health)"
                all_healthy=false
            fi
        else
            warn "$container: 未运行 ($status)"
            all_healthy=false
        fi
    done

    if [ "$all_healthy" = true ]; then
        log "所有容器运行正常"
    else
        warn "部分容器有问题，尝试重启..."
        cd "$INSTALL_DIR"
        docker compose down 2>/dev/null || true
        sleep 2
        docker compose up -d
        sleep 5
    fi
}

wait_health() {
    info "等待服务就绪..."

    local max=60
    local count=0

    while [ $count -lt $max ]; do
        if curl -sf "http://localhost:${FRONTEND_PORT}/api/health" >/dev/null 2>&1; then
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
    ensure_nginx_config
    load_images
    generate_config
    build_frontend

    # Start services
    start_services
    wait_health
    check_containers

    # Setup SSL if domain provided
    setup_ssl

    # Final container check
    check_containers

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
        echo -e "    ${CYAN}http://${PUBLIC_IP}:${FRONTEND_PORT}${NC}"
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

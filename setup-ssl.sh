#!/bin/bash

# ── Ensure we can read from the terminal even when piped ──
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

INSTALL_DIR="/opt/subforge"

echo -e "${CYAN}${BOLD}SubForge SSL Setup (Let's Encrypt)${NC}"
echo ""

# Root check
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root${NC}"
    exit 1
fi

if [ ! -d "$INSTALL_DIR/.git" ]; then
    echo -e "${RED}SubForge not found at $INSTALL_DIR${NC}"
    echo -e "${DIM}Please run install.sh first${NC}"
    exit 1
fi

read -p "$(echo -e "${CYAN}域名 Domain: ${NC}")" DOMAIN
read -p "$(echo -e "${CYAN}邮箱 Email: ${NC}")" EMAIL

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}域名和邮箱为必填项${NC}"
    exit 1
fi

# ─────────────────────────────────────
# Step 1: Install certbot
# ─────────────────────────────────────
echo -e "${YELLOW}[1/5] 检查 certbot...${NC}"
if ! command -v certbot &>/dev/null; then
    echo -e "  ${YELLOW}安装 certbot...${NC}"
    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq certbot python3-certbot-nginx
    elif command -v dnf &>/dev/null; then
        dnf install -y -q certbot python3-certbot-nginx
    elif command -v yum &>/dev/null; then
        yum install -y -q epel-release 2>/dev/null || true
        yum install -y -q certbot python3-certbot-nginx
    elif command -v apk &>/dev/null; then
        apk add --no-cache certbot certbot-nginx
    elif command -v pacman &>/dev/null; then
        pacman -S --noconfirm certbot certbot-nginx
    else
        echo -e "  ${RED}✗ 无法自动安装 certbot，请手动安装${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓ certbot 已安装${NC}"
else
    echo -e "  ${GREEN}✓ $(certbot --version 2>&1 | head -1)${NC}"
fi

# ─────────────────────────────────────
# Step 2: Update nginx SSL config
# ─────────────────────────────────────
echo -e "${YELLOW}[2/5] 更新 nginx 配置...${NC}"
cd "$INSTALL_DIR"

if [ ! -f nginx/nginx-ssl.conf ]; then
    echo -e "  ${RED}✗ nginx-ssl.conf 不存在${NC}"
    exit 1
fi

# Replace placeholder domain (use # as sed delimiter since domain may contain dots)
cp nginx/nginx-ssl.conf nginx/nginx.conf
sed -i "s#your-domain\.com#${DOMAIN}#g" nginx/nginx.conf 2>/dev/null || \
    sed -i '' "s#your-domain\.com#${DOMAIN}#g" nginx/nginx.conf  # macOS compat

echo -e "  ${GREEN}✓ 配置已更新 (域名: ${DOMAIN})${NC}"

# ─────────────────────────────────────
# Step 3: Get SSL certificate
# ─────────────────────────────────────
echo -e "${YELLOW}[3/5] 申请 SSL 证书...${NC}"

# Use standalone mode (temporarily stops nginx on port 80)
cd "$INSTALL_DIR"
docker compose stop nginx 2>/dev/null || true
sleep 2

if certbot certonly --standalone \
    -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive; then
    echo -e "  ${GREEN}✓ 证书申请成功${NC}"
else
    echo -e "  ${RED}✗ 证书申请失败${NC}"
    echo -e "  ${DIM}请确保域名 ${DOMAIN} 已解析到本机 IP${NC}"
    docker compose start nginx 2>/dev/null || true
    exit 1
fi

# Restart nginx
docker compose start nginx 2>/dev/null || true

# ─────────────────────────────────────
# Step 4: Setup auto-renewal
# ─────────────────────────────────────
echo -e "${YELLOW}[4/5] 配置自动续期...${NC}"

# Create renewal hook to restart nginx after cert renewal
HOOK_DIR="/etc/letsencrypt/renewal-hooks/deploy"
mkdir -p "$HOOK_DIR"
cat > "$HOOK_DIR/restart-nginx.sh" <<'EOF'
#!/bin/bash
cd /opt/subforge && docker compose restart nginx 2>/dev/null || true
EOF
chmod +x "$HOOK_DIR/restart-nginx.sh"

# Setup cron job for renewal (twice daily, as recommended by Let's Encrypt)
CRON_LINE="0 3,15 * * * certbot renew --quiet --deploy-hook '/etc/letsencrypt/renewal-hooks/deploy/restart-nginx.sh'"
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo -e "  ${GREEN}✓ 已配置自动续期 (每天 3:00/15:00 检查)${NC}"
else
    echo -e "  ${GREEN}✓ 自动续期已存在${NC}"
fi

# ─────────────────────────────────────
# Step 5: Restart nginx with SSL
# ─────────────────────────────────────
echo -e "${YELLOW}[5/5] 重启 nginx...${NC}"
cd "$INSTALL_DIR"
docker compose restart nginx

# Verify
sleep 3
if curl -sf "https://${DOMAIN}" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ HTTPS 正常${NC}"
else
    echo -e "  ${YELLOW}⚠ HTTPS 暂时不可用，请稍后检查${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ SSL 配置完成!${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════${NC}"
echo ""
echo -e "  URL:     ${CYAN}https://${DOMAIN}${NC}"
echo -e "  证书:    ${DIM}/etc/letsencrypt/live/${DOMAIN}/${NC}"
echo -e "  自动续期: ${DIM}crontab -l | grep certbot${NC}"
echo ""
echo -e "  ${DIM}手动续期: certbot renew${NC}"
echo -e "  ${DIM}检查状态: certbot certificates${NC}"
echo ""

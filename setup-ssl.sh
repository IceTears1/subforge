#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}SubForge SSL Setup (Let's Encrypt)${NC}"
echo ""

read -p "$(echo -e ${CYAN}Domain name: ${NC})" DOMAIN
read -p "$(echo -e ${CYAN}Email for cert: ${NC})" EMAIL

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo -e "${RED}Domain and email are required${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/4] Installing certbot...${NC}"
if ! command -v certbot &>/dev/null; then
    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq certbot python3-certbot-nginx
    elif command -v yum &>/dev/null; then
        yum install -y certbot python3-certbot-nginx
    fi
fi

echo -e "${YELLOW}[2/4] Updating nginx config...${NC}"
INSTALL_DIR="/opt/subforge"
cd "$INSTALL_DIR"

# Update domain in SSL config
sed -i "s/your-domain.com/$DOMAIN/g" nginx/nginx-ssl.conf

# Use SSL config
cp nginx/nginx-ssl.conf nginx/nginx.conf

echo -e "${YELLOW}[3/4] Getting SSL certificate...${NC}"
certbot certonly --webroot -w "$INSTALL_DIR" -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive

echo -e "${YELLOW}[4/4] Restarting nginx...${NC}"
docker compose restart nginx

echo ""
echo -e "${GREEN}SSL setup complete!${NC}"
echo -e "URL: ${CYAN}https://${DOMAIN}${NC}"
echo ""
echo -e "Auto-renewal is configured via certbot timer."
echo -e "Check: ${CYAN}systemctl list-timers | grep certbot${NC}"

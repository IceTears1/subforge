#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  ____        _   _____                   "
echo " / ___| _   _| | |  ___|___  _ __ ___    "
echo " \___ \| | | | | | |_ / _ \| '__/ _ \   "
echo "  ___) | |_| | | |  _| (_) | | |  __/   "
echo " |____/ \__,_|_| |_|  \___/|_|  \___|   "
echo ""
echo "  VPN Subscription Universal Converter"
echo -e "${NC}"

# Generate random strings
generate_secret() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32
}

# Create .env if not exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}[1/4] Generating .env configuration...${NC}"
    DB_PASSWORD=$(generate_secret)
    JWT_SECRET=$(generate_secret)
    ADMIN_PASSWORD=$(generate_secret | head -c 16)

    cat > .env << EOF
FRONTEND_PORT=3001
BACKEND_PORT=45001
DB_PORT=45000
SSL_PORT=443
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
    echo -e "${GREEN}  .env created${NC}"
    echo -e "${YELLOW}  Default admin password: ${ADMIN_PASSWORD}${NC}"
    echo -e "${YELLOW}  Please save this password!${NC}"
else
    echo -e "${GREEN}[1/4] .env already exists, skipping${NC}"
fi

# Build and start
echo -e "${YELLOW}[2/4] Building Docker images...${NC}"
docker compose build --no-cache

echo -e "${YELLOW}[3/4] Starting services...${NC}"
docker compose up -d

# Wait for health
echo -e "${YELLOW}[4/4] Waiting for services to be ready...${NC}"
sleep 5

# Check status
if docker compose ps | grep -q "Up"; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  SubForge deployed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "  URL:      ${CYAN}http://localhost:3001${NC}"
    echo -e "  Username: ${CYAN}admin${NC}"
    if [ -n "${ADMIN_PASSWORD}" ]; then
        echo -e "  Password: ${CYAN}${ADMIN_PASSWORD}${NC}"
    else
        echo -e "  Password: ${CYAN}check .env file${NC}"
    fi
    echo ""
    echo -e "  ${YELLOW}Commands:${NC}"
    echo -e "    View logs:   ${CYAN}docker compose logs -f${NC}"
    echo -e "    Stop:        ${CYAN}docker compose down${NC}"
    echo -e "    Restart:     ${CYAN}docker compose restart${NC}"
    echo ""
else
    echo -e "${RED}Deployment failed. Check logs with: docker compose logs${NC}"
    exit 1
fi

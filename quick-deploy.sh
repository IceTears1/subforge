#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/subforge"
GO_VERSION="1.22.4"
NODE_VERSION="20"

echo -e "${CYAN}SubForge Quick Deploy (Debian/Ubuntu)${NC}"
echo ""

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}请先运行安装脚本${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

# Step 1: Stop everything
echo -e "${YELLOW}[1/7] 停止旧服务...${NC}"
docker compose down 2>/dev/null || true
pkill -f subforge 2>/dev/null || true
echo -e "  ${GREEN}✓ 完成${NC}"

# Step 2: Install Go
echo -e "${YELLOW}[2/7] 安装 Go...${NC}"
if command -v go &>/dev/null; then
    echo -e "  ${GREEN}✓ 已安装: $(go version | awk '{print $3}')${NC}"
else
    echo -e "  下载 Go ${GO_VERSION}..."
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin
    echo -e "  ${GREEN}✓ Go ${GO_VERSION} 已安装${NC}"
fi

# Step 3: Install Node.js
echo -e "${YELLOW}[3/7] 安装 Node.js...${NC}"
if command -v node &>/dev/null; then
    echo -e "  ${GREEN}✓ 已安装: $(node --version)${NC}"
else
    echo -e "  安装 Node.js ${NODE_VERSION}..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    apt-get install -y -qq nodejs
    npm config set registry https://registry.npmmirror.com
    echo -e "  ${GREEN}✓ Node.js $(node --version) 已安装${NC}"
fi

# Step 4: Build backend
echo -e "${YELLOW}[4/7] 编译后端...${NC}"
cd backend
export GOPROXY=https://goproxy.cn,direct
export PATH=$PATH:/usr/local/go/bin
/usr/local/go/bin/go mod tidy
CGO_ENABLED=0 /usr/local/go/bin/go build -o ../subforge ./cmd/server
cd ..
echo -e "  ${GREEN}✓ 后端编译完成 ($(ls -lh subforge | awk '{print $5}'))${NC}"

# Step 5: Build frontend
echo -e "${YELLOW}[5/7] 编译前端...${NC}"
cd frontend
npm install --legacy-peer-deps 2>/dev/null
npm run build
cd ..
echo -e "  ${GREEN}✓ 前端编译完成${NC}"

# Step 6: Start database and nginx
echo -e "${YELLOW}[6/7] 启动数据库和 Nginx...${NC}"
docker compose up -d postgres nginx
echo -e "  ${YELLOW}等待数据库就绪...${NC}"
sleep 10
echo -e "  ${GREEN}✓ 服务启动完成${NC}"

# Step 7: Run backend
echo -e "${YELLOW}[7/7] 启动后端服务...${NC}"
chmod +x subforge

# Create systemd service
cat > /etc/systemd/system/subforge.service << EOF
[Unit]
Description=SubForge Backend
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/subforge
Restart=always
RestartSec=5
EnvironmentFile=${INSTALL_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable subforge
systemctl start subforge
sleep 3

if systemctl is-active --quiet subforge; then
    echo -e "  ${GREEN}✓ 后端启动成功${NC}"
else
    echo -e "  ${RED}✗ 后端启动失败${NC}"
    journalctl -u subforge --no-pager -n 20
    exit 1
fi

# Get public IP
PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
PORT=$(grep PORT .env | cut -d'=' -f2)
PORT=${PORT:-8080}
ADMIN_PASSWORD=$(grep ADMIN_PASSWORD .env | cut -d'=' -f2)

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ 部署成功!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  URL:      ${CYAN}http://${PUBLIC_IP}:${PORT}${NC}"
echo -e "  用户名:   ${CYAN}admin${NC}"
echo -e "  密码:     ${CYAN}${ADMIN_PASSWORD}${NC}"
echo ""
echo -e "  ${YELLOW}管理命令:${NC}"
echo -e "    查看状态:   systemctl status subforge"
echo -e "    查看日志:   journalctl -u subforge -f"
echo -e "    重启服务:   systemctl restart subforge"
echo -e "    停止服务:   systemctl stop subforge"
echo -e "    更新版本:   cd ${INSTALL_DIR} && git pull && systemctl restart subforge"
echo ""

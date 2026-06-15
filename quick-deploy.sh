#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/subforge"

echo -e "${CYAN}SubForge Quick Deploy (No Docker Build)${NC}"
echo ""

# Check if installed
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}请先运行安装脚本${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

# Step 1: Stop everything
echo -e "${YELLOW}[1/6] 停止旧服务...${NC}"
docker compose down 2>/dev/null || true

# Step 2: Install Go if needed
echo -e "${YELLOW}[2/6] 检查 Go...${NC}"
if ! command -v go &>/dev/null; then
    echo -e "  安装 Go..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq golang
    elif command -v yum &>/dev/null; then
        yum install -y golang
    elif command -v apk &>/dev/null; then
        apk add --no-cache go
    fi
fi
echo -e "  ${GREEN}✓ Go $(go version | awk '{print $3}')${NC}"

# Step 3: Build backend
echo -e "${YELLOW}[3/6] 编译后端...${NC}"
cd backend
export GOPROXY=https://goproxy.cn,direct
go mod tidy
CGO_ENABLED=0 go build -o ../subforge ./cmd/server
cd ..
echo -e "  ${GREEN}✓ 编译完成${NC}"

# Step 4: Build frontend
echo -e "${YELLOW}[4/6] 编译前端...${NC}"
if command -v npm &>/dev/null; then
    cd frontend
    npm install --legacy-peer-deps
    npm run build
    cd ..
    echo -e "  ${GREEN}✓ 前端编译完成${NC}"
else
    echo -e "  ${YELLOW}跳过前端编译（npm 未安装）${NC}"
    echo -e "  ${YELLOW}使用预构建的前端文件${NC}"
fi

# Step 5: Start only database and nginx
echo -e "${YELLOW}[5/6] 启动数据库和 Nginx...${NC}"
docker compose up -d postgres nginx
sleep 5

# Step 6: Run backend directly
echo -e "${YELLOW}[6/6] 启动后端...${NC}"
chmod +x subforge

# Get port from .env
PORT=$(grep PORT .env | cut -d'=' -f2)
PORT=${PORT:-8080}

# Run backend in background
nohup ./subforge > subforge.log 2>&1 &
echo $! > subforge.pid
sleep 3

# Check if running
if kill -0 $(cat subforge.pid) 2>/dev/null; then
    echo -e "  ${GREEN}✓ 后端启动成功${NC}"
else
    echo -e "  ${RED}✗ 后端启动失败${NC}"
    cat subforge.log
    exit 1
fi

# Get public IP
PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ 部署成功!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  URL:      ${CYAN}http://${PUBLIC_IP}:${PORT}${NC}"
echo -e "  用户名:   ${CYAN}admin${NC}"
echo -e "  密码:     ${CYAN}$(grep ADMIN_PASSWORD .env | cut -d'=' -f2)${NC}"
echo ""
echo -e "  ${YELLOW}管理命令:${NC}"
echo -e "    查看日志:   tail -f ${INSTALL_DIR}/subforge.log"
echo -e "    停止服务:   kill \$(cat ${INSTALL_DIR}/subforge.pid)"
echo -e "    重启服务:   kill \$(cat ${INSTALL_DIR}/subforge.pid) && ./subforge &"
echo ""

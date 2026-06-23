#!/bin/bash
# SubForge 一键打包脚本
# 构建 Docker 镜像（支持多架构）、保存到 images/ 目录、创建 GitHub Release

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}SubForge 一键打包${NC}"
echo "=================="
echo ""

# 检查是否在 git 仓库
if [ ! -d ".git" ]; then
    echo -e "${RED}错误: 不在 git 仓库中${NC}"
    exit 1
fi

# 获取当前版本
VERSION=$(cat VERSION 2>/dev/null || echo "unknown")
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo -e "当前版本: ${CYAN}${VERSION}${NC}"
echo -e "Git 提交: ${CYAN}${COMMIT}${NC}"
echo ""

# 选择版本
echo -e "${YELLOW}版本选项:${NC}"
echo "  1) 使用当前版本: ${CYAN}${VERSION}${NC}"
echo "  2) 输入新版本"
echo ""
read -p "$(echo -e ${CYAN}选择 [1-2]: ${NC})" OPTION

case $OPTION in
    1)
        # 使用当前版本
        ;;
    2)
        read -p "$(echo -e ${CYAN}输入版本号 (例如 1.4.8): ${NC})" NEW_VERSION
        if [ -n "$NEW_VERSION" ]; then
            VERSION=$NEW_VERSION
            echo "$VERSION" > VERSION
            # 更新 install.sh 版本号
            sed -i '' "s/# SubForge One-Click Installer v.*/# SubForge One-Click Installer v${VERSION}/" install.sh
            echo -e "  ${GREEN}版本已更新为 ${VERSION}${NC}"
        fi
        ;;
    *)
        echo -e "${RED}无效选项${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}构建信息:${NC}"
echo -e "  版本: ${CYAN}${VERSION}${NC}"
echo -e "  提交: ${CYAN}${COMMIT}${NC}"
echo ""

# 选择构建架构
echo -e "${YELLOW}构建架构:${NC}"
echo "  1) 当前架构: ${CYAN}$(uname -m)${NC}"
echo "  2) 多架构 (amd64 + arm64) - 需要 docker buildx"
echo "  3) 仅 amd64"
echo "  4) 仅 arm64"
echo ""
read -p "$(echo -e ${CYAN}选择 [1-4]: ${NC})" ARCH_OPTION

case $ARCH_OPTION in
    1)
        ARCH_LIST=($(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/'))
        ;;
    2)
        ARCH_LIST=("amd64" "arm64")
        ;;
    3)
        ARCH_LIST=("amd64")
        ;;
    4)
        ARCH_LIST=("arm64")
        ;;
    *)
        echo -e "${RED}无效选项${NC}"
        exit 1
        ;;
esac

echo -e "  构建架构: ${CYAN}${ARCH_LIST[*]}${NC}"
echo ""

# 检查 docker buildx（多架构需要）
if [ ${#ARCH_LIST[@]} -gt 1 ]; then
    if ! docker buildx version &>/dev/null; then
        echo -e "${RED}多架构构建需要 docker buildx${NC}"
        echo -e "${YELLOW}安装 buildx: docker buildx create --use --name multiarch${NC}"
        exit 1
    fi

    # 检查是否有多架构 builder
    if ! docker buildx inspect multiarch &>/dev/null; then
        echo -e "${YELLOW}创建多架构 builder...${NC}"
        docker buildx create --name multiarch --driver docker-container --use
        docker buildx inspect --bootstrap
    fi
fi

# 确认
read -p "$(echo -e ${YELLOW}开始构建? [y/N]: ${NC})" CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "已取消"
    exit 0
fi

# 清理旧镜像
echo -e "${YELLOW}[1/5] 清理旧镜像...${NC}"
rm -f images/subforge-backend-*.tar.gz images/subforge-frontend-*.tar.gz 2>/dev/null || true
echo -e "  ${GREEN}清理完成${NC}"

# 构建函数
build_backend() {
    local arch=$1
    local tag="subforge-backend:v${VERSION}-${arch}"

    echo -e "${YELLOW}构建后端镜像 (${arch})...${NC}"

    if [ ${#ARCH_LIST[@]} -gt 1 ]; then
        # 多架构构建
        docker buildx build \
            --platform "linux/${arch}" \
            --build-arg VERSION=$VERSION \
            --build-arg COMMIT=$COMMIT \
            -t "$tag" \
            -f backend-python/Dockerfile \
            --load \
            backend-python/
    else
        # 单架构构建
        docker build \
            --build-arg VERSION=$VERSION \
            --build-arg COMMIT=$COMMIT \
            -t "$tag" \
            -f backend-python/Dockerfile \
            backend-python/
    fi
    echo -e "  ${GREEN}后端镜像构建完成 (${arch})${NC}"
}

build_frontend() {
    local arch=$1
    local tag="subforge-frontend:v${VERSION}-${arch}"

    echo -e "${YELLOW}构建前端镜像 (${arch})...${NC}"

    if [ ${#ARCH_LIST[@]} -gt 1 ]; then
        # 多架构构建
        docker buildx build \
            --platform "linux/${arch}" \
            -t "$tag" \
            -f frontend/Dockerfile \
            --load \
            frontend/
    else
        # 单架构构建
        docker build \
            -t "$tag" \
            -f frontend/Dockerfile \
            frontend/
    fi
    echo -e "  ${GREEN}前端镜像构建完成 (${arch})${NC}"
}

# 构建镜像
echo -e "${YELLOW}[2/5] 构建镜像...${NC}"
mkdir -p images

for arch in "${ARCH_LIST[@]}"; do
    build_backend "$arch"
    build_frontend "$arch"
done

# 保存镜像
echo -e "${YELLOW}[3/5] 保存镜像...${NC}"
for arch in "${ARCH_LIST[@]}"; do
    docker save "subforge-backend:v${VERSION}-${arch}" | gzip > "images/subforge-backend-v${VERSION}-${arch}.tar.gz"
    docker save "subforge-frontend:v${VERSION}-${arch}" | gzip > "images/subforge-frontend-v${VERSION}-${arch}.tar.gz"
done
echo -e "  ${GREEN}镜像已保存到 images/ 目录${NC}"

# 显示镜像大小
echo ""
echo -e "${YELLOW}镜像大小:${NC}"
ls -lh images/subforge-*-v${VERSION}-*.tar.gz
echo ""

# 提交更改
echo -e "${YELLOW}[4/5] 提交更改...${NC}"
git add -A
git commit -m "release: v${VERSION}" || echo -e "  ${YELLOW}没有需要提交的更改${NC}"
echo -e "  ${GREEN}提交完成${NC}"

# 推送到 GitHub
echo -e "${YELLOW}[5/5] 推送到 GitHub...${NC}"
git push origin main
echo -e "  ${GREEN}推送完成${NC}"

# 创建 GitHub Release
echo ""
echo -e "${YELLOW}创建 GitHub Release...${NC}"

# 构建 release 文件列表
RELEASE_FILES=""
for arch in "${ARCH_LIST[@]}"; do
    RELEASE_FILES="$RELEASE_FILES images/subforge-backend-v${VERSION}-${arch}.tar.gz images/subforge-frontend-v${VERSION}-${arch}.tar.gz"
done

if command -v gh &>/dev/null; then
    # 架构说明
    ARCH_NOTE=""
    if [ ${#ARCH_LIST[@]} -gt 1 ]; then
        ARCH_NOTE="

### 支持架构
- amd64 (x86_64)
- arm64 (aarch64/Apple Silicon)

### 安装命令
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh -o install.sh
sudo bash install.sh -v ${VERSION}
\`\`\`

安装脚本会自动检测系统架构并下载对应的镜像。"
    else
        ARCH_NOTE="

### 架构
- ${ARCH_LIST[0]}

### 安装命令
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh -o install.sh
sudo bash install.sh -v ${VERSION}
\`\`\`"
    fi

    gh release create "v${VERSION}" \
        --title "v${VERSION}" \
        --target main \
        --notes "## v${VERSION}${ARCH_NOTE}" \
        $RELEASE_FILES 2>/dev/null || \
    echo -e "  ${YELLOW}Release 可能已存在，请手动创建${NC}"
    echo -e "  ${GREEN}Release 创建完成${NC}"
else
    echo -e "  ${YELLOW}gh CLI 未安装，请手动创建 Release${NC}"
fi

echo ""
echo -e "${GREEN}==================${NC}"
echo -e "${GREEN}打包完成!${NC}"
echo ""
echo -e "  版本: ${CYAN}v${VERSION}${NC}"
echo -e "  架构: ${CYAN}${ARCH_LIST[*]}${NC}"
echo -e "  镜像: ${CYAN}images/subforge-*-v${VERSION}-*.tar.gz${NC}"
echo ""
echo -e "  ${YELLOW}GitHub Release:${NC}"
echo -e "    https://github.com/IceTears1/subforge/releases/tag/v${VERSION}"
echo ""
echo -e "  ${YELLOW}安装命令:${NC}"
echo -e "    curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh -o install.sh"
echo -e "    sudo bash install.sh -v ${VERSION}"
echo ""

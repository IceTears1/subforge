# ⚡ SubForge v1.4.2

VPN 订阅链接统一转换平台 — 一键部署，扁平化 UI，多账户支持

## ✨ 特性

- 🔄 **多格式转换** — 支持 Clash / sing-box / Surge / Loon / Quantumult X / Shadowrocket / Base64
- 🌍 **智能重命名** — 节点按区域自动识别并重命名 (🇭🇰 HK 01 | VMESS)
- 👥 **子账户系统** — 管理员创建子账户，隔离管理订阅
- 🔐 **JWT 认证** — 安全的账户验证机制
- 🐳 **一键部署** — Docker Compose 一键启动
- 📡 **可扩展 API** — RESTful 接口，插件化架构
- 🎨 **扁平化 UI** — 现代化 Naive UI 界面设计
- 📊 **监控面板** — 实时查看节点状态和延迟
- 🔔 **Webhook 通知** — 订阅更新自动通知
- 🔄 **定时刷新** — 自动定时更新订阅节点
- 🏷️ **标签管理** — 灵活的订阅分类标签
- ❤️ **收藏功能** — 常用节点一键收藏
- 📦 **备份恢复** — 支持数据导出和恢复
- 🔒 **SSL 证书** — 支持 Let's Encrypt 和阿里云证书自动配置
- ⚙️ **可配置端口** — 前后端端口独立配置
- 🛠️ **CLI 管理** — 交互式命令行管理工具
- 🎯 **指定版本安装** — 支持安装指定版本
- 🔧 **订阅格式化管道** — 支持过滤器和操作符系统

## 🚀 快速开始

### VPS 一键安装（推荐）

SSH 登录 VPS 后执行：

```bash
# 安装最新版本
curl -fsSL "https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh?t=$(date +%s)" -o install.sh; sudo bash install.sh

# 安装指定版本（从 GitHub Releases 下载预构建镜像）
curl -fsSL "https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh?t=$(date +%s)" -o install.sh; sudo bash install.sh -v 1.4.2
```

### 安装说明

- **最新版本**: 自动从 main 分支克隆代码，从 Releases 下载预构建镜像
- **指定版本**: 克隆指定 tag，从 Releases 下载对应版本的预构建镜像
- **镜像下载失败**: 自动回退到本地构建（需要较长时间）间）

### 安装流程

```
═══════════════════════════════════════
  ⚙️  配置安装参数
═══════════════════════════════════════

前端访问端口 [3001]: 
后端 API 端口 [3002]: 
管理员账户 [admin]: 
管理员密码 随机生成: admin123

--- 域名/SSL 配置 留空跳过 ---
域名 例: example.com: vpn.example.com

SSL 证书来源:
  1) Let's Encrypt (免费)
  2) 阿里云 SSL 证书
  3) 跳过 SSL 配置
> 2

阿里云 AccessKey ID: LTAI5txxxxxxxxx
阿里云 AccessKey Secret: xxxxxxxxxxxxx

═══════════════════════════════════════
  📋 配置确认
═══════════════════════════════════════
  前端端口:     3001
  后端端口:     3002
  管理员账户:   admin
  管理员密码:   admin123
  域名:         vpn.example.com
  SSL:          阿里云证书

确认开始安装? [Y/n]
```

### 安装完成

```
═══════════════════════════════════════
  ✅ 安装完成!
═══════════════════════════════════════

  访问地址:
    https://vpn.example.com:3003
    http://your-ip:3001

  登录信息:
    用户名: admin
    密  码: admin123

  ---------- ClashMeta 订阅 ----------
    https://vpn.example.com:3003/sub/{token}/export?target=clash
    在线二维码:
    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://vpn.example.com:3003/sub/{token}/export?target=clash

  ---------- 默认订阅 (base64) ----------
    https://vpn.example.com:3003/sub/{token}/export?target=base64
    在线二维码:
    https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=https://vpn.example.com:3003/sub/{token}/export?target=base64

  快捷管理:
    subforge  # 输入此命令打开交互式管理菜单
```

### 本地部署

```bash
# 1. 克隆项目
git clone https://github.com/IceTears1/subforge.git
cd subforge

# 2. 一键部署
chmod +x deploy.sh
./deploy.sh

# 3. 访问
open http://localhost:3001
```

### Docker Compose 部署

```bash
# 1. 复制配置文件
cp .env.example .env

# 2. 修改配置
vim .env
# FRONTEND_PORT=3001
# BACKEND_PORT=3002
# ADMIN_PASSWORD=your-password

# 3. 启动服务
VERSION=$(cat VERSION) COMMIT=$(git rev-parse --short HEAD) docker compose up -d

# 4. 查看日志
docker compose logs -f
```

## 📖 使用指南

### 登录系统

- 访问 `http://your-domain:PORT`
- 默认用户名：`admin`
- 密码：安装时设置的密码

### 添加订阅

1. 点击左侧菜单「订阅管理」
2. 点击「添加订阅」按钮
3. 输入订阅名称和 URL
4. 点击保存，系统自动拉取节点

### 导入单个节点

支持直接导入节点链接：

1. 点击「导入节点」按钮
2. 粘贴节点链接（支持多行）
3. 支持格式：`vmess://`、`vless://`、`trojan://`、`ss://`、`hysteria2://`

### 获取订阅链接

每个订阅都有唯一的访问链接：

```bash
# 单个订阅 (Clash 格式)
http://your-domain:PORT/sub/{token}/export?target=clash

# 单个订阅 (Base64 格式，适用于小飞机/Shadowrocket)
http://your-domain:PORT/sub/{token}/export?target=base64

# 合并所有订阅
http://your-domain:PORT/api/subscriptions/export-all?target=clash
```

支持的格式参数：
| 参数 | 说明 | 适用客户端 |
|------|------|------------|
| `target=clash` | Clash 配置（默认） | Clash / Mihomo |
| `target=singbox` | sing-box 配置 | sing-box |
| `target=base64` | Base64 订阅 | Shadowrocket / Quantumult X / Surge |
| `target=plain` | 纯文本 | 通用 |

### 节点管理

- **一键测速** — 测试所有节点延迟
- **区域筛选** — 按区域过滤节点
- **搜索** — 按名称/地址搜索
- **导出** — 导出订阅链接和二维码

### 节点分组

- 按区域分组
- 按协议分组
- 按状态分组
- 按订阅来源分组
- 每个分组支持单独导出

## 🛠️ CLI 管理工具

安装完成后，可使用 `subforge` 命令进行管理：

```bash
subforge
```

```
═══════════════════════════════════════
  🚀 SubForge 管理
═══════════════════════════════════════

  1) 查看状态
  2) 启动服务
  3) 停止服务
  4) 重启服务
  5) 查看日志 (实时)
  6) 查看后端日志
  7) 查看数据库日志
  8) 进入后端容器
  9) 进入数据库
  10) 备份数据库
  11) 恢复数据库
  12) 更新版本
  13) 查看版本
  0) 退出

═══════════════════════════════════════
请选择 [0-13]:
```

## ⚙️ 配置说明

### 环境变量 (.env)

```bash
# 端口配置
FRONTEND_PORT=3001      # 前端访问端口
BACKEND_PORT=3002       # 后端 API 端口
DB_PORT=45000           # 数据库端口
SSL_PORT=3003           # HTTPS 端口

# 数据库配置
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=your-db-password

# 认证配置
JWT_SECRET=your-jwt-secret
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-admin-password

# 域名/SSL 配置（可选）
DOMAIN=vpn.example.com
EMAIL=admin@example.com
ALI_AK=your-aliyun-access-key
ALI_SK=your-aliyun-secret-key
```

### 端口配置

| 服务 | 默认端口 | 说明 |
|------|----------|------|
| 前端 (Nginx) | 3001 | 用户访问的 Web 界面 |
| 后端 (FastAPI) | 3002 | API 服务端口 |
| 数据库 (PostgreSQL) | 45000 | 数据库端口 |
| HTTPS 代理 | 3003 | 域名访问时的 HTTPS 端口 |

### SSL 证书

#### Let's Encrypt（免费）

```bash
# 安装时选择 1
SSL 证书来源:
  1) Let's Encrypt (免费)
  2) 阿里云 SSL 证书
  3) 跳过 SSL 配置
> 1
```

#### 阿里云证书

```bash
# 安装时选择 2，提供 AK/SK
阿里云 AccessKey ID: LTAI5txxxxxxxxx
阿里云 AccessKey Secret: xxxxxxxxxxxxx

# 自动完成：
# 1. 安装 acme.sh
# 2. 配置阿里云 DNS API
# 3. 自动申请证书
# 4. 自动配置 Nginx
# 5. 自动续期
```

## 🔧 管理命令

### 服务管理

```bash
# 使用 CLI 工具（推荐）
subforge

# 或使用 Docker Compose
cd /opt/subforge
docker compose ps          # 查看状态
docker compose logs -d     # 查看日志
docker compose restart     # 重启服务
docker compose down        # 停止服务
docker compose up -d       # 启动服务
```

### 更新版本

```bash
# 使用 CLI 工具
subforge
# 选择 12) 更新版本

# 或手动更新
cd /opt/subforge
git pull origin main
VERSION=$(cat VERSION) COMMIT=$(git rev-parse --short HEAD) docker compose up -d --build

# 更新到指定版本
git fetch --tags
git checkout v1.2.3
VERSION=$(cat VERSION) COMMIT=$(git rev-parse --short HEAD) docker compose up -d --build
```

### 数据库备份

```bash
# 使用 CLI 工具
subforge
# 选择 10) 备份数据库

# 或手动备份
docker exec subforge-db pg_dump -U subforge subforge > backup.sql
```

### 数据库恢复

```bash
# 使用 CLI 工具
subforge
# 选择 11) 恢复数据库

# 或手动恢复
docker exec -i subforge-db psql -U subforge subforge < backup.sql
```

## 📡 API 接口

### 认证

```bash
# 登录获取 Token
curl -X POST http://localhost:3002/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your-password"}'
```

### 订阅管理

```bash
# 获取订阅列表
curl http://localhost:3002/api/subscriptions \
  -H "Authorization: Bearer <token>"

# 添加订阅
curl -X POST http://localhost:3002/api/subscriptions \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"机场A","url":"https://..."}'

# 刷新订阅
curl -X POST http://localhost:3002/api/subscriptions/1/refresh \
  -H "Authorization: Bearer <token>"

# 导入节点
curl -X POST http://localhost:3002/api/nodes/import \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"uris":"vmess://xxx\nvless://yyy"}'
```

### 节点管理

```bash
# 获取所有节点
curl http://localhost:3002/api/nodes/all \
  -H "Authorization: Bearer <token>"

# 测试节点延迟
curl -X POST http://localhost:3002/api/nodes/speedtest-all \
  -H "Authorization: Bearer <token>"
```

### 公开接口

```bash
# 获取订阅内容 (Clash 格式)
curl "http://localhost:3002/sub/{token}/export?target=clash"

# 获取订阅内容 (Base64 格式)
curl "http://localhost:3002/sub/{token}/export?target=base64"

# 按分组导出
curl "http://localhost:3002/sub/{token}/export/group?target=clash&group_by=region&group_value=HK"

# 健康检查
curl http://localhost:3002/api/health
```

## 🛡️ 安全特性

- **JWT 认证** — 安全的 Token 验证
- **密码加密** — bcrypt 哈希存储
- **API 限流** — 防止暴力破解
- **安全头** — CSP、XSS 防护等
- **CORS 配置** — 跨域访问控制
- **SSRF 防护** — 拦截私有/本地 IP

## 📊 支持协议

### 输入格式
- VMess
- VLESS
- Trojan
- Shadowsocks
- Hysteria2
- Clash YAML
- sing-box JSON

### 输出格式
| 格式 | target 参数 | 说明 |
|------|-------------|------|
| Clash/Mihomo | `clash` | YAML 格式 |
| sing-box | `singbox` | JSON 格式 |
| Surge | `surge` | Surge 配置格式 |
| Loon | `loon` | Loon 配置格式 |
| QX | `qx` | Quantumult X 配置格式 |
| Shadowrocket | `shadowrocket` | Base64 编码的 URI 列表 |
| Base64 | `base64` | Base64 编码的 URI 列表 |

## 🏗️ 项目结构

```
subforge/
├── backend-python/       # Python 后端 (FastAPI)
│   ├── app.py            # 主应用
│   ├── config.py         # 配置管理
│   ├── models/           # 数据库模型
│   │   ├── user.py
│   │   ├── subscription.py
│   │   ├── node.py
│   │   ├── apikey.py
│   │   └── audit.py
│   ├── parsers/          # 协议解析器
│   │   ├── vless.py
│   │   ├── vmess.py
│   │   ├── trojan.py
│   │   ├── ss.py
│   │   └── clash.py
│   ├── exporters/        # 订阅导出
│   │   ├── clash.py
│   │   ├── singbox.py
│   │   ├── surge.py
│   │   ├── loon.py
│   │   ├── qx.py
│   │   ├── shadowrocket.py
│   │   └── base64.py
│   ├── pipeline/         # 订阅格式化管道
│   │   ├── filters.py
│   │   ├── operators.py
│   │   └── pipeline.py
│   ├── utils/            # 工具函数
│   │   ├── auth.py
│   │   └── time.py
│   ├── requirements.txt  # Python 依赖
│   └── Dockerfile        # Docker 镜像
├── frontend/             # Vue3 前端
│   └── src/
│       ├── views/        # 页面组件
│       ├── components/   # 公共组件
│       ├── composables/  # Vue 组合式函数
│       ├── constants/    # 常量定义
│       ├── utils/        # 工具函数
│       ├── types/        # TypeScript 类型
│       ├── api/          # API 封装
│       └── stores/       # Pinia 状态管理
├── nginx/                # Nginx 配置
├── scripts/              # 运维脚本
│   └── subforge          # CLI 管理工具
├── images/               # 预构建 Docker 镜像
├── docs/                 # 项目文档
├── docker-compose.yml    # Docker 编排
├── install.sh            # 一键安装脚本
├── deploy.sh             # 本地部署脚本
├── update-vps.sh         # VPS 更新脚本
├── setup-ssl.sh          # SSL 配置脚本
├── VERSION               # 版本号
├── CHANGELOG.md          # 更新日志
└── .env.example          # 配置模板
```

## 🛠️ 开发指南

### 本地开发

```bash
# 启动数据库
docker compose up -d postgres

# 后端开发
cd backend-python
pip install -r requirements.txt
python app.py

# 前端开发
cd frontend
npm install
npm run dev
```

### 构建 Docker 镜像

```bash
# 构建后端镜像
VERSION=$(cat VERSION) COMMIT=$(git rev-parse --short HEAD) \
  docker build --build-arg VERSION=$VERSION --build-arg COMMIT=$COMMIT \
  -t subforge-backend:v${VERSION} \
  -f backend-python/Dockerfile backend-python/

# 构建前端镜像
cd frontend
docker build -t subforge-frontend:v${VERSION} .

# 保存镜像
docker save subforge-backend:v${VERSION} | gzip > images/subforge-backend-v${VERSION}.tar.gz
docker save subforge-frontend:v${VERSION} | gzip > images/subforge-frontend-v${VERSION}.tar.gz
```

### 添加新协议

1. 在 `backend-python/app.py` 中添加解析函数
2. 在 `parse_*` 系列函数中添加新协议支持
3. 在 `generate_*` 函数中添加导出支持

## 📚 文档

| 文档 | 说明 |
|------|------|
| [更新日志](CHANGELOG.md) | 版本更新记录 |

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 License

MIT License

## 🙏 致谢

- [Clash](https://github.com/Dreamacro/clash)
- [sing-box](https://github.com/SagerNet/sing-box)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Naive UI](https://www.naiveui.com/)
- [acme.sh](https://github.com/acmesh-official/acme.sh)

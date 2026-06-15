# ⚡ SubForge

VPN 订阅链接统一转换平台 — 一键部署，扁平化 UI，多账户支持

## 特性

- 🔄 **多格式转换** — 支持 Clash / sing-box / Surge / Loon / Quantumult X / Base64
- 🌍 **智能重命名** — 节点按区域自动识别并重命名 (🇭🇰 HK 01 | VMESS)
- 👥 **子账户系统** — 管理员创建子账户，隔离管理订阅
- 🔐 **JWT 认证** — 安全的账户验证机制
- 🐳 **一键部署** — Docker Compose 一键启动
- 📡 **可扩展 API** — RESTful 接口，插件化架构
- 🎨 **扁平化 UI** — 现代化 Naive UI 界面设计

## 快速开始

### VPS 一键安装（推荐）

SSH 登录 VPS 后执行：

```bash
curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh | sudo bash
```

自动完成：安装 Docker → 下载项目 → 生成密码 → 启动服务 → 输出访问地址

### 本地部署

```bash
# 一键部署
chmod +x deploy.sh
./deploy.sh

# 或手动
cp .env.example .env
docker compose up -d
```

访问 http://localhost:8080

默认账户: `admin` / 密码见 `.env` 文件

## 技术栈

| 组件 | 技术 |
|------|------|
| 后端 | Go + Gin + GORM |
| 前端 | Vue3 + Naive UI + TypeScript |
| 数据库 | PostgreSQL 15 |
| 部署 | Docker Compose + Nginx |

## 📚 文档

| 文档 | 说明 |
|------|------|
| [用户手册](docs/user-guide.md) | 完整的用户使用指南 |
| [API 文档](docs/api.md) | RESTful API 接口说明 |
| [开发文档](docs/development.md) | 开发环境搭建和架构说明 |
| [部署文档](docs/deployment.md) | 详细的部署和运维指南 |
| [更新日志](CHANGELOG.md) | 版本更新记录 |

## API 接口

```bash
# 登录
POST /api/auth/login
{"username": "admin", "password": "..."}

# 添加订阅
POST /api/subscriptions
Authorization: Bearer <token>
{"name": "机场A", "url": "https://..."}

# 在线转换
POST /api/convert
{"source_url": "https://...", "target": "clash", "rename": true}

# 格式检测
POST /api/detect
{"source": "https://..."}
```

## 支持协议

| 输入 | 输出 |
|------|------|
| VMess / VLESS / Trojan | Clash YAML |
| Shadowsocks / ShadowsocksR | sing-box JSON |
| Hysteria2 / TUIC | Surge / Loon |
| Clash YAML / sing-box JSON | Quantumult X |
| Base64 订阅 | Base64 |

## 项目结构

```
subforge/
├── backend/          # Go 后端
│   ├── cmd/server/   # 入口
│   ├── internal/
│   │   ├── parser/   # 解析器 (可扩展)
│   │   ├── renderer/ # 渲染器 (可扩展)
│   │   ├── smart/    # 智能引擎
│   │   ├── service/  # 业务逻辑
│   │   └── handler/  # HTTP 处理
│   └── migrations/   # 数据库初始化
├── frontend/         # Vue3 前端
│   └── src/
│       ├── views/    # 页面
│       ├── api/      # API 封装
│       └── stores/   # 状态管理
├── nginx/            # 反向代理配置
├── docker-compose.yml
└── deploy.sh         # 一键部署脚本
```

## License

MIT

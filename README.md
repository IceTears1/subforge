# ⚡ SubForge

VPN 订阅链接统一转换平台 — 一键部署，扁平化 UI，多账户支持

## ✨ 特性

- 🔄 **多格式转换** — 支持 Clash / sing-box / Surge / Loon / Quantumult X / Base64
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

## 🚀 快速开始

### VPS 一键安装（推荐）

SSH 登录 VPS 后执行：

```bash
curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh | sudo bash
```

自动完成：安装 Docker → 下载项目 → 生成密码 → 启动服务 → 输出访问地址

### 本地部署

```bash
# 1. 克隆项目
git clone https://github.com/IceTears1/subforge.git
cd subforge

# 2. 一键部署（自动生成密码）
chmod +x deploy.sh
./deploy.sh

# 3. 访问
open http://localhost:8080
```

### Docker Compose 部署

```bash
# 1. 复制配置文件
cp .env.example .env

# 2. 修改配置（重要！）
vim .env
# - 修改 ADMIN_PASSWORD
# - 修改 JWT_SECRET
# - 修改 DB_PASSWORD

# 3. 启动服务
docker compose up -d

# 4. 查看日志
docker compose logs -f
```

## 📖 使用指南

### 登录系统

- 访问 `http://your-domain:8080`
- 默认用户名：`admin`
- 密码：查看 `.env` 文件中的 `ADMIN_PASSWORD`

### 添加订阅

1. 点击左侧菜单「订阅管理」
2. 点击「添加订阅」按钮
3. 输入订阅名称和 URL
4. 点击保存，系统自动拉取节点

### 获取订阅链接

每个订阅都有唯一的访问链接：

```bash
# 单个订阅
http://your-domain:8080/sub/{token}?target=clash

# 合并所有订阅
http://your-domain:8080/sub/{token}/merged?target=clash
```

支持的格式参数：
| 参数 | 说明 |
|------|------|
| `target=clash` | Clash 配置（默认） |
| `target=singbox` | sing-box 配置 |
| `target=surge` | Surge 配置 |
| `target=loon` | Loon 配置 |
| `target=quanx` | Quantumult X 配置 |
| `target=base64` | Base64 订阅 |

### 在线转换

1. 点击左侧菜单「在线转换」
2. 输入订阅链接或 Base64 内容
3. 选择目标格式
4. 点击转换，复制结果

## 🔧 管理命令

### 服务管理

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启所有服务
docker compose restart

# 停止所有服务
docker compose down

# 启动所有服务
docker compose up -d
```

### 更新版本

```bash
# 进入项目目录
cd /opt/subforge

# 拉取最新代码
git pull origin main

# 重新构建并启动
docker compose up -d --build
```

### 健康检查

```bash
# 运行健康检查脚本
bash scripts/health-check.sh

# 部署验证
bash scripts/deploy-verify.sh

# 查看指标
curl http://localhost:8080/api/metrics | jq .
```

### 备份恢复

```bash
# 创建备份
bash scripts/update.sh

# 回滚到指定版本
bash scripts/rollback.sh <commit-hash>
```

## 🌐 配置 SSL

### 使用 Let's Encrypt

```bash
# 运行 SSL 配置脚本
sudo bash setup-ssl.sh

# 输入域名和邮箱即可
# 例：
# Domain: example.com
# Email: admin@example.com
```

### 手动配置

1. 获取 SSL 证书
2. 将证书放到 `/etc/letsencrypt/live/your-domain/`
3. 修改 `nginx/nginx.conf` 为 `nginx/nginx-ssl.conf`
4. 重启 nginx：`docker compose restart nginx`

## 📡 API 接口

### 认证

```bash
# 登录获取 Token
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your-password"}'

# 响应
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {"id": 1, "username": "admin", "role": "admin"}
}
```

### 订阅管理

```bash
# 获取订阅列表
curl http://localhost:8080/api/subscriptions \
  -H "Authorization: Bearer <token>"

# 添加订阅
curl -X POST http://localhost:8080/api/subscriptions \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"机场A","url":"https://..."}'

# 刷新订阅
curl -X POST http://localhost:8080/api/subscriptions/1/refresh \
  -H "Authorization: Bearer <token>"
```

### 在线转换

```bash
# 转换订阅格式
curl -X POST http://localhost:8080/api/convert \
  -H "Content-Type: application/json" \
  -d '{"source_url":"https://...","target":"clash","rename":true}'

# 检测格式
curl -X POST http://localhost:8080/api/detect \
  -H "Content-Type: application/json" \
  -d '{"source":"https://..."}'
```

### 公开接口（无需认证）

```bash
# 获取订阅内容
curl "http://localhost:8080/sub/{token}?target=clash"

# 健康检查
curl http://localhost:8080/api/health

# 获取指标
curl http://localhost:8080/api/metrics
```

## 🛡️ 安全特性

- **JWT 认证** — 安全的 Token 验证
- **密码加密** — bcrypt 哈希存储
- **API 限流** — 防止暴力破解
- **安全头** — CSP、XSS 防护等

## 📊 支持协议

| 输入格式 | 输出格式 |
|----------|----------|
| VMess | Clash YAML |
| VLESS | sing-box JSON |
| Trojan | Surge 配置 |
| Shadowsocks | Loon 配置 |
| ShadowsocksR | Quantumult X |
| Hysteria2 | Base64 |
| TUIC | |
| Clash YAML | |
| sing-box JSON | |

## 🏗️ 项目结构

```
subforge/
├── backend-python/       # Python 后端 (FastAPI)
│   ├── app.py            # 主应用
│   ├── requirements.txt  # Python 依赖
│   └── Dockerfile        # Docker 镜像
├── frontend/             # Vue3 前端
│   └── src/
│       ├── views/        # 页面组件
│       ├── components/   # 公共组件
│       ├── api/          # API 封装
│       └── stores/       # Pinia 状态管理
├── nginx/                # Nginx 配置
├── scripts/              # 运维脚本
├── docs/                 # 项目文档
├── docker-compose.yml    # Docker 编排
├── install.sh            # 一键安装脚本
├── deploy.sh             # 本地部署脚本
├── setup-ssl.sh          # SSL 配置脚本
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

### 添加新协议

1. 在 `backend-python/app.py` 中添加新的转换函数
2. 在 `/api/convert` 端点中调用新函数

### 运行测试

```bash
# 前端构建检查
cd frontend
npm run build
```

## 📚 文档

| 文档 | 说明 |
|------|------|
| [用户手册](docs/user-guide.md) | 完整的用户使用指南 |
| [API 文档](docs/api.md) | RESTful API 接口说明 |
| [开发文档](docs/development.md) | 开发环境搭建和架构说明 |
| [部署文档](docs/deployment.md) | 详细的部署和运维指南 |
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

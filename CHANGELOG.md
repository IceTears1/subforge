# Changelog

## v1.2.2 (2026-06-22)

### Bug Fixes
- **修复 base64 订阅生成** — 支持原始 params 字符串，解决小火箭订阅失败问题

### Improvements
- 优化安装完成后的订阅输出格式
- 添加 ClashMeta 和默认订阅分类显示
- 添加在线二维码链接

## v1.2.1 (2026-06-22)

### Bug Fixes
- **修复 base64 订阅导出格式** — 解决导出订阅时 base64 编码格式问题

## v1.0.6 (2026-06-18)

### Bug Fixes
- **修复 amd64 平台镜像** — 重新构建兼容服务器架构的 Docker 镜像

## v1.0.5 (2026-06-18)

### Bug Fixes
- **修复入口脚本循环调用** — 解决 docker-entrypoint.sh 无限递归问题
- **envsubst 端口替换** — 后端端口动态配置正常工作

## v1.0.4 (2026-06-18)

### Bug Fixes
- **Nginx 健康检查** — 添加 healthcheck 配置，解决容器状态误判问题

## v1.0.3 (2026-06-18)

### Bug Fixes
- **修复 Nginx 配置语法错误** — 使用 `envsubst` 动态替换端口变量，解决容器 crash-loop 问题
- **Nginx 端口动态配置** — 支持 `.env` 中 `BACKEND_PORT` 自动同步到 nginx 配置

### Improvements
- 优化 Docker 入口脚本，配置模板化生成
- 更新安装脚本端口匹配逻辑

## v1.0.2 (2026-06-18)

### Features
- **可配置端口** — 前后端端口独立配置
- **阿里云 SSL** — 支持 acme.sh + 阿里云 DNS API 自动申请证书
- **CLI 管理工具** — 交互式命令行管理菜单 (`subforge` 命令)
- **历史配置** — 安装参数自动保存，下次安装时复用
- **交互式安装** — 支持管道执行 `curl | bash`
- **自动备份** — 升级时自动备份数据库

### Improvements
- 节点分组支持按订阅来源分组
- 每个分组支持单独导出订阅
- 一键测速支持所有节点
- 订阅管理支持健康检测
- 前端界面优化

### Bug Fixes
- 修复节点导入重复检测
- 修复订阅节点数显示不正确
- 修复分享链接获取失败
- 修复导出订阅功能
- 修复 Docker 镜像平台兼容性 (amd64/arm64)

## v1.0.1 (2026-06-17)

### Features
- **节点分组** — 支持按区域/协议/状态分组
- **订阅导出** — 每个分组支持单独导出
- **节点测速** — 一键测试所有节点延迟
- **节点导入** — 支持导入单个 vmess/vless/trojan/ss 节点

### Improvements
- 节点管理默认显示所有订阅
- 优化前端界面响应速度
- 改进错误提示信息

### Bug Fixes
- 修复版本号显示
- 修复数据库迁移问题
- 修复订阅刷新功能

## v1.0.0 (2026-06-12)

### Features
- Multi-format subscription conversion (Clash/sing-box/Surge/Loon/QX/Base64)
- Smart region-based node renaming with emoji flags
- Subscription management with CRUD operations
- Node management with filtering and search
- Online conversion tool
- Subscription sharing with QR code
- Import/Export subscriptions (JSON)
- Batch operations (delete/refresh/export)
- User management with sub-accounts
- API Key authentication
- Webhook notifications
- System monitoring dashboard
- Audit logging for security events
- Dark mode with theme persistence
- Responsive mobile design
- One-click VPS deployment
- Docker Compose orchestration
- Nginx reverse proxy with HTTPS support

### Security
- SSRF protection (blocks private/link-local IPs)
- JWT token blacklist for revocation
- Rate limiting on login (5/min per IP)
- IP whitelist for admin endpoints
- CORS origin whitelist
- Password complexity validation (8+ chars, upper/lower/digit)
- Security headers (CSP/HSTS/CORP/Referrer-Policy)
- Request body size limit (1MB)
- Input validation and sanitization
- Audit logging for all state-changing operations

### Performance
- Subscription content caching with ETag
- Database indexing (9 indexes)
- Scheduler concurrency limit (max 5)
- Graceful shutdown with signal handling
- Docker resource limits
- Log rotation configuration

### Testing
- Unit tests for parser, renderer, smart engine
- SSRF protection tests
- Rate limiter tests
- Cache tests (set/get/expiry/eviction)
- Password validation tests
- Token blacklist tests
- Deployment verification script

### Documentation
- Comprehensive API documentation
- Client usage examples (Clash/sing-box/Surge/Loon)
- Deployment guide
- Security guide
- Changelog

# Changelog

## v1.4.4 (2026-06-23)

### Changes
- **清理 git 历史** — 移除大镜像文件，.git 从 573MB 减小到 336KB
- **优化仓库结构** — 镜像通过 GitHub Releases 分发

## v1.4.3 (2026-06-23)

### Bug Fixes
- **安装脚本优化** — 镜像不存在时停止安装而非本地构建
- **错误提示** — 提示用户使用指定版本安装

## v1.4.2 (2026-06-22)

### Features
- **前端格式支持** — 更新前端 UI 支持所有新增输出格式
- **修复 QX 格式** — 修正 Quantumult X 的 target 参数为 `qx`
- **在线更新功能** — 支持从 Web UI 检查更新、更新到最新版本、版本回滚
- **GitHub 版本检查** — 自动从 GitHub 获取最新版本信息
- **一键打包脚本** — 添加 scripts/build.sh 自动构建和发布

### API 更新
- `GET /api/update/version` — 获取版本信息（检查 GitHub 更新）
- `GET /api/update/releases` — 获取所有发布版本
- `POST /api/update/latest` — 更新到最新版本
- `POST /api/update/tag` — 更新到指定版本
- `POST /api/update/rollback` — 回滚到指定版本

## v1.4.1 (2026-06-22)

### Features
- **Shadowrocket 支持** — 添加 Shadowrocket 配置导出（base64 编码的 URI 列表）

## v1.4.0 (2026-06-22)

### Features
- **订阅格式化管道** — 添加过滤器和操作符系统，支持节点筛选和修改
- **新增输出格式** — 支持 Surge、Loon、Quantumult X 配置导出
- **过滤器系统** — 正则过滤、区域过滤、类型过滤、无用节点过滤
- **操作符系统** — 设置属性、标志管理、排序、重命名、脚本修改、域名解析

### Pipeline 模块
- `pipeline/filters.py` — 过滤器基类和实现
- `pipeline/operators.py` — 操作符基类和实现
- `pipeline/pipeline.py` — 管道组合和配置解析

### Exporters 模块
- `exporters/surge.py` — Surge 配置生成
- `exporters/loon.py` — Loon 配置生成
- `exporters/qx.py` — Quantumult X 配置生成

## v1.3.3 (2026-06-22)

### Frontend
- **模块化优化** — 创建 constants/、composables/、utils/、types/ 模块
- **修复内存泄漏** — useResponsive composable 替代重复的 resize 监听
- **可复用表格列** — useNodeColumns composable 提供统一的节点表格列定义
- **剪贴板 fallback** — 支持旧版浏览器的 clipboard API
- **订阅导出工具** — 生成 Clash/sing-box/Base64 配置的工具函数

## v1.3.2 (2026-06-22)

### Performance
- **修复 N+1 查询** — export_all_subscriptions 使用子查询替代循环查询
- **并行速度测试** — speedtest_all_nodes 使用单个线程池并行测试所有节点
- **订阅导出缓存** — 添加 5 分钟 TTL 内存缓存，避免重复生成
- **缓存自动失效** — 刷新订阅时自动清除相关缓存

## v1.3.1 (2026-06-22)

### Refactor
- **后端模块化** — 创建 models/、parsers/、utils/、exporters/ 模块结构
- **配置管理** — 提取 config.py 配置模块

## v1.3.0 (2026-06-22)

### Security
- **安全警告** — 启动时检查 JWT_SECRET 和 ADMIN_PASSWORD 是否为默认值
- **CORS 配置** — 支持通过环境变量 CORS_ORIGINS 自定义允许的来源
- **API 认证** — /api/metrics 端点现在需要管理员权限
- **错误处理** — 将所有 bare except 替换为 except Exception
- **日志系统** — 使用 Python logging 模块替代 print() 语句

### Bug Fixes
- **修复数据库索引** — 为 subscriptions.user_id、nodes.subscription_id、audit_logs.created_at 添加索引
- **修复级联删除** — 删除订阅时自动删除关联节点

## v1.2.8 (2026-06-22)

### Features
- **指定版本安装** — 支持从 GitHub Releases 下载指定版本的预构建镜像
- **优化安装速度** — 使用 sparse-checkout 跳过 images 目录，从 Releases 下载镜像

### Bug Fixes
- **修复安装脚本变量未定义错误** — 使用 \${VAR:-} 语法避免 set -u 报错
- **优化镜像管理** — 本地只保留最新版本镜像

## v1.2.7 (2026-06-22)

### Bug Fixes
- **恢复完整克隆** — 包含预构建 Docker 镜像，避免服务器本地构建耗时

## v1.2.6 (2026-06-22)

### Bug Fixes
- **修复安装脚本未定义变量错误** — 使用 ${VAR:-} 语法避免 set -u 报错

## v1.2.5 (2026-06-22)

### Bug Fixes
- **修复安装脚本变量未定义错误** — 确保 VERSION 变量始终定义
- **优化克隆速度** — 使用浅克隆和 sparse-checkout 跳过大型镜像文件

## v1.2.4 (2026-06-22)

### Features
- **指定版本安装** — 安装脚本支持 `-v` 参数指定版本安装

### Bug Fixes
- **修复版本号显示** — Docker 构建时正确传入 VERSION 和 COMMIT 参数
- **更新部署脚本** — install.sh 和 update-vps.sh 自动传递版本信息
- **修复订阅链接格式** — 前端生成正确的 /export 路径
- **修复 base64 订阅生成** — 支持原始 params 字符串

### Improvements
- 优化安装完成后的订阅输出格式
- 添加 ClashMeta 和默认订阅分类显示
- 添加在线二维码链接
- 更新 README 文档

## v1.2.3 (2026-06-22)

### Bug Fixes
- **修复订阅链接格式** — 添加 /export 路径，解决小飞机刷新失败问题
- **修复前端订阅 URL 生成** — 确保生成正确的订阅链接

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

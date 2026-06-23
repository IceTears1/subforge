# SubForge 部署文档

## 目录

1. [部署方式](#部署方式)
2. [系统要求](#系统要求)
3. [Docker 部署](#docker-部署)
4. [VPS 部署](#vps-部署)
5. [HTTPS 配置](#https-配置)
6. [环境变量](#环境变量)
7. [数据库配置](#数据库配置)
8. [Nginx 配置](#nginx-配置)
9. [更新与回滚](#更新与回滚)
10. [监控与日志](#监控与日志)
11. [备份与恢复](#备份与恢复)
12. [故障排除](#故障排除)

---

## 部署方式

| 方式 | 命令 | 适用场景 |
|------|------|----------|
| 一键安装 | `curl ... \| sudo bash` | VPS 快速部署 |
| Docker Compose | `docker compose up -d` | 本地/服务器 |
| 手动部署 | 逐个组件安装 | 自定义环境 |

---

## 系统要求

### 最低配置

- **CPU**: 1 核
- **内存**: 1 GB
- **磁盘**: 10 GB
- **OS**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+

### 推荐配置

- **CPU**: 2 核
- **内存**: 2 GB
- **磁盘**: 20 GB
- **OS**: Ubuntu 22.04 LTS

### 网络要求

- 开放端口：80 (HTTP) / 443 (HTTPS)
- 出站网络：访问订阅源

---

## Docker 部署

### 一键安装

```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh -o install.sh

# 运行安装（指定版本）
sudo bash install.sh -v 1.4.8

# 或安装最新版本（不指定版本）
sudo bash install.sh
```

### 手动 Docker 部署

```bash
# 克隆项目
git clone https://github.com/IceTears1/subforge.git
cd subforge

# 配置环境变量
cp .env.example .env
nano .env  # 编辑配置

# 启动服务
docker compose up -d

# 查看状态
docker compose ps

# 查看日志
docker compose logs -f
```

### Docker Compose 配置

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: subforge
      POSTGRES_USER: subforge
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U subforge"]
      interval: 5s

  backend:
    build: ./backend
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DB_HOST: postgres
      DB_PASSWORD: ${DB_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}

  frontend:
    build: ./frontend

  nginx:
    image: nginx:alpine
    ports:
      - "${PORT:-8080}:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - backend
      - frontend

volumes:
  pgdata:
```

---

## VPS 部署

### 方式一：一键脚本

```bash
# SSH 登录 VPS
ssh root@your-vps-ip

# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/IceTears1/subforge/main/install.sh -o install.sh

# 运行安装（指定版本）
sudo bash install.sh -v 1.4.8

# 或安装最新版本（不指定版本）
sudo bash install.sh
```

### 方式二：远程部署

```bash
# 在本地运行
chmod +x deploy-vps.sh
./deploy-vps.sh

# 输入 VPS 信息
# IP: your-vps-ip
# User: root
# Port: 22
```

### 防火墙配置

```bash
# Ubuntu/Debian
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# CentOS
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

---

## HTTPS 配置

### 使用 Let's Encrypt

```bash
# 运行 SSL 设置脚本
sudo bash setup-ssl.sh

# 输入域名和邮箱
# Domain: subforge.example.com
# Email: your@email.com
```

### 手动配置

```bash
# 安装 certbot
apt-get install certbot python3-certbot-nginx

# 获取证书
certbot certonly --webroot -w /opt/subforge \
  -d subforge.example.com \
  --email your@email.com \
  --agree-tos

# 更新 nginx 配置
cp nginx/nginx-ssl.conf nginx/nginx.conf
# 编辑 nginx.conf 中的域名

# 重启 nginx
docker compose restart nginx

# 设置自动续期
crontab -e
# 添加: 0 0 1 * * certbot renew --quiet
```

---

## 环境变量

### 完整配置

```bash
# 服务器端口
PORT=8080

# 数据库
DB_HOST=postgres
DB_PORT=5432
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=your-secure-password
DB_SSL_MODE=disable  # disable|require|verify-full

# JWT
JWT_SECRET=your-jwt-secret-at-least-32-chars
JWT_EXPIRY=24h

# 管理员
ADMIN_PASSWORD=your-admin-password

# CORS (逗号分隔)
CORS_ORIGINS=https://subforge.example.com

# IP 白名单 (逗号分隔，空=不限制)
ADMIN_IP_WHITELIST=

# Gin 模式
GIN_MODE=release  # debug|release
```

### 生成安全密码

```bash
# 生成随机密码
openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24

# 生成 JWT Secret
openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32
```

---

## 数据库配置

### Docker 内部数据库

默认配置，无需额外设置。

### 外部数据库

```bash
# .env
DB_HOST=your-db-host
DB_PORT=5432
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=your-db-password
DB_SSL_MODE=require  # 生产环境建议使用 require
```

### 数据库迁移

```bash
# 自动迁移（首次启动时执行）
docker compose up -d backend

# 手动迁移
docker compose exec postgres psql -U subforge -d subforge -f /docker-entrypoint-initdb.d/init.sql
```

---

## Nginx 配置

### HTTP 配置

```nginx
server {
    listen 80;
    server_name _;

    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;

    # API 代理
    location /api/ {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 订阅端点
    location /sub/ {
        proxy_pass http://backend:8080;
    }

    # 前端
    location / {
        proxy_pass http://frontend:80;
    }
}
```

### HTTPS 配置

```nginx
server {
    listen 443 ssl http2;
    server_name subforge.example.com;

    ssl_certificate /etc/letsencrypt/live/subforge.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/subforge.example.com/privkey.pem;

    # SSL 设置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # ... 其他配置同 HTTP
}

# HTTP 重定向
server {
    listen 80;
    server_name subforge.example.com;
    return 301 https://$host$request_uri;
}
```

---

## 更新与回滚

### 安全更新

```bash
# 使用 Makefile
make update

# 或手动
cd /opt/subforge
sudo bash scripts/update.sh
```

更新流程：
1. 自动备份
2. 拉取最新代码
3. 重建容器
4. 重启服务
5. 验证部署
6. 失败自动回滚

### 版本回滚

```bash
# 使用 Makefile
make rollback

# 或手动
cd /opt/subforge
sudo bash scripts/rollback.sh <commit-hash>

# 查看历史版本
git log --oneline -10
```

### 手动更新

```bash
cd /opt/subforge

# 备份
tar -czf backup.tar.gz .env nginx/

# 拉取更新
git pull origin main

# 重建
docker compose build --no-cache

# 重启
docker compose down
docker compose up -d

# 验证
curl http://localhost:8080/api/health
```

---

## 监控与日志

### 健康检查

```bash
# 使用 Makefile
make health

# 或手动
curl http://localhost:8080/api/health
```

### 系统指标

```bash
# 使用 Makefile
make metrics

# 或手动
curl http://localhost:8080/api/metrics
```

返回：
```json
{
  "uptime_seconds": 3600,
  "database": {
    "users": 5,
    "subscriptions": 20,
    "nodes": 500
  },
  "memory": {
    "alloc_mb": 50,
    "sys_mb": 100
  },
  "goroutines": 25
}
```

### 查看日志

```bash
# 所有日志
docker compose logs -f

# 后端日志
docker compose logs -f backend

# 最近 100 行
docker compose logs --tail=100 backend

# 搜索错误
docker compose logs backend | grep ERROR
```

### 部署验证

```bash
# 使用 Makefile
make verify

# 或手动
bash scripts/deploy-verify.sh
```

验证项目：
1. 健康端点
2. 前端访问
3. 登录功能
4. 受保护端点
5. 创建订阅
6. 列表订阅
7. 监控指标
8. 格式列表

---

## 备份与恢复

### 备份数据库

```bash
# Docker 内部数据库
docker compose exec postgres pg_dump -U subforge subforge > backup_$(date +%Y%m%d).sql

# 外部数据库
pg_dump -h your-db-host -U subforge subforge > backup_$(date +%Y%m%d).sql
```

### 备份配置

```bash
tar -czf config_backup_$(date +%Y%m%d).tar.gz .env nginx/
```

### 恢复数据库

```bash
# 停止服务
docker compose down

# 恢复数据
docker compose up -d postgres
cat backup_20260612.sql | docker compose exec -T postgres psql -U subforge -d subforge

# 启动服务
docker compose up -d
```

### 自动备份

```bash
# 添加 crontab
crontab -e

# 每天凌晨 3 点备份
0 3 * * * cd /opt/subforge && docker compose exec -T postgres pg_dump -U subforge subforge | gzip > /backups/subforge_$(date +\%Y\%m\%d).sql.gz
```

---

## 故障排除

### 服务无法启动

```bash
# 查看日志
docker compose logs

# 检查端口占用
lsof -i :8080

# 检查 Docker 状态
docker ps -a
```

### 数据库连接失败

```bash
# 检查数据库状态
docker compose exec postgres pg_isready -U subforge

# 检查数据库日志
docker compose logs postgres

# 测试连接
docker compose exec postgres psql -U subforge -d subforge -c "SELECT 1;"
```

### 前端无法访问

```bash
# 检查前端容器
docker compose ps frontend

# 检查 nginx 配置
docker compose exec nginx nginx -t

# 检查 nginx 日志
docker compose logs nginx
```

### 内存不足

```bash
# 查看资源使用
docker stats

# 调整 docker-compose.yml 中的资源限制
deploy:
  resources:
    limits:
      memory: 512M
```

### 权限问题

```bash
# 修复文件权限
chmod +x scripts/*.sh
chmod +x deploy.sh

# 修复数据目录权限
sudo chown -R 1000:1000 /opt/subforge
```

---

## 性能优化

### 数据库优化

```sql
-- 分析查询
EXPLAIN ANALYZE SELECT * FROM subscriptions WHERE user_id = 1;

-- 清理旧数据
DELETE FROM nodes WHERE created_at < NOW() - INTERVAL '30 days';
VACUUM;
```

### 应用优化

```bash
# 调整 Go GC
GOGC=100  # 默认值，可根据内存调整

# 调整并发
GOMAXPROCS=4  # 设置为 CPU 核心数
```

### Nginx 优化

```nginx
# 启用缓存
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=sub_cache:10m max_size=100m;

location /sub/ {
    proxy_cache sub_cache;
    proxy_cache_valid 200 5m;
}
```

---

## 获取帮助

- **GitHub Issues**: https://github.com/IceTears1/subforge/issues
- **API 文档**: [docs/api.md](api.md)
- **用户手册**: [docs/user-guide.md](user-guide.md)
- **开发文档**: [docs/development.md](development.md)

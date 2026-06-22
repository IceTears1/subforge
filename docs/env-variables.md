# 环境变量配置

SubForge 支持通过环境变量配置各项参数。

## 数据库配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `DB_HOST` | `localhost` | 数据库主机 |
| `DB_PORT` | `5432` | 数据库端口 |
| `DB_NAME` | `subforge` | 数据库名称 |
| `DB_USER` | `subforge` | 数据库用户 |
| `DB_PASSWORD` | `subforge123` | 数据库密码 |

## 认证配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `JWT_SECRET` | `change-me-in-production` | JWT 密钥（必须修改） |
| `JWT_EXPIRY` | `24h` | JWT 过期时间 |
| `ADMIN_USERNAME` | `admin` | 管理员用户名 |
| `ADMIN_PASSWORD` | `admin123` | 管理员密码（必须修改） |

## 服务配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `BACKEND_PORT` | `3002` | 后端 API 端口 |
| `FRONTEND_PORT` | `3001` | 前端访问端口 |
| `DB_PORT` | `45000` | 数据库对外端口 |
| `SSL_PORT` | `3003` | HTTPS 端口 |

## CORS 配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `CORS_ORIGINS` | `*` | 允许的来源（逗号分隔） |

## 域名/SSL 配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `DOMAIN` | `` | 域名（如 example.com） |
| `EMAIL` | `` | SSL 证书邮箱 |

## 阿里云 SSL 配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `ALI_AK` | `` | 阿里云 AccessKey ID |
| `ALI_SK` | `` | 阿里云 AccessKey Secret |

## 安全建议

1. **必须修改** `JWT_SECRET` 和 `ADMIN_PASSWORD`
2. 生产环境应限制 `CORS_ORIGINS`
3. 使用强密码

## 示例 .env 文件

```bash
# 数据库
DB_HOST=localhost
DB_PORT=5432
DB_NAME=subforge
DB_USER=subforge
DB_PASSWORD=your-strong-password

# 认证
JWT_SECRET=your-random-jwt-secret
ADMIN_PASSWORD=your-strong-admin-password

# 服务
BACKEND_PORT=3002
FRONTEND_PORT=3001

# CORS
CORS_ORIGINS=https://your-domain.com
```

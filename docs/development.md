# SubForge 开发文档

## 目录

1. [项目架构](#项目架构)
2. [技术栈](#技术栈)
3. [开发环境搭建](#开发环境搭建)
4. [项目结构](#项目结构)
5. [核心概念](#核心概念)
6. [后端开发](#后端开发)
7. [前端开发](#前端开发)
8. [数据库设计](#数据库设计)
9. [API 设计](#api-设计)
10. [测试](#测试)
11. [部署](#部署)
12. [贡献指南](#贡献指南)

---

## 项目架构

```
┌─────────────────────────────────────────────────────────┐
│                      Nginx (反向代理)                     │
├─────────────────────────────────────────────────────────┤
│                      Frontend (Vue3)                     │
├─────────────────────────────────────────────────────────┤
│                    Backend (Python/FastAPI)              │
├─────────────────────────────────────────────────────────┤
│                      PostgreSQL                         │
└─────────────────────────────────────────────────────────┘
```

### 请求流程

```
Client → Nginx → Backend API → Service Layer → Database
                ↓
            Frontend (静态文件)
```

### 分层架构

```
Handler (HTTP 处理)
    ↓
Service (业务逻辑)
    ↓
Model (数据模型)
    ↓
Database (PostgreSQL)
```

---

## 技术栈

### 后端

| 技术 | 版本 | 用途 |
|------|------|------|
| Python | 3.11+ | 主语言 |
| FastAPI | 0.109+ | Web 框架 |
| SQLAlchemy | 2.0+ | ORM |
| PostgreSQL | 15 | 数据库 |
| python-jose | 3.3+ | JWT 认证 |
| passlib | 1.7+ | 密码加密 |

### 前端

| 技术 | 版本 | 用途 |
|------|------|------|
| Vue | 3.4+ | 框架 |
| TypeScript | 5.3+ | 类型系统 |
| Naive UI | 2.38+ | 组件库 |
| Pinia | 2.1+ | 状态管理 |
| Vue Router | 4.3+ | 路由 |
| Axios | 1.6+ | HTTP 客户端 |
| Vite | 5.0+ | 构建工具 |

### DevOps

| 技术 | 用途 |
|------|------|
| Docker | 容器化 |
| Docker Compose | 编排 |
| Nginx | 反向代理 |
| GitHub Actions | CI/CD |

---

## 开发环境搭建

### 前置要求

- Python 3.11+
- Node.js 20+
- PostgreSQL 15+
- Docker (可选)

### 后端开发

```bash
# 克隆项目
git clone https://github.com/IceTears1/subforge.git
cd subforge/backend-python

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
cp ../.env.example .env
# 编辑 .env 配置数据库连接

# 启动 PostgreSQL (Docker)
docker run -d \
  --name subforge-db \
  -e POSTGRES_DB=subforge \
  -e POSTGRES_USER=subforge \
  -e POSTGRES_PASSWORD=subforge123 \
  -p 5432:5432 \
  postgres:15-alpine

# 运行后端
python app.py
```

### 前端开发

```bash
cd frontend

# 安装依赖
npm install

# 启动开发服务器
npm run dev
# 访问 http://localhost:3000
```

### 完整开发环境

```bash
# 使用 Docker Compose
docker compose up -d postgres

# 终端 1: 后端
cd backend-python && python app.py

# 终端 2: 前端
cd frontend && npm run dev
```

---

## 项目结构

```
subforge/
├── backend-python/            # Python 后端
│   ├── app.py                 # 主应用 (FastAPI)
│   ├── requirements.txt       # Python 依赖
│   └── Dockerfile             # Docker 镜像
├── frontend/                  # Vue3 前端
│   └── src/
│       ├── views/             # 页面组件
│       ├── components/        # 公共组件
│       ├── api/               # API 封装
│       └── stores/            # Pinia 状态管理
├── nginx/                     # Nginx 配置
├── scripts/                   # 运维脚本
├── docs/                      # 项目文档
├── docker-compose.yml         # Docker 编排
├── install.sh                 # 一键安装脚本
├── deploy.sh                  # 本地部署脚本
├── setup-ssl.sh               # SSL 配置脚本
└── .env.example               # 配置模板
```
│   │   │   ├── webhook.go      # Webhook
│   │   │   ├── apikey.go       # API Key
│   │   │   ├── token.go        # Token 黑名单
│   │   │   └── scheduler.go    # 定时任务
│   │   ├── handler/            # HTTP 处理器
│   │   │   ├── auth.go         # 认证处理
│   │   │   ├── user.go         # 用户处理
│   │   │   ├── subscription.go # 订阅处理
│   │   │   ├── convert.go      # 转换处理
│   │   │   ├── public.go       # 公开端点
│   │   │   ├── profile.go      # 个人资料
│   │   │   ├── export.go       # 导入导出
│   │   │   ├── batch.go        # 批量操作
│   │   │   ├── webhook.go      # Webhook
│   │   │   ├── apikey.go       # API Key
│   │   │   ├── health.go       # 健康检查
│   │   │   ├── audit.go        # 审计日志
│   │   │   ├── metrics.go      # 监控指标
│   │   │   └── middleware.go   # 中间件
│   │   ├── router/             # 路由
│   │   │   └── router.go
│   │   └── pkg/                # 工具包
│   │       ├── response/       # 响应封装
│   │       ├── jwt/            # JWT 工具
│   │       ├── crypto/         # 加密工具
│   │       ├── httputil/       # HTTP 工具 (SSRF防护)
│   │       ├── limiter/        # 限流器
│   │       └── cache/          # 缓存
│   ├── migrations/             # 数据库迁移
│   │   └── init.sql
│   └── Dockerfile
│
├── frontend/                   # Vue3 前端
│   ├── src/
│   │   ├── api/                # API 封装
│   │   │   ├── request.ts      # Axios 实例
│   │   │   ├── auth.ts         # 认证 API
│   │   │   ├── user.ts         # 用户 API
│   │   │   ├── subscription.ts # 订阅 API
│   │   │   └── apikey.ts       # API Key API
│   │   ├── components/         # 组件
│   │   │   ├── Layout.vue      # 主布局
│   │   │   ├── ShareModal.vue  # 分享弹窗
│   │   │   ├── ImportModal.vue # 导入弹窗
│   │   │   └── SubscriptionDetail.vue
│   │   ├── views/              # 页面
│   │   │   ├── Login.vue       # 登录
│   │   │   ├── Dashboard.vue   # 仪表盘
│   │   │   ├── Subscriptions.vue
│   │   │   ├── Nodes.vue       # 节点管理
│   │   │   ├── Convert.vue     # 在线转换
│   │   │   ├── APIKeys.vue     # API Keys
│   │   │   ├── Users.vue       # 用户管理
│   │   │   ├── Monitor.vue     # 系统监控
│   │   │   ├── Settings.vue    # 系统设置
│   │   │   └── NotFound.vue    # 404
│   │   ├── stores/             # 状态管理
│   │   │   ├── auth.ts         # 认证状态
│   │   │   ├── subscription.ts # 订阅状态
│   │   │   └── theme.ts        # 主题状态
│   │   ├── router/             # 路由
│   │   │   └── index.ts
│   │   └── styles/             # 样式
│   │       └── global.css
│   └── Dockerfile
│
├── nginx/                      # Nginx 配置
│   ├── nginx.conf              # HTTP 配置
│   └── nginx-ssl.conf          # HTTPS 配置
│
├── scripts/                    # 脚本
│   ├── deploy.sh               # 本地部署
│   ├── deploy-vps.sh           # VPS 部署
│   ├── update-vps.sh           # VPS 更新
│   ├── update.sh               # 安全更新
│   ├── rollback.sh             # 版本回滚
│   ├── health-check.sh         # 健康检查
│   └── deploy-verify.sh        # 部署验证
│
├── docs/                       # 文档
│   ├── api.md                  # API 文档
│   ├── user-guide.md           # 用户手册
│   ├── development.md          # 开发文档
│   └── deployment.md           # 部署文档
│
├── .github/workflows/          # CI/CD
│   └── build.yml
│
├── docker-compose.yml          # Docker 编排
├── Makefile                    # 构建命令
├── install.sh                  # 一键安装
├── setup-ssl.sh                # SSL 设置
├── CHANGELOG.md                # 更新日志
└── README.md                   # 项目说明
```

---

## 核心概念

### 统一节点结构 (UPN)

所有代理协议都转换为统一的 `ProxyNode` 结构：

```go
type ProxyNode struct {
    Name      string                 `json:"name"`
    Type      string                 `json:"type"`      // vmess|vless|trojan|ss|ssr|hysteria2|tuic
    Server    string                 `json:"server"`
    Port      int                    `json:"port"`
    Transport string                 `json:"transport"`  // tcp|ws|grpc|h2|quic
    TLS       bool                   `json:"tls"`
    SNI       string                 `json:"sni,omitempty"`
    UUID      string                 `json:"uuid,omitempty"`
    Password  string                 `json:"password,omitempty"`
    Extra     map[string]interface{} `json:"extra,omitempty"`
}
```

### 解析器接口

```go
type Parser interface {
    Name() string
    Detect(content string) bool
    Parse(content string) ([]ProxyNode, error)
}
```

### 渲染器接口

```go
type Renderer interface {
    Name() string
    Render(nodes []ProxyNode) (string, error)
}
```

### 扩展新协议

1. 创建解析器：`internal/parser/my_protocol.go`
2. 实现 `Parser` 接口
3. 在 `parser.go` 的 `init()` 中注册

```go
func init() {
    Register(&MyProtocolParser{})
}
```

---

## 后端开发

### 添加新 API 端点

1. **创建 Handler**

```go
// internal/handler/my_handler.go
package handler

type MyHandler struct {
    svc *service.MyService
}

func NewMyHandler(svc *service.MyService) *MyHandler {
    return &MyHandler{svc: svc}
}

func (h *MyHandler) MyEndpoint(c *gin.Context) {
    // 处理逻辑
    response.OK(c, data)
}
```

2. **创建 Service**

```go
// internal/service/my_service.go
package service

type MyService struct {
    db *gorm.DB
}

func NewMyService(db *gorm.DB) *MyService {
    return &MyService{db: db}
}
```

3. **注册路由**

```go
// internal/router/router.go
api.GET("/my-endpoint", myH.MyEndpoint)
```

4. **初始化服务**

```go
// cmd/server/main.go
mySvc := service.NewMyService(db)
myH := handler.NewMyHandler(mySvc)
```

### 中间件

```go
// 认证中间件
func AuthMiddleware(authSvc *service.AuthService) gin.HandlerFunc {
    return func(c *gin.Context) {
        token := c.GetHeader("Authorization")
        // 验证逻辑
        c.Next()
    }
}

// 使用
api.Use(handler.AuthMiddleware(authSvc))
```

### 数据库操作

```go
// 创建
db.Create(&model.User{Username: "test"})

// 查询
var user model.User
db.Where("username = ?", "test").First(&user)

// 更新
db.Model(&user).Update("status", 0)

// 删除
db.Delete(&user)
```

---

## 前端开发

### 添加新页面

1. **创建页面组件**

```vue
<!-- src/views/MyPage.vue -->
<template>
  <n-card :bordered="false">
    <template #header>
      <span>我的页面</span>
    </template>
    <!-- 内容 -->
  </n-card>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { NCard } from 'naive-ui'

// 逻辑
</script>
```

2. **添加路由**

```typescript
// src/router/index.ts
{ path: 'mypage', name: 'MyPage', component: () => import('../views/MyPage.vue') }
```

3. **添加菜单**

```typescript
// src/components/Layout.vue
{ label: '我的页面', key: '/mypage', icon: () => h(NIcon, { component: MyIcon }) }
```

### API 调用

```typescript
// src/api/my_api.ts
import api from './request'

export function getMyData() {
  return api.get('/my-endpoint')
}

export function createMyData(data: any) {
  return api.post('/my-endpoint', data)
}
```

### 状态管理

```typescript
// src/stores/my_store.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useMyStore = defineStore('my', () => {
  const data = ref([])

  async function loadData() {
    const res = await getMyData()
    data.value = res.data
  }

  return { data, loadData }
})
```

---

## 数据库设计

### 用户表 (users)

```sql
CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(64) UNIQUE NOT NULL,
    password    VARCHAR(128) NOT NULL,
    role        VARCHAR(16) DEFAULT 'user',
    created_by  INTEGER REFERENCES users(id),
    status      SMALLINT DEFAULT 1,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);
```

### 订阅表 (subscriptions)

```sql
CREATE TABLE subscriptions (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
    token       VARCHAR(32) UNIQUE,
    name        VARCHAR(128) NOT NULL,
    url         TEXT NOT NULL,
    auto_refresh INTEGER DEFAULT 3600,
    tags        JSONB DEFAULT '[]',
    last_fetch  TIMESTAMP,
    node_count  INTEGER DEFAULT 0,
    status      SMALLINT DEFAULT 1,
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW()
);
```

### 节点表 (nodes)

```sql
CREATE TABLE nodes (
    id              SERIAL PRIMARY KEY,
    subscription_id INTEGER REFERENCES subscriptions(id) ON DELETE CASCADE,
    name            VARCHAR(256),
    display_name    VARCHAR(256),
    node_type       VARCHAR(32),
    server          VARCHAR(256),
    port            INTEGER,
    region          VARCHAR(64),
    raw_uri         TEXT,
    config_json     JSONB,
    latency         INTEGER,
    last_check      TIMESTAMP,
    status          SMALLINT DEFAULT 1,
    created_at      TIMESTAMP DEFAULT NOW()
);
```

### 索引

```sql
CREATE INDEX idx_nodes_sub ON nodes(subscription_id);
CREATE INDEX idx_nodes_region ON nodes(region);
CREATE INDEX idx_nodes_server ON nodes(server);
CREATE INDEX idx_nodes_latency ON nodes(latency);
CREATE INDEX idx_subs_user ON subscriptions(user_id);
CREATE INDEX idx_subs_token ON subscriptions(token);
CREATE INDEX idx_subs_status ON subscriptions(status);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role);
```

---

## API 设计

### 响应格式

```json
{
  "code": 0,
  "message": "success",
  "data": {}
}
```

### 错误响应

```json
{
  "code": -1,
  "message": "error message"
}
```

### 分页响应

```json
{
  "code": 0,
  "data": {
    "items": [],
    "total": 100,
    "page": 1,
    "page_size": 20
  }
}
```

---

## 测试

### 运行测试

```bash
# 运行所有测试
go test ./...

# 运行特定包的测试
go test ./internal/parser/
go test ./internal/renderer/
go test ./internal/smart/

# 运行带覆盖率的测试
go test -cover ./...

# 运行特定测试
go test -run TestParseVMess ./internal/parser/
```

### 编写测试

```go
// internal/parser/my_test.go
package parser

import (
    "testing"
)

func TestMyParser(t *testing.T) {
    p := &MyParser{}
    
    // 测试检测
    if !p.Detect("valid input") {
        t.Error("should detect valid input")
    }
    
    // 测试解析
    nodes, err := p.Parse("valid input")
    if err != nil {
        t.Fatalf("parse error: %v", err)
    }
    if len(nodes) != 1 {
        t.Errorf("expected 1 node, got %d", len(nodes))
    }
}
```

---

## 部署

### Docker 部署

```bash
# 一键部署
chmod +x deploy.sh
./deploy.sh

# 或手动
cp .env.example .env
docker compose up -d
```

### VPS 部署

```bash
# 一键部署到 VPS
chmod +x deploy-vps.sh
./deploy-vps.sh
```

### 更新

```bash
# 安全更新
make update

# 回滚
make rollback
```

---

## 贡献指南

### 开发流程

1. Fork 项目
2. 创建功能分支：`git checkout -b feature/my-feature`
3. 提交更改：`git commit -m "feat: add my feature"`
4. 推送分支：`git push origin feature/my-feature`
5. 创建 Pull Request

### 提交规范

```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式
refactor: 重构
test: 测试
chore: 构建/工具
```

### 代码规范

- Go: 使用 `gofmt` 格式化
- TypeScript: 使用 ESLint
- Vue: 使用 Vue 3 Composition API

### Pull Request 要求

- 描述清楚改动内容
- 包含测试
- 通过 CI 检查
- 更新文档（如需要）

---

## 获取帮助

- **GitHub Issues**: https://github.com/IceTears1/subforge/issues
- **API 文档**: [docs/api.md](api.md)
- **用户手册**: [docs/user-guide.md](user-guide.md)

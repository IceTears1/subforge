# SubForge Backend

Go + Gin + GORM 后端服务

## 开发

```bash
# 安装依赖
go mod tidy

# 运行
go run ./cmd/server

# 构建
go build -o subforge ./cmd/server
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| PORT | 8080 | 服务端口 |
| DB_HOST | localhost | 数据库地址 |
| DB_PORT | 5432 | 数据库端口 |
| DB_NAME | subforge | 数据库名 |
| DB_USER | subforge | 数据库用户 |
| DB_PASSWORD | subforge123 | 数据库密码 |
| JWT_SECRET | change-me | JWT 密钥 |
| JWT_EXPIRY | 24h | Token 过期时间 |
| ADMIN_PASSWORD | admin123 | 管理员密码 |

## 项目结构

```
internal/
├── config/      # 配置加载
├── core/        # 统一节点结构 (UPN)
├── parser/      # 输入解析器 (可扩展)
├── renderer/    # 输出渲染器 (可扩展)
├── smart/       # 智能引擎
├── service/     # 业务逻辑
├── handler/     # HTTP 处理
├── router/      # 路由注册
└── pkg/         # 工具包
```

## 扩展协议

### 添加新解析器

```go
// internal/parser/my_parser.go
type MyParser struct{}

func (p *MyParser) Name() string { return "myparser" }
func (p *MyParser) Detect(content string) bool { /* ... */ }
func (p *MyParser) Parse(content string) ([]core.ProxyNode, error) { /* ... */ }

// 在 parser.go init() 中注册
func init() {
    Register(&MyParser{})
}
```

### 添加新渲染器

```go
// internal/renderer/my_renderer.go
type MyRenderer struct{}

func (r *MyRenderer) Name() string { return "myformat" }
func (r *MyRenderer) Render(nodes []core.ProxyNode) (string, error) { /* ... */ }

// 在 renderer.go init() 中注册
func init() {
    Register(&MyRenderer{})
}
```

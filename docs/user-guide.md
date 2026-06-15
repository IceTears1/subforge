# SubForge 用户使用手册

## 目录

1. [快速开始](#快速开始)
2. [登录系统](#登录系统)
3. [订阅管理](#订阅管理)
4. [节点管理](#节点管理)
5. [在线转换](#在线转换)
6. [分享订阅](#分享订阅)
7. [导入导出](#导入导出)
8. [API Keys](#api-keys)
9. [子账户管理](#子账户管理)
10. [系统监控](#系统监控)
11. [系统设置](#系统设置)
12. [客户端配置](#客户端配置)
13. [常见问题](#常见问题)

---

## 快速开始

### 访问系统

1. 部署完成后，访问 `http://your-domain:8080`
2. 使用默认账户登录：
   - 用户名：`admin`
   - 密码：查看 `.env` 文件中的 `ADMIN_PASSWORD`

### 首次登录后建议

1. **修改管理员密码**：进入「系统设置」→「修改密码」
2. **创建子账户**：如果需要多人使用，进入「子账户管理」创建
3. **添加订阅**：进入「订阅管理」添加你的订阅链接

---

## 登录系统

### 登录页面

![登录页面](login.png)

- 输入用户名和密码
- 点击「登录」按钮
- 登录成功后自动跳转到仪表盘

### 修改密码

1. 点击右上角用户名
2. 选择「修改密码」
3. 输入旧密码和新密码
4. 点击「保存」

**密码要求：**
- 至少 8 个字符
- 包含大写字母
- 包含小写字母
- 包含数字

---

## 订阅管理

### 添加订阅

1. 进入「订阅管理」页面
2. 点击「添加订阅」按钮
3. 填写信息：
   - **名称**：订阅名称（如：机场A）
   - **订阅链接**：完整的订阅 URL
   - **自动刷新间隔**：默认 3600 秒（1小时）
4. 点击「保存」

### 查看订阅

订阅列表显示：
- **ID**：订阅编号
- **名称**：订阅名称
- **节点数**：当前节点数量
- **状态**：正常/禁用
- **最后更新**：上次刷新时间

### 编辑订阅

1. 点击订阅行的「编辑」按钮
2. 修改名称、链接或刷新间隔
3. 点击「保存」

### 删除订阅

1. 点击订阅行的「删除」按钮
2. 确认删除

### 刷新订阅

1. 点击订阅行的「刷新」按钮
2. 系统自动拉取最新节点
3. 节点按区域自动重命名

### 批量操作

1. 勾选多个订阅
2. 点击顶部按钮：
   - **刷新选中**：批量刷新
   - **导出选中**：批量导出
   - **删除选中**：批量删除

### 订阅详情

点击「详情」按钮查看：
- 完整订阅信息
- 订阅链接
- 创建时间
- 标签

---

## 节点管理

### 查看节点

1. 进入「节点管理」页面
2. 选择订阅
3. 查看节点列表

### 筛选节点

- **区域筛选**：选择特定区域（HK/JP/SG/US 等）
- **搜索**：输入关键词搜索节点名称或地址

### 节点信息

- **名称**：智能重命名后的名称
- **类型**：vmess/vless/trojan/ss 等
- **地址**：服务器地址
- **端口**：服务器端口
- **区域**：自动识别的区域
- **延迟**：节点延迟（颜色标识）
  - 🟢 绿色：< 200ms
  - 🟡 黄色：200-500ms
  - 🔴 红色：> 500ms
- **状态**：在线/离线

### 健康检查

1. 在订阅列表点击「检测」按钮
2. 系统测试所有节点连通性
3. 显示在线/离线/总计数量

---

## 在线转换

### 使用方法

1. 进入「在线转换」页面
2. 输入订阅链接或粘贴内容
3. 选择输出格式：
   - Clash
   - sing-box
   - Surge
   - Loon
   - Quantumult X
   - Base64
4. 设置选项：
   - ✅ 智能重命名
   - ✅ 自动去重
   - 区域筛选
5. 点击「转换」
6. 复制输出内容

### 高级选项

- **区域筛选**：只保留特定区域的节点
- **排除关键词**：排除包含特定关键词的节点

---

## 分享订阅

### 分享方式

1. 在订阅列表点击「分享」按钮
2. 选择客户端格式
3. 复制订阅链接
4. 或扫描二维码

### 分享链接格式

```
http://your-domain:8080/sub/{token}?target=clash
```

支持的格式参数：
- `clash` - Clash/Mihomo
- `singbox` - sing-box
- `surge` - Surge
- `loon` - Loon
- `quanx` - Quantumult X
- `base64` - 通用 Base64

---

## 导入导出

### 导出订阅

1. 点击「导出」按钮
2. 下载 JSON 文件
3. 文件包含所有订阅信息

### 导入订阅

1. 点击「导入」按钮
2. 选择导入方式：
   - **文件导入**：选择 JSON 文件
   - **文本导入**：粘贴 JSON 内容
3. 点击「导入」

**JSON 格式：**
```json
[
  {
    "name": "订阅1",
    "url": "https://example.com/subscribe",
    "auto_refresh": 3600,
    "tags": ["paid"]
  }
]
```

---

## API Keys

### 创建 API Key

1. 进入「API Keys」页面
2. 点击「创建 API Key」
3. 输入名称
4. 复制生成的密钥（只显示一次）

### 使用 API Key

在请求头中添加：
```
Authorization: Bearer sf_xxxxxxxxxxxxxxxx
```

### API Key 用途

- 程序化访问 SubForge API
- 自动化脚本
- 第三方集成

---

## 子账户管理

### 创建子账户

1. 进入「子账户管理」（仅管理员）
2. 点击「添加子账户」
3. 输入用户名和密码
4. 点击「创建」

### 管理子账户

- **启用/禁用**：控制账户状态
- **重置密码**：重置账户密码
- **删除**：删除账户

### 权限说明

- **管理员**：所有功能
- **普通用户**：订阅管理、节点管理、在线转换、API Keys

---

## 系统监控

### 监控指标

- **运行时间**：服务运行时长
- **Goroutines**：Go 协程数量
- **内存使用**：当前内存分配
- **Go 版本**：运行时版本

### 数据库统计

- 用户数
- 订阅数
- 节点数

### 审计日志

记录所有操作：
- 登录/登出
- 订阅创建/更新/删除
- 用户管理操作
- 密码修改

---

## 系统设置

### 智能重命名规则

- **启用区域重命名**：自动按区域重命名节点
- **命名格式**：自定义命名模板
- **排除关键词**：自动排除包含特定关键词的节点

### 默认设置

- **默认输出格式**：选择常用格式
- **自动去重**：自动去除重复节点
- **默认刷新间隔**：新订阅的默认刷新时间

### API 接口

显示常用 API 端点：
- 订阅地址
- 转换接口
- 格式检测

---

## 客户端配置

### Clash / Mihomo

```yaml
proxy-providers:
  subforge:
    type: http
    url: "http://your-domain:8080/sub/YOUR_TOKEN?target=clash"
    interval: 3600
    path: ./proxies/subforge.yaml
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300
```

### sing-box

```json
{
  "outbounds": [
    {
      "type": "urltest",
      "tag": "auto",
      "url": "http://your-domain:8080/sub/YOUR_TOKEN?target=singbox",
      "interval": "5m"
    }
  ]
}
```

### Surge

```ini
[Proxy]
#!subscribe http://your-domain:8080/sub/YOUR_TOKEN?target=surge
```

### Loon

```ini
[Proxy]
#!subscribe http://your-domain:8080/sub/YOUR_TOKEN?target=loon
```

### Quantumult X

```
[filter_remote]
http://your-domain:8080/sub/YOUR_TOKEN?target=quanx, tag=SubForge, force-policy=SubForge, update-interval=3600, opt-parser=true
```

### Shadowrocket

1. 打开 Shadowrocket
2. 点击「+」添加订阅
3. 选择「Subscribe」
4. 输入：`http://your-domain:8080/sub/YOUR_TOKEN?target=base64`

---

## 常见问题

### Q: 订阅刷新失败？

**A:** 检查以下几点：
1. 订阅链接是否有效
2. 服务器是否能访问订阅链接
3. 查看系统日志：`docker compose logs backend`

### Q: 节点延迟显示为 `-`？

**A:** 表示节点未检测或检测失败：
1. 点击「检测」按钮测试节点
2. 检查服务器网络连接

### Q: 如何修改端口？

**A:** 编辑 `.env` 文件：
```bash
PORT=8080  # 修改为其他端口
```
然后重启：`docker compose restart`

### Q: 如何开启 HTTPS？

**A:** 运行 SSL 设置脚本：
```bash
sudo bash setup-ssl.sh
```
输入域名和邮箱，自动申请 Let's Encrypt 证书。

### Q: 忘记管理员密码？

**A:** 重置方法：
```bash
cd /opt/subforge
# 编辑 .env 修改 ADMIN_PASSWORD
docker compose restart backend
```

### Q: 如何备份数据？

**A:** 备份方法：
```bash
# 备份数据库
docker compose exec postgres pg_dump -U subforge subforge > backup.sql

# 备份配置
tar -czf backup.tar.gz .env nginx/
```

### Q: 如何查看日志？

**A:** 查看日志：
```bash
# 查看所有日志
docker compose logs -f

# 查看后端日志
docker compose logs -f backend

# 查看最近 100 行
docker compose logs --tail=100 backend
```

---

## 获取帮助

- **GitHub Issues**: https://github.com/IceTears1/subforge/issues
- **API 文档**: [docs/api.md](api.md)
- **部署文档**: [docs/deployment.md](deployment.md)

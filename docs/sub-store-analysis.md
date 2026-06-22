# Sub-Store 项目分析

## 项目概览

| 指标 | 数据 |
|------|------|
| **Stars** | 9,886 |
| **Forks** | 1,190 |
| **语言** | JavaScript |
| **创建时间** | 2020-08-19 |
| **许可证** | GPL-3.0 |

**定位**: 高级订阅管理器，支持 QX、Loon、Surge、Stash、Egern、Shadowrocket 等多个平台。

## 架构分析

### 核心架构
```
backend/src/
├── core/                    # 核心逻辑
│   ├── app.js              # OpenAPI 抽象层
│   ├── proxy-utils/        # 代理工具
│   │   ├── parsers/        # 输入解析器
│   │   ├── producers/      # 输出生成器
│   │   ├── processors/     # 处理器
│   │   └── validators/     # 验证器
│   └── rule-utils/         # 规则工具
├── restful/                 # REST API
├── products/                # 产品构建
├── utils/                   # 工具函数
└── vendor/                  # 第三方库
```

### 多平台适配
Sub-Store 的核心创新是 **OpenAPI 抽象层**，通过检测运行环境适配不同平台。

## 核心功能

### 1. 订阅转换
**支持的输入格式**:
- URI (SS, SSR, VMess, VLESS, Trojan, Hysteria, Hysteria2, TUIC, WireGuard)
- Clash/Mihomo YAML
- QX 格式
- Loon 格式
- Surge 格式

**支持的输出格式**:
- Clash/Mihomo
- sing-box
- Surge/SurgeMac
- Loon
- QX
- Shadowrocket
- Stash
- Egern
- V2Ray
- Surfboard

### 2. 订阅格式化
- **过滤器**: 正则、区域、类型、脚本
- **操作符**: 设置属性、标志、排序、重命名、脚本修改
- **解析器**: 域名解析

## SubForge 可以借鉴的点

1. **订阅格式化管道** — 添加过滤器/操作符系统
2. **更多输出格式** — 支持 Surge、Loon、QX 等
3. **脚本操作符** — 允许用户自定义节点修改逻辑
4. **域名解析操作** — 将节点域名解析为 IP

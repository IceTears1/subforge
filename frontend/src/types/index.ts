// 用户类型
export interface User {
  id: number
  username: string
  role: string
  status?: number
  created_at?: string
}

// 登录参数
export interface LoginParams {
  username: string
  password: string
}

// 登录结果
export interface LoginResult {
  token: string
  user: User
}

// 订阅类型
export interface Subscription {
  id: number
  user_id?: number
  name: string
  url: string
  token?: string
  auto_refresh?: number
  tags?: string[]
  last_fetch: string | null
  node_count: number
  status: number
  created_at?: string
  updated_at?: string
  nodes?: Node[]
}

// 节点类型
export interface Node {
  id: number
  subscription_id?: number
  subscription_name?: string
  name: string
  display_name?: string
  node_type: string
  server: string
  port: number
  region: string
  latency: number
  status: number
  config_json?: Record<string, any>
  raw_uri?: string
}

// API 响应
export interface ApiResponse<T> {
  items?: T[]
  total?: number
  data?: T
}

// 版本信息
export interface VersionInfo {
  current: string
  current_tag: string
  current_commit?: string
  latest: string
  latest_tag: string
  has_update: boolean
  changelog?: string
  update_mode: 'tag' | 'branch'
  updating?: boolean
  last_check?: string
  last_update?: UpdateResult
}

// 更新结果
export interface UpdateStep {
  name: string
  status: 'pending' | 'running' | 'success' | 'failed'
  message: string
}

export interface UpdateResult {
  success: boolean
  from: string
  to: string
  steps: UpdateStep[]
  timestamp: string
  error?: string
}

// 系统指标
export interface Metrics {
  users: number
  subscriptions: number
  nodes: number
  uptime_seconds: number
  memory: {
    alloc_mb: number
    total_mb: number
  }
  goroutines: number
  cpu_percent: number
}

// 审计日志
export interface AuditLog {
  id: number
  user_id: number
  username: string
  action: string
  resource: string
  detail: string
  ip: string
  success: number
  created_at: string
}

// 分页参数
export interface PaginationParams {
  page: number
  page_size: number
}

// 分页响应
export interface PaginatedResponse<T> {
  items: T[]
  total: number
  page: number
  page_size: number
}

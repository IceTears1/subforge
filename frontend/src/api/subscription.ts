import api from './request'

export interface Subscription {
  id: number
  user_id: number
  name: string
  url: string
  auto_refresh: number
  tags: string[]
  last_fetch: string | null
  node_count: number
  status: number
  created_at: string
  nodes?: Node[]
}

export interface Node {
  id: number
  subscription_id: number
  name: string
  display_name: string
  node_type: string
  server: string
  port: number
  region: string
  latency: number
  status: number
}

export function getSubscriptions() {
  return api.get<Subscription[]>('/subscriptions')
}

export function getSubscription(id: number) {
  return api.get<Subscription>(`/subscriptions/${id}`)
}

export function createSubscription(name: string, url: string, autoRefresh?: number, tags?: string[]) {
  return api.post('/subscriptions', { name, url, auto_refresh: autoRefresh || 3600, tags: tags || [] })
}

export function updateSubscription(id: number, name: string, url: string, autoRefresh?: number, tags?: string[]) {
  return api.put(`/subscriptions/${id}`, { name, url, auto_refresh: autoRefresh || 3600, tags: tags || [] })
}

export function deleteSubscription(id: number) {
  return api.delete(`/subscriptions/${id}`)
}

export function refreshSubscription(id: number) {
  return api.post(`/subscriptions/${id}/refresh`)
}

export function getNodes(subId: number, region?: string) {
  return api.get<Node[]>(`/subscriptions/${subId}/nodes`, { params: { region } })
}

export function convertSub(sourceUrl: string, target: string, options?: Record<string, any>) {
  return api.post('/convert', { source_url: sourceUrl, target, ...options }, { responseType: 'text' })
}

export function detectFormat(source: string) {
  return api.post('/detect', { source })
}

export function getFormats() {
  return api.get('/formats')
}

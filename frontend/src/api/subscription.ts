import api from './request'

export interface Subscription {
  id: number
  user_id: number
  name: string
  url: string
  token?: string
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
  subscription_name?: string
  name: string
  display_name: string
  node_type: string
  server: string
  port: number
  region: string
  latency: number
  download_speed?: number
  download_speed_type?: string
  status: number
}

export function getSubscriptions(page = 1, pageSize = 20) {
  return api.get('/subscriptions', { params: { page, page_size: pageSize } })
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

export function getAllNodes() {
  return api.get<Node[]>('/nodes/all')
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

export function exportSubscriptions() {
  return api.get('/export', { responseType: 'blob' })
}

export function importSubscriptions(data: any[]) {
  return api.post('/import', data)
}

export function batchDeleteSubscriptions(ids: number[]) {
  return api.post('/subscriptions/batch/delete', { ids })
}

export function batchRefreshSubscriptions(ids: number[]) {
  return api.post('/subscriptions/batch/refresh', { ids })
}

export function checkSubscriptionHealth(id: number) {
  return api.post(`/subscriptions/${id}/check`)
}

export function batchExportSubscriptions(ids: number[]) {
  return api.post('/subscriptions/batch/export', { ids }, { responseType: 'blob' })
}

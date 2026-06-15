import api from './request'

export interface VersionInfo {
  current: string
  latest: string
  has_update: boolean
  changelog: string
  last_check: string
  updating: boolean
  last_update?: UpdateResult
}

export interface VersionEntry {
  hash: string
  message: string
  date: string
}

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

export function getVersion() {
  return api.get<VersionInfo>('/update/version')
}

export function getUpdateStatus() {
  return api.get<{ updating: boolean; last_result: UpdateResult | null }>('/update/status')
}

export function getChangelog(count = 20) {
  return api.get<VersionEntry[]>('/update/changelog', { params: { count } })
}

export function performUpdate() {
  return api.post<UpdateResult>('/update')
}

export function performRollback(version: string) {
  return api.post<UpdateResult>('/update/rollback', { version })
}

import api from './request'

export interface VersionInfo {
  current: string
  latest: string
  has_update: boolean
  changelog: string
  last_check: string
}

export interface VersionEntry {
  hash: string
  message: string
  date: string
}

export interface UpdateResult {
  from: string
  to: string
  timestamp: string
  success: boolean
  message: string
}

export function getVersion() {
  return api.get<VersionInfo>('/update/version')
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

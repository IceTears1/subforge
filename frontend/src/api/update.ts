import api from './request'
import type { VersionInfo, UpdateResult } from '../types'

export type { VersionInfo, UpdateResult }

export interface Release {
  tag: string
  commit_hash: string
  message: string
  date: string
  is_current: boolean
}

export interface ChangelogEntry {
  hash: string
  message: string
  date: string
}

// 获取版本信息
export function getVersion() {
  return api.get<VersionInfo>('/update/version')
}

// 获取所有发布版本
export function getReleases() {
  return api.get<Release[]>('/update/releases')
}

// 获取更新状态
export function getUpdateStatus() {
  return api.get<{ updating: boolean; last_result: UpdateResult | null }>('/update/status')
}

// 获取更新日志
export function getChangelog(from?: string, to?: string) {
  return api.get<ChangelogEntry[]>('/update/changelog', { params: { from, to } })
}

// 更新到最新版本
export function updateToLatest() {
  return api.post<UpdateResult>('/update/latest')
}

// 更新到指定 Tag
export function updateToTag(tag: string) {
  return api.post<UpdateResult>('/update/tag', { tag })
}

// 回滚到指定版本
export function performRollback(version: string) {
  return api.post<UpdateResult>('/update/rollback', { version })
}

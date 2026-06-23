import api from './request'
import type { LoginParams, LoginResult } from '../types'

export type { LoginParams, LoginResult }

export function login(params: LoginParams) {
  return api.post<LoginResult>('/auth/login', params)
}

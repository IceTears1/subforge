import api from './request'

export interface LoginParams {
  username: string
  password: string
}

export interface LoginResult {
  token: string
  expires_in: number
  user: {
    id: number
    username: string
    role: string
  }
}

export function login(params: LoginParams) {
  return api.post<LoginResult>('/auth/login', params)
}

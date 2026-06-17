import api from './request'

export interface User {
  id: number
  username: string
  role: string
  status: number
  created_by: number | null
  created_at: string
}

export function getUsers(page = 1, pageSize = 20) {
  return api.get('/users', { params: { page, page_size: pageSize } })
}

export function createUser(username: string, password: string) {
  return api.post('/users', { username, password })
}

export function updateUserStatus(id: number, status: number) {
  return api.put(`/users/${id}/status`, { status })
}

export function resetPassword(id: number, password: string) {
  return api.put(`/users/${id}/password`, { password })
}

export function deleteUser(id: number) {
  return api.delete(`/users/${id}`)
}

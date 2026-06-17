import api from './request'

export interface APIKey {
  id: number
  name: string
  key: string
  last_used: string | null
  status: number
}

export function getAPIKeys() {
  return api.get<APIKey[]>('/apikeys')
}

export function createAPIKey(name: string) {
  return api.post('/apikeys', { name })
}

export function deleteAPIKey(id: number) {
  return api.delete(`/apikeys/${id}`)
}

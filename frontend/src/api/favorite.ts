import api from './request'

export interface FavoriteNode {
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

export function getFavorites() {
  return api.get<FavoriteNode[]>('/favorites')
}

export function addFavorite(nodeId: number, note?: string) {
  return api.post('/favorites', { node_id: nodeId, note })
}

export function removeFavorite(nodeId: number) {
  return api.delete(`/favorites/${nodeId}`)
}

export function checkFavorite(nodeId: number) {
  return api.get<{ is_favorite: boolean }>(`/favorites/${nodeId}/check`)
}

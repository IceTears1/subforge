import { defineStore } from 'pinia'
import { ref } from 'vue'
import { getSubscriptions, refreshSubscription } from '../api/subscription'
import type { Subscription } from '../types'

export const useSubStore = defineStore('subscription', () => {
  const subscriptions = ref<Subscription[]>([])
  const loading = ref(false)

  async function load() {
    loading.value = true
    try {
      const res = await getSubscriptions()
      // Handle both paginated ({ items: [...] }) and flat array responses
      const data = res.data
      subscriptions.value = Array.isArray(data) ? data : (data.items || [])
    } catch (error) {
      console.error('Failed to load subscriptions:', error)
      subscriptions.value = []
    } finally {
      loading.value = false
    }
  }

  async function refresh(id: number) {
    try {
      await refreshSubscription(id)
      await load()
    } catch (error) {
      console.error('Failed to refresh subscription:', error)
      throw error
    }
  }

  return { subscriptions, loading, load, refresh }
})

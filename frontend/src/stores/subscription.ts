import { defineStore } from 'pinia'
import { ref } from 'vue'
import { getSubscriptions, refreshSubscription } from '../api/subscription'
import type { Subscription } from '../api/subscription'

export const useSubStore = defineStore('subscription', () => {
  const subscriptions = ref<Subscription[]>([])
  const loading = ref(false)

  async function load() {
    loading.value = true
    try {
      const res = await getSubscriptions()
      subscriptions.value = res.data
    } finally {
      loading.value = false
    }
  }

  async function refresh(id: number) {
    await refreshSubscription(id)
    await load()
  }

  return { subscriptions, loading, load, refresh }
})

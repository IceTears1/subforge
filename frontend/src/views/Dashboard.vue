<template>
  <div>
    <n-grid :cols="4" :x-gap="16" :y-gap="16">
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="订阅数量">
            <template #prefix>
              <n-icon :component="CloudOutline" color="#6366f1" />
            </template>
            {{ stats.subscriptions }}
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="节点总数">
            <template #prefix>
              <n-icon :component="ServerOutline" color="#10b981" />
            </template>
            {{ stats.nodes }}
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="覆盖区域">
            <template #prefix>
              <n-icon :component="GlobeOutline" color="#f59e0b" />
            </template>
            {{ stats.regions }}
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="在线状态">
            <template #prefix>
              <n-icon :component="PulseOutline" :color="stats.healthy ? '#10b981' : '#ef4444'" />
            </template>
            {{ stats.healthy ? '正常' : '异常' }}
          </n-statistic>
        </n-card>
      </n-gi>
    </n-grid>

    <n-card title="最近订阅" :bordered="false" style="margin-top: 24px">
      <n-alert v-if="error" type="error" style="margin-bottom: 16px">
        {{ error }}
      </n-alert>
      <n-data-table :columns="columns" :data="recentSubs" :loading="loading" :bordered="false" />
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, h } from 'vue'
import { NGrid, NGi, NCard, NStatistic, NIcon, NDataTable, NTag, NAlert } from 'naive-ui'
import { CloudOutline, ServerOutline, GlobeOutline, PulseOutline } from '@vicons/ionicons5'
import { getSubscriptions, getNodes } from '../api/subscription'
import type { Subscription } from '../api/subscription'

const loading = ref(false)
const error = ref('')
const stats = ref({ subscriptions: 0, nodes: 0, regions: 0, healthy: true })
const recentSubs = ref<Subscription[]>([])

const columns = [
  { title: '名称', key: 'name' },
  { title: '节点数', key: 'node_count' },
  {
    title: '状态',
    key: 'status',
    render(row: Subscription) {
      return h(NTag, { type: row.status === 1 ? 'success' : 'error', size: 'small', bordered: false }, { default: () => row.status === 1 ? '正常' : '禁用' })
    },
  },
  {
    title: '最后更新',
    key: 'last_fetch',
    render(row: Subscription) {
      return row.last_fetch ? new Date(row.last_fetch).toLocaleString() : '未更新'
    },
  },
]

onMounted(async () => {
  loading.value = true
  error.value = ''
  try {
    const res = await getSubscriptions()
    recentSubs.value = res.data.slice(0, 10)
    stats.value.subscriptions = res.data.length
    stats.value.nodes = res.data.reduce((sum: number, s: Subscription) => sum + s.node_count, 0)

    // Count unique regions from actual nodes
    const regionSet = new Set<string>()
    for (const sub of res.data.slice(0, 5)) { // sample first 5 subs
      try {
        const nodesRes = await getNodes(sub.id)
        nodesRes.data.forEach((n: any) => { if (n.region) regionSet.add(n.region) })
      } catch { /* skip */ }
    }
    stats.value.regions = regionSet.size || res.data.length
    stats.value.healthy = true
  } catch (e: any) {
    error.value = e.response?.data?.message || '加载失败，请检查服务状态'
    stats.value.healthy = false
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.stat-card {
  text-align: center;
}
</style>

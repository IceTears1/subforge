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
              <n-icon :component="PulseOutline" color="#10b981" />
            </template>
            正常
          </n-statistic>
        </n-card>
      </n-gi>
    </n-grid>

    <n-card title="最近订阅" :bordered="false" style="margin-top: 24px">
      <n-data-table :columns="columns" :data="recentSubs" :bordered="false" />
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, h } from 'vue'
import { NGrid, NGi, NCard, NStatistic, NIcon, NDataTable, NTag } from 'naive-ui'
import { CloudOutline, ServerOutline, GlobeOutline, PulseOutline } from '@vicons/ionicons5'
import { getSubscriptions } from '../api/subscription'
import type { Subscription } from '../api/subscription'

const stats = ref({ subscriptions: 0, nodes: 0, regions: 0 })
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
  try {
    const res = await getSubscriptions()
    recentSubs.value = res.data.slice(0, 10)
    stats.value.subscriptions = res.data.length
    stats.value.nodes = res.data.reduce((sum: number, s: Subscription) => sum + s.node_count, 0)
    // Count unique regions from nodes
    const regions = new Set(res.data.map((s: Subscription) => s.name))
    stats.value.regions = regions.size
  } catch {}
})
</script>

<style scoped>
.stat-card {
  text-align: center;
}
</style>

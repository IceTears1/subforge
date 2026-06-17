<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>节点性能测试</span>
          <n-space>
            <n-select v-model:value="selectedSub" :options="subOptions" placeholder="选择订阅" style="width: 200px" @update:value="loadNodes" />
            <n-button type="primary" :loading="testing" @click="handleTest" :disabled="nodes.length === 0">
              开始测试 ({{ nodes.length }} 个节点)
            </n-button>
          </n-space>
        </n-space>
      </template>

      <n-space style="margin-bottom: 16px">
        <n-tag :bordered="false">总计: {{ results.length }}</n-tag>
        <n-tag :bordered="false" type="success">在线: {{ onlineCount }}</n-tag>
        <n-tag :bordered="false" type="error">离线: {{ offlineCount }}</n-tag>
        <n-tag :bordered="false" type="info">平均延迟: {{ avgLatency }}ms</n-tag>
      </n-space>

      <n-data-table
        :columns="columns"
        :data="sortedResults"
        :loading="testing"
        :bordered="false"
        :max-height="600"
        :scroll-x="900"
      />
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, h } from 'vue'
import { useMessage, NCard, NSelect, NButton, NSpace, NTag, NDataTable, NProgress } from 'naive-ui'
import { getSubscriptions, getNodes, checkSubscriptionHealth } from '../api/subscription'
import type { Subscription, Node } from '../api/subscription'

const message = useMessage()
const testing = ref(false)
const subscriptions = ref<Subscription[]>([])
const nodes = ref<Node[]>([])
const selectedSub = ref<number | null>(null)
const results = ref<any[]>([])

const subOptions = computed(() => subscriptions.value.map(s => ({ label: s.name, value: s.id })))

const onlineCount = computed(() => results.value.filter(r => r.status === 'online').length)
const offlineCount = computed(() => results.value.filter(r => r.status !== 'online').length)
const avgLatency = computed(() => {
  const online = results.value.filter(r => r.latency > 0)
  if (online.length === 0) return 0
  return Math.round(online.reduce((sum, r) => sum + r.latency, 0) / online.length)
})

const sortedResults = computed(() => {
  return [...results.value].sort((a, b) => {
    if (a.status === 'online' && b.status !== 'online') return -1
    if (a.status !== 'online' && b.status === 'online') return 1
    return a.latency - b.latency
  })
})

const columns = [
  { title: '名称', key: 'name', width: 200, ellipsis: { tooltip: true } },
  { title: '类型', key: 'type', width: 80 },
  { title: '地址', key: 'server', width: 150, ellipsis: { tooltip: true } },
  { title: '端口', key: 'port', width: 70 },
  { title: '区域', key: 'region', width: 80 },
  {
    title: '延迟', key: 'latency', width: 100,
    render(row: any) {
      if (row.latency <= 0) return '-'
      const color = row.latency < 100 ? '#10b981' : row.latency < 200 ? '#22c55e' : row.latency < 500 ? '#f59e0b' : '#ef4444'
      return h('span', { style: { color, fontWeight: 600 } }, `${row.latency}ms`)
    },
  },
  {
    title: '状态', key: 'status', width: 80,
    render(row: any) {
      const type = row.status === 'online' ? 'success' : row.status === 'timeout' ? 'warning' : 'error'
      return h(NTag, { type, size: 'small', bordered: false }, { default: () => row.status })
    },
  },
  {
    title: '评级', key: 'grade', width: 100,
    render(row: any) {
      if (row.latency <= 0) return '-'
      let grade = 'D'
      let color = '#ef4444'
      if (row.latency < 100) { grade = 'A+'; color = '#10b981' }
      else if (row.latency < 200) { grade = 'A'; color = '#22c55e' }
      else if (row.latency < 300) { grade = 'B'; color = '#84cc16' }
      else if (row.latency < 500) { grade = 'C'; color = '#f59e0b' }
      return h(NTag, { type: 'info', size: 'small', bordered: false, style: { color } }, { default: () => grade })
    },
  },
]

async function loadNodes() {
  if (!selectedSub.value) return
  try {
    const res = await getNodes(selectedSub.value)
    nodes.value = res.data || []
    results.value = nodes.value.map(n => ({
      ...n,
      latency: n.latency || 0,
      status: n.status === 1 ? 'online' : 'unknown',
    }))
  } catch {}
}

async function handleTest() {
  if (!selectedSub.value) return
  testing.value = true

  try {
    const res = await checkSubscriptionHealth(selectedSub.value)
    const healthResults = res.data.results || []

    // Merge health results with nodes
    results.value = nodes.value.map(n => {
      const health = healthResults.find((h: any) => h.node_id === n.id)
      return {
        ...n,
        latency: health?.latency || n.latency || 0,
        status: health?.status || (n.status === 1 ? 'online' : 'unknown'),
      }
    })

    message.success(`测试完成: ${onlineCount.value} 在线, ${offlineCount.value} 离线`)
  } catch (e: any) {
    message.error('测试失败')
  } finally {
    testing.value = false
  }
}

onMounted(async () => {
  try {
    const res = await getSubscriptions(1, 100)
    subscriptions.value = res.data.items || res.data
    if (subscriptions.value.length > 0) {
      selectedSub.value = subscriptions.value[0].id
      await loadNodes()
    }
  } catch {}
})
</script>

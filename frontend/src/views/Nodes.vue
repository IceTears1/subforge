<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>节点管理</span>
          <n-space>
            <n-select v-model:value="selectedSub" :options="subOptions" placeholder="选择订阅" style="width: 200px" @update:value="loadNodes" />
            <n-select v-model:value="selectedRegion" :options="regionOptions" placeholder="区域筛选" clearable style="width: 140px" @update:value="filterNodes" />
            <n-input v-model:value="searchQuery" placeholder="搜索节点..." clearable style="width: 200px" @update:value="filterNodes" />
          </n-space>
        </n-space>
      </template>

      <n-space style="margin-bottom: 16px">
        <n-tag :bordered="false">总计: {{ filteredNodes.length }}</n-tag>
        <n-tag :bordered="false" type="success">在线: {{ onlineCount }}</n-tag>
        <n-tag :bordered="false" type="error">离线: {{ offlineCount }}</n-tag>
        <n-tag :bordered="false" type="info">区域: {{ regionCount }}</n-tag>
      </n-space>

      <n-data-table
        :columns="columns"
        :data="filteredNodes"
        :loading="loading"
        :bordered="false"
        :max-height="600"
        :scroll-x="800"
      />
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, h } from 'vue'
import { NCard, NDataTable, NSelect, NInput, NSpace, NTag } from 'naive-ui'
import { getSubscriptions, getNodes } from '../api/subscription'
import type { Subscription, Node } from '../api/subscription'

const loading = ref(false)
const subscriptions = ref<Subscription[]>([])
const nodes = ref<Node[]>([])
const filteredNodes = ref<Node[]>([])
const selectedSub = ref<number | null>(null)
const selectedRegion = ref<string | null>(null)
const searchQuery = ref('')

const subOptions = computed(() => subscriptions.value.map(s => ({ label: s.name, value: s.id })))

const regionOptions = [
  { label: '🇭🇰 HK', value: 'HK' },
  { label: '🇯🇵 JP', value: 'JP' },
  { label: '🇸🇬 SG', value: 'SG' },
  { label: '🇺🇸 US', value: 'US' },
  { label: '🇨🇳 TW', value: 'TW' },
  { label: '🇰🇷 KR', value: 'KR' },
  { label: '🇬🇧 UK', value: 'UK' },
  { label: '🇩🇪 DE', value: 'DE' },
]

const onlineCount = computed(() => nodes.value.filter(n => n.status === 1).length)
const offlineCount = computed(() => nodes.value.filter(n => n.status !== 1).length)
const regionCount = computed(() => new Set(nodes.value.map(n => n.region).filter(Boolean)).size)

const columns = [
  { title: 'ID', key: 'id', width: 60 },
  { title: '名称', key: 'display_name', width: 200, ellipsis: { tooltip: true } },
  { title: '类型', key: 'node_type', width: 80 },
  { title: '地址', key: 'server', width: 150, ellipsis: { tooltip: true } },
  { title: '端口', key: 'port', width: 70 },
  {
    title: '区域', key: 'region', width: 80,
    render(row: Node) {
      const emoji = { HK: '🇭🇰', JP: '🇯🇵', SG: '🇸🇬', US: '🇺🇸', TW: '🇨🇳', KR: '🇰🇷', UK: '🇬🇧', DE: '🇩🇪' }[row.region] || '🌐'
      return `${emoji} ${row.region || '-'}`
    },
  },
  {
    title: '延迟', key: 'latency', width: 80,
    render(row: Node) {
      if (!row.latency) return '-'
      const color = row.latency < 200 ? '#10b981' : row.latency < 500 ? '#f59e0b' : '#ef4444'
      return h('span', { style: { color } }, `${row.latency}ms`)
    },
  },
  {
    title: '状态', key: 'status', width: 70,
    render(row: Node) {
      return h(NTag, { type: row.status === 1 ? 'success' : 'error', size: 'small', bordered: false }, { default: () => row.status === 1 ? '在线' : '离线' })
    },
  },
]

async function loadSubs() {
  try {
    const res = await getSubscriptions(1, 100)
    subscriptions.value = res.data.items || res.data
    if (subscriptions.value.length > 0 && !selectedSub.value) {
      selectedSub.value = subscriptions.value[0].id
      await loadNodes()
    }
  } catch {}
}

async function loadNodes() {
  if (!selectedSub.value) return
  loading.value = true
  try {
    const res = await getNodes(selectedSub.value)
    nodes.value = res.data || []
    filterNodes()
  } catch {} finally { loading.value = false }
}

function filterNodes() {
  let result = [...nodes.value]
  if (selectedRegion.value) {
    result = result.filter(n => n.region === selectedRegion.value)
  }
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    result = result.filter(n =>
      n.display_name?.toLowerCase().includes(q) ||
      n.server?.toLowerCase().includes(q) ||
      n.node_type?.toLowerCase().includes(q)
    )
  }
  filteredNodes.value = result
}

onMounted(loadSubs)
</script>

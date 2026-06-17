<template>
  <div>
    <n-grid :cols="isMobile ? 2 : 4" :x-gap="16" :y-gap="16">
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

    <n-grid :cols="isMobile ? 1 : 2" :x-gap="24" style="margin-top: 24px">
      <n-gi>
        <n-card title="节点区域分布" :bordered="false">
          <div class="region-bars">
            <div v-for="item in regionStats" :key="item.region" class="region-bar">
              <div class="region-label">
                <span>{{ item.emoji }} {{ item.region }}</span>
                <span class="region-count">{{ item.count }}</span>
              </div>
              <n-progress
                :percentage="item.percent"
                :show-indicator="false"
                :color="item.color"
                :rail-color="isDark ? '#2a2a4a' : '#f0f0f0'"
                style="height: 8px"
              />
            </div>
          </div>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card title="协议分布" :bordered="false">
          <div class="region-bars">
            <div v-for="item in protocolStats" :key="item.type" class="region-bar">
              <div class="region-label">
                <span>{{ item.type.toUpperCase() }}</span>
                <span class="region-count">{{ item.count }}</span>
              </div>
              <n-progress
                :percentage="item.percent"
                :show-indicator="false"
                :color="item.color"
                :rail-color="isDark ? '#2a2a4a' : '#f0f0f0'"
                style="height: 8px"
              />
            </div>
          </div>
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
import { ref, computed, onMounted, h } from 'vue'
import { NGrid, NGi, NCard, NStatistic, NIcon, NDataTable, NTag, NAlert, NProgress } from 'naive-ui'
import { CloudOutline, ServerOutline, GlobeOutline, PulseOutline } from '@vicons/ionicons5'
import { getSubscriptions, getNodes } from '../api/subscription'
import { useThemeStore } from '../stores/theme'
import type { Subscription, Node } from '../api/subscription'

const themeStore = useThemeStore()
const isDark = computed(() => themeStore.isDark)
const isMobile = ref(window.innerWidth <= 768)
const loading = ref(false)
const error = ref('')
const stats = ref({ subscriptions: 0, nodes: 0, regions: 0, healthy: true })
const recentSubs = ref<Subscription[]>([])
const allNodes = ref<Node[]>([])

const regionColors: Record<string, string> = {
  HK: '#ef4444', JP: '#f59e0b', SG: '#10b981', US: '#6366f1',
  TW: '#ec4899', KR: '#8b5cf6', UK: '#06b6d4', DE: '#84cc16', OTHER: '#9ca3af',
}

const protocolColors: Record<string, string> = {
  vmess: '#6366f1', vless: '#10b981', trojan: '#f59e0b',
  ss: '#ef4444', ssr: '#ec4899', hysteria2: '#8b5cf6', tuic: '#06b6d4',
}

const regionStats = computed(() => {
  const counts: Record<string, number> = {}
  allNodes.value.forEach(n => { counts[n.region || 'OTHER'] = (counts[n.region || 'OTHER'] || 0) + 1 })
  const total = allNodes.value.length || 1
  return Object.entries(counts)
    .map(([region, count]) => ({
      region,
      count,
      percent: Math.round((count / total) * 100),
      emoji: { HK: '🇭🇰', JP: '🇯🇵', SG: '🇸🇬', US: '🇺🇸', TW: '🇨🇳', KR: '🇰🇷', UK: '🇬🇧', DE: '🇩🇪' }[region] || '🌐',
      color: regionColors[region] || regionColors.OTHER,
    }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8)
})

const protocolStats = computed(() => {
  const counts: Record<string, number> = {}
  allNodes.value.forEach(n => { counts[n.node_type || 'other'] = (counts[n.node_type || 'other'] || 0) + 1 })
  const total = allNodes.value.length || 1
  return Object.entries(counts)
    .map(([type, count]) => ({
      type,
      count,
      percent: Math.round((count / total) * 100),
      color: protocolColors[type] || '#9ca3af',
    }))
    .sort((a, b) => b.count - a.count)
})

const columns = [
  { title: '名称', key: 'name' },
  { title: '节点数', key: 'node_count' },
  {
    title: '状态', key: 'status',
    render(row: Subscription) {
      return h(NTag, { type: row.status === 1 ? 'success' : 'error', size: 'small', bordered: false }, { default: () => row.status === 1 ? '正常' : '禁用' })
    },
  },
  {
    title: '最后更新', key: 'last_fetch',
    render(row: Subscription) {
      return row.last_fetch ? new Date(row.last_fetch).toLocaleString() : '未更新'
    },
  },
]

onMounted(async () => {
  loading.value = true
  error.value = ''
  try {
    const res = await getSubscriptions(1, 50)
    const items = res.data.items || res.data
    recentSubs.value = items.slice(0, 10)
    stats.value.subscriptions = res.data.total || items.length
    stats.value.nodes = items.reduce((sum: number, s: Subscription) => sum + s.node_count, 0)

    const regionSet = new Set<string>()
    for (const sub of items.slice(0, 10)) {
      try {
        const nodesRes = await getNodes(sub.id)
        const nodes = nodesRes.data || []
        allNodes.value.push(...nodes)
        nodes.forEach((n: Node) => { if (n.region) regionSet.add(n.region) })
      } catch { /* skip */ }
    }
    stats.value.regions = regionSet.size || items.length
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
.stat-card { text-align: center; }
.region-bars { display: flex; flex-direction: column; gap: 12px; }
.region-label { display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 13px; }
.region-count { font-weight: 600; color: #6366f1; }
</style>

<template>
  <div>
    <n-grid :cols="isMobile ? 2 : 4" :x-gap="16" :y-gap="16">
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="总订阅数">
            <template #prefix>
              <n-icon :component="CloudOutline" color="#6366f1" />
            </template>
            {{ stats.totalSubs }}
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="总节点数">
            <template #prefix>
              <n-icon :component="ServerOutline" color="#10b981" />
            </template>
            {{ stats.totalNodes }}
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="平均节点/订阅">
            <template #prefix>
              <n-icon :component="AnalyticsOutline" color="#f59e0b" />
            </template>
            {{ stats.avgNodesPerSub }}
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="区域覆盖">
            <template #prefix>
              <n-icon :component="GlobeOutline" color="#8b5cf6" />
            </template>
            {{ stats.regionCount }}
          </n-statistic>
        </n-card>
      </n-gi>
    </n-grid>

    <n-grid :cols="isMobile ? 1 : 2" :x-gap="24" style="margin-top: 24px">
      <n-gi>
        <n-card title="订阅节点分布" :bordered="false">
          <div class="chart-container">
            <div v-for="sub in subNodeDistribution" :key="sub.name" class="bar-item">
              <div class="bar-label">
                <span>{{ sub.name }}</span>
                <span class="bar-value">{{ sub.count }}</span>
              </div>
              <n-progress
                :percentage="sub.percent"
                :show-indicator="false"
                :color="sub.color"
                :rail-color="isDark ? '#2a2a4a' : '#f0f0f0'"
                style="height: 8px"
              />
            </div>
          </div>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card title="区域节点分布" :bordered="false">
          <div class="chart-container">
            <div v-for="region in regionDistribution" :key="region.name" class="bar-item">
              <div class="bar-label">
                <span>{{ region.emoji }} {{ region.name }}</span>
                <span class="bar-value">{{ region.count }}</span>
              </div>
              <n-progress
                :percentage="region.percent"
                :show-indicator="false"
                :color="region.color"
                :rail-color="isDark ? '#2a2a4a' : '#f0f0f0'"
                style="height: 8px"
              />
            </div>
          </div>
        </n-card>
      </n-gi>
    </n-grid>

    <n-grid :cols="isMobile ? 1 : 2" :x-gap="24" style="margin-top: 24px">
      <n-gi>
        <n-card title="协议分布" :bordered="false">
          <div class="chart-container">
            <div v-for="proto in protocolDistribution" :key="proto.name" class="bar-item">
              <div class="bar-label">
                <span>{{ proto.name.toUpperCase() }}</span>
                <span class="bar-value">{{ proto.count }}</span>
              </div>
              <n-progress
                :percentage="proto.percent"
                :show-indicator="false"
                :color="proto.color"
                :rail-color="isDark ? '#2a2a4a' : '#f0f0f0'"
                style="height: 8px"
              />
            </div>
          </div>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card title="刷新状态" :bordered="false">
          <n-space vertical>
            <div class="metric-row">
              <span>最后刷新</span>
              <n-tag size="small">{{ stats.lastRefresh || '未刷新' }}</n-tag>
            </div>
            <div class="metric-row">
              <span>成功订阅</span>
              <n-tag type="success" size="small">{{ stats.successSubs }}</n-tag>
            </div>
            <div class="metric-row">
              <span>失败订阅</span>
              <n-tag :type="stats.failedSubs > 0 ? 'error' : 'success'" size="small">
                {{ stats.failedSubs }}
              </n-tag>
            </div>
            <div class="metric-row">
              <span>平均延迟</span>
              <n-tag :type="stats.avgLatency < 200 ? 'success' : stats.avgLatency < 500 ? 'warning' : 'error'" size="small">
                {{ stats.avgLatency }}ms
              </n-tag>
            </div>
          </n-space>
        </n-card>
      </n-gi>
    </n-grid>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { NGrid, NGi, NCard, NStatistic, NIcon, NProgress, NSpace, NTag } from 'naive-ui'
import { CloudOutline, ServerOutline, AnalyticsOutline, GlobeOutline } from '@vicons/ionicons5'
import { getSubscriptions, getNodes } from '../api/subscription'
import { useThemeStore } from '../stores/theme'
import type { Subscription, Node } from '../api/subscription'

const themeStore = useThemeStore()
const isDark = computed(() => themeStore.isDark)
const isMobile = ref(window.innerWidth <= 768)

const stats = ref({
  totalSubs: 0,
  totalNodes: 0,
  avgNodesPerSub: 0,
  regionCount: 0,
  lastRefresh: '',
  successSubs: 0,
  failedSubs: 0,
  avgLatency: 0,
})

const allNodes = ref<Node[]>([])
const subscriptions = ref<Subscription[]>([])

const regionColors: Record<string, string> = {
  HK: '#ef4444', JP: '#f59e0b', SG: '#10b981', US: '#6366f1',
  TW: '#ec4899', KR: '#8b5cf6', UK: '#06b6d4', DE: '#84cc16', OTHER: '#9ca3af',
}

const protocolColors: Record<string, string> = {
  vmess: '#6366f1', vless: '#10b981', trojan: '#f59e0b',
  ss: '#ef4444', ssr: '#ec4899', hysteria2: '#8b5cf6', tuic: '#06b6d4',
}

const subNodeDistribution = computed(() => {
  const total = allNodes.value.length || 1
  return subscriptions.value
    .map(s => ({
      name: s.name,
      count: s.node_count,
      percent: Math.round((s.node_count / total) * 100),
      color: '#6366f1',
    }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8)
})

const regionDistribution = computed(() => {
  const counts: Record<string, number> = {}
  allNodes.value.forEach(n => { counts[n.region || 'OTHER'] = (counts[n.region || 'OTHER'] || 0) + 1 })
  const total = allNodes.value.length || 1
  return Object.entries(counts)
    .map(([name, count]) => ({
      name,
      count,
      percent: Math.round((count / total) * 100),
      emoji: { HK: '🇭🇰', JP: '🇯🇵', SG: '🇸🇬', US: '🇺🇸', TW: '🇨🇳', KR: '🇰🇷', UK: '🇬🇧', DE: '🇩🇪' }[name] || '🌐',
      color: regionColors[name] || regionColors.OTHER,
    }))
    .sort((a, b) => b.count - a.count)
})

const protocolDistribution = computed(() => {
  const counts: Record<string, number> = {}
  allNodes.value.forEach(n => { counts[n.node_type || 'other'] = (counts[n.node_type || 'other'] || 0) + 1 })
  const total = allNodes.value.length || 1
  return Object.entries(counts)
    .map(([name, count]) => ({
      name,
      count,
      percent: Math.round((count / total) * 100),
      color: protocolColors[name] || '#9ca3af',
    }))
    .sort((a, b) => b.count - a.count)
})

onMounted(async () => {
  try {
    const res = await getSubscriptions(1, 100)
    subscriptions.value = res.data.items || res.data
    stats.value.totalSubs = subscriptions.value.length
    stats.value.successSubs = subscriptions.value.filter(s => s.status === 1).length
    stats.value.failedSubs = subscriptions.value.filter(s => s.status !== 1).length

    let totalNodes = 0
    let totalLatency = 0
    let latencyCount = 0

    for (const sub of subscriptions.value.slice(0, 20)) {
      try {
        const nodesRes = await getNodes(sub.id)
        const nodes = nodesRes.data || []
        allNodes.value.push(...nodes)
        totalNodes += nodes.length
        nodes.forEach((n: Node) => {
          if (n.latency > 0) {
            totalLatency += n.latency
            latencyCount++
          }
        })
      } catch {}
    }

    stats.value.totalNodes = totalNodes
    stats.value.avgNodesPerSub = subscriptions.value.length > 0
      ? Math.round(totalNodes / subscriptions.value.length)
      : 0
    stats.value.regionCount = new Set(allNodes.value.map(n => n.region).filter(Boolean)).size
    stats.value.avgLatency = latencyCount > 0 ? Math.round(totalLatency / latencyCount) : 0

    const lastSub = subscriptions.value.find(s => s.last_fetch)
    if (lastSub?.last_fetch) {
      stats.value.lastRefresh = new Date(lastSub.last_fetch).toLocaleString()
    }
  } catch {}
})
</script>

<style scoped>
.stat-card { text-align: center; }
.chart-container { display: flex; flex-direction: column; gap: 12px; }
.bar-item { display: flex; flex-direction: column; gap: 4px; }
.bar-label { display: flex; justify-content: space-between; font-size: 13px; }
.bar-value { font-weight: 600; color: #6366f1; }
.metric-row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid rgba(0,0,0,0.05); }
.metric-row:last-child { border-bottom: none; }
</style>

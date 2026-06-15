<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>节点分组</span>
          <n-space>
            <n-select v-model:value="selectedSub" :options="subOptions" placeholder="选择订阅" style="width: 200px" @update:value="loadNodes" />
            <n-select v-model:value="groupBy" :options="groupOptions" placeholder="分组方式" style="width: 140px" @update:value="regroup" />
          </n-space>
        </n-space>
      </template>

      <n-grid :cols="isMobile ? 1 : 2" :x-gap="16" :y-gap="16">
        <n-gi v-for="group in groups" :key="group.name">
          <n-card :bordered="false" :title="`${group.emoji} ${group.name} (${group.nodes.length})`">
            <n-data-table
              :columns="nodeColumns"
              :data="group.nodes"
              :bordered="false"
              :max-height="300"
              size="small"
            />
          </n-card>
        </n-gi>
      </n-grid>

      <n-empty v-if="groups.length === 0" description="请选择订阅和分组方式" style="padding: 40px 0" />
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, h } from 'vue'
import { NCard, NSelect, NGrid, NGi, NDataTable, NTag, NSpace, NEmpty } from 'naive-ui'
import { getSubscriptions, getNodes } from '../api/subscription'
import type { Subscription, Node } from '../api/subscription'

const isMobile = ref(window.innerWidth <= 768)
const subscriptions = ref<Subscription[]>([])
const nodes = ref<Node[]>([])
const selectedSub = ref<number | null>(null)
const groupBy = ref('region')

const subOptions = computed(() => subscriptions.value.map(s => ({ label: s.name, value: s.id })))

const groupOptions = [
  { label: '按区域', value: 'region' },
  { label: '按协议', value: 'type' },
  { label: '按状态', value: 'status' },
]

const regionEmoji: Record<string, string> = {
  HK: '🇭🇰', JP: '🇯🇵', SG: '🇸🇬', US: '🇺🇸',
  TW: '🇨🇳', KR: '🇰🇷', UK: '🇬🇧', DE: '🇩🇪',
  FR: '🇫🇷', AU: '🇦🇺', OTHER: '🌐',
}

const nodeColumns = [
  { title: '名称', key: 'display_name', width: 180, ellipsis: { tooltip: true } },
  { title: '类型', key: 'node_type', width: 80 },
  { title: '地址', key: 'server', width: 150, ellipsis: { tooltip: true } },
  { title: '端口', key: 'port', width: 70 },
  {
    title: '延迟', key: 'latency', width: 80,
    render(row: Node) {
      if (!row.latency) return '-'
      const color = row.latency < 200 ? '#10b981' : row.latency < 500 ? '#f59e0b' : '#ef4444'
      return h('span', { style: { color } }, `${row.latency}ms`)
    },
  },
]

interface NodeGroup {
  name: string
  emoji: string
  nodes: Node[]
}

const groups = computed<NodeGroup[]>(() => {
  const map = new Map<string, Node[]>()

  for (const node of nodes.value) {
    let key = ''
    switch (groupBy.value) {
      case 'region':
        key = node.region || 'OTHER'
        break
      case 'type':
        key = node.node_type || 'unknown'
        break
      case 'status':
        key = node.status === 1 ? '在线' : '离线'
        break
      default:
        key = 'all'
    }
    if (!map.has(key)) map.set(key, [])
    map.get(key)!.push(node)
  }

  return Array.from(map.entries())
    .map(([name, nodes]) => ({
      name,
      emoji: regionEmoji[name] || getGroupEmoji(name),
      nodes: nodes.sort((a, b) => (a.latency || 9999) - (b.latency || 9999)),
    }))
    .sort((a, b) => b.nodes.length - a.nodes.length)
})

function getGroupEmoji(name: string): string {
  const emojiMap: Record<string, string> = {
    vmess: '🔷', vless: '🟢', trojan: '🟡', ss: '🔴', ssr: '🟣',
    hysteria2: '⚡', tuic: '🌊',
    '在线': '✅', '离线': '❌',
  }
  return emojiMap[name] || '📦'
}

async function loadNodes() {
  if (!selectedSub.value) return
  try {
    const res = await getNodes(selectedSub.value)
    nodes.value = res.data || []
  } catch {}
}

function regroup() {
  // Reactive, no action needed
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
  window.addEventListener('resize', () => { isMobile.value = window.innerWidth <= 768 })
})
</script>

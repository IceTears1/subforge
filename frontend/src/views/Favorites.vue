<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>收藏节点</span>
          <n-tag :bordered="false">共 {{ nodes.length }} 个</n-tag>
        </n-space>
      </template>

      <n-data-table
        :columns="columns"
        :data="nodes"
        :loading="loading"
        :bordered="false"
        :max-height="600"
      />
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, h } from 'vue'
import { useMessage, NCard, NDataTable, NButton, NIcon, NSpace, NTag, NPopconfirm } from 'naive-ui'
import { TrashOutline, StarOutline } from '@vicons/ionicons5'
import { getFavorites, removeFavorite } from '../api/favorite'
import type { FavoriteNode } from '../api/favorite'

const message = useMessage()
const loading = ref(false)
const nodes = ref<FavoriteNode[]>([])

const columns = [
  { title: '名称', key: 'display_name', width: 200, ellipsis: { tooltip: true } },
  { title: '类型', key: 'node_type', width: 80 },
  { title: '地址', key: 'server', width: 150, ellipsis: { tooltip: true } },
  { title: '端口', key: 'port', width: 70 },
  {
    title: '区域', key: 'region', width: 80,
    render(row: FavoriteNode) {
      const emoji = { HK: '🇭🇰', JP: '🇯🇵', SG: '🇸🇬', US: '🇺🇸', TW: '🇨🇳', KR: '🇰🇷', UK: '🇬🇧', DE: '🇩🇪' }[row.region] || '🌐'
      return `${emoji} ${row.region || '-'}`
    },
  },
  {
    title: '延迟', key: 'latency', width: 80,
    render(row: FavoriteNode) {
      if (!row.latency) return '-'
      const color = row.latency < 200 ? '#10b981' : row.latency < 500 ? '#f59e0b' : '#ef4444'
      return h('span', { style: { color } }, `${row.latency}ms`)
    },
  },
  {
    title: '操作', key: 'actions', width: 80,
    render(row: FavoriteNode) {
      return h(NPopconfirm, { onPositiveClick: () => handleRemove(row) }, {
        trigger: () => h(NButton, { size: 'small', quaternary: true, type: 'error' }, { icon: () => h(NIcon, { component: TrashOutline }) }),
        default: () => '取消收藏？',
      })
    },
  },
]

async function load() {
  loading.value = true
  try {
    const res = await getFavorites()
    nodes.value = res.data || []
  } catch {} finally { loading.value = false }
}

async function handleRemove(node: FavoriteNode) {
  try {
    await removeFavorite(node.id)
    message.success('已取消收藏')
    await load()
  } catch { message.error('操作失败') }
}

onMounted(load)
</script>

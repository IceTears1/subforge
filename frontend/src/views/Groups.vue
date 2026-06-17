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
          <n-card :bordered="false">
            <template #header>
              <n-space justify="space-between" align="center" style="width: 100%">
                <span>{{ group.emoji }} {{ group.name }} ({{ group.nodes.length }})</span>
                <n-button
                  size="small"
                  type="primary"
                  quaternary
                  @click="openExportModal(group)"
                >
                  <template #icon><n-icon :component="DownloadOutline" /></template>
                  导出
                </n-button>
              </n-space>
            </template>
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

    <!-- Export Modal -->
    <n-modal v-model:show="showExportModal" preset="card" title="导出订阅地址" style="width: 600px">
      <n-grid :cols="2" :x-gap="24">
        <n-gi>
          <n-space vertical>
            <n-text strong>分组: {{ exportGroup?.name }}</n-text>
            <n-text depth="3" style="font-size: 12px;">{{ exportGroup?.nodes.length }} 个节点</n-text>

            <n-text strong>导出格式</n-text>
            <n-select v-model:value="exportFormat" :options="exportFormatOptions" />

            <n-text strong>订阅地址</n-text>
            <n-input :value="exportUrl" readonly type="textarea" :rows="4" style="font-family: monospace; font-size: 12px;" />

            <n-space>
              <n-button @click="copyExportUrl" type="primary">
                <template #icon><n-icon :component="CopyOutline" /></template>
                复制地址
              </n-button>
              <n-button @click="openExportUrl">
                <template #icon><n-icon :component="OpenOutline" /></template>
                打开链接
              </n-button>
            </n-space>
          </n-space>
        </n-gi>
        <n-gi>
          <n-space vertical align="center">
            <n-text strong>二维码</n-text>
            <n-card :bordered="false" style="width: 200px;">
              <div style="display: flex; justify-content: center;">
                <QRCodeVue3
                  :value="exportUrl"
                  :size="180"
                  :dots-options="{ type: 'rounded', color: '#000000' }"
                  :corners-square-options="{ type: 'extra-rounded' }"
                />
              </div>
            </n-card>
            <n-text depth="3" style="font-size: 12px;">扫描二维码导入订阅</n-text>
          </n-space>
        </n-gi>
      </n-grid>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, h } from 'vue'
import { NCard, NSelect, NGrid, NGi, NDataTable, NTag, NSpace, NEmpty, NButton, NIcon, NModal, NText, NInput, useMessage } from 'naive-ui'
import { DownloadOutline, CopyOutline, OpenOutline } from '@vicons/ionicons5'
import QRCodeVue3 from 'qrcode.vue'
import { getSubscriptions, getNodes } from '../api/subscription'
import type { Subscription, Node } from '../api/subscription'

const message = useMessage()
const isMobile = ref(window.innerWidth <= 768)
const subscriptions = ref<Subscription[]>([])
const nodes = ref<Node[]>([])
const selectedSub = ref<number | null>(null)
const groupBy = ref('region')

// Export modal state
const showExportModal = ref(false)
const exportGroup = ref<NodeGroup | null>(null)
const exportFormat = ref('clash')

const subOptions = computed(() => subscriptions.value.map(s => ({ label: s.name, value: s.id, token: s.token })))

const groupOptions = [
  { label: '按区域', value: 'region' },
  { label: '按协议', value: 'type' },
  { label: '按状态', value: 'status' },
]

const exportFormatOptions = [
  { label: 'Clash / Mihomo', value: 'clash' },
  { label: 'sing-box', value: 'singbox' },
  { label: 'Base64', value: 'base64' },
  { label: '纯文本', value: 'plain' },
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

const exportUrl = computed(() => {
  if (!exportGroup.value || !selectedSub.value) return ''

  const sub = subscriptions.value.find(s => s.id === selectedSub.value)
  if (!sub || !sub.token) return ''

  const origin = window.location.origin
  const params = new URLSearchParams({
    target: exportFormat.value,
    group_by: groupBy.value,
    group_value: exportGroup.value.name,
  })

  return `${origin}/sub/${sub.token}/export/group?${params.toString()}`
})

function getGroupEmoji(name: string): string {
  const emojiMap: Record<string, string> = {
    vmess: '🔷', vless: '🟢', trojan: '🟡', ss: '🔴', ssr: '🟣',
    hysteria2: '⚡', tuic: '🌊',
    '在线': '✅', '离线': '❌',
  }
  return emojiMap[name] || '📦'
}

function openExportModal(group: NodeGroup) {
  exportGroup.value = group
  showExportModal.value = true
}

function copyExportUrl() {
  if (!exportUrl.value) return
  navigator.clipboard.writeText(exportUrl.value).then(() => {
    message.success('订阅地址已复制')
  }).catch(() => {
    message.error('复制失败')
  })
}

function openExportUrl() {
  if (!exportUrl.value) return
  window.open(exportUrl.value, '_blank')
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

<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>节点分组</span>
          <n-space>
            <n-select v-model:value="groupBy" :options="groupOptions" placeholder="分组方式" style="width: 140px" />
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

      <n-empty v-if="groups.length === 0 && !loading" description="暂无节点数据" style="padding: 40px 0" />
      <div v-if="loading" style="padding: 40px 0; text-align: center;">
        <n-spin size="medium" description="加载中..." />
      </div>
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

            <n-text strong>说明</n-text>
            <n-alert type="info" style="font-size: 12px;">
              导出的订阅包含当前分组中的所有节点，可直接导入到 Clash/sing-box 等客户端
            </n-alert>
          </n-space>
        </n-gi>
        <n-gi>
          <n-space vertical align="center">
            <n-text strong>支持的客户端</n-text>
            <n-space>
              <n-tag>Clash</n-tag>
              <n-tag>Mihomo</n-tag>
              <n-tag>sing-box</n-tag>
              <n-tag>Surge</n-tag>
            </n-space>
          </n-space>
        </n-gi>
      </n-grid>
      <template #footer>
        <n-space justify="end">
          <n-button @click="showExportModal = false">关闭</n-button>
          <n-button type="primary" @click="exportCurrentGroup">
            <template #icon><n-icon :component="DownloadOutline" /></template>
            导出配置文件
          </n-button>
        </n-space>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, h } from 'vue'
import { NCard, NSelect, NGrid, NGi, NDataTable, NTag, NSpace, NEmpty, NButton, NIcon, NModal, NText, NInput, NAlert, NSpin, useMessage } from 'naive-ui'
import { DownloadOutline, CopyOutline, OpenOutline } from '@vicons/ionicons5'
import { getAllNodes } from '../api/subscription'
import type { Node } from '../api/subscription'
import { formatOptions as exportFormatOptions } from '@/constants/formats'
import { generateClashYaml, generateSingboxJson, generateBase64 } from '@/utils/export'

const message = useMessage()
const isMobile = ref(window.innerWidth <= 768)
const nodes = ref<Node[]>([])
const loading = ref(false)
const groupBy = ref('region')

// Export modal state
const showExportModal = ref(false)
const exportGroup = ref<NodeGroup | null>(null)
const exportFormat = ref('clash')

const groupOptions = [
  { label: '按区域', value: 'region' },
  { label: '按协议', value: 'type' },
  { label: '按状态', value: 'status' },
  { label: '按订阅来源', value: 'subscription' },
]

const regionEmoji: Record<string, string> = {
  HK: '🇭🇰', JP: '🇯🇵', SG: '🇸🇬', US: '🇺🇸',
  TW: '🇨🇳', KR: '🇰🇷', UK: '🇬🇧', DE: '🇩🇪',
  FR: '🇫🇷', AU: '🇦🇺', OTHER: '🌐',
}

const nodeColumns = [
  { title: '名称', key: 'display_name', width: 150, ellipsis: { tooltip: true } },
  { title: '类型', key: 'node_type', width: 70 },
  { title: '地址', key: 'server', width: 130, ellipsis: { tooltip: true } },
  { title: '端口', key: 'port', width: 60 },
  { title: '来源', key: 'subscription_name', width: 100, ellipsis: { tooltip: true } },
  {
    title: '延迟', key: 'latency', width: 70,
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
      case 'subscription':
        key = node.subscription_name || '未知来源'
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

function openExportModal(group: NodeGroup) {
  exportGroup.value = group
  showExportModal.value = true
}

function exportCurrentGroup() {
  if (!exportGroup.value) return

  // Generate subscription content based on format
  const groupNodes = exportGroup.value.nodes
  let content = ''
  let filename = ''
  let mimeType = ''

  if (exportFormat.value === 'clash') {
    content = generateClashYaml(groupNodes)
    filename = `subforge_${exportGroup.value.name}.yaml`
    mimeType = 'text/yaml'
  } else if (exportFormat.value === 'singbox') {
    content = generateSingboxJson(groupNodes)
    filename = `subforge_${exportGroup.value.name}.json`
    mimeType = 'application/json'
  } else if (exportFormat.value === 'base64') {
    content = generateBase64(groupNodes)
    filename = `subforge_${exportGroup.value.name}.txt`
    mimeType = 'text/plain'
  } else {
    // For surge, loon, qx, shadowrocket - fall back to base64 with raw URIs
    content = generateBase64(groupNodes)
    filename = `subforge_${exportGroup.value.name}.txt`
    mimeType = 'text/plain'
  }

  // Download file
  const blob = new Blob([content], { type: mimeType })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)

  message.success(`已导出 ${exportGroup.value.name} (${groupNodes.length} 个节点)`)
  showExportModal.value = false
}

async function loadAllNodes() {
  loading.value = true
  try {
    const res = await getAllNodes()
    nodes.value = res.data || []
  } catch (e) {
    message.error('加载节点失败')
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await loadAllNodes()
  window.addEventListener('resize', () => { isMobile.value = window.innerWidth <= 768 })
})
</script>

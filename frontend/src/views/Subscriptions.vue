<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>订阅管理</span>
          <n-space>
            <n-button v-if="selectedIds.length > 0" type="warning" @click="handleBatchRefresh">
              刷新选中 ({{ selectedIds.length }})
            </n-button>
            <n-button v-if="selectedIds.length > 0" @click="handleBatchExport">
              导出选中 ({{ selectedIds.length }})
            </n-button>
            <n-popconfirm v-if="selectedIds.length > 0" @positive-click="handleBatchDelete">
              <template #trigger>
                <n-button type="error">删除选中 ({{ selectedIds.length }})</n-button>
              </template>
              确认删除 {{ selectedIds.length }} 个订阅？
            </n-popconfirm>
            <n-button type="success" :loading="refreshingAll" @click="handleRefreshAll">
              <template #icon><n-icon :component="RefreshOutline" /></template>
              一键刷新全部
            </n-button>
            <n-button @click="showTemplate = true">
              <template #icon><n-icon :component="DocumentTextOutline" /></template>
              模板
            </n-button>
            <n-button @click="showImport = true">
              <template #icon><n-icon :component="CloudUploadOutline" /></template>
              导入
            </n-button>
            <n-button type="info" @click="showNodeImport = true">
              <template #icon><n-icon :component="AddOutline" /></template>
              导入节点
            </n-button>
            <n-button @click="handleExport">
              <template #icon><n-icon :component="CloudDownloadOutline" /></template>
              导出
            </n-button>
            <n-button type="primary" @click="openAdd">
              <template #icon><n-icon :component="AddOutline" /></template>
              添加订阅
            </n-button>
          </n-space>
        </n-space>
      </template>
      <n-data-table
        :columns="columns"
        :data="subscriptions"
        :loading="loading"
        :bordered="false"
        :row-key="(row: Subscription) => row.id"
        v-model:checked-row-keys="selectedIds"
      />
    </n-card>

    <!-- Add/Edit Modal -->
    <n-modal v-model:show="showForm" preset="card" :title="editingId ? '编辑订阅' : '添加订阅'" style="width: 500px">
      <n-form ref="formRef" :model="form" :rules="rules">
        <n-form-item label="名称" path="name">
          <n-input v-model:value="form.name" placeholder="订阅名称" />
        </n-form-item>
        <n-form-item label="订阅链接" path="url">
          <n-input v-model:value="form.url" placeholder="https://..." />
        </n-form-item>
        <n-form-item label="自动刷新间隔 (秒)">
          <n-input-number v-model:value="form.auto_refresh" :min="300" :step="300" />
        </n-form-item>
      </n-form>
      <template #action>
        <n-space justify="end">
          <n-button @click="showForm = false">取消</n-button>
          <n-button type="primary" :loading="saving" @click="handleSave">保存</n-button>
        </n-space>
      </template>
    </n-modal>

    <!-- Nodes Modal -->
    <n-modal v-model:show="showNodes" preset="card" :title="`节点列表 - ${currentSub?.name}`" style="width: 900px">
      <n-space style="margin-bottom: 16px">
        <n-input v-model:value="nodeSearch" placeholder="搜索节点名称/地址..." clearable style="width: 240px" />
        <n-select v-model:value="nodeRegion" :options="regionOptions" placeholder="区域筛选" clearable style="width: 140px" />
      </n-space>
      <n-data-table :columns="nodeColumns" :data="filteredNodes" :bordered="false" :max-height="400" />
    </n-modal>

    <!-- Token Modal -->
    <n-modal v-model:show="showToken" preset="card" title="订阅链接" style="width: 520px">
      <n-space vertical>
        <n-text>复制以下链接到客户端使用：</n-text>
        <n-input :value="tokenUrl" readonly type="textarea" :rows="3" />
        <n-space>
          <n-select v-model:value="tokenFormat" :options="formatOptions" style="width: 140px" @update:value="updateTokenUrl" />
          <n-button @click="copyToken">复制链接</n-button>
        </n-space>
      </n-space>
    </n-modal>

    <ShareModal :show="showShare" :token="shareToken" @update:show="showShare = $event" />
    <ImportModal :show="showImport" @update:show="showImport = $event" @imported="load" />
    <SubscriptionDetail
      :show="showDetail"
      :sub="detailSub"
      @update:show="showDetail = $event"
      @refresh="(sub: Subscription) => handleRefresh(sub)"
      @share="(sub: Subscription) => openShare(sub)"
    />
    <TemplateModal
      :show="showTemplate"
      @update:show="showTemplate = $event"
      @create="handleTemplateCreate"
    />

    <!-- Import Nodes Modal -->
    <n-modal v-model:show="showNodeImport" preset="card" title="导入节点" style="width: 600px">
      <n-space vertical>
        <n-text>粘贴节点链接（支持 vmess://、vless://、trojan://、ss://、hysteria2://），每行一个：</n-text>
        <n-input
          v-model:value="nodeUris"
          type="textarea"
          :rows="10"
          placeholder="vmess://eyJwb3J0Ijo1MDAxMCwicHMiOi...
vless://xxxxx@server:443?...
trojan://password@server:443?..."
          style="font-family: monospace; font-size: 12px;"
        />
        <n-alert v-if="importResult" :type="importResult.success ? 'success' : 'error'">
          {{ importResult.message }}
        </n-alert>
      </n-space>
      <template #footer>
        <n-space justify="end">
          <n-button @click="showNodeImport = false">取消</n-button>
          <n-button type="primary" :loading="importingNodes" @click="handleImportNodes">
            导入
          </n-button>
        </n-space>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, h } from 'vue'
import { useMessage, NCard, NDataTable, NButton, NIcon, NSpace, NModal, NForm, NFormItem, NInput, NInputNumber, NTag, NSelect, NText, NPopconfirm, NAlert } from 'naive-ui'
import { AddOutline, RefreshOutline, TrashOutline, EyeOutline, CreateOutline, LinkOutline, PulseOutline, ShareOutline, CloudUploadOutline, CloudDownloadOutline, DocumentTextOutline } from '@vicons/ionicons5'
import ShareModal from '../components/ShareModal.vue'
import ImportModal from '../components/ImportModal.vue'
import SubscriptionDetail from '../components/SubscriptionDetail.vue'
import TemplateModal from '../components/TemplateModal.vue'
import {
  getSubscriptions, createSubscription, updateSubscription, deleteSubscription,
  refreshSubscription, getNodes, batchDeleteSubscriptions, batchRefreshSubscriptions, checkSubscriptionHealth,
  exportSubscriptions, batchExportSubscriptions, importNodes,
} from '../api/subscription'
import type { Subscription, Node } from '../api/subscription'

const message = useMessage()
const loading = ref(false)
const saving = ref(false)
const checkingId = ref<number | null>(null)
const showForm = ref(false)
const showNodes = ref(false)
const showToken = ref(false)
const editingId = ref<number | null>(null)
const subscriptions = ref<Subscription[]>([])
const currentSub = ref<Subscription | null>(null)
const currentNodes = ref<Node[]>([])
const nodeSearch = ref('')
const nodeRegion = ref<string | null>(null)
const tokenUrl = ref('')
const tokenFormat = ref('clash')
const selectedIds = ref<number[]>([])
const showShare = ref(false)
const shareToken = ref('')
const showImport = ref(false)
const showDetail = ref(false)
const detailSub = ref<Subscription | null>(null)
const showTemplate = ref(false)
const refreshingAll = ref(false)
const showNodeImport = ref(false)
const nodeUris = ref('')
const importingNodes = ref(false)
const importResult = ref<{ success: boolean; message: string } | null>(null)

const form = ref({ name: '', url: '', auto_refresh: 3600 })
const rules = {
  name: { required: true, message: '请输入名称' },
  url: { required: true, message: '请输入链接' },
}

const formatOptions = [
  { label: 'Clash', value: 'clash' },
  { label: 'sing-box', value: 'singbox' },
  { label: 'Surge', value: 'surge' },
  { label: 'Loon', value: 'loon' },
  { label: 'QX', value: 'qx' },
  { label: 'Shadowrocket', value: 'shadowrocket' },
  { label: 'Base64', value: 'base64' },
]

const regionOptions = [
  { label: '🇭🇰 HK', value: 'HK' },
  { label: '🇯🇵 JP', value: 'JP' },
  { label: '🇸🇬 SG', value: 'SG' },
  { label: '🇺🇸 US', value: 'US' },
  { label: '🇨🇳 TW', value: 'TW' },
  { label: '🇰🇷 KR', value: 'KR' },
]

const filteredNodes = computed(() => {
  let nodes = currentNodes.value
  if (nodeSearch.value) {
    const q = nodeSearch.value.toLowerCase()
    nodes = nodes.filter(n => n.display_name?.toLowerCase().includes(q) || n.server?.toLowerCase().includes(q))
  }
  if (nodeRegion.value) {
    nodes = nodes.filter(n => n.region === nodeRegion.value)
  }
  return nodes
})

const columns = [
  { title: 'ID', key: 'id', width: 60 },
  { title: '名称', key: 'name' },
  { title: '节点数', key: 'node_count', width: 80 },
  {
    title: '状态', key: 'status', width: 80,
    render(row: Subscription) {
      return h(NTag, { type: row.status === 1 ? 'success' : 'error', size: 'small', bordered: false }, { default: () => row.status === 1 ? '正常' : '禁用' })
    },
  },
  {
    title: '最后更新', key: 'last_fetch', width: 160,
    render(row: Subscription) {
      return row.last_fetch ? new Date(row.last_fetch).toLocaleString() : '未更新'
    },
  },
  {
    title: '操作', key: 'actions', width: 320,
    render(row: Subscription) {
      return h(NSpace, { size: 'small' }, {
        default: () => [
          h(NButton, { size: 'small', quaternary: true, onClick: () => openDetail(row) }, { default: () => '详情' }),
          h(NButton, { size: 'small', quaternary: true, type: 'info', onClick: () => viewNodes(row) }, { icon: () => h(NIcon, { component: EyeOutline }), default: () => '节点' }),
          h(NButton, { size: 'small', quaternary: true, type: 'primary', onClick: () => openEdit(row) }, { icon: () => h(NIcon, { component: CreateOutline }) }),
          h(NButton, { size: 'small', quaternary: true, type: 'success', onClick: () => viewToken(row) }, { icon: () => h(NIcon, { component: LinkOutline }) }),
          h(NButton, { size: 'small', quaternary: true, onClick: () => openShare(row) }, { icon: () => h(NIcon, { component: ShareOutline }) }),
          h(NButton, { size: 'small', quaternary: true, type: 'warning', onClick: () => handleRefresh(row) }, { icon: () => h(NIcon, { component: RefreshOutline }) }),
          h(NButton, { size: 'small', quaternary: true, onClick: () => handleCheck(row), loading: checkingId.value === row.id, disabled: checkingId.value !== null && checkingId.value !== row.id }, { icon: () => h(NIcon, { component: PulseOutline }), default: () => checkingId.value === row.id ? '检测中...' : '检测' }),
          h(NPopconfirm, { onPositiveClick: () => handleDelete(row) }, {
            trigger: () => h(NButton, { size: 'small', quaternary: true, type: 'error' }, { icon: () => h(NIcon, { component: TrashOutline }) }),
            default: () => '确认删除？',
          }),
        ],
      })
    },
  },
]

const nodeColumns = [
  { title: '名称', key: 'display_name', width: 200 },
  { title: '类型', key: 'node_type', width: 80 },
  { title: '地址', key: 'server' },
  { title: '端口', key: 'port', width: 70 },
  { title: '区域', key: 'region', width: 60 },
  { title: '延迟', key: 'latency', width: 70, render(row: Node) { return row.latency ? `${row.latency}ms` : '-' } },
]

async function load() {
  loading.value = true
  try {
    const res = await getSubscriptions(1, 100)
    subscriptions.value = res.data.items || res.data
  } catch { message.error('加载失败') } finally { loading.value = false }
}

function openAdd() {
  editingId.value = null
  form.value = { name: '', url: '', auto_refresh: 3600 }
  showForm.value = true
}

function openEdit(sub: Subscription) {
  editingId.value = sub.id
  form.value = { name: sub.name, url: sub.url, auto_refresh: sub.auto_refresh || 3600 }
  showForm.value = true
}

function openDetail(sub: Subscription) {
  detailSub.value = sub
  showDetail.value = true
}

async function handleSave() {
  saving.value = true
  try {
    if (editingId.value) {
      await updateSubscription(editingId.value, form.value.name, form.value.url, form.value.auto_refresh)
      message.success('更新成功')
    } else {
      await createSubscription(form.value.name, form.value.url, form.value.auto_refresh)
      message.success('添加成功')
    }
    showForm.value = false
    await load()
  } catch (e: any) { message.error(e.response?.data?.message || '操作失败') } finally { saving.value = false }
}

async function handleRefresh(sub: Subscription) {
  try { await refreshSubscription(sub.id); message.success('刷新成功'); await load() }
  catch (e: any) { message.error(e.response?.data?.message || '刷新失败') }
}

async function handleRefreshAll() {
  refreshingAll.value = true
  try {
    const res = await fetch('/api/subscriptions/refresh-all', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` }
    })
    const data = await res.json()
    if (data.results) {
      const success = data.results.filter((r: any) => r.status === 'success').length
      const failed = data.results.filter((r: any) => r.status !== 'success').length
      message.success(`刷新完成: ${success} 成功, ${failed} 失败`)
    }
    await load()
  } catch (e: any) {
    message.error('一键刷新失败')
  } finally {
    refreshingAll.value = false
  }
}

async function handleDelete(sub: Subscription) {
  await deleteSubscription(sub.id)
  message.success('已删除')
  await load()
}

async function handleBatchDelete() {
  try {
    const res = await batchDeleteSubscriptions(selectedIds.value)
    message.success(`已删除 ${res.data.deleted} 个订阅`)
    selectedIds.value = []
    await load()
  } catch { message.error('批量删除失败') }
}

async function handleBatchRefresh() {
  try {
    const res = await batchRefreshSubscriptions(selectedIds.value)
    message.success(`已刷新 ${res.data.refreshed} 个订阅`)
    await load()
  } catch { message.error('批量刷新失败') }
}

async function handleBatchExport() {
  try {
    const res = await batchExportSubscriptions(selectedIds.value)
    const blob = new Blob([JSON.stringify(res.data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `subforge-export-${new Date().toISOString().slice(0, 10)}.json`
    a.click()
    URL.revokeObjectURL(url)
    message.success(`已导出 ${selectedIds.value.length} 个订阅`)
  } catch { message.error('批量导出失败') }
}

async function handleCheck(sub: Subscription) {
  checkingId.value = sub.id
  try {
    const res = await checkSubscriptionHealth(sub.id)
    const { total, online, offline } = res.data
    message.success(`检测完成: ${online}/${total} 在线, ${offline} 离线`)
    await load()
  } catch { message.error('检测失败') }
  finally { checkingId.value = null }
}

async function handleTemplateCreate(data: { name: string; url: string; autoRefresh: number; tags: string[] }) {
  try {
    await createSubscription(data.name, data.url, data.autoRefresh, data.tags)
    message.success('从模板创建成功')
    await load()
  } catch (e: any) {
    message.error(e.response?.data?.message || '创建失败')
  }
}

async function viewNodes(sub: Subscription) {
  currentSub.value = sub
  nodeSearch.value = ''
  nodeRegion.value = null
  try {
    const res = await getNodes(sub.id)
    currentNodes.value = res.data
    showNodes.value = true
  } catch { message.error('获取节点失败') }
}

async function viewToken(sub: Subscription) {
  currentSub.value = sub
  tokenFormat.value = 'clash'
  // Use token directly from subscription object
  if (sub.token) {
    tokenUrl.value = `${window.location.origin}/sub/${sub.token}/export?target=clash`
  } else {
    tokenUrl.value = `${window.location.origin}/sub/loading/export?target=clash`
  }
  showToken.value = true
}

function updateTokenUrl(format: string) {
  const base = tokenUrl.value.split('?')[0]
  tokenUrl.value = `${base}?target=${format}`
}

function copyToken() {
  navigator.clipboard.writeText(tokenUrl.value)
  message.success('已复制')
}

async function openShare(sub: Subscription) {
  try {
    // Token is already available in the subscription object
    if (sub.token) {
      shareToken.value = sub.token
      showShare.value = true
    } else {
      // Fallback: fetch from API if token not available
      const { default: api } = await import('../api/request')
      const res = await api.get(`/subscriptions/${sub.id}/token`)
      shareToken.value = res.data.token
      showShare.value = true
    }
  } catch { message.error('获取订阅链接失败') }
}

async function handleExport() {
  try {
    const res = await exportSubscriptions()
    const blob = new Blob([JSON.stringify(res.data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `subforge-export-${new Date().toISOString().slice(0, 10)}.json`
    a.click()
    URL.revokeObjectURL(url)
    message.success('导出成功')
  } catch { message.error('导出失败') }
}

async function handleImportNodes() {
  if (!nodeUris.value.trim()) {
    importResult.value = { success: false, message: '请输入节点链接' }
    return
  }

  importingNodes.value = true
  importResult.value = null

  try {
    const res = await importNodes(nodeUris.value)
    const { imported, subscription_name } = res.data
    importResult.value = {
      success: true,
      message: `成功导入 ${imported} 个节点到「${subscription_name}」`
    }
    nodeUris.value = ''
    await load()
    setTimeout(() => {
      showNodeImport.value = false
      importResult.value = null
    }, 2000)
  } catch (e: any) {
    importResult.value = {
      success: false,
      message: e.response?.data?.detail || '导入失败'
    }
  } finally {
    importingNodes.value = false
  }
}

onMounted(load)
</script>

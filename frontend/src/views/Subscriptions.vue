<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>订阅管理</span>
          <n-button type="primary" @click="openAdd">
            <template #icon><n-icon :component="AddOutline" /></template>
            添加订阅
          </n-button>
        </n-space>
      </template>
      <n-data-table :columns="columns" :data="subscriptions" :loading="loading" :bordered="false" />
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
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, h } from 'vue'
import { useMessage, NCard, NDataTable, NButton, NIcon, NSpace, NModal, NForm, NFormItem, NInput, NInputNumber, NTag, NSelect, NText, NPopconfirm } from 'naive-ui'
import { AddOutline, RefreshOutline, TrashOutline, EyeOutline, CreateOutline, LinkOutline } from '@vicons/ionicons5'
import {
  getSubscriptions, createSubscription, updateSubscription, deleteSubscription,
  refreshSubscription, getNodes,
} from '../api/subscription'
import type { Subscription, Node } from '../api/subscription'

const message = useMessage()
const loading = ref(false)
const saving = ref(false)
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
  { label: 'QX', value: 'quanx' },
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
    title: '操作', key: 'actions', width: 280,
    render(row: Subscription) {
      return h(NSpace, { size: 'small' }, {
        default: () => [
          h(NButton, { size: 'small', quaternary: true, type: 'info', onClick: () => viewNodes(row) }, { icon: () => h(NIcon, { component: EyeOutline }), default: () => '节点' }),
          h(NButton, { size: 'small', quaternary: true, type: 'primary', onClick: () => openEdit(row) }, { icon: () => h(NIcon, { component: CreateOutline }) }),
          h(NButton, { size: 'small', quaternary: true, type: 'success', onClick: () => viewToken(row) }, { icon: () => h(NIcon, { component: LinkOutline }) }),
          h(NButton, { size: 'small', quaternary: true, type: 'warning', onClick: () => handleRefresh(row) }, { icon: () => h(NIcon, { component: RefreshOutline }) }),
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
    const res = await getSubscriptions()
    subscriptions.value = res.data
  } catch { message.error('加载失败') } finally { loading.value = false }
}

function openAdd() {
  editingId.value = null
  form.value = { name: '', url: '', auto_refresh: 3600 }
  showForm.value = true
}

function openEdit(sub: Subscription) {
  editingId.value = sub.id
  form.value = { name: sub.name, url: sub.url, auto_refresh: sub.auto_refresh }
  showForm.value = true
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

async function handleDelete(sub: Subscription) {
  await deleteSubscription(sub.id)
  message.success('已删除')
  await load()
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
  tokenUrl.value = `${window.location.origin}/sub/${sub.token || 'loading'}?target=clash`
  showToken.value = true
  // Fetch token from API
  try {
    const { default: api } = await import('../api/request')
    const res = await api.get(`/subscriptions/${sub.id}/token`)
    tokenUrl.value = `${window.location.origin}/sub/${res.data.token}?target=${tokenFormat.value}`
  } catch { /* use placeholder */ }
}

function updateTokenUrl(format: string) {
  const base = tokenUrl.value.split('?')[0]
  tokenUrl.value = `${base}?target=${format}`
}

function copyToken() {
  navigator.clipboard.writeText(tokenUrl.value)
  message.success('已复制')
}

onMounted(load)
</script>

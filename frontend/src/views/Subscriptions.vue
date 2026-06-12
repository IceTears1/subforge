<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>订阅管理</span>
          <n-button type="primary" @click="showAdd = true">
            <template #icon><n-icon :component="AddOutline" /></template>
            添加订阅
          </n-button>
        </n-space>
      </template>
      <n-data-table :columns="columns" :data="subscriptions" :loading="loading" :bordered="false" />
    </n-card>

    <!-- Add/Edit Modal -->
    <n-modal v-model:show="showAdd" preset="card" title="添加订阅" style="width: 500px">
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
          <n-button @click="showAdd = false">取消</n-button>
          <n-button type="primary" :loading="saving" @click="handleSave">保存</n-button>
        </n-space>
      </template>
    </n-modal>

    <!-- Nodes Modal -->
    <n-modal v-model:show="showNodes" preset="card" :title="`节点列表 - ${currentSub?.name}`" style="width: 800px">
      <n-data-table :columns="nodeColumns" :data="currentNodes" :bordered="false" :max-height="400" />
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, h } from 'vue'
import { useMessage, NCard, NDataTable, NButton, NIcon, NSpace, NModal, NForm, NFormItem, NInput, NInputNumber, NTag } from 'naive-ui'
import { AddOutline, RefreshOutline, TrashOutline, EyeOutline } from '@vicons/ionicons5'
import {
  getSubscriptions, createSubscription, deleteSubscription,
  refreshSubscription, getNodes,
} from '../api/subscription'
import type { Subscription, Node } from '../api/subscription'

const message = useMessage()
const loading = ref(false)
const saving = ref(false)
const showAdd = ref(false)
const showNodes = ref(false)
const subscriptions = ref<Subscription[]>([])
const currentSub = ref<Subscription | null>(null)
const currentNodes = ref<Node[]>([])
const formRef = ref()

const form = ref({ name: '', url: '', auto_refresh: 3600 })
const rules = {
  name: { required: true, message: '请输入名称' },
  url: { required: true, message: '请输入链接' },
}

const columns = [
  { title: 'ID', key: 'id', width: 60 },
  { title: '名称', key: 'name' },
  { title: '节点数', key: 'node_count', width: 80 },
  {
    title: '状态',
    key: 'status',
    width: 80,
    render(row: Subscription) {
      return h(NTag, { type: row.status === 1 ? 'success' : 'error', size: 'small', bordered: false }, { default: () => row.status === 1 ? '正常' : '禁用' })
    },
  },
  {
    title: '最后更新',
    key: 'last_fetch',
    width: 160,
    render(row: Subscription) {
      return row.last_fetch ? new Date(row.last_fetch).toLocaleString() : '未更新'
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 200,
    render(row: Subscription) {
      return h(NSpace, { size: 'small' }, {
        default: () => [
          h(NButton, { size: 'small', quaternary: true, type: 'info', onClick: () => viewNodes(row) }, { icon: () => h(NIcon, { component: EyeOutline }), default: () => '查看' }),
          h(NButton, { size: 'small', quaternary: true, type: 'primary', onClick: () => handleRefresh(row) }, { icon: () => h(NIcon, { component: RefreshOutline }) }),
          h(NButton, { size: 'small', quaternary: true, type: 'error', onClick: () => handleDelete(row) }, { icon: () => h(NIcon, { component: TrashOutline }) }),
        ],
      })
    },
  },
]

const nodeColumns = [
  { title: '名称', key: 'display_name' },
  { title: '类型', key: 'node_type', width: 80 },
  { title: '地址', key: 'server' },
  { title: '端口', key: 'port', width: 70 },
  { title: '区域', key: 'region', width: 60 },
]

async function load() {
  loading.value = true
  try {
    const res = await getSubscriptions()
    subscriptions.value = res.data
  } catch {
    message.error('加载失败')
  } finally {
    loading.value = false
  }
}

async function handleSave() {
  saving.value = true
  try {
    await createSubscription(form.value.name, form.value.url, form.value.auto_refresh)
    message.success('添加成功')
    showAdd.value = false
    form.value = { name: '', url: '', auto_refresh: 3600 }
    await load()
  } catch (e: any) {
    message.error(e.response?.data?.message || '添加失败')
  } finally {
    saving.value = false
  }
}

async function handleRefresh(sub: Subscription) {
  try {
    await refreshSubscription(sub.id)
    message.success('刷新成功')
    await load()
  } catch (e: any) {
    message.error(e.response?.data?.message || '刷新失败')
  }
}

async function handleDelete(sub: Subscription) {
  await deleteSubscription(sub.id)
  message.success('已删除')
  await load()
}

async function viewNodes(sub: Subscription) {
  currentSub.value = sub
  try {
    const res = await getNodes(sub.id)
    currentNodes.value = res.data
    showNodes.value = true
  } catch {
    message.error('获取节点失败')
  }
}

onMounted(load)
</script>

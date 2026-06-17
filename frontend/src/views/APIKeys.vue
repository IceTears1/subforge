<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>API Key 管理</span>
          <n-button type="primary" @click="showAdd = true">
            <template #icon><n-icon :component="KeyOutline" /></template>
            创建 API Key
          </n-button>
        </n-space>
      </template>
      <n-alert type="info" style="margin-bottom: 16px">
        API Key 用于程序化访问 SubForge API。在请求头中添加 <n-text code>Authorization: Bearer sf_xxx...</n-text>
      </n-alert>
      <n-data-table :columns="columns" :data="keys" :loading="loading" :bordered="false" />
    </n-card>

    <n-modal v-model:show="showAdd" preset="card" title="创建 API Key" style="width: 420px">
      <n-form>
        <n-form-item label="名称">
          <n-input v-model:value="formName" placeholder="例如: 我的脚本" />
        </n-form-item>
      </n-form>
      <template #action>
        <n-space justify="end">
          <n-button @click="showAdd = false">取消</n-button>
          <n-button type="primary" :loading="saving" @click="handleCreate">创建</n-button>
        </n-space>
      </template>
    </n-modal>

    <n-modal v-model:show="showKey" preset="card" title="API Key 已创建" style="width: 520px">
      <n-alert type="warning" style="margin-bottom: 16px">
        请立即复制保存，此密钥只会显示一次！
      </n-alert>
      <n-input :value="newKeyValue" readonly type="textarea" :rows="3" />
      <template #action>
        <n-button type="primary" @click="copyKey">复制密钥</n-button>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, h } from 'vue'
import { useMessage, NCard, NDataTable, NButton, NIcon, NSpace, NModal, NForm, NFormItem, NInput, NAlert, NText, NPopconfirm } from 'naive-ui'
import { KeyOutline, TrashOutline, CopyOutline } from '@vicons/ionicons5'
import { getAPIKeys, createAPIKey, deleteAPIKey } from '../api/apikey'
import type { APIKey } from '../api/apikey'

const message = useMessage()
const loading = ref(false)
const saving = ref(false)
const showAdd = ref(false)
const showKey = ref(false)
const keys = ref<APIKey[]>([])
const formName = ref('')
const newKeyValue = ref('')

const columns = [
  { title: 'ID', key: 'id', width: 60 },
  { title: '名称', key: 'name' },
  { title: 'Key', key: 'key', width: 200 },
  {
    title: '最后使用', key: 'last_used', width: 160,
    render(row: APIKey) { return row.last_used || '从未使用' },
  },
  {
    title: '操作', key: 'actions', width: 100,
    render(row: APIKey) {
      return h(NPopconfirm, { onPositiveClick: () => handleDelete(row) }, {
        trigger: () => h(NButton, { size: 'small', quaternary: true, type: 'error' }, { icon: () => h(NIcon, { component: TrashOutline }) }),
        default: () => '确认删除？',
      })
    },
  },
]

async function load() {
  loading.value = true
  try {
    const res = await getAPIKeys()
    keys.value = res.data || []
  } catch { message.error('加载失败') } finally { loading.value = false }
}

async function handleCreate() {
  if (!formName.value) { message.warning('请输入名称'); return }
  saving.value = true
  try {
    const res = await createAPIKey(formName.value)
    newKeyValue.value = res.data.key
    showAdd.value = false
    showKey.value = true
    formName.value = ''
    await load()
  } catch (e: any) { message.error(e.response?.data?.message || '创建失败') } finally { saving.value = false }
}

async function handleDelete(key: APIKey) {
  await deleteAPIKey(key.id)
  message.success('已删除')
  await load()
}

function copyKey() {
  navigator.clipboard.writeText(newKeyValue.value)
  message.success('已复制')
}

onMounted(load)
</script>

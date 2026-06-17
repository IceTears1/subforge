<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>子账户管理</span>
          <n-button type="primary" @click="showAdd = true">
            <template #icon><n-icon :component="PersonAddOutline" /></template>
            添加子账户
          </n-button>
        </n-space>
      </template>
      <n-data-table :columns="columns" :data="users" :loading="loading" :bordered="false" />
    </n-card>

    <n-modal v-model:show="showAdd" preset="card" title="添加子账户" style="width: 420px">
      <n-form :model="form">
        <n-form-item label="用户名">
          <n-input v-model:value="form.username" placeholder="用户名" />
        </n-form-item>
        <n-form-item label="密码">
          <n-input v-model:value="form.password" type="password" placeholder="密码" show-password-on="click" />
        </n-form-item>
      </n-form>
      <template #action>
        <n-space justify="end">
          <n-button @click="showAdd = false">取消</n-button>
          <n-button type="primary" :loading="saving" @click="handleCreate">创建</n-button>
        </n-space>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, h } from 'vue'
import { useMessage, NCard, NDataTable, NButton, NIcon, NSpace, NModal, NForm, NFormItem, NInput, NTag, NPopconfirm } from 'naive-ui'

import { PersonAddOutline, TrashOutline } from '@vicons/ionicons5'
import { getUsers, createUser, deleteUser, updateUserStatus } from '../api/user'
import type { User } from '../api/user'

const message = useMessage()
const loading = ref(false)
const saving = ref(false)
const showAdd = ref(false)
const users = ref<User[]>([])
const form = ref({ username: '', password: '' })

const columns = [
  { title: 'ID', key: 'id', width: 60 },
  { title: '用户名', key: 'username' },
  {
    title: '角色',
    key: 'role',
    width: 80,
    render(row: User) {
      return h(NTag, { type: row.role === 'admin' ? 'warning' : 'info', size: 'small', bordered: false }, { default: () => row.role === 'admin' ? '管理员' : '用户' })
    },
  },
  {
    title: '状态',
    key: 'status',
    width: 80,
    render(row: User) {
      return h(NTag, { type: row.status === 1 ? 'success' : 'error', size: 'small', bordered: false }, { default: () => row.status === 1 ? '正常' : '禁用' })
    },
  },
  {
    title: '创建时间',
    key: 'created_at',
    width: 160,
    render(row: User) {
      return new Date(row.created_at).toLocaleString()
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 160,
    render(row: User) {
      if (row.role === 'admin') return '-'
      return h(NSpace, { size: 'small' }, {
        default: () => [
          h(NButton, {
            size: 'small', quaternary: true, type: row.status === 1 ? 'warning' : 'success',
            onClick: () => toggleStatus(row),
          }, { default: () => row.status === 1 ? '禁用' : '启用' }),
          h(NPopconfirm, { onPositiveClick: () => handleDelete(row) }, {
            trigger: () => h(NButton, { size: 'small', quaternary: true, type: 'error' }, { icon: () => h(NIcon, { component: TrashOutline }) }),
            default: () => '确认删除该用户？',
          }),
        ],
      })
    },
  },
]

async function load() {
  loading.value = true
  try {
    const res = await getUsers(1, 100)
    users.value = res.data.items || res.data
  } catch {
    message.error('加载失败')
  } finally {
    loading.value = false
  }
}

async function handleCreate() {
  if (!form.value.username || !form.value.password) {
    message.warning('请填写完整')
    return
  }
  saving.value = true
  try {
    await createUser(form.value.username, form.value.password)
    message.success('创建成功')
    showAdd.value = false
    form.value = { username: '', password: '' }
    await load()
  } catch (e: any) {
    message.error(e.response?.data?.message || '创建失败')
  } finally {
    saving.value = false
  }
}

async function toggleStatus(user: User) {
  await updateUserStatus(user.id, user.status === 1 ? 0 : 1)
  await load()
}

async function handleDelete(user: User) {
  await deleteUser(user.id)
  message.success('已删除')
  await load()
}

onMounted(load)
</script>

<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>标签管理</span>
          <n-button type="primary" @click="showAdd = true">
            <template #icon><n-icon :component="AddOutline" /></template>
            添加标签
          </n-button>
        </n-space>
      </template>

      <n-grid :cols="isMobile ? 2 : 4" :x-gap="12" :y-gap="12">
        <n-gi v-for="tag in tags" :key="tag.name">
          <n-card :bordered="false" class="tag-card">
            <n-space justify="space-between" align="center">
              <n-space align="center">
                <n-tag :color="tag.color" :bordered="false">{{ tag.name }}</n-tag>
                <n-text depth="3" style="font-size: 12px">{{ tag.count }} 个订阅</n-text>
              </n-space>
              <n-popconfirm @positive-click="handleDelete(tag.name)">
                <template #trigger>
                  <n-button size="tiny" quaternary type="error">
                    <template #icon><n-icon :component="TrashOutline" /></template>
                  </n-button>
                </template>
                删除标签？
              </n-popconfirm>
            </n-space>
          </n-card>
        </n-gi>
      </n-grid>

      <n-empty v-if="tags.length === 0" description="暂无标签" style="padding: 40px 0" />
    </n-card>

    <n-modal v-model:show="showAdd" preset="card" title="添加标签" style="width: 400px">
      <n-form>
        <n-form-item label="标签名称">
          <n-input v-model:value="newTag" placeholder="输入标签名称" />
        </n-form-item>
        <n-form-item label="标签颜色">
          <n-color-picker v-model:value="newColor" :swatches="colorSwatches" />
        </n-form-item>
      </n-form>
      <template #action>
        <n-space justify="end">
          <n-button @click="showAdd = false">取消</n-button>
          <n-button type="primary" @click="handleAdd">添加</n-button>
        </n-space>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useMessage, NCard, NGrid, NGi, NSpace, NTag, NText, NButton, NIcon, NPopconfirm, NModal, NForm, NFormItem, NInput, NColorPicker, NEmpty } from 'naive-ui'
import { AddOutline, TrashOutline } from '@vicons/ionicons5'
import { getSubscriptions } from '../api/subscription'
import type { Subscription } from '../api/subscription'

const message = useMessage()
const isMobile = ref(window.innerWidth <= 768)
const subscriptions = ref<Subscription[]>([])
const showAdd = ref(false)
const newTag = ref('')
const newColor = ref('#6366f1')

const colorSwatches = ['#6366f1', '#10b981', '#f59e0b', '#ef4444', '#ec4899', '#8b5cf6', '#06b6d4', '#84cc16']

interface TagInfo {
  name: string
  color: string
  count: number
}

const tags = ref<TagInfo[]>([])

function computeTags() {
  const map = new Map<string, number>()
  for (const sub of subscriptions.value) {
    for (const tag of (sub.tags || [])) {
      map.set(tag, (map.get(tag) || 0) + 1)
    }
  }
  tags.value = Array.from(map.entries()).map(([name, count]) => ({
    name,
    color: colorSwatches[tags.value.findIndex(t => t.name === name) % colorSwatches.length] || '#6366f1',
    count,
  }))
}

async function load() {
  try {
    const res = await getSubscriptions(1, 100)
    subscriptions.value = res.data.items || res.data
    computeTags()
  } catch {}
}

function handleAdd() {
  if (!newTag.value) {
    message.warning('请输入标签名称')
    return
  }
  // In a real app, this would save to backend
  tags.value.push({
    name: newTag.value,
    color: newColor.value,
    count: 0,
  })
  showAdd.value = false
  newTag.value = ''
  message.success('标签已添加')
}

function handleDelete(name: string) {
  tags.value = tags.value.filter(t => t.name !== name)
  message.success('标签已删除')
}

onMounted(() => {
  load()
  window.addEventListener('resize', () => { isMobile.value = window.innerWidth <= 768 })
})
</script>

<style scoped>
.tag-card {
  transition: all 0.2s ease;
}
.tag-card:hover {
  transform: translateY(-2px);
}
</style>

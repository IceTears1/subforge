<template>
  <n-modal :show="show" @update:show="$emit('update:show', $event)" preset="card" title="订阅模板" style="width: 600px">
    <n-space vertical>
      <n-alert type="info">
        选择预设模板快速创建订阅，或自定义模板。
      </n-alert>

      <n-grid :cols="2" :x-gap="12" :y-gap="12">
        <n-gi v-for="template in templates" :key="template.id">
          <n-card
            :bordered="false"
            :class="{ 'template-card': true, 'selected': selected?.id === template.id }"
            @click="selectTemplate(template)"
          >
            <n-space vertical>
              <n-space align="center">
                <n-icon :component="template.icon" :size="24" :color="template.color" />
                <n-text strong>{{ template.name }}</n-text>
              </n-space>
              <n-text depth="3" style="font-size: 12px">{{ template.description }}</n-text>
              <n-space>
                <n-tag v-for="tag in template.tags" :key="tag" size="small" :bordered="false">
                  {{ tag }}
                </n-tag>
              </n-space>
            </n-space>
          </n-card>
        </n-gi>
      </n-grid>

      <n-divider />

      <n-form v-if="selected" :model="form">
        <n-form-item label="订阅名称">
          <n-input v-model:value="form.name" :placeholder="selected.name" />
        </n-form-item>
        <n-form-item label="订阅链接">
          <n-input v-model:value="form.url" placeholder="https://..." />
        </n-form-item>
        <n-form-item label="刷新间隔">
          <n-select v-model:value="form.autoRefresh" :options="refreshOptions" />
        </n-form-item>
      </n-form>

      <n-space justify="end">
        <n-button @click="$emit('update:show', false)">取消</n-button>
        <n-button type="primary" :disabled="!selected || !form.url" @click="handleCreate">
          创建订阅
        </n-button>
      </n-space>
    </n-space>
  </n-modal>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { NModal, NSpace, NAlert, NGrid, NGi, NCard, NIcon, NText, NTag, NDivider, NForm, NFormItem, NInput, NSelect, NButton } from 'naive-ui'
import { CloudOutline, ShieldOutline, RocketOutline, GlobeOutline, WifiOutline, ServerOutline } from '@vicons/ionicons5'

const emit = defineEmits(['update:show', 'create'])

interface Template {
  id: string
  name: string
  description: string
  icon: any
  color: string
  tags: string[]
  defaultRefresh: number
}

const templates: Template[] = [
  {
    id: 'clash',
    name: 'Clash 订阅',
    description: '适用于 Clash/Mihomo 客户端的标准订阅格式',
    icon: ShieldOutline,
    color: '#6366f1',
    tags: ['Clash', 'Mihomo', 'YAML'],
    defaultRefresh: 3600,
  },
  {
    id: 'v2ray',
    name: 'V2Ray 订阅',
    description: '适用于 V2Ray/Xray 客户端的 Base64 订阅格式',
    icon: WifiOutline,
    color: '#10b981',
    tags: ['V2Ray', 'Xray', 'Base64'],
    defaultRefresh: 3600,
  },
  {
    id: 'singbox',
    name: 'sing-box 订阅',
    description: '适用于 sing-box 客户端的 JSON 订阅格式',
    icon: ServerOutline,
    color: '#f59e0b',
    tags: ['sing-box', 'JSON'],
    defaultRefresh: 3600,
  },
  {
    id: 'surge',
    name: 'Surge 订阅',
    description: '适用于 Surge 客户端的订阅格式',
    icon: RocketOutline,
    color: '#ec4899',
    tags: ['Surge', 'iOS', 'Mac'],
    defaultRefresh: 3600,
  },
  {
    id: 'loon',
    name: 'Loon 订阅',
    description: '适用于 Loon 客户端的订阅格式',
    icon: GlobeOutline,
    color: '#8b5cf6',
    tags: ['Loon', 'iOS'],
    defaultRefresh: 3600,
  },
  {
    id: 'quanx',
    name: 'Quantumult X 订阅',
    description: '适用于 Quantumult X 客户端的订阅格式',
    icon: CloudOutline,
    color: '#06b6d4',
    tags: ['QX', 'iOS'],
    defaultRefresh: 3600,
  },
]

const selected = ref<Template | null>(null)
const form = ref({
  name: '',
  url: '',
  autoRefresh: 3600,
})

const refreshOptions = [
  { label: '每 30 分钟', value: 1800 },
  { label: '每 1 小时', value: 3600 },
  { label: '每 2 小时', value: 7200 },
  { label: '每 6 小时', value: 21600 },
  { label: '每 12 小时', value: 43200 },
  { label: '每 24 小时', value: 86400 },
]

function selectTemplate(template: Template) {
  selected.value = template
  form.value.name = template.name
  form.value.autoRefresh = template.defaultRefresh
}

function handleCreate() {
  if (!selected.value || !form.value.url) return
  emit('create', {
    name: form.value.name || selected.value.name,
    url: form.value.url,
    autoRefresh: form.value.autoRefresh,
    tags: selected.value.tags,
  })
  emit('update:show', false)
  selected.value = null
  form.value = { name: '', url: '', autoRefresh: 3600 }
}
</script>

<style scoped>
.template-card {
  cursor: pointer;
  transition: all 0.2s ease;
}
.template-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}
.template-card.selected {
  border: 2px solid #6366f1;
}
</style>

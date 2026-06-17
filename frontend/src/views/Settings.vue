<template>
  <div>
    <n-grid :cols="isMobile ? 1 : 2" :x-gap="24">
      <n-gi>
        <n-card title="智能重命名规则" :bordered="false">
          <n-form label-placement="left">
            <n-form-item label="启用区域重命名">
              <n-switch v-model:value="settings.renameEnabled" @update:value="save" />
            </n-form-item>
            <n-form-item label="命名格式">
              <n-input v-model:value="settings.renameFormat" placeholder="{emoji} {region} {index} | {type}" @update:value="save" />
            </n-form-item>
            <n-form-item label="排除关键词">
              <n-dynamic-tags v-model:value="settings.excludeKeywords" @update:value="save" />
            </n-form-item>
          </n-form>
        </n-card>

        <n-card title="默认设置" :bordered="false" style="margin-top: 24px">
          <n-form label-placement="left">
            <n-form-item label="默认输出格式">
              <n-select v-model:value="settings.defaultFormat" :options="formatOptions" @update:value="save" />
            </n-form-item>
            <n-form-item label="自动去重">
              <n-switch v-model:value="settings.autoDedup" @update:value="save" />
            </n-form-item>
            <n-form-item label="默认刷新间隔 (秒)">
              <n-input-number v-model:value="settings.defaultRefresh" :min="300" :step="300" @update:value="save" />
            </n-form-item>
          </n-form>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card title="API 接口" :bordered="false">
          <n-descriptions :column="1" bordered>
            <n-descriptions-item label="订阅地址">
              <n-text code>/sub/{token}?target=clash</n-text>
            </n-descriptions-item>
            <n-descriptions-item label="合并订阅">
              <n-text code>/sub/{token}/merged?target=clash</n-text>
            </n-descriptions-item>
            <n-descriptions-item label="转换接口">
              <n-text code>POST /api/convert</n-text>
            </n-descriptions-item>
            <n-descriptions-item label="格式检测">
              <n-text code>POST /api/detect</n-text>
            </n-descriptions-item>
            <n-descriptions-item label="导出订阅">
              <n-text code>GET /api/export</n-text>
            </n-descriptions-item>
            <n-descriptions-item label="导入订阅">
              <n-text code>POST /api/import</n-text>
            </n-descriptions-item>
          </n-descriptions>
        </n-card>

        <n-card title="支持格式" :bordered="false" style="margin-top: 24px">
          <n-space>
            <n-tag v-for="f in formats" :key="f" :bordered="false" type="info">{{ f }}</n-tag>
          </n-space>
        </n-card>

        <n-card title="主题" :bordered="false" style="margin-top: 24px">
          <n-space align="center">
            <n-switch :value="themeStore.isDark" @update:value="themeStore.toggle()">
              <template #checked>🌙</template>
              <template #unchecked>☀️</template>
            </n-switch>
            <span>{{ themeStore.isDark ? '暗黑模式' : '明亮模式' }}</span>
          </n-space>
        </n-card>
      </n-gi>
    </n-grid>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { NGrid, NGi, NCard, NForm, NFormItem, NInput, NSwitch, NSelect, NInputNumber, NDynamicTags, NDescriptions, NDescriptionsItem, NText, NSpace, NTag } from 'naive-ui'
import { useThemeStore } from '../stores/theme'
import { getFormats } from '../api/subscription'

const themeStore = useThemeStore()
const isMobile = ref(window.innerWidth <= 768)
const formats = ref<string[]>([])

const settings = ref({
  renameEnabled: true,
  renameFormat: '{emoji} {region} {index} | {type}',
  excludeKeywords: ['过期', '到期', '剩余'],
  defaultFormat: 'clash',
  autoDedup: true,
  defaultRefresh: 3600,
})

const formatOptions = [
  { label: 'Clash', value: 'clash' },
  { label: 'sing-box', value: 'singbox' },
  { label: 'Surge', value: 'surge' },
  { label: 'Loon', value: 'loon' },
  { label: 'Quantumult X', value: 'quanx' },
  { label: 'Base64', value: 'base64' },
]

function save() {
  localStorage.setItem('subforge_settings', JSON.stringify(settings.value))
}

function load() {
  const saved = localStorage.getItem('subforge_settings')
  if (saved) {
    try { Object.assign(settings.value, JSON.parse(saved)) } catch {}
  }
}

onMounted(async () => {
  load()
  window.addEventListener('resize', () => { isMobile.value = window.innerWidth <= 768 })
  try {
    const res = await getFormats()
    formats.value = res.data.formats || []
  } catch {}
})
</script>

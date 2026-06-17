<template>
  <n-modal :show="show" @update:show="$emit('update:show', $event)" preset="card" title="导入订阅" style="width: 520px">
    <n-space vertical>
      <n-alert type="info">
        支持从 SubForge 导出的 JSON 文件导入，或手动粘贴 JSON 内容。
      </n-alert>

      <n-tabs v-model:value="importMode">
        <n-tab-pane name="file" tab="文件导入">
          <n-upload
            :max="1"
            accept=".json"
            :custom-request="handleFileUpload"
            :on-remove="() => { fileContent = '' }"
          >
            <n-button>选择 JSON 文件</n-button>
          </n-upload>
        </n-tab-pane>
        <n-tab-pane name="text" tab="文本导入">
          <n-input
            v-model:value="textContent"
            type="textarea"
            :rows="8"
            placeholder='[{"name": "订阅1", "url": "https://..."}, ...]'
          />
        </n-tab-pane>
      </n-tabs>

      <n-button type="primary" block :loading="importing" @click="handleImport" :disabled="!canImport">
        导入 ({{ previewCount }} 个订阅)
      </n-button>
    </n-space>
  </n-modal>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useMessage, NModal, NSpace, NAlert, NButton, NTabs, NTabPane, NUpload, NInput } from 'naive-ui'
import { importSubscriptions } from '../api/subscription'

const props = defineProps<{ show: boolean }>()
const emit = defineEmits(['update:show', 'imported'])
const message = useMessage()

const importMode = ref('file')
const fileContent = ref('')
const textContent = ref('')
const importing = ref(false)

const content = computed(() => importMode.value === 'file' ? fileContent.value : textContent.value)

const canImport = computed(() => {
  if (!content.value) return false
  try {
    const data = JSON.parse(content.value)
    return Array.isArray(data) && data.length > 0
  } catch { return false }
})

const previewCount = computed(() => {
  if (!content.value) return 0
  try {
    const data = JSON.parse(content.value)
    return Array.isArray(data) ? data.length : 0
  } catch { return 0 }
})

function handleFileUpload({ file }: any) {
  const reader = new FileReader()
  reader.onload = (e) => {
    fileContent.value = e.target?.result as string || ''
  }
  reader.readAsText(file.file)
}

async function handleImport() {
  if (!canImport.value) return
  importing.value = true
  try {
    const data = JSON.parse(content.value)
    const res = await importSubscriptions(data)
    message.success(`成功导入 ${res.data.imported} 个订阅`)
    emit('update:show', false)
    emit('imported')
    fileContent.value = ''
    textContent.value = ''
  } catch (e: any) {
    message.error(e.response?.data?.message || '导入失败')
  } finally {
    importing.value = false
  }
}
</script>

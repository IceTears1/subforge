<template>
  <div>
    <n-grid :cols="2" :x-gap="24">
      <n-gi>
        <n-card title="输入" :bordered="false">
          <n-form>
            <n-form-item label="订阅链接">
              <n-input v-model:value="sourceUrl" placeholder="https://example.com/subscribe" />
            </n-form-item>
            <n-divider>或</n-divider>
            <n-form-item label="原始内容">
              <n-input v-model:value="sourceContent" type="textarea" :rows="8" placeholder="粘贴订阅内容..." />
            </n-form-item>
            <n-form-item label="输出格式">
              <n-select v-model:value="target" :options="formatOptions" />
            </n-form-item>
            <n-space>
              <n-checkbox v-model:checked="rename">智能重命名</n-checkbox>
              <n-checkbox v-model:checked="dedup">自动去重</n-checkbox>
            </n-space>
            <n-form-item label="区域筛选" style="margin-top: 16px">
              <n-select v-model:value="regions" multiple :options="regionOptions" placeholder="全部" clearable />
            </n-form-item>
            <n-button type="primary" block :loading="converting" @click="handleConvert" style="margin-top: 16px">
              转换
            </n-button>
          </n-form>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card title="输出" :bordered="false">
          <template #header-extra>
            <n-button size="small" quaternary @click="copyOutput" v-if="output">复制</n-button>
          </template>
          <n-input v-model:value="output" type="textarea" :rows="20" readonly placeholder="转换结果将在此显示..." />
        </n-card>
      </n-gi>
    </n-grid>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useMessage, NGrid, NGi, NCard, NForm, NFormItem, NInput, NSelect, NButton, NSpace, NCheckbox, NDivider } from 'naive-ui'
import { convertSub } from '../api/subscription'

const message = useMessage()
const sourceUrl = ref('')
const sourceContent = ref('')
const target = ref('clash')
const rename = ref(true)
const dedup = ref(true)
const regions = ref<string[]>([])
const output = ref('')
const converting = ref(false)

const formatOptions = [
  { label: 'Clash', value: 'clash' },
  { label: 'sing-box', value: 'singbox' },
  { label: 'Surge', value: 'surge' },
  { label: 'Loon', value: 'loon' },
  { label: 'Quantumult X', value: 'quanx' },
  { label: 'Base64', value: 'base64' },
]

const regionOptions = [
  { label: '🇭🇰 香港', value: 'HK' },
  { label: '🇯🇵 日本', value: 'JP' },
  { label: '🇸🇬 新加坡', value: 'SG' },
  { label: '🇺🇸 美国', value: 'US' },
  { label: '🇨🇳 台湾', value: 'TW' },
  { label: '🇰🇷 韩国', value: 'KR' },
  { label: '🇬🇧 英国', value: 'UK' },
  { label: '🇩🇪 德国', value: 'DE' },
]

async function handleConvert() {
  if (!sourceUrl.value && !sourceContent.value) {
    message.warning('请输入订阅链接或内容')
    return
  }
  converting.value = true
  try {
    const res = await convertSub(sourceUrl.value, target.value, {
      content: sourceContent.value,
      rename: rename.value,
      dedup: dedup.value,
      regions: regions.value,
    })
    output.value = res.data
    message.success('转换成功')
  } catch (e: any) {
    message.error(e.response?.data?.message || '转换失败')
  } finally {
    converting.value = false
  }
}

function copyOutput() {
  navigator.clipboard.writeText(output.value)
  message.success('已复制')
}
</script>

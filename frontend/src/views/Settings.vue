<template>
  <div>
    <n-grid :cols="2" :x-gap="24">
      <n-gi>
        <n-card title="智能重命名规则" :bordered="false">
          <n-form label-placement="left">
            <n-form-item label="启用区域重命名">
              <n-switch v-model:value="settings.renameEnabled" />
            </n-form-item>
            <n-form-item label="命名格式">
              <n-input v-model:value="settings.renameFormat" placeholder="{emoji} {region} {index} | {type}" />
            </n-form-item>
            <n-form-item label="排除关键词">
              <n-dynamic-tags v-model:value="settings.excludeKeywords" />
            </n-form-item>
          </n-form>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card title="默认设置" :bordered="false">
          <n-form label-placement="left">
            <n-form-item label="默认输出格式">
              <n-select v-model:value="settings.defaultFormat" :options="formatOptions" />
            </n-form-item>
            <n-form-item label="自动去重">
              <n-switch v-model:value="settings.autoDedup" />
            </n-form-item>
            <n-form-item label="默认刷新间隔 (秒)">
              <n-input-number v-model:value="settings.defaultRefresh" :min="300" :step="300" />
            </n-form-item>
          </n-form>
        </n-card>

        <n-card title="API 信息" :bordered="false" style="margin-top: 24px">
          <n-descriptions :column="1" bordered>
            <n-descriptions-item label="订阅地址">
              <n-text code>/api/sub/{your-token}</n-text>
            </n-descriptions-item>
            <n-descriptions-item label="转换接口">
              <n-text code>POST /api/convert</n-text>
            </n-descriptions-item>
            <n-descriptions-item label="格式检测">
              <n-text code>POST /api/detect</n-text>
            </n-descriptions-item>
          </n-descriptions>
        </n-card>
      </n-gi>
    </n-grid>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { NGrid, NGi, NCard, NForm, NFormItem, NInput, NSwitch, NSelect, NInputNumber, NDynamicTags, NDescriptions, NDescriptionsItem, NText } from 'naive-ui'

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
</script>

<template>
  <n-modal :show="show" @update:show="$emit('update:show', $event)" preset="card" title="分享订阅" style="width: 480px">
    <n-space vertical>
      <n-text>选择客户端格式：</n-text>
      <n-radio-group v-model:value="format" style="width: 100%">
        <n-space>
          <n-radio value="clash">Clash</n-radio>
          <n-radio value="singbox">sing-box</n-radio>
          <n-radio value="surge">Surge</n-radio>
          <n-radio value="loon">Loon</n-radio>
          <n-radio value="quanx">QX</n-radio>
        </n-space>
      </n-radio-group>

      <n-divider />

      <n-text>订阅链接：</n-text>
      <n-input :value="subUrl" readonly type="textarea" :rows="3" />

      <n-space>
        <n-button type="primary" @click="copyUrl">
          <template #icon><n-icon :component="CopyOutline" /></template>
          复制链接
        </n-button>
        <n-button @click="openUrl">
          <template #icon><n-icon :component="OpenOutline" /></template>
          打开
        </n-button>
      </n-space>

      <n-divider />

      <n-text>二维码：</n-text>
      <div class="qr-container">
        <img v-if="qrUrl" :src="qrUrl" alt="QR Code" style="width: 200px; height: 200px;" />
        <n-text v-else depth="3">加载中...</n-text>
      </div>
    </n-space>
  </n-modal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useMessage, NModal, NSpace, NText, NRadioGroup, NRadio, NInput, NButton, NIcon, NDivider } from 'naive-ui'
import { CopyOutline, OpenOutline } from '@vicons/ionicons5'

const props = defineProps<{
  show: boolean
  token: string
}>()

const emit = defineEmits(['update:show'])
const message = useMessage()
const format = ref('clash')

const subUrl = computed(() => {
  if (!props.token) return ''
  return `${window.location.origin}/sub/${props.token}?target=${format.value}`
})

const qrUrl = computed(() => {
  if (!subUrl.value) return ''
  return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(subUrl.value)}`
})

function copyUrl() {
  navigator.clipboard.writeText(subUrl.value)
  message.success('已复制')
}

function openUrl() {
  window.open(subUrl.value, '_blank')
}
</script>

<style scoped>
.qr-container {
  display: flex;
  justify-content: center;
  padding: 16px;
  background: #fff;
  border-radius: 8px;
}
</style>

<template>
  <n-modal :show="show" @update:show="$emit('update:show', $event)" preset="card" :title="sub?.name || '订阅详情'" style="width: 600px">
    <n-space vertical v-if="sub">
      <n-descriptions :column="2" bordered>
        <n-descriptions-item label="ID">{{ sub.id }}</n-descriptions-item>
        <n-descriptions-item label="名称">{{ sub.name }}</n-descriptions-item>
        <n-descriptions-item label="节点数">{{ sub.node_count }}</n-descriptions-item>
        <n-descriptions-item label="状态">
          <n-tag :type="sub.status === 1 ? 'success' : 'error'" size="small" bordered>
            {{ sub.status === 1 ? '正常' : '禁用' }}
          </n-tag>
        </n-descriptions-item>
        <n-descriptions-item label="刷新间隔">{{ sub.auto_refresh }}秒</n-descriptions-item>
        <n-descriptions-item label="最后更新">{{ sub.last_fetch ? new Date(sub.last_fetch).toLocaleString() : '未更新' }}</n-descriptions-item>
        <n-descriptions-item label="创建时间">{{ new Date(sub.created_at).toLocaleString() }}</n-descriptions-item>
        <n-descriptions-item label="标签">
          <n-space>
            <n-tag v-for="tag in (sub.tags || [])" :key="tag" size="small" :bordered="false">{{ tag }}</n-tag>
          </n-space>
        </n-descriptions-item>
      </n-descriptions>

      <n-divider />

      <n-text>订阅链接：</n-text>
      <n-input :value="sub.url" readonly type="textarea" :rows="2" />

      <n-space>
        <n-button @click="copyUrl">复制链接</n-button>
        <n-button type="primary" @click="$emit('refresh', sub)">刷新</n-button>
        <n-button @click="$emit('share', sub)">分享</n-button>
      </n-space>
    </n-space>
  </n-modal>
</template>

<script setup lang="ts">
import { useMessage, NModal, NSpace, NDescriptions, NDescriptionsItem, NTag, NDivider, NText, NInput, NButton } from 'naive-ui'
import type { Subscription } from '../api/subscription'

const props = defineProps<{
  show: boolean
  sub: Subscription | null
}>()

const emit = defineEmits(['update:show', 'refresh', 'share'])
const message = useMessage()

function copyUrl() {
  if (props.sub?.url) {
    navigator.clipboard.writeText(props.sub.url)
    message.success('已复制')
  }
}
</script>

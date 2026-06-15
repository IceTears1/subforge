<template>
  <n-modal :show="show" @update:show="$emit('update:show', $event)" preset="card" title="节点去重统计" style="width: 500px">
    <n-space vertical>
      <n-descriptions :column="2" bordered>
        <n-descriptions-item label="原始节点数">
          <n-tag type="info">{{ stats.original }}</n-tag>
        </n-descriptions-item>
        <n-descriptions-item label="去重后节点数">
          <n-tag type="success">{{ stats.deduped }}</n-tag>
        </n-descriptions-item>
        <n-descriptions-item label="移除数量">
          <n-tag type="warning">{{ stats.removed }}</n-tag>
        </n-descriptions-item>
        <n-descriptions-item label="去重率">
          <n-tag :type="stats.rate > 10 ? 'error' : 'success'">
            {{ stats.rate.toFixed(1) }}%
          </n-tag>
        </n-descriptions-item>
      </n-descriptions>

      <n-divider />

      <n-text>重复节点详情：</n-text>
      <n-data-table
        :columns="columns"
        :data="duplicates"
        :bordered="false"
        :max-height="300"
        size="small"
      />
    </n-space>
  </n-modal>
</template>

<script setup lang="ts">
import { h } from 'vue'
import { NModal, NSpace, NDescriptions, NDescriptionsItem, NTag, NDivider, NText, NDataTable } from 'naive-ui'

interface DupNode {
  server: string
  port: number
  type: string
  count: number
  names: string[]
}

defineProps<{
  show: boolean
  stats: {
    original: number
    deduped: number
    removed: number
    rate: number
  }
  duplicates: DupNode[]
}>()

defineEmits(['update:show'])

const columns = [
  { title: '地址', key: 'server', width: 150 },
  { title: '端口', key: 'port', width: 70 },
  { title: '类型', key: 'type', width: 80 },
  { title: '重复次数', key: 'count', width: 80 },
  {
    title: '节点名称', key: 'names', width: 200,
    render(row: DupNode) {
      return h('div', { style: { fontSize: '12px', color: '#999' } }, row.names.join(', '))
    },
  },
]
</script>

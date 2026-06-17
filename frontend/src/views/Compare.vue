<template>
  <div>
    <n-card :bordered="false">
      <template #header>
        <n-space justify="space-between" align="center">
          <span>订阅对比</span>
          <n-button type="primary" @click="handleCompare" :disabled="selectedSubs.length < 2">
            开始对比 ({{ selectedSubs.length }}/2)
          </n-button>
        </n-space>
      </template>

      <n-space vertical>
        <n-alert type="info">
          选择 2 个订阅进行对比，查看节点差异。
        </n-alert>

        <n-select
          v-model:value="selectedSubs"
          :options="subOptions"
          multiple
          :max-tag-count="2"
          placeholder="选择 2 个订阅"
          style="width: 100%"
        />
      </n-space>
    </n-card>

    <n-grid v-if="comparison" :cols="2" :x-gap="24" style="margin-top: 24px">
      <n-gi>
        <n-card :title="comparison.sub1.name" :bordered="false">
          <n-space vertical>
            <n-descriptions :column="1" bordered size="small">
              <n-descriptions-item label="节点数">
                <n-tag type="info">{{ comparison.sub1.nodeCount }}</n-tag>
              </n-descriptions-item>
              <n-descriptions-item label="独有节点">
                <n-tag type="warning">{{ comparison.sub1.unique }}</n-tag>
              </n-descriptions-item>
              <n-descriptions-item label="区域数">
                <n-tag>{{ comparison.sub1.regions }}</n-tag>
              </n-descriptions-item>
            </n-descriptions>

            <n-divider />
            <n-text>独有节点：</n-text>
            <n-data-table
              :columns="nodeColumns"
              :data="comparison.sub1.uniqueNodes"
              :bordered="false"
              :max-height="300"
              size="small"
            />
          </n-space>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :title="comparison.sub2.name" :bordered="false">
          <n-space vertical>
            <n-descriptions :column="1" bordered size="small">
              <n-descriptions-item label="节点数">
                <n-tag type="info">{{ comparison.sub2.nodeCount }}</n-tag>
              </n-descriptions-item>
              <n-descriptions-item label="独有节点">
                <n-tag type="warning">{{ comparison.sub2.unique }}</n-tag>
              </n-descriptions-item>
              <n-descriptions-item label="区域数">
                <n-tag>{{ comparison.sub2.regions }}</n-tag>
              </n-descriptions-item>
            </n-descriptions>

            <n-divider />
            <n-text>独有节点：</n-text>
            <n-data-table
              :columns="nodeColumns"
              :data="comparison.sub2.uniqueNodes"
              :bordered="false"
              :max-height="300"
              size="small"
            />
          </n-space>
        </n-card>
      </n-gi>
    </n-grid>

    <n-card v-if="comparison" title="共同节点" :bordered="false" style="margin-top: 24px">
      <n-space vertical>
        <n-tag type="success">共同节点数: {{ comparison.common.length }}</n-tag>
        <n-data-table
          :columns="nodeColumns"
          :data="comparison.common"
          :bordered="false"
          :max-height="400"
          size="small"
        />
      </n-space>
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useMessage, NCard, NSelect, NButton, NSpace, NAlert, NGrid, NGi, NDescriptions, NDescriptionsItem, NTag, NDivider, NText, NDataTable } from 'naive-ui'
import { getSubscriptions, getNodes } from '../api/subscription'
import type { Subscription, Node } from '../api/subscription'

const message = useMessage()
const subscriptions = ref<Subscription[]>([])
const selectedSubs = ref<number[]>([])
const comparison = ref<any>(null)

const subOptions = computed(() =>
  subscriptions.value.map(s => ({ label: s.name, value: s.id }))
)

const nodeColumns = [
  { title: '名称', key: 'display_name', width: 180, ellipsis: { tooltip: true } },
  { title: '类型', key: 'node_type', width: 80 },
  { title: '地址', key: 'server', width: 150, ellipsis: { tooltip: true } },
  { title: '端口', key: 'port', width: 70 },
  { title: '区域', key: 'region', width: 80 },
]

async function handleCompare() {
  if (selectedSubs.value.length !== 2) {
    message.warning('请选择 2 个订阅')
    return
  }

  try {
    const [sub1, sub2] = selectedSubs.value
    const [nodes1Res, nodes2Res] = await Promise.all([
      getNodes(sub1),
      getNodes(sub2),
    ])

    const nodes1 = nodes1Res.data || []
    const nodes2 = nodes2Res.data || []

    const sub1Info = subscriptions.value.find(s => s.id === sub1)!
    const sub2Info = subscriptions.value.find(s => s.id === sub2)!

    // Create key sets
    const keys1 = new Set(nodes1.map((n: Node) => `${n.server}:${n.port}:${n.node_type}`))
    const keys2 = new Set(nodes2.map((n: Node) => `${n.server}:${n.port}:${n.node_type}`))

    // Find unique and common
    const unique1 = nodes1.filter((n: Node) => !keys2.has(`${n.server}:${n.port}:${n.node_type}`))
    const unique2 = nodes2.filter((n: Node) => !keys1.has(`${n.server}:${n.port}:${n.node_type}`))
    const common = nodes1.filter((n: Node) => keys2.has(`${n.server}:${n.port}:${n.node_type}`))

    const regions1 = new Set(nodes1.map((n: Node) => n.region).filter(Boolean))
    const regions2 = new Set(nodes2.map((n: Node) => n.region).filter(Boolean))

    comparison.value = {
      sub1: {
        name: sub1Info.name,
        nodeCount: nodes1.length,
        unique: unique1.length,
        uniqueNodes: unique1,
        regions: regions1.size,
      },
      sub2: {
        name: sub2Info.name,
        nodeCount: nodes2.length,
        unique: unique2.length,
        uniqueNodes: unique2,
        regions: regions2.size,
      },
      common,
    }
  } catch (e: any) {
    message.error('对比失败')
  }
}

onMounted(async () => {
  try {
    const res = await getSubscriptions(1, 100)
    subscriptions.value = res.data.items || res.data
  } catch {}
})
</script>

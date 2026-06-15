<template>
  <div>
    <n-grid :cols="isMobile ? 2 : 4" :x-gap="16" :y-gap="16">
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="运行时间">
            <template #prefix>
              <n-icon :component="TimeOutline" color="#6366f1" />
            </template>
            {{ formatUptime(metrics.uptime_seconds) }}
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="Goroutines">
            <template #prefix>
              <n-icon :component="PulseOutline" color="#10b981" />
            </template>
            {{ metrics.goroutines }}
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="内存使用">
            <template #prefix>
              <n-icon :component="HardwareChipOutline" color="#f59e0b" />
            </template>
            {{ metrics.memory?.alloc_mb || 0 }} MB
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :bordered="false" class="stat-card">
          <n-statistic label="Go 版本">
            <template #prefix>
              <n-icon :component="LogoGithub" color="#8b5cf6" />
            </template>
            {{ metrics.go_version?.replace('go', '') || '-' }}
          </n-statistic>
        </n-card>
      </n-gi>
    </n-grid>

    <n-grid :cols="isMobile ? 1 : 2" :x-gap="24" style="margin-top: 24px">
      <n-gi>
        <n-card title="数据库统计" :bordered="false">
          <n-space vertical>
            <div class="metric-row">
              <span>用户数</span>
              <n-tag type="info">{{ metrics.database?.users || 0 }}</n-tag>
            </div>
            <div class="metric-row">
              <span>订阅数</span>
              <n-tag type="success">{{ metrics.database?.subscriptions || 0 }}</n-tag>
            </div>
            <div class="metric-row">
              <span>节点数</span>
              <n-tag type="warning">{{ metrics.database?.nodes || 0 }}</n-tag>
            </div>
          </n-space>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card title="内存详情" :bordered="false">
          <n-space vertical>
            <div class="metric-row">
              <span>当前分配</span>
              <n-progress :percentage="memoryPercent" :color="memoryColor" style="width: 200px" />
              <span>{{ metrics.memory?.alloc_mb || 0 }} MB</span>
            </div>
            <div class="metric-row">
              <span>累计分配</span>
              <n-tag>{{ metrics.memory?.total_alloc_mb || 0 }} MB</n-tag>
            </div>
            <div class="metric-row">
              <span>系统内存</span>
              <n-tag>{{ metrics.memory?.sys_mb || 0 }} MB</n-tag>
            </div>
            <div class="metric-row">
              <span>GC 次数</span>
              <n-tag>{{ metrics.memory?.gc_cycles || 0 }}</n-tag>
            </div>
          </n-space>
        </n-card>
      </n-gi>
    </n-grid>

    <n-card title="审计日志" :bordered="false" style="margin-top: 24px">
      <n-data-table :columns="auditColumns" :data="auditLogs" :loading="auditLoading" :bordered="false" :max-height="300" />
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, h } from 'vue'
import { NGrid, NGi, NCard, NStatistic, NIcon, NTag, NProgress, NSpace, NDataTable } from 'naive-ui'
import { TimeOutline, PulseOutline, HardwareChipOutline, LogoGithub } from '@vicons/ionicons5'
import api from '../api/request'

const isMobile = ref(window.innerWidth <= 768)
const metrics = ref<any>({})
const auditLogs = ref<any[]>([])
const auditLoading = ref(false)
let timer: number | null = null

const memoryPercent = computed(() => {
  const alloc = metrics.value.memory?.alloc_mb || 0
  const sys = metrics.value.memory?.sys_mb || 1
  return Math.round((alloc / sys) * 100)
})

const memoryColor = computed(() => {
  const p = memoryPercent.value
  if (p < 50) return '#10b981'
  if (p < 80) return '#f59e0b'
  return '#ef4444'
})

const auditColumns = [
  { title: '时间', key: 'created_at', width: 160, render(row: any) { return new Date(row.created_at).toLocaleString() } },
  { title: '用户', key: 'username', width: 100 },
  { title: '操作', key: 'action', width: 100, render(row: any) { return h(NTag, { size: 'small', bordered: false, type: row.success ? 'success' : 'error' }, { default: () => row.action }) } },
  { title: '资源', key: 'resource', width: 100 },
  { title: '详情', key: 'detail' },
  { title: 'IP', key: 'ip', width: 120 },
]

function formatUptime(seconds: number) {
  if (!seconds) return '-'
  const d = Math.floor(seconds / 86400)
  const h = Math.floor((seconds % 86400) / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  if (d > 0) return `${d}天${h}时`
  if (h > 0) return `${h}时${m}分`
  return `${m}分`
}

async function loadMetrics() {
  try {
    const res = await api.get('/metrics')
    metrics.value = res.data
  } catch {}
}

async function loadAudit() {
  auditLoading.value = true
  try {
    const res = await api.get('/audit?page_size=50')
    auditLogs.value = res.data.items || []
  } catch {} finally { auditLoading.value = false }
}

onMounted(() => {
  loadMetrics()
  loadAudit()
  timer = window.setInterval(loadMetrics, 30000)
  window.addEventListener('resize', () => { isMobile.value = window.innerWidth <= 768 })
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<style scoped>
.stat-card { text-align: center; }
.metric-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid rgba(0,0,0,0.05);
}
.metric-row:last-child { border-bottom: none; }
</style>

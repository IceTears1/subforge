<template>
  <div>
    <n-grid :cols="isMobile ? 1 : 2" :x-gap="24">
      <n-gi>
        <n-card title="版本信息" :bordered="false">
          <n-space vertical>
            <n-descriptions :column="1" bordered>
              <n-descriptions-item label="当前版本">
                <n-tag type="info">{{ versionInfo.current || '...' }}</n-tag>
              </n-descriptions-item>
              <n-descriptions-item label="最新版本">
                <n-tag :type="versionInfo.has_update ? 'warning' : 'success'">
                  {{ versionInfo.latest || '...' }}
                </n-tag>
              </n-descriptions-item>
              <n-descriptions-item label="状态">
                <n-tag :type="versionInfo.has_update ? 'warning' : 'success'" :bordered="false">
                  {{ versionInfo.has_update ? '有可用更新' : '已是最新版本' }}
                </n-tag>
              </n-descriptions-item>
              <n-descriptions-item label="最后检查">
                {{ versionInfo.last_check ? new Date(versionInfo.last_check).toLocaleString() : '...' }}
              </n-descriptions-item>
            </n-descriptions>

            <n-space>
              <n-button @click="checkVersion" :loading="checking">
                <template #icon><n-icon :component="RefreshOutline" /></template>
                检查更新
              </n-button>
              <n-button
                v-if="versionInfo.has_update"
                type="warning"
                :loading="updating"
                @click="handleUpdate"
              >
                <template #icon><n-icon :component="CloudDownloadOutline" /></template>
                立即更新
              </n-button>
            </n-space>
          </n-space>
        </n-card>

        <n-card title="版本回滚" :bordered="false" style="margin-top: 24px">
          <n-space vertical>
            <n-alert type="warning">
              回滚将切换到指定版本并重建容器。请谨慎操作。
            </n-alert>
            <n-select
              v-model:value="rollbackTarget"
              :options="versionOptions"
              placeholder="选择要回滚的版本"
              filterable
            />
            <n-button
              type="error"
              :disabled="!rollbackTarget"
              :loading="rollingBack"
              @click="handleRollback"
            >
              回滚到选中版本
            </n-button>
          </n-space>
        </n-card>
      </n-gi>

      <n-gi>
        <n-card title="更新日志" :bordered="false">
          <n-spin :show="loadingChangelog">
            <n-timeline>
              <n-timeline-item
                v-for="(entry, index) in changelog"
                :key="entry.hash"
                :type="index === 0 ? 'success' : 'default'"
                :title="entry.message"
                :content="entry.hash"
                :time="formatDate(entry.date)"
              />
            </n-timeline>
          </n-spin>
        </n-card>
      </n-gi>
    </n-grid>

    <!-- Update Result Modal -->
    <n-modal v-model:show="showResult" preset="card" title="更新结果" style="width: 500px">
      <n-space vertical>
        <n-alert :type="updateResult?.success ? 'success' : 'error'">
          {{ updateResult?.success ? '更新成功' : '更新失败' }}
        </n-alert>
        <n-descriptions :column="1" bordered>
          <n-descriptions-item label="原版本">
            <n-tag>{{ updateResult?.from }}</n-tag>
          </n-descriptions-item>
          <n-descriptions-item label="新版本">
            <n-tag type="success">{{ updateResult?.to }}</n-tag>
          </n-descriptions-item>
          <n-descriptions-item label="时间">
            {{ updateResult?.timestamp ? new Date(updateResult.timestamp).toLocaleString() : '-' }}
          </n-descriptions-item>
        </n-descriptions>
        <n-input
          v-if="updateResult?.message"
          :value="updateResult.message"
          type="textarea"
          :rows="5"
          readonly
        />
      </n-space>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useMessage, NGrid, NGi, NCard, NDescriptions, NDescriptionsItem, NTag, NSpace, NButton, NIcon, NSelect, NAlert, NTimeline, NTimelineItem, NSpin, NModal, NInput } from 'naive-ui'
import { RefreshOutline, CloudDownloadOutline } from '@vicons/ionicons5'
import { getVersion, getChangelog, performUpdate, performRollback } from '../api/update'
import type { VersionInfo, VersionEntry, UpdateResult } from '../api/update'

const message = useMessage()
const isMobile = ref(window.innerWidth <= 768)
const checking = ref(false)
const updating = ref(false)
const rollingBack = ref(false)
const loadingChangelog = ref(false)
const showResult = ref(false)
const versionInfo = ref<VersionInfo>({ current: '', latest: '', has_update: false, changelog: '', last_check: '' })
const changelog = ref<VersionEntry[]>([])
const rollbackTarget = ref<string | null>(null)
const updateResult = ref<UpdateResult | null>(null)

const versionOptions = computed(() =>
  changelog.value.map(v => ({
    label: `${v.hash} - ${v.message}`,
    value: v.hash,
  }))
)

function formatDate(dateStr: string) {
  try {
    return new Date(dateStr).toLocaleString()
  } catch {
    return dateStr
  }
}

async function checkVersion() {
  checking.value = true
  try {
    const res = await getVersion()
    versionInfo.value = res.data
    message.success('版本信息已更新')
  } catch (e: any) {
    message.error('检查版本失败: ' + (e.response?.data?.message || e.message))
  } finally {
    checking.value = false
  }
}

async function loadChangelog() {
  loadingChangelog.value = true
  try {
    const res = await getChangelog(20)
    changelog.value = res.data || []
  } catch {} finally {
    loadingChangelog.value = false
  }
}

async function handleUpdate() {
  updating.value = true
  try {
    const res = await performUpdate()
    updateResult.value = res.data
    showResult.value = true
    if (res.data.success) {
      message.success('更新成功！服务正在重启...')
      // Refresh version info after delay
      setTimeout(checkVersion, 5000)
      setTimeout(loadChangelog, 5000)
    } else {
      message.error('更新失败')
    }
  } catch (e: any) {
    message.error('更新失败: ' + (e.response?.data?.message || e.message))
  } finally {
    updating.value = false
  }
}

async function handleRollback() {
  if (!rollbackTarget.value) return
  rollingBack.value = true
  try {
    const res = await performRollback(rollbackTarget.value)
    updateResult.value = res.data
    showResult.value = true
    if (res.data.success) {
      message.success('回滚成功！服务正在重启...')
      setTimeout(checkVersion, 5000)
      setTimeout(loadChangelog, 5000)
    } else {
      message.error('回滚失败')
    }
  } catch (e: any) {
    message.error('回滚失败: ' + (e.response?.data?.message || e.message))
  } finally {
    rollingBack.value = false
  }
}

onMounted(() => {
  checkVersion()
  loadChangelog()
  window.addEventListener('resize', () => { isMobile.value = window.innerWidth <= 768 })
})
</script>

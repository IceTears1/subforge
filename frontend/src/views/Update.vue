<template>
  <div>
    <n-grid :cols="isMobile ? 1 : 2" :x-gap="24">
      <n-gi>
        <n-card title="版本信息" :bordered="false">
          <n-space vertical>
            <n-descriptions :column="1" bordered>
              <n-descriptions-item label="当前版本">
                <n-space>
                  <n-tag type="info">{{ versionInfo.current_tag || versionInfo.current || '...' }}</n-tag>
                  <n-text depth="3" style="font-size: 12px">({{ versionInfo.current_commit || '...' }})</n-text>
                </n-space>
              </n-descriptions-item>
              <n-descriptions-item label="最新版本">
                <n-tag :type="versionInfo.has_update ? 'warning' : 'success'">
                  {{ versionInfo.latest_tag || versionInfo.latest || '...' }}
                </n-tag>
              </n-descriptions-item>
              <n-descriptions-item label="更新模式">
                <n-tag :type="versionInfo.update_mode === 'tag' ? 'success' : 'info'" size="small">
                  {{ versionInfo.update_mode === 'tag' ? 'Tag 版本管理' : 'Main 分支同步' }}
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
                v-if="versionInfo.has_update && !versionInfo.updating"
                type="warning"
                :loading="updating"
                @click="handleUpdateToLatest"
              >
                <template #icon><n-icon :component="CloudDownloadOutline" /></template>
                更新到最新
              </n-button>
              <n-button
                v-if="versionInfo.updating"
                type="info"
                loading
              >
                更新中...
              </n-button>
            </n-space>
          </n-space>
        </n-card>

        <!-- Update Progress -->
        <n-card v-if="updateResult" title="更新进度" :bordered="false" style="margin-top: 24px">
          <n-space vertical>
            <n-alert :type="updateResult.success ? 'success' : 'error'">
              {{ updateResult.success ? '更新成功！' : '更新失败' }}
              {{ updateResult.error ? ': ' + updateResult.error : '' }}
            </n-alert>

            <n-timeline>
              <n-timeline-item
                v-for="step in updateResult.steps"
                :key="step.name"
                :type="getStepType(step.status)"
                :title="step.name"
                :content="step.message"
              />
            </n-timeline>

            <n-descriptions :column="2" bordered size="small">
              <n-descriptions-item label="原版本">
                <n-tag size="small">{{ updateResult.from }}</n-tag>
              </n-descriptions-item>
              <n-descriptions-item label="新版本">
                <n-tag size="small" type="success">{{ updateResult.to }}</n-tag>
              </n-descriptions-item>
            </n-descriptions>
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
              :disabled="!rollbackTarget || versionInfo.updating"
              :loading="rollingBack"
              @click="handleRollback"
            >
              回滚到选中版本
            </n-button>
          </n-space>
        </n-card>
      </n-gi>

      <n-gi>
        <n-card title="发布历史" :bordered="false">
          <n-spin :show="loadingReleases">
            <n-timeline>
              <n-timeline-item
                v-for="release in releases"
                :key="release.tag"
                :type="release.is_current ? 'success' : 'default'"
                :title="release.tag"
                :content="release.message"
                :time="formatDate(release.date)"
              >
                <template #footer>
                  <n-button
                    v-if="!release.is_current"
                    size="tiny"
                    quaternary
                    type="primary"
                    @click="handleUpdateToTag(release.tag)"
                    :loading="updatingToTag === release.tag"
                  >
                    更新到此版本
                  </n-button>
                  <n-tag v-else size="tiny" type="success">当前版本</n-tag>
                </template>
              </n-timeline-item>
            </n-timeline>
          </n-spin>
        </n-card>
      </n-gi>
    </n-grid>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useMessage, NGrid, NGi, NCard, NDescriptions, NDescriptionsItem, NTag, NText, NSpace, NButton, NIcon, NSelect, NAlert, NTimeline, NTimelineItem, NSpin } from 'naive-ui'
import { RefreshOutline, CloudDownloadOutline } from '@vicons/ionicons5'
import { getVersion, getReleases, getUpdateStatus, updateToLatest, updateToTag, performRollback } from '../api/update'
import type { VersionInfo, Release, UpdateResult } from '../api/update'

const message = useMessage()
const isMobile = ref(window.innerWidth <= 768)
const checking = ref(false)
const updating = ref(false)
const rollingBack = ref(false)
const loadingReleases = ref(false)
const versionInfo = ref<VersionInfo>({
  current: '', current_tag: '', latest: '', latest_tag: '',
  has_update: false, changelog: '', last_check: '', update_mode: 'tag', updating: false
})
const releases = ref<Release[]>([])
const rollbackTarget = ref<string | null>(null)
const updateResult = ref<UpdateResult | null>(null)
const updatingToTag = ref<string | null>(null)
let statusTimer: number | null = null

const versionOptions = computed(() =>
  releases.value.map(r => ({
    label: `${r.tag} - ${r.message}`,
    value: r.tag,
  }))
)

function getStepType(status: string) {
  switch (status) {
    case 'success': return 'success'
    case 'failed': return 'error'
    case 'running': return 'info'
    default: return 'default'
  }
}

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
    if (res.data.last_update) {
      updateResult.value = res.data.last_update
    }
    message.success('版本信息已更新')
  } catch (e: any) {
    message.error('检查版本失败')
  } finally {
    checking.value = false
  }
}

async function loadReleases() {
  loadingReleases.value = true
  try {
    const res = await getReleases()
    releases.value = res.data || []
  } catch {} finally {
    loadingReleases.value = false
  }
}

async function pollUpdateStatus() {
  try {
    const res = await getUpdateStatus()
    versionInfo.value.updating = res.data.updating
    if (res.data.last_result) {
      updateResult.value = res.data.last_result
    }
    if (!res.data.updating && statusTimer) {
      clearInterval(statusTimer)
      statusTimer = null
      updating.value = false
      updatingToTag.value = null
      checkVersion()
      loadReleases()
    }
  } catch {}
}

function startPolling() {
  statusTimer = window.setInterval(pollUpdateStatus, 3000)
  setTimeout(() => {
    if (statusTimer) {
      clearInterval(statusTimer)
      statusTimer = null
      updating.value = false
      updatingToTag.value = null
    }
  }, 300000)
}

async function handleUpdateToLatest() {
  updating.value = true
  updateResult.value = null

  try {
    const res = await updateToLatest()
    updateResult.value = res.data
    if (res.data.success) {
      message.success('更新成功！服务正在重启...')
    } else {
      message.error('更新失败')
    }
  } catch (e: any) {
    message.error('更新失败')
    updating.value = false
    return
  }
  startPolling()
}

async function handleUpdateToTag(tag: string) {
  updatingToTag.value = tag
  updating.value = true
  updateResult.value = null

  try {
    const res = await updateToTag(tag)
    updateResult.value = res.data
    if (res.data.success) {
      message.success(`已更新到 ${tag}`)
    } else {
      message.error('更新失败')
    }
  } catch (e: any) {
    message.error('更新失败')
    updating.value = false
    updatingToTag.value = null
    return
  }
  startPolling()
}

async function handleRollback() {
  if (!rollbackTarget.value) return
  rollingBack.value = true
  updateResult.value = null

  try {
    const res = await performRollback(rollbackTarget.value)
    updateResult.value = res.data
    if (res.data.success) {
      message.success('回滚成功！')
      setTimeout(() => {
        checkVersion()
        loadReleases()
      }, 5000)
    } else {
      message.error('回滚失败')
    }
  } catch (e: any) {
    message.error('回滚失败')
  } finally {
    rollingBack.value = false
  }
}

onMounted(() => {
  checkVersion()
  loadReleases()
  pollUpdateStatus()
  window.addEventListener('resize', () => { isMobile.value = window.innerWidth <= 768 })
})

onUnmounted(() => {
  if (statusTimer) clearInterval(statusTimer)
})
</script>

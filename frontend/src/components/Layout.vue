<template>
  <n-layout has-sider style="height: 100vh">
    <n-layout-sider
      bordered
      :width="220"
      :collapsed-width="64"
      :native-scrollbar="false"
      style="background: #fff"
    >
      <div class="logo">
        <span v-if="!collapsed">⚡ SubForge</span>
        <span v-else>⚡</span>
      </div>
      <n-menu
        :collapsed="collapsed"
        :collapsed-width="64"
        :collapsed-icon-size="22"
        :options="menuOptions"
        :value="activeKey"
        @update:value="onMenuSelect"
      />
      <div class="sidebar-footer">
        <n-button quaternary @click="collapsed = !collapsed">
          <template #icon>
            <n-icon :component="collapsed ? MenuOutline : MenuOutline" />
          </template>
        </n-button>
      </div>
    </n-layout-sider>
    <n-layout>
      <n-layout-header bordered style="height: 56px; display: flex; align-items: center; padding: 0 24px; justify-content: space-between;">
        <n-breadcrumb>
          <n-breadcrumb-item>{{ currentPageTitle }}</n-breadcrumb-item>
        </n-breadcrumb>
        <n-space align="center">
          <n-tag :bordered="false" type="info" size="small">{{ auth.user?.username }}</n-tag>
          <n-button quaternary size="small" @click="handleLogout">退出</n-button>
        </n-space>
      </n-layout-header>
      <n-layout-content content-style="padding: 24px;" :native-scrollbar="false">
        <router-view />
      </n-layout-content>
    </n-layout>
  </n-layout>
</template>

<script setup lang="ts">
import { h, ref, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { NLayout, NLayoutSider, NLayoutHeader, NLayoutContent, NMenu, NButton, NIcon, NBreadcrumb, NBreadcrumbItem, NSpace, NTag } from 'naive-ui'
import { MenuOutline, GridOutline, CloudOutline, SwapHorizontalOutline, PeopleOutline, SettingsOutline } from '@vicons/ionicons5'
import { useAuthStore } from '../stores/auth'
import type { MenuOption } from 'naive-ui'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const collapsed = ref(false)

const menuOptions: MenuOption[] = [
  { label: '仪表盘', key: '/', icon: () => h(NIcon, { component: GridOutline }) },
  { label: '订阅管理', key: '/subscriptions', icon: () => h(NIcon, { component: CloudOutline }) },
  { label: '在线转换', key: '/convert', icon: () => h(NIcon, { component: SwapHorizontalOutline }) },
  ...(auth.isAdmin ? [{ label: '子账户管理', key: '/users', icon: () => h(NIcon, { component: PeopleOutline }) }] : []),
  { label: '系统设置', key: '/settings', icon: () => h(NIcon, { component: SettingsOutline }) },
]

const activeKey = computed(() => route.path)
const currentPageTitle = computed(() => {
  const map: Record<string, string> = {
    '/': '仪表盘',
    '/subscriptions': '订阅管理',
    '/convert': '在线转换',
    '/users': '子账户管理',
    '/settings': '系统设置',
  }
  return map[route.path] || ''
})

function onMenuSelect(key: string) {
  router.push(key)
}

function handleLogout() {
  auth.logout()
  router.push('/login')
}
</script>

<style scoped>
.logo {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  font-weight: 700;
  color: #6366f1;
  border-bottom: 1px solid #f0f0f0;
}
.sidebar-footer {
  position: absolute;
  bottom: 16px;
  width: 100%;
  display: flex;
  justify-content: center;
}
</style>

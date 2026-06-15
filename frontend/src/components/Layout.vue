<template>
  <n-layout has-sider style="height: 100vh">
    <n-layout-sider
      v-if="!isMobile"
      bordered
      :width="220"
      :collapsed-width="64"
      :native-scrollbar="false"
      :collapsed="collapsed"
      show-trigger
      @collapse="collapsed = true"
      @expand="collapsed = false"
      style="background: var(--n-color)"
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
    </n-layout-sider>

    <!-- Mobile drawer -->
    <n-drawer v-model:show="showMobileMenu" :width="240" placement="left">
      <n-drawer-content>
        <div class="logo">⚡ SubForge</div>
        <n-menu
          :options="menuOptions"
          :value="activeKey"
          @update:value="onMobileMenuSelect"
        />
      </n-drawer-content>
    </n-drawer>

    <n-layout>
      <n-layout-header bordered style="height: 56px; display: flex; align-items: center; padding: 0 24px; justify-content: space-between;">
        <n-space align="center">
          <n-button v-if="isMobile" quaternary @click="showMobileMenu = true" class="mobile-menu-btn">
            <template #icon><n-icon :component="MenuOutline" /></template>
          </n-button>
          <n-breadcrumb>
            <n-breadcrumb-item>{{ currentPageTitle }}</n-breadcrumb-item>
          </n-breadcrumb>
        </n-space>
        <n-space align="center">
          <n-button quaternary @click="themeStore.toggle()">
            <template #icon>
              <n-icon :component="isDark ? SunnyOutline : MoonOutline" />
            </template>
          </n-button>
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
import { h, ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import {
  NLayout, NLayoutSider, NLayoutHeader, NLayoutContent, NMenu, NButton, NIcon,
  NBreadcrumb, NBreadcrumbItem, NSpace, NTag, NDrawer, NDrawerContent,
} from 'naive-ui'
import { MenuOutline, GridOutline, CloudOutline, SwapHorizontalOutline, PeopleOutline, SettingsOutline, MoonOutline, SunnyOutline, KeyOutline } from '@vicons/ionicons5'
import { useAuthStore } from '../stores/auth'
import { useThemeStore } from '../stores/theme'
import type { MenuOption } from 'naive-ui'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const themeStore = useThemeStore()
const collapsed = ref(false)
const showMobileMenu = ref(false)
const isDark = computed(() => themeStore.isDark)

// Responsive detection
const isMobile = ref(window.innerWidth <= 768)
function handleResize() {
  isMobile.value = window.innerWidth <= 768
}
onMounted(() => window.addEventListener('resize', handleResize))
onUnmounted(() => window.removeEventListener('resize', handleResize))

const menuOptions: MenuOption[] = [
  { label: '仪表盘', key: '/', icon: () => h(NIcon, { component: GridOutline }) },
  { label: '订阅管理', key: '/subscriptions', icon: () => h(NIcon, { component: CloudOutline }) },
  { label: '在线转换', key: '/convert', icon: () => h(NIcon, { component: SwapHorizontalOutline }) },
  { label: 'API Keys', key: '/apikeys', icon: () => h(NIcon, { component: KeyOutline }) },
  ...(auth.isAdmin ? [{ label: '子账户管理', key: '/users', icon: () => h(NIcon, { component: PeopleOutline }) }] : []),
  { label: '系统设置', key: '/settings', icon: () => h(NIcon, { component: SettingsOutline }) },
]

const activeKey = computed(() => route.path)
const currentPageTitle = computed(() => {
  const map: Record<string, string> = {
    '/': '仪表盘', '/subscriptions': '订阅管理', '/convert': '在线转换',
    '/users': '子账户管理', '/apikeys': 'API Keys', '/settings': '系统设置',
  }
  return map[route.path] || ''
})

function onMenuSelect(key: string) { router.push(key) }
function onMobileMenuSelect(key: string) {
  router.push(key)
  showMobileMenu.value = false
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
  border-bottom: 1px solid var(--n-border-color);
}
</style>

import { ref, onMounted, onUnmounted } from 'vue'

/**
 * 响应式断点检测
 * 修复多个组件重复创建 resize 监听器导致的内存泄漏
 */
export function useResponsive(breakpoint = 768) {
  const isMobile = ref(window.innerWidth <= breakpoint)
  const isTablet = ref(window.innerWidth > breakpoint && window.innerWidth <= 1024)
  const isDesktop = ref(window.innerWidth > 1024)

  const updateSize = () => {
    isMobile.value = window.innerWidth <= breakpoint
    isTablet.value = window.innerWidth > breakpoint && window.innerWidth <= 1024
    isDesktop.value = window.innerWidth > 1024
  }

  onMounted(() => {
    window.addEventListener('resize', updateSize)
  })

  onUnmounted(() => {
    window.removeEventListener('resize', updateSize)
  })

  return {
    isMobile,
    isTablet,
    isDesktop,
  }
}

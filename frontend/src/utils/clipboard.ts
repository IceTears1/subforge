import { useMessage } from 'naive-ui'

/**
 * 复制文本到剪贴板
 * 支持 fallback 到旧版 API
 */
export async function copyToClipboard(text: string): Promise<boolean> {
  try {
    // 优先使用现代 Clipboard API
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text)
      return true
    }

    // Fallback: 使用 execCommand
    const textarea = document.createElement('textarea')
    textarea.value = text
    textarea.style.position = 'fixed'
    textarea.style.left = '-999999px'
    textarea.style.top = '-999999px'
    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()

    const result = document.execCommand('copy')
    document.body.removeChild(textarea)
    return result
  } catch (error) {
    console.error('Failed to copy:', error)
    return false
  }
}

/**
 * 复制并显示消息
 */
export async function copyWithMessage(text: string, successMsg = '已复制'): Promise<void> {
  const message = useMessage()
  const success = await copyToClipboard(text)
  if (success) {
    message.success(successMsg)
  } else {
    message.error('复制失败')
  }
}

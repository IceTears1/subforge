// 订阅格式选项
export const formatOptions = [
  { label: 'Clash', value: 'clash' },
  { label: 'sing-box', value: 'singbox' },
  { label: 'Surge', value: 'surge' },
  { label: 'Loon', value: 'loon' },
  { label: 'QX', value: 'quanx' },
  { label: 'Base64', value: 'base64' },
]

// 获取格式标签颜色
export function getFormatColor(format: string): string {
  const colors: Record<string, string> = {
    clash: '#10b981',
    singbox: '#3b82f6',
    surge: '#f59e0b',
    loon: '#8b5cf6',
    quanx: '#ec4899',
    base64: '#6b7280',
  }
  return colors[format] || colors.base64
}

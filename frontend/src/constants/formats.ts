// 订阅格式选项
export const formatOptions = [
  { label: 'Clash', value: 'clash' },
  { label: 'sing-box', value: 'singbox' },
  { label: 'Surge', value: 'surge' },
  { label: 'Loon', value: 'loon' },
  { label: 'QX', value: 'qx' },
  { label: 'Shadowrocket', value: 'shadowrocket' },
  { label: 'Base64', value: 'base64' },
]

// 获取格式标签颜色
export function getFormatColor(format: string): string {
  const colors: Record<string, string> = {
    clash: '#10b981',
    singbox: '#3b82f6',
    surge: '#f59e0b',
    loon: '#8b5cf6',
    qx: '#ec4899',
    shadowrocket: '#ff6b6b',
    base64: '#6b7280',
  }
  return colors[format] || colors.base64
}

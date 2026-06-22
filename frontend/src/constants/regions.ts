// 地区 Emoji 映射
export const regionEmojis: Record<string, string> = {
  HK: '🇭🇰',
  TW: '🇨🇳',
  JP: '🇯🇵',
  SG: '🇸🇬',
  US: '🇺🇸',
  KR: '🇰🇷',
  UK: '🇬🇧',
  DE: '🇩🇪',
  FR: '🇫🇷',
  CA: '🇨🇦',
  AU: '🇦🇺',
  IN: '🇮🇳',
  RU: '🇷🇺',
  BR: '🇧🇷',
  NL: '🇳🇱',
  OTHER: '🌐',
}

// 地区颜色映射
export const regionColors: Record<string, string> = {
  HK: '#ff6b6b',
  TW: '#ff6b6b',
  JP: '#4ecdc4',
  SG: '#45b7d1',
  US: '#96ceb4',
  KR: '#ffeaa7',
  UK: '#dda0dd',
  DE: '#ffd93d',
  FR: '#6c5ce7',
  CA: '#ff7675',
  AU: '#74b9ff',
  IN: '#a29bfe',
  RU: '#fd79a8',
  BR: '#00b894',
  NL: '#e17055',
  OTHER: '#636e72',
}

// 协议颜色映射
export const protocolColors: Record<string, string> = {
  vless: '#10b981',
  vmess: '#3b82f6',
  trojan: '#f59e0b',
  ss: '#ef4444',
  hysteria2: '#8b5cf6',
  unknown: '#6b7280',
}

// 获取地区 Emoji
export function getRegionEmoji(region: string): string {
  return regionEmojis[region] || regionEmojis.OTHER
}

// 获取地区颜色
export function getRegionColor(region: string): string {
  return regionColors[region] || regionColors.OTHER
}

// 获取协议颜色
export function getProtocolColor(type: string): string {
  return protocolColors[type] || protocolColors.unknown
}

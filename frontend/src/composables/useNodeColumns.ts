import { h } from 'vue'
import { NTag, NText } from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { getRegionEmoji, getRegionColor, getProtocolColor } from '@/constants/regions'

export interface NodeData {
  id: number
  name: string
  display_name?: string
  node_type: string
  server: string
  port: number
  region: string
  latency: number
  status: number
  subscription_id?: number
  subscription_name?: string
}

/**
 * 获取延迟颜色
 */
function getLatencyColor(latency: number): string {
  if (latency < 0) return '#ef4444'  // 无法连接
  if (latency < 200) return '#10b981'  // 优秀
  if (latency < 500) return '#f59e0b'  // 良好
  return '#ef4444'  // 较差
}

/**
 * 获取延迟文本
 */
function getLatencyText(latency: number): string {
  if (latency < 0) return '超时'
  return `${latency}ms`
}

/**
 * 创建节点表格列定义
 */
export function useNodeColumns(options?: {
  showSubscription?: boolean
  showActions?: boolean
  onAction?: (action: string, row: NodeData) => void
}): DataTableColumns<NodeData> {
  const columns: DataTableColumns<NodeData> = [
    {
      title: '名称',
      key: 'name',
      ellipsis: { tooltip: true },
      render(row) {
        return h('div', { style: { display: 'flex', alignItems: 'center', gap: '8px' } }, [
          h('span', {}, getRegionEmoji(row.region)),
          h('span', {}, row.display_name || row.name),
        ])
      },
    },
    {
      title: '类型',
      key: 'node_type',
      width: 100,
      render(row) {
        return h(
          NTag,
          {
            size: 'small',
            bordered: false,
            style: { backgroundColor: getProtocolColor(row.node_type) + '20', color: getProtocolColor(row.node_type) },
          },
          { default: () => row.node_type.toUpperCase() }
        )
      },
    },
    {
      title: '服务器',
      key: 'server',
      ellipsis: { tooltip: true },
    },
    {
      title: '端口',
      key: 'port',
      width: 80,
    },
    {
      title: '区域',
      key: 'region',
      width: 80,
      render(row) {
        return h(
          NTag,
          {
            size: 'small',
            bordered: false,
            style: { backgroundColor: getRegionColor(row.region) + '20', color: getRegionColor(row.region) },
          },
          { default: () => `${getRegionEmoji(row.region)} ${row.region}` }
        )
      },
    },
    {
      title: '延迟',
      key: 'latency',
      width: 100,
      render(row) {
        return h(
          NText,
          {
            style: { color: getLatencyColor(row.latency), fontWeight: '500' },
          },
          { default: () => getLatencyText(row.latency) }
        )
      },
    },
  ]

  if (options?.showSubscription) {
    columns.splice(1, 0, {
      title: '订阅',
      key: 'subscription_name',
      ellipsis: { tooltip: true },
    })
  }

  return columns
}

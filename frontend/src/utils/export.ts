import type { Node } from '@/types'

/**
 * 生成 Clash YAML 配置
 */
export function generateClashYaml(nodes: Node[]): string {
  const proxies = nodes.map(node => {
    const proxy: Record<string, any> = {
      name: node.name,
      type: node.node_type,
      server: node.server,
      port: node.port,
    }

    const config = node.config_json || {}

    if (node.node_type === 'vless') {
      proxy.uuid = config.uuid || config.id || ''
      proxy.tls = config.tls || false
      proxy.network = config.net || 'tcp'
    } else if (node.node_type === 'vmess') {
      proxy.uuid = config.id || ''
      proxy.alterId = config.aid || 0
      proxy.cipher = config.scy || 'auto'
    } else if (node.node_type === 'trojan') {
      proxy.password = config.password || ''
    } else if (node.node_type === 'ss') {
      proxy.cipher = config.method || config.cipher || 'aes-256-gcm'
      proxy.password = config.password || ''
    }

    return proxy
  })

  const config = {
    proxies,
    'proxy-groups': [
      {
        name: 'PROXY',
        type: 'select',
        proxies: nodes.map(n => n.name),
      },
    ],
    rules: ['MATCH,PROXY'],
  }

  return JSON.stringify(config, null, 2)
}

/**
 * 生成 sing-box JSON 配置
 */
export function generateSingboxJson(nodes: Node[]): string {
  const outbounds = nodes.map(node => {
    const outbound: Record<string, any> = {
      tag: node.name,
      type: node.node_type,
      server: node.server,
      server_port: node.port,
    }

    const config = node.config_json || {}

    if (node.node_type === 'vless') {
      outbound.uuid = config.uuid || config.id || ''
    } else if (node.node_type === 'vmess') {
      outbound.uuid = config.id || ''
      outbound.alter_id = config.aid || 0
    } else if (node.node_type === 'trojan') {
      outbound.password = config.password || ''
    } else if (node.node_type === 'ss') {
      outbound.method = config.method || config.cipher || 'aes-256-gcm'
      outbound.password = config.password || ''
    }

    return outbound
  })

  const config = {
    outbounds: [
      { type: 'selector', tag: 'proxy', outbounds: nodes.map(n => n.name) },
      ...outbounds,
    ],
  }

  return JSON.stringify(config, null, 2)
}

/**
 * 生成 Base64 订阅
 */
export function generateBase64(nodes: Node[]): string {
  const lines = nodes.map(node => {
    const config = node.config_json || {}

    if (node.node_type === 'vless') {
      const params = config.params || ''
      return `vless://${config.uuid || config.id}@${node.server}:${node.port}?${params}#${node.name}`
    } else if (node.node_type === 'vmess') {
      const vmessConfig = {
        v: '2',
        ps: node.name,
        add: node.server,
        port: String(node.port),
        id: config.id || '',
        aid: String(config.aid || 0),
        net: config.net || 'tcp',
        type: config.type || 'none',
        host: config.host || '',
        path: config.path || '',
        tls: config.tls || '',
      }
      return `vmess://${btoa(JSON.stringify(vmessConfig))}`
    } else if (node.node_type === 'trojan') {
      const params = config.params || ''
      return `trojan://${config.password}@${node.server}:${node.port}?${params}#${node.name}`
    } else if (node.node_type === 'ss') {
      const method = config.method || config.cipher || 'aes-256-gcm'
      const encoded = btoa(`${method}:${config.password}`)
      return `ss://${encoded}@${node.server}:${node.port}#${node.name}`
    }

    return node.raw_uri || ''
  }).filter(Boolean)

  return btoa(lines.join('\n'))
}

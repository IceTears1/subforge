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
    } else if (node.node_type === 'hysteria2') {
      proxy.password = config.password || ''
      proxy.ports = config.ports || ''
      if (config.obfs) {
        proxy.obfs = config.obfs
        proxy['obfs-password'] = config['obfs-password'] || ''
      }
    } else if (node.node_type === 'tuic') {
      proxy.password = config.password || ''
      proxy.uuid = config.uuid || ''
      proxy['udp-relay'] = true
    } else if (node.node_type === 'anytls') {
      proxy.password = config.password || ''
      if (config.sni) {
        proxy.sni = config.sni
      }
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
    } else if (node.node_type === 'hysteria2') {
      outbound.password = config.password || ''
      if (config.sni) {
        outbound.tls = { enabled: true, server_name: config.sni }
      }
    } else if (node.node_type === 'tuic') {
      outbound.password = config.password || ''
      outbound.uuid = config.uuid || ''
    } else if (node.node_type === 'anytls') {
      outbound.password = config.password || ''
      if (config.sni) {
        outbound.tls = { enabled: true, server_name: config.sni }
      }
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
    } else if (node.node_type === 'hysteria2') {
      const params: string[] = []
      if (config.sni) params.push(`sni=${config.sni}`)
      if (config.obfs) params.push(`obfs=${config.obfs}`)
      if (config['obfs-password']) params.push(`obfs-password=${config['obfs-password']}`)
      const query = params.length ? `?${params.join('&')}` : ''
      return `hysteria2://${config.password}@${node.server}:${node.port}${query}#${node.name}`
    } else if (node.node_type === 'tuic') {
      const params: string[] = []
      if (config.uuid) params.push(`uuid=${config.uuid}`)
      if (config.sni) params.push(`sni=${config.sni}`)
      const query = params.length ? `?${params.join('&')}` : ''
      return `tuic://${config.password}@${node.server}:${node.port}${query}#${node.name}`
    } else if (node.node_type === 'anytls') {
      const params: string[] = []
      if (config.sni) params.push(`sni=${config.sni}`)
      const query = params.length ? `?${params.join('&')}` : ''
      return `anytls://${config.password}@${node.server}:${node.port}${query}#${node.name}`
    }

    return node.raw_uri || ''
  }).filter(Boolean)

  return btoa(lines.join('\n'))
}

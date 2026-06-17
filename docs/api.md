# SubForge API Documentation

Base URL: `http://your-domain:8080`

## Authentication

All protected endpoints require a JWT token or API key in the Authorization header:
```
Authorization: Bearer <token>
Authorization: Bearer sf_<api-key>
```

API keys start with `sf_` prefix and can be created via the web UI or API.

---

## Auth Endpoints

### POST /api/auth/login
Login and get JWT token.

**Rate Limit:** 5 requests/minute per IP

**Request:**
```json
{
  "username": "admin",
  "password": "your-password"
}
```

**Response:**
```json
{
  "code": 0,
  "data": {
    "token": "eyJ...",
    "expires_in": 86400,
    "user": {
      "id": 1,
      "username": "admin",
      "role": "admin"
    }
  }
}
```

---

## Profile Endpoints

### GET /api/me
Get current user profile.

### PUT /api/me/password
Change password.

**Request:**
```json
{
  "old_password": "current-password",
  "new_password": "new-password"
}
```

---

## Subscription Endpoints

### GET /api/subscriptions
List subscriptions (paginated).

**Query Params:**
- `page` (int, default: 1)
- `page_size` (int, default: 20, max: 100)

**Response:**
```json
{
  "code": 0,
  "data": {
    "items": [...],
    "total": 50,
    "page": 1,
    "page_size": 20
  }
}
```

### POST /api/subscriptions
Create a subscription.

**Request:**
```json
{
  "name": "My Subscription",
  "url": "https://example.com/subscribe",
  "auto_refresh": 3600,
  "tags": ["paid", "stable"]
}
```

**Validation:**
- `name`: required, 1-128 chars
- `url`: required, http/https only, max 2048 chars
- `auto_refresh`: min 60 seconds

### GET /api/subscriptions/:id
Get subscription details with nodes.

### PUT /api/subscriptions/:id
Update subscription.

### DELETE /api/subscriptions/:id
Delete subscription.

### POST /api/subscriptions/:id/refresh
Manually refresh subscription nodes.

### GET /api/subscriptions/:id/nodes
Get subscription nodes.

**Query Params:**
- `region` (string, optional): filter by region (HK, JP, SG, etc.)

### GET /api/subscriptions/:id/token
Get subscription's public access token.

**Response:**
```json
{
  "code": 0,
  "data": {
    "token": "abc123...",
    "url": "/sub/abc123...?target=clash"
  }
}
```

---

## Public Subscription Endpoint (No Auth)

### GET /sub/:token
Get rendered subscription content.

**Query Params:**
- `target` (string, default: "clash"): output format
  - `clash`, `singbox`, `surge`, `loon`, `quanx`, `base64`

**Response:** Plain text subscription content

### GET /sub/:token/merged
Get all subscriptions merged.

---

## Convert Endpoint

### POST /api/convert
Convert subscription content.

**Request:**
```json
{
  "source_url": "https://example.com/subscribe",
  "content": "vmess://...",
  "target": "clash",
  "rename": true,
  "dedup": true,
  "regions": ["HK", "JP"],
  "exclude": ["过期", "到期"]
}
```

**Response:** Plain text converted content

### POST /api/detect
Detect subscription format.

**Request:**
```json
{
  "source": "https://example.com/subscribe"
}
```

**Response:**
```json
{
  "code": 0,
  "data": {
    "format": "base64",
    "node_count": 25
  }
}
```

### GET /api/formats
List supported output formats.

---

## User Management (Admin Only)

### GET /api/users
List users (paginated).

### POST /api/users
Create a sub-user.

**Request:**
```json
{
  "username": "user1",
  "password": "password123"
}
```

### PUT /api/users/:id/status
Enable/disable user.

**Request:**
```json
{
  "status": 0
}
```

### PUT /api/users/:id/password
Reset user password (admin).

### DELETE /api/users/:id
Delete user.

---

## Export/Import

### GET /api/export
Export all subscriptions as JSON file.

### POST /api/import
Import subscriptions from JSON.

**Request:** Array of subscription objects
```json
[
  {
    "name": "Sub 1",
    "url": "https://...",
    "auto_refresh": 3600,
    "tags": ["tag1"]
  }
]
```

**Response:**
```json
{
  "code": 0,
  "data": {
    "imported": 3,
    "total": 3
  }
}
```

---

## Webhooks

### GET /api/webhooks
List webhook configs.

### POST /api/webhooks
Create webhook.

**Request:**
```json
{
  "url": "https://your-service.com/webhook",
  "events": "refresh,fail"
}
```

**Events:**
- `refresh`: subscription refreshed successfully
- `fail`: subscription refresh failed

**Webhook Payload:**
```json
{
  "event": "refresh",
  "timestamp": 1718000000,
  "sub_id": 1,
  "sub_name": "My Sub",
  "node_count": 25,
  "error": ""
}
```

### DELETE /api/webhooks/:id
Delete webhook.

---

## API Keys

### GET /api/apikeys
List API keys (masked).

### POST /api/apikeys
Create API key.

**Request:**
```json
{
  "name": "My Script"
}
```

**Response:**
```json
{
  "code": 0,
  "data": {
    "id": 1,
    "name": "My Script",
    "key": "sf_abc123...",
    "status": 1
  }
}
```

### DELETE /api/apikeys/:id
Delete API key.

---

## Batch Operations

### POST /api/subscriptions/batch/delete
Delete multiple subscriptions.

**Request:**
```json
{
  "ids": [1, 2, 3]
}
```

**Response:**
```json
{
  "code": 0,
  "data": {
    "deleted": 3
  }
}
```

### POST /api/subscriptions/batch/refresh
Refresh multiple subscriptions.

### POST /api/subscriptions/batch/export
Export selected subscriptions as JSON.

---

## Monitoring

### GET /api/metrics
System metrics (uptime, database stats, memory, goroutines).

### GET /api/audit
Audit logs (admin only, paginated).

**Query Params:**
- `page` (int, default: 1)
- `page_size` (int, default: 20)
- `action` (string, optional): filter by action

---

## Health Check

### GET /api/health
Service health check.

**Response:**
```json
{
  "status": "ok"
}
```

---

## Client Usage

### Clash
```yaml
proxy-providers:
  subforge:
    type: http
    url: "http://your-domain:8080/sub/YOUR_TOKEN?target=clash"
    interval: 3600
```

### sing-box
```json
{
  "outbounds": [
    {
      "type": "urltest",
      "tag": "auto",
      "url": "http://your-domain:8080/sub/YOUR_TOKEN?target=singbox",
      "interval": "5m"
    }
  ]
}
```

### Surge
```ini
[Proxy]
#!subscribe http://your-domain:8080/sub/YOUR_TOKEN?target=surge
```

### Loon
```ini
[Proxy]
#!subscribe http://your-domain:8080/sub/YOUR_TOKEN?target=loon
```

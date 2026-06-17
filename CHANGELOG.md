# Changelog

## v1.0.0 (2026-06-12)

### Features
- Multi-format subscription conversion (Clash/sing-box/Surge/Loon/QX/Base64)
- Smart region-based node renaming with emoji flags
- Subscription management with CRUD operations
- Node management with filtering and search
- Online conversion tool
- Subscription sharing with QR code
- Import/Export subscriptions (JSON)
- Batch operations (delete/refresh/export)
- User management with sub-accounts
- API Key authentication
- Webhook notifications
- System monitoring dashboard
- Audit logging for security events
- Dark mode with theme persistence
- Responsive mobile design
- One-click VPS deployment
- Docker Compose orchestration
- Nginx reverse proxy with HTTPS support

### Security
- SSRF protection (blocks private/link-local IPs)
- JWT token blacklist for revocation
- Rate limiting on login (5/min per IP)
- IP whitelist for admin endpoints
- CORS origin whitelist
- Password complexity validation (8+ chars, upper/lower/digit)
- Security headers (CSP/HSTS/CORP/Referrer-Policy)
- Request body size limit (1MB)
- Input validation and sanitization
- Audit logging for all state-changing operations

### Performance
- Subscription content caching with ETag
- Database indexing (9 indexes)
- Scheduler concurrency limit (max 5)
- Graceful shutdown with signal handling
- Docker resource limits
- Log rotation configuration

### Testing
- Unit tests for parser, renderer, smart engine
- SSRF protection tests
- Rate limiter tests
- Cache tests (set/get/expiry/eviction)
- Password validation tests
- Token blacklist tests
- Deployment verification script

### Documentation
- Comprehensive API documentation
- Client usage examples (Clash/sing-box/Surge/Loon)
- Deployment guide
- Security guide
- Changelog

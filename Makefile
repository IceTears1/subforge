.PHONY: build up down logs clean deploy deploy-vps update-vps update rollback

# Local deploy
deploy:
	chmod +x deploy.sh && ./deploy.sh

# VPS one-click deploy
deploy-vps:
	chmod +x deploy-vps.sh && ./deploy-vps.sh

# VPS update
update-vps:
	chmod +x update-vps.sh && ./update-vps.sh

# Build all images
build:
	docker compose build

# Start services
up:
	docker compose up -d

# Stop services
down:
	docker compose down

# View logs
logs:
	docker compose logs -f

# Restart
restart:
	docker compose restart

# Clean everything
clean:
	docker compose down -v --rmi local

# Dev mode - backend
dev-backend:
	cd backend && go run ./cmd/server

# Dev mode - frontend
dev-frontend:
	cd frontend && npm run dev

# Health check
health:
	chmod +x scripts/health-check.sh && ./scripts/health-check.sh

# View metrics
metrics:
	curl -s http://localhost:8080/api/metrics | jq .

# Deploy verification
verify:
	chmod +x scripts/deploy-verify.sh && ./scripts/deploy-verify.sh

# Update (safe with backup)
update:
	chmod +x scripts/update.sh && sudo bash scripts/update.sh

# Rollback to previous version
rollback:
	chmod +x scripts/rollback.sh && sudo bash scripts/rollback.sh

# Create a new release
release:
	chmod +x scripts/release.sh && bash scripts/release.sh

.PHONY: build up down logs clean

# One-click deploy
deploy:
	chmod +x deploy.sh && ./deploy.sh

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

FROM node:20-alpine AS builder

# npm registry for faster downloads in China
RUN npm config set registry https://registry.npmmirror.com

WORKDIR /app

# Cache dependencies
COPY package.json package-lock.json* ./
RUN npm ci --legacy-peer-deps 2>/dev/null || npm install --legacy-peer-deps

# Copy source and build
COPY . .
RUN npm run build

FROM nginx:alpine

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html
# NOTE: Do NOT copy default.conf - it conflicts with nginx.conf template
# The entrypoint generates the complete nginx config from the template
COPY nginx/nginx-python.conf.template /etc/nginx/nginx.conf.template
COPY nginx/nginx-ssl.conf.template /etc/nginx/nginx-ssl.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]

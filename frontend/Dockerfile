FROM node:20-alpine AS builder

# npm registry: try Chinese mirror first, fall back to default
RUN npm config set registry https://registry.npmmirror.com || true

WORKDIR /app
COPY package.json ./
RUN npm install --legacy-peer-deps
COPY . .
RUN npm run build

FROM nginx:alpine

# Install dependencies (try Aliyun mirror, fall back to default)
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories 2>/dev/null; \
    apk --no-cache add curl || \
    (sed -i 's/mirrors.aliyun.com/dl-cdn.alpinelinux.org/g' /etc/apk/repositories 2>/dev/null; \
     apk --no-cache add curl)

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80

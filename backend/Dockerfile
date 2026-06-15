FROM golang:1.25-alpine AS builder

# Go proxy: try Chinese mirror first, fall back to default
ENV GOPROXY=https://goproxy.cn,https://goproxy.io,direct
ENV GO111MODULE=on

WORKDIR /app
COPY go.mod ./
RUN go mod download || true
COPY . .
RUN go mod tidy 2>/dev/null || true
RUN CGO_ENABLED=0 GOOS=linux go build -o /subforge ./cmd/server

FROM alpine:3.19

# Install dependencies (try Aliyun mirror, fall back to default)
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories 2>/dev/null; \
    apk --no-cache add ca-certificates tzdata || \
    (sed -i 's/mirrors.aliyun.com/dl-cdn.alpinelinux.org/g' /etc/apk/repositories 2>/dev/null; \
     apk --no-cache add ca-certificates tzdata)

WORKDIR /app
COPY --from=builder /subforge .
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["./docker-entrypoint.sh"]

FROM golang:1.22-alpine AS builder

# Use Chinese Go proxy for faster downloads
ENV GOPROXY=https://goproxy.cn,direct
ENV GO111MODULE=on

WORKDIR /app
COPY go.mod ./
RUN go mod download || true
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o /subforge ./cmd/server

FROM alpine:3.19

# Use Alpine mirrors for China
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app
COPY --from=builder /subforge .
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["./docker-entrypoint.sh"]

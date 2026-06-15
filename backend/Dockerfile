FROM golang:1.25-alpine AS builder

# Go proxy for faster downloads in China
ENV GOPROXY=https://goproxy.cn,https://goproxy.io,direct
ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOOS=linux

WORKDIR /app

# Copy source files
COPY . .

# Generate go.sum and download dependencies
RUN go mod tidy && go mod download

# Build
RUN go build -ldflags="-s -w" -o /subforge ./cmd/server

FROM alpine:3.19

# Install dependencies
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app
COPY --from=builder /subforge .
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["./docker-entrypoint.sh"]

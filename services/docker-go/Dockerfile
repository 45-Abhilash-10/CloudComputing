# syntax=docker/dockerfile:1
# Multi-Arch Dockerfile for MobileNetV2 Go Microservice
# Targets: linux/amd64 and linux/arm64

FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /app
COPY go.mod ./
# Download dependencies if any
RUN go mod download || true

COPY . .

# Compile static binary for target OS/ARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -ldflags="-s -w -extldflags '-static'" \
    -o mobilenet-server .

# Minimal scratch runtime
FROM --platform=$TARGETPLATFORM alpine:3.19

ARG TARGETPLATFORM
LABEL maintainer="Team 3 Benchmark Project"
LABEL description="MobileNetV2 Go Inference Microservice - Lightweight OCI Container"

RUN apk --no-cache add ca-certificates curl

WORKDIR /app
COPY --from=builder /app/mobilenet-server /app/mobilenet-server
RUN mkdir -p /models

ENV LABELS_PATH=/models/imagenet_classes.json
ENV PORT=8081

EXPOSE 8081

HEALTHCHECK --interval=10s --timeout=3s --start-period=3s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

ENTRYPOINT ["/app/mobilenet-server"]

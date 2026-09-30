# syntax=docker/dockerfile:1
# Multi-Arch Dockerfile for MobileNetV2 Python Inference Microservice
# Supports: linux/amd64 (x86_64 AWS EC2) and linux/arm64 (ARM64 Raspberry Pi 4 / Graviton)

FROM --platform=$TARGETPLATFORM python:3.11-slim as builder

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Final runtime image
FROM --platform=$TARGETPLATFORM python:3.11-slim

ARG TARGETPLATFORM
ARG BUILDPLATFORM
LABEL maintainer="Team 3 Benchmark Project"
LABEL description="MobileNetV2 Inference Microservice - Python / OCI Container"

WORKDIR /app

# Copy installed wheels from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# Copy microservice code
COPY app.py /app/app.py
RUN mkdir -p /models

ENV MODEL_PATH=/models/mobilenetv2-12.onnx
ENV LABELS_PATH=/models/imagenet_classes.json
ENV PORT=8082

EXPOSE 8082

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8082/health || exit 1

ENTRYPOINT ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8082", "--workers", "1"]

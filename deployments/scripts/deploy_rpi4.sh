#!/usr/bin/env bash
# Raspberry Pi 4 / AWS Graviton (ARM64) Edge Deployment Script
# Configures ARM64 runtime environments and enables hardware telemetry

set -e

echo "=== Initializing ARM64 Edge Testbed Environment ==="

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    echo "[WARN] Expected aarch64/arm64 architecture, detected: $ARCH"
fi

sudo apt-get update -y
sudo apt-get install -y curl git python3 python3-pip python3-venv \
    build-essential htop vcgencmd linux-tools-generic jq || true

# Docker setup
if ! command -v docker &> /dev/null; then
    echo "Installing Docker for ARM64..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker "$USER"
fi

# Install WasmEdge for aarch64
if ! command -v wasmedge &> /dev/null; then
    echo "Installing WasmEdge on ARM64..."
    curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash
    source "$HOME/.wasmedge/env"
fi

# Install Wasmtime
if ! command -v wasmtime &> /dev/null; then
    echo "Installing Wasmtime on ARM64..."
    curl https://wasmtime.dev/install.sh -sSf | bash
fi

# Install Python requirements
pip3 install --upgrade pip
pip3 install onnxruntime numpy pillow psutil requests

# Enable thermal and frequency governor checks
echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
echo "Max Frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo 'N/A')"

echo "=== ARM64 Edge Testbed Initialized Successfully ==="

#!/usr/bin/env bash
# AWS EC2 c6i (x86_64) Cloud-Init & Deployment Script
# Automatically configures Docker, WasmEdge, Wasmtime, Python, and runs benchmarks

set -e

echo "=== Initializing EC2 x86_64 Testbed Environment ==="

# 1. System updates & package installation
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release \
    git build-essential linux-tools-common linux-tools-generic \
    python3 python3-pip python3-venv htop jq

# 2. Docker installation
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker "$USER"
fi

# 3. WasmEdge installation with WASI-NN
if ! command -v wasmedge &> /dev/null; then
    echo "Installing WasmEdge..."
    curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash -s -- --plugins wasi_nn-onnx
    source "$HOME/.wasmedge/env"
fi

# 4. Wasmtime installation
if ! command -v wasmtime &> /dev/null; then
    echo "Installing Wasmtime..."
    curl https://wasmtime.dev/install.sh -sSf | bash
    export PATH="$HOME/.wasmtime/bin:$PATH"
fi

# 5. Rust and WASI target
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    rustup target add wasm32-wasip1
fi

# 6. Python dependencies
pip3 install --upgrade pip
pip3 install onnxruntime numpy pillow psutil requests matplotlib seaborn

echo "=== EC2 x86_64 Testbed Ready ==="
echo "Host Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"
lscpu | grep "Model name\|CPU(s):"

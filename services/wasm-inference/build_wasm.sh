#!/usr/bin/env bash
# Build script for WebAssembly MobileNetV2 microservice
# Supports wasm32-wasip1 and wasm32-wasi targets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building MobileNetV2 WebAssembly Microservice ==="

TARGET="wasm32-wasip1"

# Check if target is installed
if ! rustup target list | grep -q "$TARGET (installed)"; then
    echo "Adding rust target: $TARGET"
    rustup target add $TARGET || rustup target add wasm32-wasi
fi

echo "Compiling release binary for $TARGET..."
cargo build --target "$TARGET" --release || cargo build --target wasm32-wasi --release

WASM_OUTPUT="target/$TARGET/release/wasm_inference_server.wasm"
if [ ! -f "$WASM_OUTPUT" ]; then
    WASM_OUTPUT="target/wasm32-wasi/release/wasm_inference_server.wasm"
fi

echo "Binary built successfully at: $WASM_OUTPUT"

# Optional optimization with wasm-opt if available
if command -v wasm-opt &> /dev/null; then
    echo "Optimizing with wasm-opt -O3..."
    wasm-opt -O3 "$WASM_OUTPUT" -o "$WASM_OUTPUT.opt"
    mv "$WASM_OUTPUT.opt" "$WASM_OUTPUT"
    echo "Optimized binary size: $(du -h "$WASM_OUTPUT" | cut -f1)"
fi

echo "=== Build Complete ==="

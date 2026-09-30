#!/usr/bin/env bash
# Linux perf stat & systemd timestamp analyzer for MobileNetV2 benchmarks
# Collects hardware performance counters: instructions, cycles, cache misses, energy

set -e

RUNTIME="${1:-native}"
COMMAND="${2:-python3 services/native/run_native.py --bench --iter 10}"
OUTPUT_DIR="${3:-results/raw}"

mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
PERF_OUT="$OUTPUT_DIR/perf_${RUNTIME}_${TIMESTAMP}.txt"

echo "=== Running Hardware Telemetry for: $RUNTIME ==="
echo "Command: $COMMAND"
echo "Target output: $PERF_OUT"

if command -v perf &> /dev/null; then
    perf stat -e \
        instructions,cycles,cache-references,cache-misses,page-faults,context-switches,power/energy-pkg/ \
        -r 3 \
        -o "$PERF_OUT" \
        $COMMAND
    echo "Hardware counters recorded in $PERF_OUT"
    cat "$PERF_OUT"
else
    echo "[WARN] 'perf' tool not installed. Run: sudo apt install linux-tools-common linux-tools-generic"
    echo "Falling back to /usr/bin/time -v..."
    /usr/bin/time -v $COMMAND 2>&1 | tee "$PERF_OUT"
fi

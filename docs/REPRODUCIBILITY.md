# Artifact & Benchmark Reproducibility Guide

This guide provides step-by-step instructions for reproducing all empirical experiments, figures, and academic paper artifacts on local development machines, cloud instances (AWS EC2), and edge devices (Raspberry Pi 4).

---

## 1. Prerequisites & Toolchain Setup

### Minimum Host Requirements
- **Operating Systems:** Linux (Ubuntu 22.04 LTS / Debian 12 recommended), Windows 10/11 with WSL2, or macOS (Darwin).
- **CPUs:** x86_64 or ARM64 (aarch64).
- **RAM:** Minimum 4 GB RAM.

### Required Software Packages
```bash
# Ubuntu / Debian
sudo apt-get update && sudo apt-get install -y \
    python3 python3-pip python3-venv git curl build-essential jq

# Python Requirements
pip3 install onnxruntime numpy pillow psutil requests matplotlib seaborn
```

### Optional Runtimes
- **Docker & Docker Compose:** For running OCI microservices (`docker-compose up`).
- **Rust & WASI:** For compiling the Wasm binary (`rustup target add wasm32-wasip1`).
- **WasmEdge / Wasmtime:**
  ```bash
  # Install WasmEdge
  curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash
  # Install Wasmtime
  curl https://wasmtime.dev/install.sh -sSf | bash
  ```

---

## 2. Step-by-Step Reproduction Workflow

### Step 1: Download Pretrained Models & Test Payloads
Download the canonical MobileNetV2 ONNX model and ImageNet labels:
```bash
python models/download_models.py
```
*Expected output:* Confirms `models/mobilenetv2-12.onnx`, `imagenet_classes.json`, and sample test images (`tabby_cat.jpg`, `golden_retriever.jpg`, `sports_car.jpg`) are ready and validated.

---

### Step 2: Run Microservices

#### Option A: Native Bare-Metal Baselines
```bash
# Python Native Inference Server (Port 8084)
python services/native/run_native.py --server --port 8084

# Go Native Inference Server (Port 8083)
go run services/native/run_native_go.go -server -port 8083
```

#### Option B: Docker Containers via Docker Compose
```bash
cd deployments
docker compose up -d
# docker-go listens on http://localhost:8081
# docker-python listens on http://localhost:8082
```

#### Option C: WebAssembly Inference
```bash
cd services/wasm-inference
bash build_wasm.sh
# Execute directly via WasmEdge CLI
wasmedge target/wasm32-wasip1/release/wasm_inference_server.wasm < ../../models/sample_images/tabby_cat.jpg
```

---

### Step 3: Run the Benchmarking & Telemetry Suite

To run a quick sanity check:
```bash
python benchmarks/runner.py --quick
```

To run individual telemetry profilers:
```bash
# 1. Cold-Start Latency
python benchmarks/telemetry/cold_start.py --trials 3

# 2. Memory Footprint (Idle vs Active)
python benchmarks/telemetry/memory_tracker.py

# 3. CPU Energy Consumption (Joules & Inferences / Joule)
python benchmarks/telemetry/energy_meter.py --inferences 1000

# 4. High-Concurrency Load Testing
python benchmarks/synthetic_load.py --url http://localhost:8081/classify --requests 500 --concurrency 50
```

All master results will be automatically exported to:
- `results/processed/summary.json`
- `results/raw/`

---

### Step 4: Generate Publication Figures
Generate the 6 high-resolution (300 DPI) publication figures:
```bash
python results/generate_charts.py
```
Figures are saved simultaneously to:
- `results/figures/`
- `paper/figures/`
  1. `fig1_cold_start.png`
  2. `fig2_memory_footprint.png`
  3. `fig3_throughput_scaling.png`
  4. `fig4_latency_distributions.png`
  5. `fig5_energy_efficiency.png`
  6. `fig6_tradeoff_radar.png`

---

### Step 5: Launch the Interactive Web Dashboard
You can open `dashboard/index.html` directly in any modern browser:
```bash
# Windows
start dashboard/index.html

# Linux
xdg-open dashboard/index.html

# Or serve via standard HTTP
python -m http.server 8000 --directory dashboard
# Open http://localhost:8000
```

---

### Step 6: Compile the Academic Research Paper
The academic paper is provided in both Markdown (`paper/paper.md`) and standard IEEE conference LaTeX (`paper/paper.tex`):

```bash
cd paper
pdflatex paper.tex
bibtex paper
pdflatex paper.tex
pdflatex paper.tex
```
*Output:* `paper.pdf` ready for conference submission.

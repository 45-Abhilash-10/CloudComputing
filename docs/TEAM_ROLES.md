# Team 3 Work Distribution & Member Roles

**Project Title:** Empirical Cross-Architecture Benchmark: WebAssembly Runtimes vs. OCI Containers for Edge-Cloud AI Inference  
**Team Name:** Team 3 (4 Students)  
**Course:** Advanced Cloud Computing & Systems Architecture  

---

## Executive Role Allocation Summary

To ensure rigorous execution and balanced contribution, each of the four team members assumed leadership over a core architectural domain while participating in cross-functional peer reviews and integration testing:

| Member | Primary Role | Core Ownership & Deliverables |
|---|---|---|
| **Student 1** | **Systems Architect & Team Lead** | Wasm Runtime Engineering, Rust Microservice, WASI-NN Integration, Multi-Arch Pipelines |
| **Student 2** | **Cloud & Container Infrastructure Lead** | Docker Go & Python Services, Multi-Stage OCI Builds, AWS EC2 & RPi4 Deployments, K3s runwasi |
| **Student 3** | **Benchmarking & Telemetry Engineer** | Telemetry Suite (Cold Start, Memory Tracker, Energy in Joules RAPL), k6/JMeter Load Tests |
| **Student 4** | **Data Analyst, Visualization & Research Lead** | Statistical Data Aggregation, Interactive Web Dashboard, Academic Paper (Markdown & LaTeX) |

---

## Detailed Member Responsibilities & Deliverables

### Student 1: Systems Architect & WebAssembly Engineer
- **Responsibilities:**
  - Led the overall software architecture and design of the empirical benchmarking harness.
  - Implemented the high-performance Rust WebAssembly microservice (`services/wasm-inference/`).
  - Implemented zero-dependency planar tensor preprocessing (`preprocess.rs`) matching ImageNet normalization standards.
  - Authored the WebAssembly build pipeline (`services/wasm-inference/build_wasm.sh`) targeting `wasm32-wasip1` with `wasm-opt -O3` binary stripping.
  - Configured WasmEdge and Wasmtime execution harnesses with AOT and Cranelift JIT compiler flags.
- **Key Code Deliverables:**
  - `services/wasm-inference/Cargo.toml`
  - `services/wasm-inference/src/main.rs`
  - `services/wasm-inference/src/preprocess.rs`
  - `services/wasm-inference/src/labels.rs`
  - `services/wasm-inference/build_wasm.sh`

---

### Student 2: Containerization & Cloud Infrastructure Lead
- **Responsibilities:**
  - Designed and implemented the containerized Go microservice (`services/docker-go/main.go`, `model.go`).
  - Designed and implemented the standard enterprise Python FastAPI microservice with ONNX Runtime (`services/docker-python/app.py`).
  - Built optimized multi-stage Dockerfiles utilizing Alpine Linux and Debian Slim.
  - Configured Docker Buildx multi-arch pipeline (`deployments/scripts/build_multiarch.sh`) targeting `linux/amd64` and `linux/arm64`.
  - Authored automated cloud-init provisioning scripts for AWS EC2 c6i.xlarge (`deploy_ec2.sh`) and Raspberry Pi 4 Model B (`deploy_rpi4.sh`).
  - Formulated Kubernetes `RuntimeClass` and containerd shim specification (`deployments/wasm-edge-oci.yaml`).
- **Key Code Deliverables:**
  - `services/docker-go/` (main.go, model.go, Dockerfile, go.mod)
  - `services/docker-python/` (app.py, Dockerfile, requirements.txt)
  - `deployments/docker-compose.yml`, `docker-compose.arm64.yml`, `docker-compose.x86_64.yml`
  - `deployments/wasm-edge-oci.yaml`
  - `deployments/scripts/` (build_multiarch.sh, deploy_ec2.sh, deploy_rpi4.sh)

---

### Student 3: Benchmarking & Telemetry Instrumentation Engineer
- **Responsibilities:**
  - Engineered the high-resolution cold-start latency profiler (`benchmarks/telemetry/cold_start.py`).
  - Implemented the Linux procfs and psutil Resident Set Size (RSS) and Virtual Memory Size (VMS) memory tracker (`memory_tracker.py`).
  - Designed the dynamic CPU energy measurement tool (`energy_meter.py`) leveraging Intel RAPL (`/sys/class/powercap`) and physical hardware power models.
  - Built the staged k6 load testing suite (`benchmarks/k6/load_test.js`) and configurations for 100, 1,000, and 10,000 concurrent Virtual Users.
  - Implemented the Apache JMeter benchmark test plan (`benchmarks/jmeter/mobilenetv2_benchmark.jmx`).
  - Developed the native Python and Go uncontained execution baselines (`services/native/`).
- **Key Code Deliverables:**
  - `benchmarks/telemetry/cold_start.py`
  - `benchmarks/telemetry/memory_tracker.py`
  - `benchmarks/telemetry/energy_meter.py`
  - `benchmarks/telemetry/perf_telemetry.sh`
  - `benchmarks/k6/` (load_test.js, config_100vu.json, config_1000vu.json, config_10000vu.json)
  - `benchmarks/jmeter/mobilenetv2_benchmark.jmx`
  - `benchmarks/synthetic_load.py`
  - `services/native/run_native.py` and `services/native/run_native_go.go`

---

### Student 4: Data Analytics, Visualization & Research Lead
- **Responsibilities:**
  - Built the master benchmark orchestrator CLI (`benchmarks/runner.py`) aggregating telemetry into canonical JSON datasets.
  - Created publication-quality chart generation script (`results/generate_charts.py`) producing high-resolution (300 DPI) figures.
  - Designed and developed the modern dark-mode, glassmorphic interactive web dashboard (`dashboard/index.html`, `styles.css`, `app.js`).
  - Built the live inference playground enabling real-time interactive testing and top-5 ImageNet classification visualizations.
  - Primary author of the academic research paper in both IEEE conference LaTeX format (`paper/paper.tex`, `references.bib`) and Markdown (`paper/paper.md`).
  - Authored comprehensive documentation (`docs/METRICS_EXPLAINED.md`, `docs/REPRODUCIBILITY.md`, `README.md`).
- **Key Code Deliverables:**
  - `benchmarks/runner.py`
  - `results/generate_charts.py`
  - `results/figures/` and `paper/figures/` (fig1 to fig6)
  - `dashboard/` (index.html, styles.css, app.js)
  - `paper/paper.md`, `paper/paper.tex`, `paper/references.bib`
  - `docs/METRICS_EXPLAINED.md`, `docs/REPRODUCIBILITY.md`, `docs/ARCHITECTURE.md`

---

## Collaboration & Peer Review Protocol
- **Git Commit Workflow:** Feature branch development with mandatory two-person code reviews before merging into the main branch.
- **Data Validation:** Every empirical data point was validated independently on both simulated development hosts and physical hardware targets.
- **Writing Process:** All four students contributed technical subsections to the academic paper and reviewed the final LaTeX manuscript prior to submission.

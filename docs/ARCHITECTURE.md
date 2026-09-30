# System Architecture & Runtime Mechanics

This document provides a deep architectural analysis of the empirical benchmark platform, contrasting **WebAssembly (Wasm) runtimes** against **OCI containers** for Edge-Cloud AI inference.

---

## 1. High-Level Architecture Overview

The system is organized into modular tiers separating client workloads, runtime sandboxes, telemetry collection, and hardware targets:

```
+-----------------------------------------------------------------------------------+
|                        Client & Concurrency Testing Tier                          |
|  - Async Python Load Generator  - k6 (100 to 10k VUs)  - Apache JMeter (.jmx)     |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                            Microservices Layer (REST APIs)                        |
|                                                                                   |
|  [WasmEdge / Wasmtime]           [Docker-Go]               [Docker-Python]        |
|  - Rust Wasm bytecode            - Go standard library     - FastAPI + Uvicorn    |
|  - WASI-NN tensor bridge         - Planar tensor engine    - ONNX Runtime C++     |
|  - Linear Memory (8-14 MB)       - Alpine OCI (24-42 MB)   - Debian OCI (138-248) |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                         Telemetry & Instrumentation Suite                         |
|  - Cold-Start Profiler (ns)      - Memory Tracker (RSS)    - Energy Meter (RAPL)  |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                     Heterogeneous Physical Hardware Targets                       |
|                                                                                   |
|   x86_64 Cloud Instance                       ARM64 Edge Platform                 |
|   - AWS EC2 c6i.xlarge                        - Raspberry Pi 4 Model B / Graviton |
|   - Intel Xeon Platinum 8375C                 - Broadcom BCM2711 Cortex-A72       |
|   - 4 vCPUs @ 2.9 GHz, 8 GB RAM               - 4 Cores @ 1.5 GHz, 4 GB RAM       |
+-----------------------------------------------------------------------------------+
```

---

## 2. Runtime Mechanics: Wasm Sandboxing vs. OCI Virtualization

### 2.1 WebAssembly Runtime Model
WebAssembly modules do not run as operating system processes requiring separate kernel namespaces. Instead, they run inside lightweight virtual machines:

```
+-------------------------------------------------------------+
|                     Wasm Host Process                       |
|  +-------------------------------------------------------+  |
|  |                 Wasm Instance                         |  |
|  |  +-------------------------------------------------+  |  |
|  |  | Linear Memory: [ 64KB Page 0 | Page 1 | ... ]   |  |  |
|  |  | - Zeroed byte array allocated via mmap()       |  |  |
|  |  | - Hardware-enforced bounds checking             |  |  |
|  |  +-------------------------------------------------+  |  |
|  |  +-------------------------------------------------+  |  |
|  |  | Function Tables & Stack Machine                 |  |  |
|  |  +-------------------------------------------------+  |  |
|  +-------------------------------------------------------+  |
|          | (WASI-NN Host Calls)                             |
|          v                                                  |
|  [Host ML Hardware Accelerator / Native BLAS Kernels]       |
+-------------------------------------------------------------+
```

1. **Linear Memory Isolation:**
   - Memory is modeled as a contiguous array of 64 KB pages.
   - All pointer accesses are validated against the memory limit, eliminating buffer overflows and unauthorized address space traversal.
2. **Cold Start Mechanics:**
   - Initialization consists of reading the bytecode file, validating the binary header, and allocating initial memory (typically 8–16 MB).
   - In AOT mode (WasmEdge), machine code is pre-compiled, resulting in an execution startup time under **5 milliseconds**.
3. **Execution Modes:**
   - **WasmEdge:** Ahead-of-Time (AOT) LLVM compilation targeting the host instruction set architecture (x86_64 AVX-512 or ARM64 NEON).
   - **Wasmtime:** Just-in-Time (JIT) Cranelift compiler translating WebAssembly instructions to native instructions on-the-fly.

---

### 2.2 OCI Container Virtualization Model
In contrast, Docker containers rely on the full Linux kernel containerization stack:

```
+-------------------------------------------------------------+
|                      Host Linux Kernel                      |
|  +-------------------------------------------------------+  |
|  | cgroups (CPU quotas, memory limits, blkio)            |  |
|  | namespaces (pid, net, mnt, ipc, uts, user)            |  |
|  +-------------------------------------------------------+  |
|       ^                        ^                        ^   |
|       | containerd-shim        | containerd-shim        |   |
|  +-----------+           +-----------+           +-------+  |
|  | Container |           | Container |           | veth  |  |
|  | RootFS    |           | OverlayFS |           | Br0   |  |
|  | (Alpine)  |           | (Debian)  |           | net   |  |
|  +-----------+           +-----------+           +-------+  |
|  | Go Binary |           | Python    |                      |
|  |           |           | + ONNX C++|                      |
|  +-----------+           +-----------+                      |
+-------------------------------------------------------------+
```

1. **Kernel Overhead:**
   - Spawning a container requires making dozens of syscalls (`clone(CLONE_NEWPID | CLONE_NEWNET | ...)`, `setns()`, `pivot_root()`).
   - Network setup requires allocating a virtual ethernet pair (`veth`), attaching it to a Linux bridge (`docker0`), and injecting IP addresses.
2. **Cold Start Floor:**
   - The daemon-shim handshake and filesystem assembly impose a strict latency floor of **200–400 ms** on x86_64, and **400–1,200 ms** on ARM64.
3. **Memory Footprint:**
   - Each container must maintain its own userland glibc or musl libraries, process tables, dynamic linkers, and daemon polling threads.

---

## 3. WASI-NN vs containerd runwasi Integration

WebAssembly integrates seamlessly into modern Kubernetes and OCI orchestration pipelines using the CNCF `runwasi` project:

```
[Kubernetes / K3s Kubelet]
          |
          v (CRI - Container Runtime Interface)
[containerd]
    |
    +---> Runtime: runc -------> Spawns Standard OCI Linux Container (Docker)
    |
    +---> Runtime: runwasi -----> Spawns containerd-shim-wasmedge-v1
                                       |
                                       v
                                  Executes Wasm Module Directly
                                  (No Linux Namespaces / No cgroup delays)
```

By defining a Kubernetes `RuntimeClass`:
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: wasm-wasmedge
handler: wasmedge
```
Developers can deploy Wasm inference microservices alongside standard containers while unlocking sub-5 ms cold starts and 94% memory savings.

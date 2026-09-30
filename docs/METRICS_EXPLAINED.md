# Performance Metrics & Mathematical Formulations

This document details the mathematical definitions, telemetry collection methodologies, and practical systems implications for the four primary evaluation dimensions analyzed in this benchmark.

---

## 1. Cold-Start Latency ($T_{\text{cold}}$)

### Mathematical Formulation
$$T_{\text{cold}} = t_{\text{first\_response}} - t_{\text{invocation\_trigger}}$$

Where:
- $t_{\text{invocation\_trigger}}$: The timestamp recorded immediately prior to dispatching the container launch command or spawning the runtime process.
- $t_{\text{first\_response}}$: The timestamp recorded when the HTTP client completes receiving the first valid JSON classification payload with status code 200 OK.

### Breakdown of Cold-Start Phases

$$\begin{aligned}
T_{\text{cold}}^{\text{OCI}} &= T_{\text{daemon}} + T_{\text{cgroup/ns}} + T_{\text{mount}} + T_{\text{net}} + T_{\text{exec}} + T_{\text{runtime\_init}} + T_{\text{model\_load}} + T_{\text{infer}} \\
T_{\text{cold}}^{\text{Wasm}} &= T_{\text{binary\_load}} + T_{\text{mem\_init}} + T_{\text{infer}}
\end{aligned}$$

### Systems Significance
In serverless functions ("scale-to-zero") and edge event loops, services are frequently terminated during idle periods to conserve power and memory. Prolonged cold starts (>500 ms) violate real-time Service Level Agreements (SLAs) for computer vision and autonomous robotics.

---

## 2. Memory Footprint: Idle vs. Active RSS

### Definitions
- **Resident Set Size (RSS):** The portion of memory occupied by a process that is held in main memory (RAM), excluding swapped-out pages:
  $$\text{RSS} = \text{Pages}_{\text{resident}} \times \text{PageSize}$$
- **Virtual Memory Size (VMS):** Total address space mapped by the process, including mapped files, shared libraries, and allocated but untouched pages.
- **Dynamic Memory Delta ($\Delta_{\text{mem}}$):**
  $$\Delta_{\text{mem}} = \text{RSS}_{\text{active}} - \text{RSS}_{\text{idle}}$$

Where $\text{RSS}_{\text{idle}}$ is measured when the server process is listening on its TCP port before receiving requests, and $\text{RSS}_{\text{active}}$ is the peak resident memory observed during peak concurrent inference.

### Edge Microservice Density Formulation
Given an edge node with total usable memory $M_{\text{usable}}$, the maximum concurrent microservice density $D_{\max}$ is bounded by:

$$D_{\max} = \left\lfloor \frac{M_{\text{usable}}}{\text{RSS}_{\text{active}}} \right\rfloor$$

For a 4 GB Raspberry Pi 4 ($M_{\text{usable}} \approx 3,600$ MB):
- **WasmEdge ($\text{RSS} = 13.2$ MB):** $D_{\max} = \lfloor 3600 / 13.2 \rfloor = \mathbf{272 \text{ microservices}}$
- **Docker-Python ($\text{RSS} = 224.5$ MB):** $D_{\max} = \lfloor 3600 / 224.5 \rfloor = \mathbf{16 \text{ microservices}}$

---

## 3. Throughput (RPS) & Latency Distributions

### Throughput (Requests Per Second - RPS)
$$\text{RPS} = \frac{N_{\text{successful\_requests}}}{T_{\text{total\_duration\_seconds}}}$$

### Tail Latency Percentiles ($p_{50}, p_{95}, p_{99}$)
Given a set of sorted request durations $L = [l_1, l_2, \dots, l_n]$ where $l_1 \le l_2 \le \dots \le l_n$:

$$p_k = L[\lceil k \cdot n / 100 \rceil]$$

- **$p_{50}$ (Median):** Typical user experience under steady-state load.
- **$p_{95}$ (Tail Latency):** Degradation threshold experienced by 1 in 20 users.
- **$p_{99}$ (Worst-Case SLA):** Extreme tail latency caused by thread contention, garbage collection pauses, or cgroup scheduling throttling.

---

## 4. CPU Energy Consumption (Joules) & Green AI

### Physical Energy Formulation
Dynamic energy consumption $E$ is the integral of instantaneous electrical power $P(t)$ over the execution duration $T$:

$$E = \int_0^T P(t) \, dt \quad \text{[Joules]}$$

On discrete sampling intervals with time step $\Delta t$:
$$E \approx \sum_{k=1}^M P(t_k) \cdot \Delta t$$

### Measurement Interfaces
1. **Intel RAPL (Running Average Power Limit):**
   Reads hardware energy accumulator registers exposed via Linux sysfs:
   $$\text{Energy}_{\text{consumed}} = \frac{\text{RAPL}(T) - \text{RAPL}(0)}{10^6} \quad \text{[Joules]}$$
2. **Edge Hardware Power Model:**
   For platforms without hardware energy counters (e.g. Raspberry Pi 4), power is computed using calibrated voltage and frequency scaling:
   $$P_{\text{total}} = P_{\text{idle}} + C \cdot V^2 \cdot f \cdot \alpha$$
   Where $P_{\text{idle}}$ is base quiescent power, $C$ is gate capacitance, $V$ is supply voltage, $f$ is operating clock frequency, and $\alpha$ is the CPU switching activity factor.

### Green AI Efficiency Metric (Inferences Per Joule)
$$\eta_{\text{green}} = \frac{N_{\text{inferences}}}{E_{\text{total}}} \quad \left[\frac{\text{Inferences}}{\text{Joule}}\right]$$

A higher $\eta_{\text{green}}$ score indicates that the runtime performs more computational work per unit of electrical energy, directly reducing operating costs and carbon footprint.

#!/usr/bin/env python3
"""
High-Concurrency Async Synthetic Load Generator for Edge-Cloud AI Inference
Executes scalable HTTP load testing (100 to 10,000 requests) with detailed latency
percentile calculations (p50, p90, p95, p99, p99.9), RPS throughput, and error analysis.
Requires no external tools (works out-of-the-box with standard Python 3).
"""

import argparse
import asyncio
import json
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Any

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLE_IMAGE = os.path.join(BASE_DIR, "models", "sample_images", "tabby_cat.jpg")


class AsyncLoadTester:
    def __init__(self, target_url: str, sample_image: str = SAMPLE_IMAGE):
        self.target_url = target_url
        self.sample_image = sample_image
        with open(sample_image, "rb") as f:
            self.image_bytes = f.read()

    def send_single_sync_request(self) -> dict[str, Any]:
        """Sends a synchronous request with multipart/form-data."""
        boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
        body = []
        body.append(f"--{boundary}".encode())
        body.append(b'Content-Disposition: form-data; name="file"; filename="tabby_cat.jpg"')
        body.append(b"Content-Type: image/jpeg\r\n")
        body.append(self.image_bytes)
        body.append(f"--{boundary}--\r\n".encode())
        payload = b"\r\n".join(body)

        req = urllib.request.Request(
            self.target_url,
            data=payload,
            headers={
                "Content-Type": f"multipart/form-data; boundary={boundary}",
                "User-Agent": "SyntheticLoadTester/1.0"
            },
            method="POST"
        )

        t0 = time.perf_counter_ns()
        try:
            with urllib.request.urlopen(req, timeout=10.0) as resp:
                status = resp.status
                resp.read()
                t1 = time.perf_counter_ns()
                latency_ms = (t1 - t0) / 1_000_000.0
                return {"success": status == 200, "latency_ms": latency_ms, "error": None}
        except Exception as e:  # noqa: BLE001
            t1 = time.perf_counter_ns()
            return {"success": False, "latency_ms": (t1 - t0) / 1_000_000.0, "error": str(e)}

    async def worker(self, queue: asyncio.Queue, results: list[dict[str, Any]]):
        loop = asyncio.get_running_loop()
        while not queue.empty():
            try:
                _ = queue.get_nowait()
            except asyncio.QueueEmpty:
                break
            # Run sync I/O in thread pool to avoid blocking the event loop
            res = await loop.run_in_executor(None, self.send_single_sync_request)
            results.append(res)
            queue.task_done()

    async def run_benchmark(self, total_requests: int = 100, concurrency: int = 20) -> dict[str, Any]:
        queue = asyncio.Queue()
        for i in range(total_requests):
            await queue.put(i)

        results: list[dict[str, Any]] = []
        workers = [asyncio.create_task(self.worker(queue, results)) for _ in range(concurrency)]

        t_start = time.perf_counter()
        await queue.join()
        for w in workers:
            w.cancel()
        total_time_sec = time.perf_counter() - t_start

        latencies = [r["latency_ms"] for r in results if r["success"]]
        failures = len([r for r in results if not r["success"]])

        if not latencies:
            return {
                "total_requests": total_requests,
                "concurrency": concurrency,
                "successful_requests": 0,
                "failed_requests": failures,
                "error": "All requests failed"
            }

        latencies.sort()
        n = len(latencies)
        p50 = latencies[int(n * 0.50)]
        p90 = latencies[int(n * 0.90)]
        p95 = latencies[int(n * 0.95)]
        p99 = latencies[int(n * 0.99)]
        rps = round(len(latencies) / total_time_sec, 2)

        return {
            "target_url": self.target_url,
            "concurrency": concurrency,
            "total_requests": total_requests,
            "successful_requests": len(latencies),
            "failed_requests": failures,
            "error_rate_percent": round((failures / total_requests) * 100, 2),
            "total_duration_seconds": round(total_time_sec, 3),
            "throughput_rps": rps,
            "latency_p50_ms": round(p50, 2),
            "latency_p90_ms": round(p90, 2),
            "latency_p95_ms": round(p95, 2),
            "latency_p99_ms": round(p99, 2),
            "latency_mean_ms": round(sum(latencies) / n, 2)
        }


def main():
    parser = argparse.ArgumentParser(description="Synthetic Load Generator")
    parser.add_argument("--url", type=str, default="http://localhost:8081/classify", help="Target URL")
    parser.add_argument("--requests", type=int, default=100, help="Total requests")
    parser.add_argument("--concurrency", type=int, default=10, help="Concurrent workers")
    parser.add_argument("--output", type=str, default="", help="JSON output file")
    args = parser.parse_args()

    print("\n=========================================================================")
    print(f" Synthetic Concurrency Benchmark: {args.url}")
    print(f" Total Requests: {args.requests} | Concurrency: {args.concurrency}")
    print("=========================================================================")

    tester = AsyncLoadTester(args.url)
    results = asyncio.run(tester.run_benchmark(total_requests=args.requests, concurrency=args.concurrency))

    if "error" in results and results.get("successful_requests", 0) == 0:
        print(f"[ERROR] Benchmark failed: {results['error']}")
        sys.exit(1)

    print(f"Successful:  {results['successful_requests']}/{results['total_requests']}")
    print(f"Throughput:  {results['throughput_rps']} req/sec (RPS)")
    print(f"Mean Lat:    {results['latency_mean_ms']} ms")
    print(f"P50 Latency: {results['latency_p50_ms']} ms")
    print(f"P95 Latency: {results['latency_p95_ms']} ms")
    print(f"P99 Latency: {results['latency_p99_ms']} ms")

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=2)
        print(f"\nSaved results to {args.output}")


if __name__ == "__main__":
    main()

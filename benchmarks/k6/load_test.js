import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// Custom Prometheus/Grafana compatible metrics
const inferenceLatency = new Trend('inference_latency_ms', true);
const preprocessLatency = new Trend('preprocess_latency_ms', true);
const errorRate = new Rate('inference_errors');
const inferenceCounter = new Counter('total_inferences');

// Binary sample image embedded in virtual users memory
const sampleImage = open('../../models/sample_images/tabby_cat.jpg', 'b');

export const options = {
  scenarios: {
    stress_ramp_up: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '15s', target: 100 },   // Warmup to 100 VUs
        { duration: '30s', target: 500 },   // Scale to 500 VUs
        { duration: '30s', target: 1000 },  // Scale to 1,000 VUs
        { duration: '20s', target: 2000 },  // Burst to 2,000 VUs
        { duration: '15s', target: 0 },     // Cooldown
      ],
      gracefulRampDown: '5s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'], // <1% errors
    http_req_duration: ['p(95)<250', 'p(99)<500'], // 95% of requests under 250ms
  },
};

const TARGET_URL = __ENV.TARGET_URL || 'http://localhost:8081/classify';

export default function () {
  const data = {
    file: http.file(sampleImage, 'tabby_cat.jpg', 'image/jpeg'),
  };

  const params = {
    headers: {
      'User-Agent': 'k6-edge-cloud-benchmark/1.0',
    },
    timeout: '10s',
  };

  const res = http.post(TARGET_URL, data, params);
  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'has predictions': (r) => r.body && r.body.includes('predictions'),
  });

  if (success) {
    inferenceCounter.add(1);
    try {
      const json = JSON.parse(res.body);
      if (json.telemetry && json.telemetry.inference_time_ms) {
        inferenceLatency.add(json.telemetry.inference_time_ms);
      }
      if (json.telemetry && json.telemetry.preprocess_time_ms) {
        preprocessLatency.add(json.telemetry.preprocess_time_ms);
      }
    } catch (e) {
      // Body parse fallback
    }
  } else {
    errorRate.add(1);
  }

  sleep(0.05); // 50ms pacing between client iterations
}

// k6 Load Test: Health Check Endpoint
// This tests the /health endpoint under various load conditions

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const healthCheckDuration = new Trend('health_check_duration');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp up to 50 users
    { duration: '1m', target: 100 },   // Ramp up to 100 users
    { duration: '3m', target: 100 },   // Stay at 100 users
    { duration: '30s', target: 200 },  // Spike to 200 users
    { duration: '1m', target: 200 },   // Stay at 200 users
    { duration: '30s', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'], // 95% < 500ms, 99% < 1s
    http_req_failed: ['rate<0.01'],                  // < 1% errors
    errors: ['rate<0.01'],                           // < 1% custom errors
    http_reqs: ['rate>50'],                          // > 50 RPS minimum
  },
};

// Environment variables
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  const res = http.get(`${BASE_URL}/health`);

  // Record custom metric
  healthCheckDuration.add(res.timings.duration);

  // Checks
  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
    'response has status field': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status !== undefined;
      } catch (e) {
        return false;
      }
    },
    'status is healthy': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status === 'healthy';
      } catch (e) {
        return false;
      }
    },
  });

  errorRate.add(!success);

  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'health-check-results.json': JSON.stringify(data),
  };
}

function textSummary(data, options) {
  const indent = options.indent || '';
  const enableColors = options.enableColors || false;

  let summary = `
${indent}📊 Load Test Results: Health Check
${indent}${'='.repeat(50)}
${indent}
${indent}Duration: ${data.state.testRunDurationMs / 1000}s
${indent}Iterations: ${data.metrics.iterations.values.count}
${indent}VUs (max): ${data.metrics.vus_max.values.value}
${indent}
${indent}HTTP Requests:
${indent}  Total: ${data.metrics.http_reqs.values.count}
${indent}  Rate: ${data.metrics.http_reqs.values.rate.toFixed(2)} req/s
${indent}  Failed: ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%
${indent}
${indent}Response Times:
${indent}  P50: ${data.metrics.http_req_duration.values['p(50)'].toFixed(2)}ms
${indent}  P95: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms
${indent}  P99: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms
${indent}  Max: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms
${indent}
${indent}Custom Metrics:
${indent}  Error Rate: ${(data.metrics.errors.values.rate * 100).toFixed(2)}%
${indent}
`;

  return summary;
}

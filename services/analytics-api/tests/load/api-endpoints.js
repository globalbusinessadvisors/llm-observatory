// k6 Load Test: API Endpoints
// This tests various API endpoints under realistic load conditions

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const apiLatency = new Trend('api_latency');
const requestCounter = new Counter('request_count');

// Test configuration
export const options = {
  stages: [
    { duration: '1m', target: 50 },   // Ramp up to 50 users
    { duration: '3m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 150 },  // Ramp up to 150 users
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
    errors: ['rate<0.01'],
    http_reqs: ['rate>100'],
  },
};

// Environment variables
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const API_TOKEN = __ENV.API_TOKEN || 'test-token';

export default function () {
  const headers = {
    'Authorization': `Bearer ${API_TOKEN}`,
    'Content-Type': 'application/json',
  };

  // Test Health Endpoint
  group('Health Check', function () {
    const res = http.get(`${BASE_URL}/health`);
    requestCounter.add(1);
    apiLatency.add(res.timings.duration);

    const success = check(res, {
      'health status is 200': (r) => r.status === 200,
      'health response time < 100ms': (r) => r.timings.duration < 100,
    });

    errorRate.add(!success);
  });

  sleep(1);

  // Test Traces Endpoint
  group('List Traces', function () {
    const res = http.get(`${BASE_URL}/api/v1/traces?limit=50`, { headers });
    requestCounter.add(1);
    apiLatency.add(res.timings.duration);

    const success = check(res, {
      'traces status is 200 or 401': (r) => r.status === 200 || r.status === 401,
      'traces response time < 500ms': (r) => r.timings.duration < 500,
    });

    errorRate.add(!success);
  });

  sleep(1);

  // Test Metrics Endpoint
  group('Get Metrics', function () {
    const startTime = new Date(Date.now() - 86400000).toISOString(); // 24h ago
    const endTime = new Date().toISOString();

    const res = http.get(
      `${BASE_URL}/api/v1/metrics/analytics?start_time=${startTime}&end_time=${endTime}`,
      { headers }
    );
    requestCounter.add(1);
    apiLatency.add(res.timings.duration);

    const success = check(res, {
      'metrics status is 200 or 401': (r) => r.status === 200 || r.status === 401,
      'metrics response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    errorRate.add(!success);
  });

  sleep(2);

  // Test Cost Analytics Endpoint
  group('Cost Analytics', function () {
    const startTime = new Date(Date.now() - 604800000).toISOString(); // 7 days ago
    const endTime = new Date().toISOString();

    const res = http.get(
      `${BASE_URL}/api/v1/costs/analytics?start_time=${startTime}&end_time=${endTime}&group_by=model`,
      { headers }
    );
    requestCounter.add(1);
    apiLatency.add(res.timings.duration);

    const success = check(res, {
      'costs status is 200 or 401': (r) => r.status === 200 || r.status === 401,
      'costs response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    errorRate.add(!success);
  });

  sleep(2);
}

export function handleSummary(data) {
  console.log('\n📊 Load Test Results: API Endpoints');
  console.log('='.repeat(60));
  console.log(`Duration: ${data.state.testRunDurationMs / 1000}s`);
  console.log(`Total Requests: ${data.metrics.request_count.values.count}`);
  console.log(`Request Rate: ${data.metrics.http_reqs.values.rate.toFixed(2)} req/s`);
  console.log(`Failed Requests: ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%`);
  console.log('\nResponse Times:');
  console.log(`  P50: ${data.metrics.http_req_duration.values['p(50)'].toFixed(2)}ms`);
  console.log(`  P95: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms`);
  console.log(`  P99: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms`);
  console.log(`  Max: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms`);
  console.log('\nCustom Metrics:');
  console.log(`  Error Rate: ${(data.metrics.errors.values.rate * 100).toFixed(2)}%`);
  console.log('='.repeat(60));

  return {
    'api-endpoints-results.json': JSON.stringify(data, null, 2),
  };
}

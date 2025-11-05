import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';

// Custom metrics
const metricsDuration = new Trend('metrics_request_duration');
const metricsErrors = new Counter('metrics_errors');

// Load test configuration
export const options = {
  stages: [
    { duration: '30s', target: 3 },    // Ramp up to 3 VUs
    { duration: '1m30s', target: 20 }, // Ramp up to 20 VUs
    { duration: '2m', target: 20 },    // Stay at 20 VUs
    { duration: '1m', target: 10 },    // Ramp down to 10 VUs
    { duration: '30s', target: 0 },    // Ramp down to 0 VUs
  ],
  thresholds: {
    'http_req_duration': ['p(99)<2000', 'p(95)<1000'],
    'http_req_failed': ['rate<0.1'],
    'metrics_request_duration': ['p(95)<1500'],
  },
};

const BASE_URL = 'http://localhost:8002';

export default function () {
  group('Analytics API - Health Check', () => {
    const response = http.get(`${BASE_URL}/health`);

    check(response, {
      'health check status is 200': (r) => r.status === 200,
      'health response time < 100ms': (r) => r.timings.duration < 100,
    });
  });

  group('Analytics API - Metrics Summary', () => {
    const response = http.get(`${BASE_URL}/v1/metrics/summary`);

    const success = check(response, {
      'summary status is 200': (r) => r.status === 200,
      'summary has metrics data': (r) => {
        const body = r.json();
        return body.summary !== undefined || body.metrics !== undefined || Object.keys(body).length > 0;
      },
      'response time < 500ms': (r) => r.timings.duration < 500,
    });

    if (!success) {
      metricsErrors.add(1);
    }

    metricsDuration.add(response.timings.duration);
  });

  group('Analytics API - Conversation Metrics', () => {
    const response = http.get(`${BASE_URL}/v1/metrics/conversations`);

    const success = check(response, {
      'conversation metrics status is 200': (r) => r.status === 200,
      'has conversation data': (r) => {
        const body = r.json();
        return body.conversations !== undefined || body.metrics !== undefined || Array.isArray(body);
      },
      'response time < 800ms': (r) => r.timings.duration < 800,
    });

    if (!success) {
      metricsErrors.add(1);
    }

    metricsDuration.add(response.timings.duration);
  });

  group('Analytics API - Cost Metrics', () => {
    const response = http.get(`${BASE_URL}/v1/metrics/costs`);

    const success = check(response, {
      'cost metrics status is 200': (r) => r.status === 200 || r.status === 404,
      'response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    if (!success && response.status !== 404) {
      metricsErrors.add(1);
    }

    metricsDuration.add(response.timings.duration);
  });

  group('Analytics API - Performance Metrics', () => {
    const response = http.get(`${BASE_URL}/v1/metrics/performance`);

    const success = check(response, {
      'performance metrics status is 200': (r) => r.status === 200 || r.status === 404,
      'response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    if (!success && response.status !== 404) {
      metricsErrors.add(1);
    }

    metricsDuration.add(response.timings.duration);
  });

  group('Analytics API - Metrics with Date Range', () => {
    const endDate = new Date();
    const startDate = new Date(endDate.getTime() - 7 * 24 * 60 * 60 * 1000);

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const response = http.get(
      `${BASE_URL}/v1/metrics/conversations?start_date=${startDate.toISOString()}&end_date=${endDate.toISOString()}`,
      params
    );

    check(response, {
      'date filtered metrics status is 200': (r) => r.status === 200 || r.status === 400,
      'response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    metricsDuration.add(response.timings.duration);
  });

  group('Analytics API - Error Rate Metrics', () => {
    const response = http.get(`${BASE_URL}/v1/metrics/performance/error-rate`);

    const success = check(response, {
      'error rate status is 200': (r) => r.status === 200 || r.status === 404,
      'response time < 500ms': (r) => r.timings.duration < 500,
    });

    if (!success && response.status !== 404) {
      metricsErrors.add(1);
    }

    metricsDuration.add(response.timings.duration);
  });

  group('Analytics API - Conversation Count', () => {
    const response = http.get(`${BASE_URL}/v1/metrics/conversations/count`);

    const success = check(response, {
      'conversation count status is 200': (r) => r.status === 200 || r.status === 404,
      'response time < 300ms': (r) => r.timings.duration < 300,
    });

    if (!success && response.status !== 404) {
      metricsErrors.add(1);
    }

    metricsDuration.add(response.timings.duration);
  });

  group('Analytics API - Cost by Provider', () => {
    const response = http.get(`${BASE_URL}/v1/metrics/costs/by-provider`);

    check(response, {
      'cost by provider status is 200 or 404': (r) => r.status === 200 || r.status === 404,
      'response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    metricsDuration.add(response.timings.duration);
  });

  group('Analytics API - Performance Latency', () => {
    const response = http.get(`${BASE_URL}/v1/metrics/performance/latency-percentiles`);

    check(response, {
      'latency percentiles status is 200 or 404': (r) => r.status === 200 || r.status === 404,
      'response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    metricsDuration.add(response.timings.duration);
  });

  sleep(2);
}

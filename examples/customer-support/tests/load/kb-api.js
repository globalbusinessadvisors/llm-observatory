import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Custom metrics
const searchDuration = new Trend('search_duration');
const searchErrors = new Counter('search_errors');
const listDocErrors = new Counter('list_documents_errors');
const listDocDuration = new Trend('list_documents_duration');

// Load test configuration
export const options = {
  stages: [
    { duration: '30s', target: 5 },    // Ramp up to 5 VUs
    { duration: '1m30s', target: 30 }, // Ramp up to 30 VUs
    { duration: '2m', target: 30 },    // Stay at 30 VUs
    { duration: '1m', target: 15 },    // Ramp down to 15 VUs
    { duration: '30s', target: 0 },    // Ramp down to 0 VUs
  ],
  thresholds: {
    'http_req_duration': ['p(99)<1500', 'p(95)<800'],
    'http_req_failed': ['rate<0.1'],
    'search_duration': ['p(95)<1000'],
    'list_documents_duration': ['p(95)<500'],
  },
};

const BASE_URL = 'http://localhost:8001';

// Sample queries for testing
const SAMPLE_QUERIES = [
  'password reset',
  'account login',
  'billing information',
  'technical support',
  'refund policy',
  'customer service',
  'product features',
  'documentation',
  'troubleshooting',
  'contact us',
];

function getRandomQuery() {
  return SAMPLE_QUERIES[Math.floor(Math.random() * SAMPLE_QUERIES.length)];
}

export default function () {
  group('KB API - Health Check', () => {
    const response = http.get(`${BASE_URL}/health`);

    check(response, {
      'health check status is 200': (r) => r.status === 200,
      'health response time < 100ms': (r) => r.timings.duration < 100,
    });
  });

  group('KB API - Semantic Search', () => {
    const payload = JSON.stringify({
      query: getRandomQuery(),
      top_k: 5,
      search_type: 'semantic',
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: '10s',
    };

    const response = http.post(
      `${BASE_URL}/v1/search`,
      payload,
      params
    );

    const success = check(response, {
      'search status is 200': (r) => r.status === 200,
      'search has results': (r) => {
        const body = r.json();
        return body.results !== undefined || Array.isArray(body);
      },
      'response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    if (!success) {
      searchErrors.add(1);
    }

    searchDuration.add(response.timings.duration);
  });

  group('KB API - Hybrid Search', () => {
    const payload = JSON.stringify({
      query: getRandomQuery(),
      top_k: 10,
      search_type: 'hybrid',
      weights: {
        semantic: 0.7,
        keyword: 0.3,
      },
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: '10s',
    };

    const response = http.post(
      `${BASE_URL}/v1/search`,
      payload,
      params
    );

    check(response, {
      'hybrid search status is 200': (r) => r.status === 200,
      'has search results': (r) => r.body.length > 0,
      'response time < 1500ms': (r) => r.timings.duration < 1500,
    });

    searchDuration.add(response.timings.duration);
  });

  group('KB API - List Documents', () => {
    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const response = http.get(
      `${BASE_URL}/v1/documents`,
      params
    );

    const success = check(response, {
      'list documents status is 200': (r) => r.status === 200,
      'response has documents': (r) => {
        const body = r.json();
        return Array.isArray(body) || body.documents !== undefined;
      },
      'response time < 500ms': (r) => r.timings.duration < 500,
    });

    if (!success) {
      listDocErrors.add(1);
    }

    listDocDuration.add(response.timings.duration);
  });

  group('KB API - Search with Filters', () => {
    const payload = JSON.stringify({
      query: getRandomQuery(),
      top_k: 5,
      filters: {
        category: 'faq',
        language: 'en',
      },
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: '10s',
    };

    const response = http.post(
      `${BASE_URL}/v1/search`,
      payload,
      params
    );

    check(response, {
      'filtered search status is 200': (r) => r.status === 200 || r.status === 404,
      'response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    searchDuration.add(response.timings.duration);
  });

  group('KB API - Search Rankings', () => {
    const payload = JSON.stringify({
      query: getRandomQuery(),
      top_k: 10,
      ranking: 'relevance',
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: '10s',
    };

    const response = http.post(
      `${BASE_URL}/v1/search`,
      payload,
      params
    );

    check(response, {
      'ranking search status is 200': (r) => r.status === 200,
      'response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    searchDuration.add(response.timings.duration);
  });

  sleep(1);
}

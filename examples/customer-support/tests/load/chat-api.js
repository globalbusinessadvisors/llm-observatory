import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const createConvErrors = new Counter('create_conv_errors');
const sendMessageErrors = new Counter('send_message_errors');
const createConvDuration = new Trend('create_conversation_duration');
const sendMessageDuration = new Trend('send_message_duration');
const healthCheckDuration = new Trend('health_check_duration');

// Load test configuration
export const options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp up to 10 VUs
    { duration: '1m30s', target: 50 }, // Ramp up to 50 VUs
    { duration: '2m', target: 50 },    // Stay at 50 VUs
    { duration: '1m', target: 25 },    // Ramp down to 25 VUs
    { duration: '30s', target: 0 },    // Ramp down to 0 VUs
  ],
  thresholds: {
    'http_req_duration': ['p(99)<1000', 'p(95)<500'],
    'http_req_failed': ['rate<0.1'],
    'create_conversation_duration': ['p(95)<500'],
    'send_message_duration': ['p(95)<1000'],
  },
};

const BASE_URL = 'http://localhost:8000';
const CONVERSATIONS = {};

export default function () {
  group('Chat API - Health Check', () => {
    const response = http.get(`${BASE_URL}/health`);

    check(response, {
      'health check status is 200': (r) => r.status === 200,
      'health check response time < 100ms': (r) => r.timings.duration < 100,
    });

    healthCheckDuration.add(response.timings.duration);
  });

  group('Chat API - Create Conversation', () => {
    const payload = JSON.stringify({
      title: `Test Conversation ${Date.now()}`,
      metadata: {
        user_id: `user_${__VU}_${__ITER}`,
        session_id: `session_${__VU}`,
      },
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const response = http.post(
      `${BASE_URL}/v1/conversations`,
      payload,
      params
    );

    const success = check(response, {
      'create conversation status is 201': (r) => r.status === 201,
      'conversation has id': (r) => r.json('id') !== undefined,
      'response time < 500ms': (r) => r.timings.duration < 500,
    });

    if (!success) {
      createConvErrors.add(1);
    }

    createConvDuration.add(response.timings.duration);

    // Store conversation ID for later use
    if (response.status === 201) {
      const convId = response.json('id');
      CONVERSATIONS[`conv_${__VU}`] = convId;
    }
  });

  group('Chat API - Send Message', () => {
    const convId = CONVERSATIONS[`conv_${__VU}`] || `conv_${Date.now()}`;

    const payload = JSON.stringify({
      conversation_id: convId,
      message: 'What is customer support?',
      provider: 'openai',
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: '10s',
    };

    const response = http.post(
      `${BASE_URL}/v1/chat/completions`,
      payload,
      params
    );

    const success = check(response, {
      'send message status is 200 or 201': (r) => r.status === 200 || r.status === 201,
      'has response': (r) => r.json('response') !== undefined || r.json('choices') !== undefined,
      'response time < 1000ms': (r) => r.timings.duration < 1000,
    });

    if (!success) {
      sendMessageErrors.add(1);
    }

    sendMessageDuration.add(response.timings.duration);
  });

  group('Chat API - Get Conversations', () => {
    const response = http.get(`${BASE_URL}/v1/conversations`);

    check(response, {
      'get conversations status is 200': (r) => r.status === 200,
      'response is array or has conversations field': (r) => {
        const body = r.json();
        return Array.isArray(body) || body.conversations !== undefined;
      },
      'response time < 200ms': (r) => r.timings.duration < 200,
    });
  });

  sleep(1);
}

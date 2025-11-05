# Node.js SDK - LLM Observatory

## Installation

```bash
npm install @llm-observatory/sdk
# or
yarn add @llm-observatory/sdk
```

## Quick Start

```typescript
import { Observatory } from '@llm-observatory/sdk';
import OpenAI from 'openai';

// Initialize Observatory
Observatory.init({
  serviceName: 'my-app',
  otlpEndpoint: 'http://localhost:4317'
});

// Your LLM calls are automatically instrumented
const openai = new OpenAI();
const response = await openai.chat.completions.create({
  model: 'gpt-4-turbo',
  messages: [{ role: 'user', content: 'Hello!' }]
});
```

## Express Middleware

```typescript
import express from 'express';
import { observabilityMiddleware } from '@llm-observatory/sdk';

const app = express();

// Add Observatory middleware
app.use(observabilityMiddleware({
  serviceName: 'my-api',
  captureHeaders: true,
  captureBody: false
}));

app.post('/chat', async (req, res) => {
  // Automatically traced
  const response = await openai.chat.completions.create({
    model: 'gpt-4-turbo',
    messages: req.body.messages
  });
  res.json(response);
});
```

## Manual Tracing

```typescript
import { trace } from '@llm-observatory/sdk';

const tracer = trace.getTracer('my-app');

async function processQuery(query: string) {
  return tracer.startActiveSpan('process_query', async (span) => {
    span.setAttribute('query.length', query.length);
    try {
      const result = await llm.generate(query);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } finally {
      span.end();
    }
  });
}
```

## Configuration Options

```typescript
Observatory.init({
  serviceName: 'my-app',
  otlpEndpoint: 'http://localhost:4317',
  enableMetrics: true,
  enableTraces: true,
  sampleRate: 0.1,
  capturePrompts: true,
  redactPII: true,
  headers: {
    'x-api-key': 'your-key'
  }
});
```

See [examples/nodejs](../../examples/nodejs/) for complete examples.

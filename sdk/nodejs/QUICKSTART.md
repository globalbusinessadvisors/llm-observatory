# Quick Start Guide

Get started with LLM Observatory Node.js SDK in 5 minutes.

## Prerequisites

- Node.js 16.0.0 or higher
- OpenAI API key (for examples)
- LLM Observatory collector running (optional for testing)

## Installation

```bash
npm install @llm-observatory/sdk openai
```

## Minimal Example

```typescript
import { initObservatory, instrumentOpenAI } from '@llm-observatory/sdk';
import OpenAI from 'openai';

async function main() {
  // 1. Initialize Observatory
  await initObservatory({
    serviceName: 'my-app',
    otlpEndpoint: 'http://localhost:4317',
  });

  // 2. Create and instrument OpenAI client
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  instrumentOpenAI(openai);

  // 3. Use as normal - automatically traced!
  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: 'Hello!' }],
  });

  console.log(response.choices[0].message.content);
}

main();
```

## What You Get

After instrumentation, every LLM call automatically captures:

- **Request Parameters**: Model, temperature, max_tokens, etc.
- **Token Usage**: Prompt tokens, completion tokens, total
- **Cost**: Calculated in real-time using current pricing
- **Latency**: Total duration and time-to-first-token
- **Errors**: Automatic error tracking with stack traces
- **Metadata**: User ID, session ID, custom tags

## Viewing Traces

### Option 1: Debug Mode

Enable debug logging to see traces in console:

```typescript
await initObservatory({
  serviceName: 'my-app',
  debug: true, // Console output
});
```

### Option 2: OpenTelemetry Collector

Run the LLM Observatory stack:

```bash
# In the main repository
cd llm-observatory
docker compose up -d

# View in Grafana
open http://localhost:3000
```

### Option 3: Other OTLP Receivers

Point to any OTLP-compatible receiver:

```typescript
await initObservatory({
  serviceName: 'my-app',
  otlpEndpoint: 'https://your-collector.example.com:4317',
});
```

## Common Patterns

### Pattern 1: Express API

```typescript
import express from 'express';
import { initObservatory, instrumentOpenAI } from '@llm-observatory/sdk';

const app = express();
const observatory = await initObservatory({ serviceName: 'api' });

// Auto-trace all requests
app.use(observatory.middleware());

app.post('/chat', async (req, res) => {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: req.body.message }],
  });
  res.json({ response: response.choices[0].message.content });
});

app.listen(3000);
```

### Pattern 2: Streaming

```typescript
const stream = await openai.chat.completions.create({
  model: 'gpt-4o-mini',
  messages: [{ role: 'user', content: 'Write a story' }],
  stream: true,
});

for await (const chunk of stream) {
  process.stdout.write(chunk.choices[0]?.delta?.content || '');
}
// Automatically tracks TTFT and streaming metrics!
```

### Pattern 3: Cost Tracking

```typescript
import { PricingEngine } from '@llm-observatory/sdk';

// Compare models before calling
const costs = PricingEngine.compareCosts(
  ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo'],
  1000, // estimated prompt tokens
  500   // estimated completion tokens
);

console.log('Cost comparison:', costs);
// Choose the cheapest model that meets requirements
```

### Pattern 4: Custom Metadata

```typescript
instrumentOpenAI(openai, {
  metadata: {
    userId: req.user.id,
    sessionId: req.session.id,
    environment: 'production',
    tags: ['customer-support', 'priority-high'],
  },
});

// Now all traces include this metadata for filtering
```

## Next Steps

1. **Run Examples**: Check the [`examples/`](./examples/) directory
2. **Read Docs**: Full API documentation in [README.md](./README.md)
3. **Add Tests**: See [`test/`](./test/) for testing patterns
4. **Configure Sampling**: Optimize for high-traffic applications
5. **Set Up Dashboards**: Use Grafana for visualization

## Troubleshooting

### No traces appearing?

```typescript
// Enable debug mode
await initObservatory({
  serviceName: 'debug-test',
  debug: true, // See traces in console
});
```

### Want to see costs?

```typescript
instrumentOpenAI(openai, {
  enableCost: true,
  spanProcessor: (span) => {
    if (span.cost) {
      console.log(`💰 Cost: $${span.cost.amountUsd.toFixed(6)}`);
    }
  },
});
```

### Need to shutdown gracefully?

```typescript
process.on('SIGTERM', async () => {
  await observatory.shutdown();
  process.exit(0);
});
```

## Support

- **Examples**: See [`examples/`](./examples/)
- **Full Docs**: [README.md](./README.md)
- **Issues**: [GitHub Issues](https://github.com/llm-observatory/llm-observatory/issues)

Happy observing! 🔍

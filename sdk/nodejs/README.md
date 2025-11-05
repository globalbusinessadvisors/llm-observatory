# LLM Observatory Node.js SDK

[![npm version](https://badge.fury.io/js/%40llm-observatory%2Fsdk.svg)](https://www.npmjs.com/package/@llm-observatory/sdk)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](../../LICENSE)
[![Node.js](https://img.shields.io/badge/node-%3E%3D16.0.0-brightgreen)](https://nodejs.org/)

**Production-ready observability for LLM applications with OpenTelemetry.**

The official Node.js SDK for [LLM Observatory](https://github.com/llm-observatory/llm-observatory) - a high-performance, open-source observability platform for Large Language Model applications.

## Features

- **🔍 Automatic Instrumentation** - Wrap OpenAI clients with zero code changes
- **💰 Cost Tracking** - Real-time cost calculation for all major LLM providers
- **📊 OpenTelemetry Native** - Standards-based telemetry with OTLP export
- **🌊 Streaming Support** - Full support for streaming completions with TTFT tracking
- **⚡ High Performance** - Minimal overhead with async/await and batching
- **🎯 Type Safety** - Full TypeScript support with comprehensive types
- **🔧 Middleware Support** - Express middleware for automatic request tracing
- **📈 Rich Metrics** - Token usage, latency, errors, and custom attributes

## Installation

```bash
npm install @llm-observatory/sdk
# or
yarn add @llm-observatory/sdk
# or
pnpm add @llm-observatory/sdk
```

## Quick Start

### 1. Initialize Observatory

```typescript
import { initObservatory } from '@llm-observatory/sdk';

const observatory = await initObservatory({
  serviceName: 'my-llm-app',
  serviceVersion: '1.0.0',
  otlpEndpoint: 'http://localhost:4317',
  environment: 'production',
});
```

### 2. Instrument OpenAI Client

```typescript
import { instrumentOpenAI } from '@llm-observatory/sdk';
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Instrument the client
instrumentOpenAI(openai, {
  enableCost: true,
  enableStreaming: true,
});
```

### 3. Use as Normal

```typescript
// All calls are automatically traced and cost-tracked
const response = await openai.chat.completions.create({
  model: 'gpt-4o-mini',
  messages: [{ role: 'user', content: 'Hello!' }],
});

console.log(response.choices[0].message.content);
// Traces and metrics are automatically sent to your collector
```

## Configuration

### Observatory Options

```typescript
interface ObservatoryConfig {
  serviceName: string;              // Required: Service identifier
  serviceVersion?: string;          // Service version (default: '1.0.0')
  otlpEndpoint?: string;            // OTLP endpoint (default: 'http://localhost:4317')
  useGrpc?: boolean;                // Use gRPC protocol (default: true)
  enableMetrics?: boolean;          // Enable metrics collection (default: true)
  enableTraces?: boolean;           // Enable trace collection (default: true)
  sampleRate?: number;              // Sample rate 0.0-1.0 (default: 1.0)
  environment?: string;             // Environment name (default: NODE_ENV)
  resourceAttributes?: Record<...>; // Custom resource attributes
  debug?: boolean;                  // Enable debug logging (default: false)
  exportIntervalMs?: number;        // Export interval (default: 5000ms)
  maxBatchSize?: number;            // Max batch size (default: 512)
}
```

### Instrumentation Options

```typescript
interface InstrumentOpenAIOptions {
  enableCost?: boolean;             // Enable cost calculation (default: true)
  enableStreaming?: boolean;        // Enable streaming support (default: true)
  logPayloads?: boolean;            // Log request/response (default: false)
  metadata?: Metadata;              // Custom metadata for all spans
  spanProcessor?: (span) => void;   // Custom span processor
}
```

## Usage Examples

### Basic Chat Completion

```typescript
import { initObservatory, instrumentOpenAI } from '@llm-observatory/sdk';
import OpenAI from 'openai';

async function main() {
  await initObservatory({ serviceName: 'chat-app' });

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  instrumentOpenAI(openai);

  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: 'Hello!' }],
  });

  console.log(response.choices[0].message.content);
}
```

### Streaming Completions

```typescript
const stream = await openai.chat.completions.create({
  model: 'gpt-4o-mini',
  messages: [{ role: 'user', content: 'Write a haiku' }],
  stream: true,
});

for await (const chunk of stream) {
  const content = chunk.choices[0]?.delta?.content || '';
  process.stdout.write(content);
}
// Automatically tracks TTFT and streaming metrics
```

### Express Middleware

```typescript
import express from 'express';
import { initObservatory } from '@llm-observatory/sdk';

const app = express();
const observatory = await initObservatory({ serviceName: 'api' });

// Add automatic request tracing
app.use(observatory.middleware({
  captureRequestBody: true,
  ignorePaths: ['/health', '/metrics'],
}));

app.post('/chat', async (req, res) => {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: req.body.message }],
  });
  res.json({ response: response.choices[0].message.content });
});
```

### Custom Metadata

```typescript
instrumentOpenAI(openai, {
  metadata: {
    userId: 'user-123',
    sessionId: 'session-456',
    environment: 'production',
    tags: ['chat', 'customer-support'],
    attributes: {
      region: 'us-east-1',
      version: '2.0',
    },
  },
});
```

### Cost Tracking

```typescript
import { PricingEngine } from '@llm-observatory/sdk';

// List all available models
const models = PricingEngine.listModels();
console.log(`Available models: ${models.length}`);

// Compare costs across models
const comparisons = PricingEngine.compareCosts(
  ['gpt-4o', 'gpt-4o-mini', 'claude-3-5-sonnet-20241022'],
  1000, // prompt tokens
  500   // completion tokens
);

comparisons.forEach(({ model, cost }) => {
  console.log(`${model}: $${cost.toFixed(6)}`);
});

// Add custom pricing
PricingEngine.addCustomPricing({
  model: 'my-custom-model',
  promptCostPer1k: 0.001,
  completionCostPer1k: 0.002,
});
```

### Advanced Tracing

```typescript
import { withSpan, Provider } from '@llm-observatory/sdk';

// Create custom spans
await withSpan(
  'rag.workflow',
  async (span) => {
    span.setAttribute('query', 'What is observability?');

    // Nested operations are automatically traced
    const embedding = await generateEmbedding(query);
    const documents = await retrieveDocuments(embedding);
    const response = await generateResponse(documents);

    return response;
  },
  { provider: Provider.OpenAI, model: 'gpt-4o' }
);
```

### Error Handling

```typescript
try {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: 'Hello' }],
  });
} catch (error) {
  // Errors are automatically captured in traces
  console.error('LLM call failed:', error);
}
```

## Cost Calculation

The SDK includes comprehensive pricing data for all major LLM providers, updated as of January 2025:

### Supported Providers

- **OpenAI**: GPT-4o, GPT-4o mini, GPT-4 Turbo, GPT-3.5 Turbo, o1 models
- **Anthropic**: Claude Sonnet 4.5, Claude 3.5, Claude 3 (Opus, Sonnet, Haiku)
- **Google**: Gemini 2.5 Pro/Flash, Gemini 1.5 Pro/Flash
- **Mistral**: Mistral Large, Small, open-source models

### Cost Examples

```typescript
// Automatic cost tracking
instrumentOpenAI(openai, {
  enableCost: true,
  spanProcessor: (span) => {
    if (span.cost) {
      console.log(`Cost: $${span.cost.amountUsd.toFixed(6)}`);
    }
  },
});

// Manual cost calculation
const cost = PricingEngine.calculateCost('gpt-4o', 1000, 500);
console.log(`Estimated cost: $${cost.toFixed(6)}`);
```

## OpenTelemetry Integration

The SDK uses OpenTelemetry semantic conventions with LLM-specific attributes:

### Span Attributes

```typescript
// System attributes
llm.system = 'openai'
llm.request.model = 'gpt-4o'
llm.request.temperature = 0.7
llm.request.max_tokens = 500

// Token usage
llm.usage.prompt_tokens = 100
llm.usage.completion_tokens = 200
llm.usage.total_tokens = 300

// Cost
llm.cost.total_usd = 0.0045
llm.cost.prompt_usd = 0.001
llm.cost.completion_usd = 0.0035

// Latency
llm.latency.ttft_ms = 234
llm.duration_ms = 1567

// Streaming
llm.streaming.enabled = true
llm.streaming.chunk_count = 42
```

## Development

### Building

```bash
npm run build
```

### Testing

```bash
npm test
npm run test:coverage
```

### Linting

```bash
npm run lint
npm run lint:fix
```

### Examples

```bash
# Run examples (requires OpenAI API key)
export OPENAI_API_KEY=your-key
npx ts-node examples/basic-usage.ts
npx ts-node examples/streaming.ts
npx ts-node examples/cost-tracking.ts
```

## Architecture

```
Your App
   ↓
OpenAI Client (instrumented)
   ↓
LLM Observatory SDK
   ↓
OpenTelemetry SDK
   ↓
OTLP Exporter (gRPC/HTTP)
   ↓
LLM Observatory Collector
   ↓
Storage (TimescaleDB, Tempo, Loki)
   ↓
Grafana
```

## Performance

- **< 1ms overhead** per LLM call
- **Async batching** for minimal latency impact
- **Memory efficient** with streaming support
- **Configurable sampling** for high-volume scenarios

## Best Practices

1. **Initialize once** at application startup
2. **Use middleware** for automatic request tracing
3. **Enable cost tracking** to monitor spending
4. **Set metadata** for better trace filtering
5. **Configure sampling** for high-traffic applications
6. **Graceful shutdown** to flush telemetry

```typescript
// Graceful shutdown example
process.on('SIGTERM', async () => {
  await observatory.flush();
  await observatory.shutdown();
  process.exit(0);
});
```

## Troubleshooting

### Traces not appearing

1. Verify collector is running: `curl http://localhost:4317`
2. Enable debug logging: `debug: true`
3. Check for errors in console
4. Verify OTLP endpoint configuration

### Cost calculation errors

1. Check if model is supported: `PricingEngine.hasPricing(model)`
2. Add custom pricing if needed
3. Verify model name matches exactly

### High memory usage

1. Reduce `maxBatchSize` in config
2. Increase `exportIntervalMs`
3. Lower `sampleRate` for high traffic

## Examples

See the [`examples/`](./examples/) directory for complete examples:

- [`basic-usage.ts`](./examples/basic-usage.ts) - Simple chat completion
- [`streaming.ts`](./examples/streaming.ts) - Streaming responses
- [`express-middleware.ts`](./examples/express-middleware.ts) - Express integration
- [`cost-tracking.ts`](./examples/cost-tracking.ts) - Cost analysis
- [`advanced-tracing.ts`](./examples/advanced-tracing.ts) - RAG workflow

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

Apache 2.0 - see [LICENSE](../../LICENSE) for details.

## Support

- **Documentation**: [docs.llm-observatory.io](https://docs.llm-observatory.io)
- **Issues**: [GitHub Issues](https://github.com/llm-observatory/llm-observatory/issues)
- **Discussions**: [GitHub Discussions](https://github.com/llm-observatory/llm-observatory/discussions)

## Related Projects

- [LLM Observatory](https://github.com/llm-observatory/llm-observatory) - Main repository
- [Rust SDK](../../crates/sdk/) - Rust implementation
- [OpenTelemetry](https://opentelemetry.io/) - Observability framework

---

**Built with ❤️ for the LLM community**

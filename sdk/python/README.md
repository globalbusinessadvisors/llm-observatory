# LLM Observatory Python SDK

[![PyPI version](https://badge.fury.io/py/llm-observatory.svg)](https://badge.fury.io/py/llm-observatory)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](../../LICENSE)

High-performance observability SDK for LLM applications with OpenTelemetry integration.

## Features

- **Auto-Instrumentation**: Automatic tracing for OpenAI, Anthropic, and Azure OpenAI
- **Comprehensive Cost Tracking**: Real-time cost calculation for all major LLM providers
- **OpenTelemetry Native**: Standards-based telemetry with OTLP export
- **Streaming Support**: Full support for streaming responses with TTFT metrics
- **Context Window Optimization**: Intelligent context management to prevent token limit errors
- **Production Ready**: Error handling, retries, and minimal overhead

## Installation

```bash
# Basic installation
pip install llm-observatory

# With OpenAI support
pip install llm-observatory[openai]

# With Anthropic support
pip install llm-observatory[anthropic]

# With all providers
pip install llm-observatory[all]

# For development
pip install llm-observatory[dev]
```

## Quick Start

### OpenAI

```python
from openai import OpenAI
from llm_observatory import LLMObservatory, instrument_openai

# Initialize observatory
observatory = LLMObservatory(
    service_name="my-app",
    otlp_endpoint="http://localhost:4317"
)

# Create and instrument OpenAI client
client = OpenAI(api_key="your-api-key")
instrument_openai(client)

# Use as normal - all calls are automatically traced
response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### Anthropic

```python
from anthropic import Anthropic
from llm_observatory import LLMObservatory, instrument_anthropic

# Initialize observatory
observatory = LLMObservatory(
    service_name="my-app",
    otlp_endpoint="http://localhost:4317"
)

# Create and instrument Anthropic client
client = Anthropic(api_key="your-api-key")
instrument_anthropic(client)

# Use as normal - all calls are automatically traced
response = client.messages.create(
    model="claude-3-opus-20240229",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### Azure OpenAI

```python
from openai import AzureOpenAI
from llm_observatory import LLMObservatory, instrument_azure_openai

# Initialize observatory
observatory = LLMObservatory(
    service_name="my-app",
    otlp_endpoint="http://localhost:4317"
)

# Create and instrument Azure OpenAI client
client = AzureOpenAI(
    api_key="your-api-key",
    api_version="2024-02-01",
    azure_endpoint="https://your-resource.openai.azure.com"
)
instrument_azure_openai(client)

# Use as normal
response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

## What Gets Traced?

The SDK automatically captures:

- **Request Parameters**: Model, messages, temperature, max_tokens, etc.
- **Response Data**: Content, finish_reason, etc.
- **Token Usage**: Prompt tokens, completion tokens, total tokens
- **Cost**: Real-time cost calculation in USD
- **Latency Metrics**: Total duration, time-to-first-token (for streaming)
- **Errors**: Exception types and messages
- **Streaming**: Chunk events and streaming metrics

## Streaming Support

Streaming responses are fully supported with automatic chunk tracking:

```python
stream = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Write a poem"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)

# Automatically tracks:
# - Time to first token (TTFT)
# - Individual chunk events (sampled)
# - Total streaming time
# - All standard metrics
```

## Context Window Optimization

Prevent token limit errors with intelligent context management:

```python
from llm_observatory.optimizers import ContextWindowOptimizer

# Create optimizer for your model
optimizer = ContextWindowOptimizer(
    model="gpt-3.5-turbo",
    warning_threshold=0.8,  # Warn at 80% capacity
    action_threshold=0.9    # Optimize at 90% capacity
)

# Check if messages fit
check = optimizer.check_context_window(messages)
print(f"Utilization: {check['utilization']:.1%}")

# Get suggestions
suggestion = optimizer.get_optimization_suggestion(messages)
if suggestion:
    print(suggestion)

# Optimize if needed
if check['should_optimize']:
    optimized = optimizer.optimize_messages(
        messages,
        strategy="truncate_old"  # or "truncate_middle", "summarize"
    )
    messages = optimized
```

### Optimization Strategies

- **truncate_old**: Remove oldest messages (keeps system prompt and recent messages)
- **truncate_middle**: Keep first and last messages, remove middle
- **summarize**: Summarize old messages (requires summarizer function)

## Cost Tracking

Calculate and compare costs across models:

```python
from llm_observatory.cost import CostCalculator

calculator = CostCalculator()

# Calculate cost for a specific request
cost = calculator.calculate_cost(
    model="gpt-4",
    prompt_tokens=1000,
    completion_tokens=500
)
print(f"Cost: ${cost:.6f}")

# Get detailed breakdown
prompt_cost, completion_cost, total = calculator.calculate_cost_breakdown(
    model="gpt-4",
    prompt_tokens=1000,
    completion_tokens=500
)

# Compare models
costs = calculator.compare_models(
    models=["gpt-4", "gpt-4o", "gpt-3.5-turbo"],
    prompt_tokens=1000,
    completion_tokens=500
)
for model, cost in sorted(costs.items(), key=lambda x: x[1]):
    print(f"{model}: ${cost:.6f}")
```

### Supported Models

The SDK includes pricing for 50+ models including:

**OpenAI**: GPT-4, GPT-4 Turbo, GPT-4o, GPT-3.5 Turbo, o1-preview, o1-mini

**Anthropic**: Claude 3 Opus, Sonnet, Haiku, Claude 3.5, Claude Sonnet 4.5

**Google**: Gemini 1.5 Pro, Gemini 1.5 Flash, Gemini 2.5

**Mistral**: Mistral Large, Medium, Small

**Azure OpenAI**: Same as OpenAI pricing

## Configuration

### Environment Variables

```bash
# Service configuration
export LLM_OBSERVATORY_SERVICE_NAME="my-app"
export LLM_OBSERVATORY_SERVICE_VERSION="1.0.0"

# OTLP endpoint
export LLM_OBSERVATORY_OTLP_ENDPOINT="http://localhost:4317"

# Enable console export for debugging
export LLM_OBSERVATORY_CONSOLE_EXPORT="true"
```

Then initialize from environment:

```python
from llm_observatory import LLMObservatory

observatory = LLMObservatory.from_env()
```

### Manual Configuration

```python
observatory = LLMObservatory(
    service_name="my-app",
    service_version="1.0.0",
    otlp_endpoint="http://localhost:4317",
    insecure=True,  # Use insecure gRPC connection
    console_export=True,  # Also print to console
    auto_shutdown=True,  # Auto-shutdown on exit
)
```

### Context Manager

```python
with LLMObservatory(service_name="my-app", otlp_endpoint="http://localhost:4317") as obs:
    # Your code here
    pass
# Automatically shuts down and flushes traces
```

## OpenTelemetry Integration

The SDK uses OpenTelemetry for tracing and exports data via OTLP (OpenTelemetry Protocol).

### Collector Setup

Deploy an OpenTelemetry collector to receive traces:

```yaml
# docker-compose.yml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4317:4317"  # OTLP gRPC
      - "4318:4318"  # OTLP HTTP
```

Or use the full LLM Observatory stack:

```bash
git clone https://github.com/llm-observatory/llm-observatory
cd llm-observatory
docker compose up -d
```

This includes:
- OpenTelemetry Collector
- TimescaleDB (metrics storage)
- Grafana (visualization)
- Tempo (trace storage)
- Loki (logs)

## Advanced Usage

### Custom Span Attributes

```python
from llm_observatory.tracing import add_span_attribute, add_span_event

# Add custom attributes to current span
add_span_attribute("user_id", "user-123")
add_span_attribute("session_id", "session-456")

# Add custom events
add_span_event("user_action", {"action": "button_click", "button_id": "submit"})
```

### Manual Tracing

```python
from llm_observatory.tracing import trace_llm_call

with trace_llm_call(
    operation_name="custom.llm.operation",
    model="gpt-4",
    provider="openai",
    custom_attribute="value"
) as span:
    # Your code here
    response = some_llm_call()
    span.set_attribute("result_length", len(response))
```

### Custom Cost Models

```python
from llm_observatory.cost import Pricing

calculator = CostCalculator()

# Add custom pricing
custom_pricing = Pricing(
    model="my-custom-model",
    prompt_cost_per_1k=0.001,
    completion_cost_per_1k=0.002
)
calculator.db.add_pricing(custom_pricing)

# Now calculate costs
cost = calculator.calculate_cost("my-custom-model", 1000, 500)
```

## Examples

See the [examples](./examples/) directory for complete examples:

- [basic_openai.py](./examples/basic_openai.py) - Basic OpenAI instrumentation
- [streaming_openai.py](./examples/streaming_openai.py) - Streaming with TTFT tracking
- [anthropic_example.py](./examples/anthropic_example.py) - Anthropic/Claude instrumentation
- [context_optimizer.py](./examples/context_optimizer.py) - Context window management
- [cost_tracking.py](./examples/cost_tracking.py) - Cost calculation and comparison

## Performance

The SDK is designed for minimal overhead:

- **< 1ms** overhead per LLM call
- **Async span export** (non-blocking)
- **Batch processing** (512 spans per batch)
- **Sampling support** (head and tail sampling)
- **Memory efficient** (~256 bytes per span)

## Testing

Run tests:

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Run tests
pytest tests/ -v

# With coverage
pytest tests/ --cov=llm_observatory --cov-report=html
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](../../LICENSE) file for details.

## Support

- **Documentation**: [https://docs.llm-observatory.io](https://docs.llm-observatory.io)
- **Issues**: [GitHub Issues](https://github.com/llm-observatory/llm-observatory/issues)
- **Discussions**: [GitHub Discussions](https://github.com/llm-observatory/llm-observatory/discussions)

## Related Projects

- [LLM Observatory (Rust)](../../README.md) - Main project with collector and storage
- [OpenTelemetry](https://opentelemetry.io/) - Observability framework
- [Grafana](https://grafana.com/) - Visualization platform

## Acknowledgments

Built with:
- [OpenTelemetry Python](https://github.com/open-telemetry/opentelemetry-python)
- [OpenAI Python SDK](https://github.com/openai/openai-python)
- [Anthropic Python SDK](https://github.com/anthropics/anthropic-sdk-python)

---

**Built with ❤️ for the LLM community**

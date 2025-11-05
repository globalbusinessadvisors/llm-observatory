# Python SDK - LLM Observatory

## Installation

```bash
pip install llm-observatory
```

## Quick Start

```python
from llm_observatory import Observatory
import openai

# Initialize Observatory
Observatory.init(
    service_name="my-app",
    otlp_endpoint="http://localhost:4317"
)

# Your LLM calls are automatically instrumented
client = openai.OpenAI()
response = client.chat.completions.create(
    model="gpt-4-turbo",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

## Auto-Instrumentation

```python
from llm_observatory import trace_llm

@trace_llm(capture_input=True, capture_output=True)
async def generate_response(prompt: str):
    response = await openai.chat.completions.create(
        model="gpt-4-turbo",
        messages=[{"role": "user", "content": prompt}]
    )
    return response.choices[0].message.content
```

## Manual Instrumentation

```python
from llm_observatory import get_tracer

tracer = get_tracer(__name__)

with tracer.start_as_current_span("custom_operation") as span:
    span.set_attribute("llm.model", "gpt-4-turbo")
    span.set_attribute("llm.tokens.total", 150)
    # Your code
```

## Configuration

```python
Observatory.init(
    service_name="my-app",
    otlp_endpoint="http://localhost:4317",
    enable_metrics=True,
    enable_traces=True,
    sample_rate=0.1,  # Sample 10% of requests
    capture_prompts=True,
    redact_pii=True
)
```

See [examples/python](../../examples/python/) for complete examples.

# Rust SDK - LLM Observatory

## Installation

Add to `Cargo.toml`:
```toml
[dependencies]
llm-observatory = "0.1"
tokio = { version = "1", features = ["full"] }
```

## Quick Start

```rust
use llm_observatory::Observatory;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize Observatory
    let _guard = Observatory::init()
        .with_service_name("my-app")
        .with_otlp_endpoint("http://localhost:4317")
        .start()
        .await?;

    // Your LLM calls are automatically instrumented
    let response = openai_client
        .chat()
        .create(request)
        .await?;

    Ok(())
}
```

## Auto-Instrumentation with Macros

```rust
use llm_observatory::prelude::*;

#[instrument(name = "generate_response")]
async fn generate_response(prompt: &str) -> Result<String> {
    let response = openai.complete(prompt).await?;
    Ok(response.text)
}
```

## Manual Tracing

```rust
use opentelemetry::trace::{Tracer, TracerProvider};
use opentelemetry::KeyValue;

let tracer = global::tracer("my-app");

let mut span = tracer.start("llm.completion");
span.set_attribute(KeyValue::new("llm.model", "gpt-4-turbo"));
span.set_attribute(KeyValue::new("llm.tokens.total", 150));

// Your code

span.end();
```

## Trait-Based Integration

```rust
use llm_observatory::LlmProvider;

#[async_trait]
impl LlmProvider for MyCustomProvider {
    async fn complete(&self, prompt: &str) -> Result<Completion> {
        // Automatically traced
        self.call_api(prompt).await
    }
}
```

## Configuration

```rust
Observatory::init()
    .with_service_name("my-app")
    .with_otlp_endpoint("http://localhost:4317")
    .with_sample_rate(0.1)
    .with_capture_prompts(true)
    .with_pii_redaction(true)
    .start()
    .await?;
```

See [examples/rust](../../examples/rust/) for complete examples.

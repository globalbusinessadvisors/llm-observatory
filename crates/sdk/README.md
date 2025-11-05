# LLM Observatory Rust SDK

[![Crates.io](https://img.shields.io/crates/v/llm-observatory-sdk)](https://crates.io/crates/llm-observatory-sdk)
[![Documentation](https://docs.rs/llm-observatory-sdk/badge.svg)](https://docs.rs/llm-observatory-sdk)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](../../LICENSE)

Production-ready Rust SDK for LLM Observatory with trait-based instrumentation, automatic cost tracking, and OpenTelemetry integration.

## Features

- **Automatic Instrumentation**: Built-in OpenTelemetry tracing for all LLM operations
- **Cost Tracking**: Real-time cost calculation based on token usage and model pricing
- **Provider Support**: OpenAI, Anthropic, and extensible trait system for custom providers
- **Async/Await**: Full async support with Tokio runtime
- **Type Safety**: Strong typing with comprehensive error handling
- **Streaming**: Support for streaming completions (where available)
- **Zero Configuration**: Sensible defaults with optional customization

## Quick Start

Add the SDK to your `Cargo.toml`:

```toml
[dependencies]
llm-observatory-sdk = "0.1"
tokio = { version = "1.40", features = ["full"] }
```

### Basic Example

```rust
use llm_observatory_sdk::{LLMObservatory, OpenAIClient, InstrumentedLLM, ChatCompletionRequest};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize the observatory
    let observatory = LLMObservatory::builder()
        .with_service_name("my-app")
        .with_otlp_endpoint("http://localhost:4317")
        .build()?;

    // Create an instrumented client
    let client = OpenAIClient::new("your-api-key")
        .with_observatory(observatory);

    // Make a request
    let request = ChatCompletionRequest::new("gpt-4o-mini")
        .with_user("What is the capital of France?");

    let response = client.chat_completion(request).await?;

    println!("Response: {}", response.content);
    println!("Cost: ${:.6}", response.cost_usd);
    println!("Tokens: {}", response.total_tokens());
    println!("Trace ID: {}", response.trace_id);

    Ok(())
}
```

## Installation

### Prerequisites

- Rust 1.75.0 or later
- OpenTelemetry Collector (for trace export)

### From Crates.io

```bash
cargo add llm-observatory-sdk
```

### From Source

```bash
git clone https://github.com/llm-observatory/llm-observatory.git
cd llm-observatory/crates/sdk
cargo build --release
```

## Usage

### Initialize the Observatory

The observatory manages OpenTelemetry setup and configuration:

```rust
let observatory = LLMObservatory::builder()
    .with_service_name("my-service")
    .with_otlp_endpoint("http://localhost:4317")
    .with_environment("production")
    .with_sampling_rate(1.0)  // Sample 100% of traces
    .with_attribute("region", "us-east-1")
    .build()?;
```

### Create an Instrumented Client

#### OpenAI

```rust
let client = OpenAIClient::new("sk-...")
    .with_observatory(observatory);
```

#### Custom Configuration

```rust
use llm_observatory_sdk::OpenAIConfig;

let config = OpenAIConfig::new("sk-...")
    .with_base_url("https://custom-endpoint.com/v1")
    .with_timeout(120)
    .with_organization("org-123");

let client = OpenAIClient::with_config(config)
    .with_observatory(observatory);
```

### Make Requests

#### Simple Request

```rust
let request = ChatCompletionRequest::new("gpt-4o")
    .with_system("You are a helpful assistant.")
    .with_user("Hello, world!");

let response = client.chat_completion(request).await?;
```

#### Advanced Request

```rust
let request = ChatCompletionRequest::new("gpt-4o")
    .with_message("system", "You are a helpful assistant.")
    .with_message("user", "Hello!")
    .with_message("assistant", "Hi there!")
    .with_message("user", "How are you?")
    .with_temperature(0.7)
    .with_max_tokens(500)
    .with_top_p(0.9)
    .with_frequency_penalty(0.5)
    .with_user_id("user_123")
    .with_metadata("session_id", "abc123")
    .with_metadata("feature", "chat");

let response = client.chat_completion(request).await?;
```

### Cost Tracking

#### Calculate Costs

```rust
use llm_observatory_sdk::cost::{calculate_cost, estimate_cost};

// Calculate actual cost
let usage = TokenUsage::new(1000, 500);
let cost = calculate_cost("gpt-4", &usage)?;
println!("Cost: ${:.6}", cost.amount_usd);

// Estimate cost before request
let estimated_cost = estimate_cost("gpt-4", 1000, 500)?;
println!("Estimated: ${:.6}", estimated_cost);
```

#### Track Cumulative Costs

```rust
use llm_observatory_sdk::cost::CostTracker;

let mut tracker = CostTracker::new();

// Make multiple requests
for request in requests {
    let response = client.chat_completion(request).await?;
    tracker.record(&response.model, &Cost::new(response.cost_usd), &response.usage);
}

// View statistics
println!("{}", tracker.summary());
println!("Total: ${:.6}", tracker.total_cost());
println!("Average: ${:.6}", tracker.average_cost());
```

### Error Handling

```rust
use llm_observatory_sdk::Error;

match client.chat_completion(request).await {
    Ok(response) => {
        println!("Success: {}", response.content);
    }
    Err(Error::RateLimit(msg)) => {
        eprintln!("Rate limited: {}", msg);
        // Implement backoff logic
    }
    Err(Error::Auth(msg)) => {
        eprintln!("Auth error: {}", msg);
        // Check API key
    }
    Err(e) if e.is_retryable() => {
        eprintln!("Retryable error: {}", e);
        // Retry the request
    }
    Err(e) => {
        eprintln!("Error: {}", e);
    }
}
```

### Custom Attributes & Metadata

```rust
// Add custom attributes to the observatory
let observatory = LLMObservatory::builder()
    .with_service_name("my-app")
    .with_attribute("team", "ai-research")
    .with_attribute("version", "1.2.3")
    .build()?;

// Add metadata to requests
let request = ChatCompletionRequest::new("gpt-4o")
    .with_user("Hello!")
    .with_user_id("user_123")
    .with_metadata("session_id", "abc")
    .with_metadata("experiment", "ab-test-v2");

let response = client.chat_completion(request).await?;

// Metadata is preserved in the response
if let Some(session) = response.metadata.get("session_id") {
    println!("Session: {}", session);
}
```

## Architecture

The SDK is built around several core concepts:

### LLMObservatory

Central manager for OpenTelemetry setup and tracer management. Handles:
- OTLP exporter configuration
- Resource attributes
- Sampling strategies
- Tracer lifecycle

### InstrumentedLLM Trait

Provider-agnostic trait for instrumented LLM clients:

```rust
#[async_trait]
pub trait InstrumentedLLM: Send + Sync {
    async fn chat_completion(
        &self,
        request: ChatCompletionRequest,
    ) -> Result<ChatCompletionResponse>;

    async fn streaming_completion(
        &self,
        request: ChatCompletionRequest,
    ) -> Result<Pin<Box<dyn Stream<Item = Result<StreamChunk>> + Send>>>;

    fn provider_name(&self) -> &str;
}
```

### Automatic Instrumentation

Every LLM call automatically:
1. Creates an OpenTelemetry span
2. Records request parameters
3. Tracks token usage
4. Calculates costs
5. Measures latency
6. Records errors

## OpenTelemetry Integration

The SDK follows [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/):

### Span Attributes

- `gen_ai.system`: Provider name (e.g., "openai")
- `gen_ai.request.model`: Model identifier
- `gen_ai.request.temperature`: Temperature setting
- `gen_ai.request.max_tokens`: Max tokens setting
- `gen_ai.usage.prompt_tokens`: Prompt token count
- `gen_ai.usage.completion_tokens`: Completion token count
- `gen_ai.cost.usd`: Cost in USD

### Metrics

- Token usage per request
- Cost per request
- Latency (total and TTFT)
- Error rates by type

## Examples

The SDK includes comprehensive examples:

```bash
# Basic usage
cargo run --example basic --features openai

# Streaming completions
cargo run --example streaming --features openai

# Custom attributes
cargo run --example custom_attributes --features openai

# Error handling
cargo run --example error_handling --features openai

# Cost tracking
cargo run --example cost_tracking --features openai
```

## Testing

Run unit tests:

```bash
cargo test
```

Run integration tests (requires API keys):

```bash
export OPENAI_API_KEY=sk-...
cargo test --features openai -- --ignored
```

## Configuration

### Environment Variables

- `OPENAI_API_KEY`: OpenAI API key
- `OTEL_EXPORTER_OTLP_ENDPOINT`: OTLP endpoint (default: http://localhost:4317)
- `OTEL_SERVICE_NAME`: Service name for tracing

### Sampling

Control trace sampling to reduce overhead:

```rust
let observatory = LLMObservatory::builder()
    .with_service_name("my-app")
    .with_sampling_rate(0.1)  // Sample 10% of traces
    .build()?;
```

## Performance

The SDK is designed for production use with minimal overhead:

- Async/await for non-blocking I/O
- Connection pooling via reqwest
- Efficient span creation
- Batched OTLP exports

## Roadmap

- [ ] Streaming support for OpenAI
- [ ] Anthropic provider implementation
- [ ] Google Gemini provider
- [ ] Request retries with exponential backoff
- [ ] Circuit breaker pattern
- [ ] Rate limiting
- [ ] Response caching
- [ ] Token counting utilities
- [ ] Prompt template support

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](../../LICENSE) for details.

## Support

- Documentation: https://docs.llm-observatory.io
- Issues: https://github.com/llm-observatory/llm-observatory/issues
- Discussions: https://github.com/llm-observatory/llm-observatory/discussions

## Acknowledgments

Built with:
- [OpenTelemetry Rust](https://github.com/open-telemetry/opentelemetry-rust)
- [Tokio](https://tokio.rs/)
- [Reqwest](https://github.com/seanmonstar/reqwest)
- [Serde](https://serde.rs/)

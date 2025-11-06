# llm-observatory-providers

LLM provider implementations and pricing models for LLM Observatory.

## Overview

Comprehensive LLM provider support with real-time cost tracking:

- **OpenAI**: GPT-4o, GPT-4, GPT-3.5, o1 models
- **Anthropic**: Claude 3.5 Sonnet, Claude 3 Opus/Sonnet/Haiku
- **Google**: Gemini 2.5 Pro/Flash, Gemini 1.5 Pro/Flash
- **Mistral**: Mistral Large, Small, open-source models

## Features

- **Real-time Pricing**: Up-to-date pricing for 50+ models (January 2025)
- **Cost Calculation**: Automatic cost tracking per request
- **Token Counting**: Accurate token usage measurement
- **Provider Traits**: Extensible provider interface

## Usage

Add to your `Cargo.toml`:

```toml
[dependencies]
llm-observatory-providers = "0.1"
```

Example:

```rust
use llm_observatory_providers::{Provider, PricingEngine};

// Calculate cost for a request
let cost = PricingEngine::calculate_cost(
    Provider::OpenAI,
    "gpt-4o",
    1000,  // prompt tokens
    500,   // completion tokens
)?;

println!("Cost: ${:.6}", cost);
```

## Supported Providers

| Provider | Models | Features |
|----------|--------|----------|
| OpenAI | GPT-4o, GPT-4, GPT-3.5, o1 | Cost tracking, streaming |
| Anthropic | Claude 3.5, Claude 3 | Cost tracking, streaming |
| Google | Gemini 2.5, Gemini 1.5 | Cost tracking |
| Mistral | Large, Small, OSS | Cost tracking |

## Documentation

See the [provider documentation](https://docs.llm-observatory.io/providers) for detailed usage.

## License

Apache-2.0

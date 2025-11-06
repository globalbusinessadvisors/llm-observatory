# llm-observatory-core

Core types, traits, and utilities for LLM Observatory.

## Overview

This crate provides the fundamental building blocks for the LLM Observatory platform:

- Core types for LLM spans, traces, and telemetry
- OpenTelemetry integration primitives
- Shared utilities and error handling
- Provider trait definitions

## Features

- **Type Safety**: Strongly-typed span and trace structures
- **OpenTelemetry Native**: Built on OpenTelemetry standards
- **Async-First**: Built with Tokio for high performance
- **Serialization**: Serde support for all core types

## Usage

Add to your `Cargo.toml`:

```toml
[dependencies]
llm-observatory-core = "0.1"
```

## Documentation

See the [main documentation](https://docs.llm-observatory.io) for detailed usage.

## License

Apache-2.0

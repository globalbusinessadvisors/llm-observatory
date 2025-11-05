# Changelog

All notable changes to the LLM Observatory Node.js SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-XX

### Added
- Initial release of LLM Observatory Node.js SDK
- OpenTelemetry-based tracing for LLM calls
- Automatic OpenAI client instrumentation
- Cost calculation for all major LLM providers (OpenAI, Anthropic, Google, Mistral)
- Streaming support with TTFT tracking
- Express middleware for automatic request tracing
- Comprehensive TypeScript types
- Unit and integration tests
- Full documentation and examples

### Features
- `LLMObservatory` class for initialization and configuration
- `instrumentOpenAI()` function for automatic client instrumentation
- `PricingEngine` for cost calculation and comparison
- `LLMTracer` for custom span creation
- `withSpan()` helper for manual tracing
- Express middleware for HTTP request tracing
- Support for custom metadata and attributes
- Configurable sampling and batching
- Debug logging support

### Providers Supported
- OpenAI (GPT-4o, GPT-4, GPT-3.5, o1 models)
- Anthropic (Claude Sonnet 4.5, Claude 3.5, Claude 3)
- Google (Gemini 2.5, Gemini 1.5)
- Mistral (Large, Small, open-source models)

### Documentation
- Comprehensive README with usage examples
- 5 complete example applications
- TypeScript type definitions
- API documentation in code comments

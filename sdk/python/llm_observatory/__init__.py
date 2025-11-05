# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
LLM Observatory Python SDK

A comprehensive observability SDK for LLM applications with OpenTelemetry integration.

Key Features:
- Auto-instrumentation for OpenAI, Anthropic, and Azure OpenAI
- Comprehensive cost tracking for all major LLM providers
- OpenTelemetry-native tracing with OTLP export
- Context window optimization
- Streaming support
- Error handling and retries

Example:
    >>> from llm_observatory import LLMObservatory, instrument_openai
    >>> import openai
    >>>
    >>> # Initialize observatory
    >>> observatory = LLMObservatory(
    ...     service_name="my-app",
    ...     otlp_endpoint="http://localhost:4317"
    ... )
    >>>
    >>> # Auto-instrument OpenAI
    >>> client = openai.OpenAI()
    >>> instrument_openai(client)
    >>>
    >>> # Your code is now automatically instrumented
    >>> response = client.chat.completions.create(
    ...     model="gpt-4",
    ...     messages=[{"role": "user", "content": "Hello!"}]
    ... )
"""

from llm_observatory.observatory import LLMObservatory
from llm_observatory.instrument import (
    instrument_openai,
    instrument_anthropic,
    instrument_azure_openai,
)
from llm_observatory.cost import CostCalculator, PricingDatabase
from llm_observatory.optimizers import ContextWindowOptimizer
from llm_observatory.tracing import (
    get_tracer,
    get_current_span,
    add_span_attribute,
    add_span_event,
)

__version__ = "0.1.0"
__all__ = [
    "LLMObservatory",
    "instrument_openai",
    "instrument_anthropic",
    "instrument_azure_openai",
    "CostCalculator",
    "PricingDatabase",
    "ContextWindowOptimizer",
    "get_tracer",
    "get_current_span",
    "add_span_attribute",
    "add_span_event",
]

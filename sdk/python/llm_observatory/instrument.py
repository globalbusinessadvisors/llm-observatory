# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
Auto-instrumentation for LLM providers.

This module provides automatic instrumentation for OpenAI, Anthropic, and
Azure OpenAI clients, capturing all LLM calls with comprehensive telemetry.
"""

import time
import functools
from typing import Any, Optional, Callable, Iterator

from llm_observatory.tracing import trace_llm_call, SpanRecorder, get_current_span
from llm_observatory.cost import CostCalculator


# Global cost calculator
_cost_calculator = CostCalculator()


def instrument_openai(client: Any) -> Any:
    """
    Instrument OpenAI client for automatic tracing.

    This function wraps the OpenAI client's methods to automatically capture
    telemetry for all LLM calls including:
    - Request parameters (model, messages, temperature, etc.)
    - Response data (content, tokens, finish reason)
    - Cost calculation
    - Latency metrics
    - Streaming support

    Args:
        client: OpenAI client instance (openai.OpenAI or openai.AsyncOpenAI)

    Returns:
        Instrumented client (same instance, methods wrapped)

    Example:
        >>> import openai
        >>> from llm_observatory import instrument_openai
        >>>
        >>> client = openai.OpenAI(api_key="...")
        >>> instrument_openai(client)
        >>>
        >>> # All calls are now automatically traced
        >>> response = client.chat.completions.create(
        ...     model="gpt-4",
        ...     messages=[{"role": "user", "content": "Hello!"}]
        ... )
    """
    # Check if already instrumented
    if hasattr(client, "_llm_observatory_instrumented"):
        return client

    # Instrument chat completions
    if hasattr(client, "chat") and hasattr(client.chat, "completions"):
        original_create = client.chat.completions.create
        client.chat.completions.create = _wrap_openai_chat_create(original_create)

    # Instrument completions (legacy)
    if hasattr(client, "completions") and hasattr(client.completions, "create"):
        original_create = client.completions.create
        client.completions.create = _wrap_openai_completion_create(original_create)

    # Mark as instrumented
    client._llm_observatory_instrumented = True

    return client


def _wrap_openai_chat_create(original_func: Callable) -> Callable:
    """Wrap OpenAI chat completion create method."""

    @functools.wraps(original_func)
    def wrapper(*args, **kwargs):
        # Extract parameters
        model = kwargs.get("model", "unknown")
        messages = kwargs.get("messages", [])
        temperature = kwargs.get("temperature")
        max_tokens = kwargs.get("max_tokens")
        top_p = kwargs.get("top_p")
        stream = kwargs.get("stream", False)

        # Start tracing
        with trace_llm_call(
            operation_name="openai.chat.completion",
            model=model,
            provider="openai",
            streaming=stream,
        ) as span:
            # Record request
            SpanRecorder.record_request(
                span,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                top_p=top_p,
                stream=stream,
            )

            try:
                # Call original method
                response = original_func(*args, **kwargs)

                # Handle streaming vs non-streaming
                if stream:
                    return _wrap_openai_stream(response, span, model)
                else:
                    # Record response for non-streaming
                    _record_openai_response(response, span, model)
                    return response

            except Exception as e:
                # Record error
                span.set_attribute("error", True)
                span.set_attribute("error.type", type(e).__name__)
                span.set_attribute("error.message", str(e))
                raise

    return wrapper


def _wrap_openai_stream(stream: Iterator, span: Any, model: str) -> Iterator:
    """Wrap OpenAI streaming response to capture chunks."""
    chunk_count = 0
    content_buffer = []
    start_time = time.time()
    first_token_time = None
    prompt_tokens = None
    completion_tokens = 0

    try:
        for chunk in stream:
            chunk_count += 1

            # Record first token time
            if first_token_time is None:
                first_token_time = time.time()

            # Extract content
            if hasattr(chunk, "choices") and len(chunk.choices) > 0:
                delta = chunk.choices[0].delta
                if hasattr(delta, "content") and delta.content:
                    content = delta.content
                    content_buffer.append(content)
                    completion_tokens += _estimate_tokens(content)

                    # Record chunk event (sample every 10th chunk to reduce overhead)
                    if chunk_count % 10 == 0:
                        elapsed_ms = (time.time() - start_time) * 1000
                        SpanRecorder.record_streaming_chunk(
                            span,
                            chunk_index=chunk_count,
                            chunk_content=content,
                            timestamp_ms=elapsed_ms,
                        )

            # Extract usage if available (final chunk)
            if hasattr(chunk, "usage") and chunk.usage:
                prompt_tokens = chunk.usage.prompt_tokens
                completion_tokens = chunk.usage.completion_tokens

            yield chunk

        # Record final metrics after stream completes
        full_content = "".join(content_buffer)
        ttft_ms = (first_token_time - start_time) * 1000 if first_token_time else None

        # If we didn't get token counts from the API, estimate them
        if prompt_tokens is None:
            prompt_tokens = 0  # Can't estimate prompt tokens easily

        # Calculate cost
        cost_usd = None
        if prompt_tokens and completion_tokens:
            cost_usd = _cost_calculator.calculate_cost(
                model, prompt_tokens, completion_tokens
            )

        # Record response
        SpanRecorder.record_response(
            span,
            content=full_content,
            finish_reason="stop",
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=prompt_tokens + completion_tokens if prompt_tokens else completion_tokens,
            cost_usd=cost_usd,
            ttft_ms=ttft_ms,
            chunk_count=chunk_count,
        )

    except Exception as e:
        span.set_attribute("error", True)
        span.set_attribute("error.type", type(e).__name__)
        span.set_attribute("error.message", str(e))
        raise


def _record_openai_response(response: Any, span: Any, model: str) -> None:
    """Record OpenAI response data."""
    if not hasattr(response, "choices") or len(response.choices) == 0:
        return

    choice = response.choices[0]
    content = choice.message.content if hasattr(choice.message, "content") else ""
    finish_reason = choice.finish_reason if hasattr(choice, "finish_reason") else None

    # Extract token usage
    prompt_tokens = None
    completion_tokens = None
    total_tokens = None

    if hasattr(response, "usage") and response.usage:
        prompt_tokens = response.usage.prompt_tokens
        completion_tokens = response.usage.completion_tokens
        total_tokens = response.usage.total_tokens

    # Calculate cost
    cost_usd = None
    if prompt_tokens and completion_tokens:
        cost_usd = _cost_calculator.calculate_cost(
            model, prompt_tokens, completion_tokens
        )

    # Record response
    SpanRecorder.record_response(
        span,
        content=content,
        finish_reason=finish_reason,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        total_tokens=total_tokens,
        cost_usd=cost_usd,
    )


def _wrap_openai_completion_create(original_func: Callable) -> Callable:
    """Wrap OpenAI completion create method (legacy)."""

    @functools.wraps(original_func)
    def wrapper(*args, **kwargs):
        model = kwargs.get("model", "unknown")
        prompt = kwargs.get("prompt", "")
        temperature = kwargs.get("temperature")
        max_tokens = kwargs.get("max_tokens")

        with trace_llm_call(
            operation_name="openai.completion",
            model=model,
            provider="openai",
        ) as span:
            # Record request
            SpanRecorder.record_request(
                span,
                prompt=prompt,
                temperature=temperature,
                max_tokens=max_tokens,
            )

            try:
                response = original_func(*args, **kwargs)
                _record_openai_response(response, span, model)
                return response

            except Exception as e:
                span.set_attribute("error", True)
                span.set_attribute("error.type", type(e).__name__)
                span.set_attribute("error.message", str(e))
                raise

    return wrapper


def instrument_anthropic(client: Any) -> Any:
    """
    Instrument Anthropic client for automatic tracing.

    Args:
        client: Anthropic client instance

    Returns:
        Instrumented client

    Example:
        >>> import anthropic
        >>> from llm_observatory import instrument_anthropic
        >>>
        >>> client = anthropic.Anthropic(api_key="...")
        >>> instrument_anthropic(client)
        >>>
        >>> # All calls are now automatically traced
        >>> response = client.messages.create(
        ...     model="claude-3-opus-20240229",
        ...     messages=[{"role": "user", "content": "Hello!"}]
        ... )
    """
    # Check if already instrumented
    if hasattr(client, "_llm_observatory_instrumented"):
        return client

    # Instrument messages API
    if hasattr(client, "messages") and hasattr(client.messages, "create"):
        original_create = client.messages.create
        client.messages.create = _wrap_anthropic_messages_create(original_create)

    # Mark as instrumented
    client._llm_observatory_instrumented = True

    return client


def _wrap_anthropic_messages_create(original_func: Callable) -> Callable:
    """Wrap Anthropic messages create method."""

    @functools.wraps(original_func)
    def wrapper(*args, **kwargs):
        model = kwargs.get("model", "unknown")
        messages = kwargs.get("messages", [])
        temperature = kwargs.get("temperature")
        max_tokens = kwargs.get("max_tokens")
        stream = kwargs.get("stream", False)

        with trace_llm_call(
            operation_name="anthropic.messages.create",
            model=model,
            provider="anthropic",
            streaming=stream,
        ) as span:
            # Record request
            SpanRecorder.record_request(
                span,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=stream,
            )

            try:
                response = original_func(*args, **kwargs)

                # Handle streaming vs non-streaming
                if stream:
                    return _wrap_anthropic_stream(response, span, model)
                else:
                    _record_anthropic_response(response, span, model)
                    return response

            except Exception as e:
                span.set_attribute("error", True)
                span.set_attribute("error.type", type(e).__name__)
                span.set_attribute("error.message", str(e))
                raise

    return wrapper


def _wrap_anthropic_stream(stream: Iterator, span: Any, model: str) -> Iterator:
    """Wrap Anthropic streaming response."""
    chunk_count = 0
    content_buffer = []
    start_time = time.time()
    first_token_time = None
    prompt_tokens = None
    completion_tokens = 0

    try:
        for event in stream:
            chunk_count += 1

            # Record first token time
            if first_token_time is None and hasattr(event, "type") and event.type == "content_block_delta":
                first_token_time = time.time()

            # Extract content
            if hasattr(event, "type") and event.type == "content_block_delta":
                if hasattr(event, "delta") and hasattr(event.delta, "text"):
                    content = event.delta.text
                    content_buffer.append(content)
                    completion_tokens += _estimate_tokens(content)

            # Extract usage from final message
            if hasattr(event, "type") and event.type == "message_stop":
                if hasattr(event, "message") and hasattr(event.message, "usage"):
                    prompt_tokens = event.message.usage.input_tokens
                    completion_tokens = event.message.usage.output_tokens

            yield event

        # Record final metrics
        full_content = "".join(content_buffer)
        ttft_ms = (first_token_time - start_time) * 1000 if first_token_time else None

        # Calculate cost
        cost_usd = None
        if prompt_tokens and completion_tokens:
            cost_usd = _cost_calculator.calculate_cost(
                model, prompt_tokens, completion_tokens
            )

        SpanRecorder.record_response(
            span,
            content=full_content,
            finish_reason="stop",
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=prompt_tokens + completion_tokens if prompt_tokens else completion_tokens,
            cost_usd=cost_usd,
            ttft_ms=ttft_ms,
            chunk_count=chunk_count,
        )

    except Exception as e:
        span.set_attribute("error", True)
        span.set_attribute("error.type", type(e).__name__)
        span.set_attribute("error.message", str(e))
        raise


def _record_anthropic_response(response: Any, span: Any, model: str) -> None:
    """Record Anthropic response data."""
    content = ""
    if hasattr(response, "content") and len(response.content) > 0:
        # Anthropic returns a list of content blocks
        content = " ".join(
            block.text for block in response.content
            if hasattr(block, "text")
        )

    finish_reason = response.stop_reason if hasattr(response, "stop_reason") else None

    # Extract token usage
    prompt_tokens = None
    completion_tokens = None
    total_tokens = None

    if hasattr(response, "usage"):
        prompt_tokens = response.usage.input_tokens
        completion_tokens = response.usage.output_tokens
        total_tokens = prompt_tokens + completion_tokens

    # Calculate cost
    cost_usd = None
    if prompt_tokens and completion_tokens:
        cost_usd = _cost_calculator.calculate_cost(
            model, prompt_tokens, completion_tokens
        )

    SpanRecorder.record_response(
        span,
        content=content,
        finish_reason=finish_reason,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        total_tokens=total_tokens,
        cost_usd=cost_usd,
    )


def instrument_azure_openai(client: Any) -> Any:
    """
    Instrument Azure OpenAI client for automatic tracing.

    Azure OpenAI uses the same API as OpenAI, so we use the same instrumentation.

    Args:
        client: Azure OpenAI client instance

    Returns:
        Instrumented client

    Example:
        >>> from openai import AzureOpenAI
        >>> from llm_observatory import instrument_azure_openai
        >>>
        >>> client = AzureOpenAI(
        ...     api_key="...",
        ...     api_version="2024-02-01",
        ...     azure_endpoint="https://..."
        ... )
        >>> instrument_azure_openai(client)
    """
    # Azure OpenAI uses the same interface as OpenAI
    return instrument_openai(client)


def _estimate_tokens(text: str) -> int:
    """
    Estimate token count for text.

    This is a rough approximation: ~4 characters per token for English text.
    For accurate counts, use tiktoken or the provider's tokenizer.

    Args:
        text: Input text

    Returns:
        Estimated token count
    """
    return max(1, len(text) // 4)

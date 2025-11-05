# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
OpenTelemetry tracing integration for LLM Observatory.

This module provides OpenTelemetry tracing setup and utilities for capturing
LLM operations with full semantic conventions support.
"""

import time
from typing import Any, Dict, Optional
from contextlib import contextmanager

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter
from opentelemetry.sdk.resources import Resource, SERVICE_NAME, SERVICE_VERSION
from opentelemetry.trace import Status, StatusCode, SpanKind
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator


class TracingConfig:
    """Configuration for OpenTelemetry tracing."""

    def __init__(
        self,
        service_name: str,
        service_version: str = "0.1.0",
        otlp_endpoint: Optional[str] = None,
        insecure: bool = True,
        console_export: bool = False,
        batch_size: int = 512,
        max_export_batch_size: int = 512,
        export_timeout_millis: int = 30000,
    ):
        """
        Initialize tracing configuration.

        Args:
            service_name: Name of the service
            service_version: Version of the service
            otlp_endpoint: OTLP collector endpoint (e.g., "localhost:4317")
            insecure: Whether to use insecure connection
            console_export: Whether to also export to console (for debugging)
            batch_size: Batch size for span export
            max_export_batch_size: Maximum batch size
            export_timeout_millis: Export timeout in milliseconds
        """
        self.service_name = service_name
        self.service_version = service_version
        self.otlp_endpoint = otlp_endpoint
        self.insecure = insecure
        self.console_export = console_export
        self.batch_size = batch_size
        self.max_export_batch_size = max_export_batch_size
        self.export_timeout_millis = export_timeout_millis


class TracingManager:
    """Manages OpenTelemetry tracing lifecycle."""

    def __init__(self, config: TracingConfig):
        """
        Initialize tracing manager.

        Args:
            config: Tracing configuration
        """
        self.config = config
        self.tracer_provider: Optional[TracerProvider] = None
        self.tracer: Optional[trace.Tracer] = None

    def initialize(self) -> None:
        """Initialize OpenTelemetry tracing."""
        # Create resource with service information
        resource = Resource.create({
            SERVICE_NAME: self.config.service_name,
            SERVICE_VERSION: self.config.service_version,
            "telemetry.sdk.name": "llm-observatory",
            "telemetry.sdk.language": "python",
            "telemetry.sdk.version": "0.1.0",
        })

        # Create tracer provider
        self.tracer_provider = TracerProvider(resource=resource)

        # Add OTLP exporter if endpoint is configured
        if self.config.otlp_endpoint:
            otlp_exporter = OTLPSpanExporter(
                endpoint=self.config.otlp_endpoint,
                insecure=self.config.insecure,
            )
            span_processor = BatchSpanProcessor(
                otlp_exporter,
                max_queue_size=2048,
                max_export_batch_size=self.config.max_export_batch_size,
                export_timeout_millis=self.config.export_timeout_millis,
            )
            self.tracer_provider.add_span_processor(span_processor)

        # Add console exporter for debugging
        if self.config.console_export:
            console_exporter = ConsoleSpanExporter()
            self.tracer_provider.add_span_processor(
                BatchSpanProcessor(console_exporter)
            )

        # Set global tracer provider
        trace.set_tracer_provider(self.tracer_provider)

        # Create tracer
        self.tracer = trace.get_tracer("llm-observatory")

    def shutdown(self) -> None:
        """Shutdown tracing and flush remaining spans."""
        if self.tracer_provider:
            self.tracer_provider.shutdown()

    def get_tracer(self) -> trace.Tracer:
        """Get the configured tracer."""
        if not self.tracer:
            raise RuntimeError("Tracing not initialized. Call initialize() first.")
        return self.tracer


# Global tracing manager instance
_tracing_manager: Optional[TracingManager] = None


def initialize_tracing(config: TracingConfig) -> None:
    """
    Initialize global tracing.

    Args:
        config: Tracing configuration
    """
    global _tracing_manager
    _tracing_manager = TracingManager(config)
    _tracing_manager.initialize()


def shutdown_tracing() -> None:
    """Shutdown tracing and flush remaining spans."""
    global _tracing_manager
    if _tracing_manager:
        _tracing_manager.shutdown()
        _tracing_manager = None


def get_tracer() -> trace.Tracer:
    """
    Get the global tracer.

    Returns:
        OpenTelemetry tracer

    Raises:
        RuntimeError: If tracing is not initialized
    """
    if not _tracing_manager:
        raise RuntimeError("Tracing not initialized. Initialize LLMObservatory first.")
    return _tracing_manager.get_tracer()


def get_current_span() -> trace.Span:
    """
    Get the current active span.

    Returns:
        Current span or a non-recording span if no span is active
    """
    return trace.get_current_span()


def add_span_attribute(key: str, value: Any) -> None:
    """
    Add an attribute to the current span.

    Args:
        key: Attribute key
        value: Attribute value
    """
    span = get_current_span()
    if span.is_recording():
        span.set_attribute(key, value)


def add_span_event(name: str, attributes: Optional[Dict[str, Any]] = None) -> None:
    """
    Add an event to the current span.

    Args:
        name: Event name
        attributes: Event attributes
    """
    span = get_current_span()
    if span.is_recording():
        span.add_event(name, attributes or {})


@contextmanager
def trace_llm_call(
    operation_name: str,
    model: str,
    provider: str,
    **attributes
):
    """
    Context manager for tracing LLM calls.

    Args:
        operation_name: Name of the operation (e.g., "chat.completion")
        model: Model identifier
        provider: Provider name
        **attributes: Additional span attributes

    Yields:
        Span object
    """
    tracer = get_tracer()

    with tracer.start_as_current_span(
        operation_name,
        kind=SpanKind.CLIENT,
    ) as span:
        # Set standard LLM attributes
        span.set_attribute("llm.provider", provider)
        span.set_attribute("llm.model", model)
        span.set_attribute("llm.operation", operation_name)

        # Set additional attributes
        for key, value in attributes.items():
            span.set_attribute(key, value)

        # Record start time
        start_time = time.time()

        try:
            yield span
        except Exception as e:
            # Record error
            span.set_status(Status(StatusCode.ERROR))
            span.record_exception(e)
            raise
        finally:
            # Record duration
            duration_ms = (time.time() - start_time) * 1000
            span.set_attribute("llm.duration_ms", duration_ms)


class SpanRecorder:
    """Helper class for recording LLM span data."""

    @staticmethod
    def record_request(
        span: trace.Span,
        messages: Optional[list] = None,
        prompt: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        top_p: Optional[float] = None,
        **kwargs
    ) -> None:
        """
        Record LLM request parameters.

        Args:
            span: OpenTelemetry span
            messages: Chat messages (for chat models)
            prompt: Text prompt (for completion models)
            temperature: Temperature parameter
            max_tokens: Maximum tokens to generate
            top_p: Top-p sampling parameter
            **kwargs: Additional parameters
        """
        if not span.is_recording():
            return

        # Record messages or prompt
        if messages:
            span.set_attribute("llm.request.type", "chat")
            span.set_attribute("llm.request.message_count", len(messages))
            # Record first message for context (truncated)
            if messages:
                first_msg = str(messages[0])[:500]
                span.set_attribute("llm.request.first_message", first_msg)
        elif prompt:
            span.set_attribute("llm.request.type", "completion")
            span.set_attribute("llm.request.prompt", prompt[:500])  # Truncate

        # Record parameters
        if temperature is not None:
            span.set_attribute("llm.request.temperature", temperature)
        if max_tokens is not None:
            span.set_attribute("llm.request.max_tokens", max_tokens)
        if top_p is not None:
            span.set_attribute("llm.request.top_p", top_p)

        # Record additional parameters
        for key, value in kwargs.items():
            if value is not None:
                span.set_attribute(f"llm.request.{key}", str(value))

    @staticmethod
    def record_response(
        span: trace.Span,
        content: Optional[str] = None,
        finish_reason: Optional[str] = None,
        prompt_tokens: Optional[int] = None,
        completion_tokens: Optional[int] = None,
        total_tokens: Optional[int] = None,
        cost_usd: Optional[float] = None,
        ttft_ms: Optional[float] = None,
        **kwargs
    ) -> None:
        """
        Record LLM response data.

        Args:
            span: OpenTelemetry span
            content: Response content
            finish_reason: Reason for completion (stop, length, etc.)
            prompt_tokens: Number of prompt tokens
            completion_tokens: Number of completion tokens
            total_tokens: Total tokens
            cost_usd: Cost in USD
            ttft_ms: Time to first token in milliseconds
            **kwargs: Additional response data
        """
        if not span.is_recording():
            return

        # Record content (truncated)
        if content:
            span.set_attribute("llm.response.content", content[:500])

        # Record finish reason
        if finish_reason:
            span.set_attribute("llm.response.finish_reason", finish_reason)

        # Record token usage
        if prompt_tokens is not None:
            span.set_attribute("llm.usage.prompt_tokens", prompt_tokens)
        if completion_tokens is not None:
            span.set_attribute("llm.usage.completion_tokens", completion_tokens)
        if total_tokens is not None:
            span.set_attribute("llm.usage.total_tokens", total_tokens)

        # Record cost
        if cost_usd is not None:
            span.set_attribute("llm.cost.total_usd", cost_usd)

        # Record TTFT
        if ttft_ms is not None:
            span.set_attribute("llm.metrics.ttft_ms", ttft_ms)

        # Record additional data
        for key, value in kwargs.items():
            if value is not None:
                span.set_attribute(f"llm.response.{key}", str(value))

    @staticmethod
    def record_streaming_chunk(
        span: trace.Span,
        chunk_index: int,
        chunk_content: str,
        timestamp_ms: Optional[float] = None
    ) -> None:
        """
        Record a streaming chunk event.

        Args:
            span: OpenTelemetry span
            chunk_index: Index of the chunk
            chunk_content: Content of the chunk
            timestamp_ms: Timestamp of the chunk
        """
        if not span.is_recording():
            return

        attributes = {
            "chunk.index": chunk_index,
            "chunk.content": chunk_content[:100],  # Truncate
        }

        if timestamp_ms is not None:
            attributes["chunk.timestamp_ms"] = timestamp_ms

        span.add_event("llm.streaming.chunk", attributes)

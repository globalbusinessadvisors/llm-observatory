# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""Tests for tracing module."""

import pytest
from unittest.mock import Mock, patch, MagicMock
from llm_observatory.tracing import (
    TracingConfig,
    TracingManager,
    initialize_tracing,
    shutdown_tracing,
    get_tracer,
    get_current_span,
    add_span_attribute,
    add_span_event,
    trace_llm_call,
    SpanRecorder,
)


class TestTracingConfig:
    """Test TracingConfig class."""

    def test_default_config(self):
        """Test default configuration."""
        config = TracingConfig(service_name="test-service")
        assert config.service_name == "test-service"
        assert config.service_version == "0.1.0"
        assert config.insecure is True
        assert config.console_export is False

    def test_custom_config(self):
        """Test custom configuration."""
        config = TracingConfig(
            service_name="my-service",
            service_version="2.0.0",
            otlp_endpoint="localhost:5000",
            insecure=False,
            console_export=True,
        )
        assert config.service_name == "my-service"
        assert config.service_version == "2.0.0"
        assert config.otlp_endpoint == "localhost:5000"
        assert config.insecure is False
        assert config.console_export is True


class TestTracingManager:
    """Test TracingManager class."""

    def test_initialization(self):
        """Test manager initialization."""
        config = TracingConfig(service_name="test-service")
        manager = TracingManager(config)
        assert manager.config == config
        assert manager.tracer_provider is None
        assert manager.tracer is None

    @patch("llm_observatory.tracing.TracerProvider")
    @patch("llm_observatory.tracing.OTLPSpanExporter")
    @patch("llm_observatory.tracing.trace.set_tracer_provider")
    @patch("llm_observatory.tracing.trace.get_tracer")
    def test_initialize_with_otlp(
        self, mock_get_tracer, mock_set_provider, mock_otlp, mock_provider
    ):
        """Test initialization with OTLP endpoint."""
        config = TracingConfig(
            service_name="test-service",
            otlp_endpoint="localhost:4317",
        )
        manager = TracingManager(config)
        manager.initialize()

        # Should create tracer provider
        assert mock_provider.called

        # Should create OTLP exporter
        assert mock_otlp.called

    @patch("llm_observatory.tracing.TracerProvider")
    @patch("llm_observatory.tracing.trace.set_tracer_provider")
    @patch("llm_observatory.tracing.trace.get_tracer")
    def test_initialize_without_otlp(
        self, mock_get_tracer, mock_set_provider, mock_provider
    ):
        """Test initialization without OTLP endpoint."""
        config = TracingConfig(service_name="test-service", otlp_endpoint=None)
        manager = TracingManager(config)
        manager.initialize()

        # Should still create tracer provider
        assert mock_provider.called

    def test_get_tracer_before_init(self):
        """Test getting tracer before initialization."""
        config = TracingConfig(service_name="test-service")
        manager = TracingManager(config)

        with pytest.raises(RuntimeError, match="not initialized"):
            manager.get_tracer()


class TestGlobalTracingFunctions:
    """Test global tracing functions."""

    def test_initialize_and_get_tracer(self):
        """Test initializing and getting global tracer."""
        config = TracingConfig(service_name="test-service", otlp_endpoint=None)
        initialize_tracing(config)

        tracer = get_tracer()
        assert tracer is not None

        # Cleanup
        shutdown_tracing()

    def test_get_tracer_not_initialized(self):
        """Test getting tracer when not initialized."""
        # Make sure tracing is shutdown
        shutdown_tracing()

        with pytest.raises(RuntimeError, match="not initialized"):
            get_tracer()

    def test_shutdown_idempotent(self):
        """Test that shutdown is idempotent."""
        config = TracingConfig(service_name="test-service", otlp_endpoint=None)
        initialize_tracing(config)
        shutdown_tracing()
        # Should not raise
        shutdown_tracing()


class TestSpanRecorder:
    """Test SpanRecorder helper class."""

    def test_record_request_chat(self):
        """Test recording chat request."""
        mock_span = Mock()
        mock_span.is_recording.return_value = True

        messages = [
            {"role": "user", "content": "Hello"},
            {"role": "assistant", "content": "Hi there!"},
        ]

        SpanRecorder.record_request(
            mock_span,
            messages=messages,
            temperature=0.7,
            max_tokens=100,
        )

        # Should set attributes
        assert mock_span.set_attribute.called
        calls = mock_span.set_attribute.call_args_list
        attr_names = [call[0][0] for call in calls]

        assert "llm.request.type" in attr_names
        assert "llm.request.message_count" in attr_names
        assert "llm.request.temperature" in attr_names
        assert "llm.request.max_tokens" in attr_names

    def test_record_request_completion(self):
        """Test recording completion request."""
        mock_span = Mock()
        mock_span.is_recording.return_value = True

        SpanRecorder.record_request(
            mock_span,
            prompt="Test prompt",
            temperature=0.5,
        )

        # Should set attributes
        assert mock_span.set_attribute.called
        calls = mock_span.set_attribute.call_args_list
        attr_names = [call[0][0] for call in calls]

        assert "llm.request.type" in attr_names
        assert "llm.request.prompt" in attr_names

    def test_record_request_not_recording(self):
        """Test recording request when span is not recording."""
        mock_span = Mock()
        mock_span.is_recording.return_value = False

        SpanRecorder.record_request(mock_span, prompt="test")

        # Should not set attributes
        assert not mock_span.set_attribute.called

    def test_record_response(self):
        """Test recording response."""
        mock_span = Mock()
        mock_span.is_recording.return_value = True

        SpanRecorder.record_response(
            mock_span,
            content="Hello world",
            finish_reason="stop",
            prompt_tokens=10,
            completion_tokens=5,
            total_tokens=15,
            cost_usd=0.001,
        )

        # Should set attributes
        assert mock_span.set_attribute.called
        calls = mock_span.set_attribute.call_args_list
        attr_names = [call[0][0] for call in calls]

        assert "llm.response.content" in attr_names
        assert "llm.response.finish_reason" in attr_names
        assert "llm.usage.prompt_tokens" in attr_names
        assert "llm.usage.completion_tokens" in attr_names
        assert "llm.cost.total_usd" in attr_names

    def test_record_streaming_chunk(self):
        """Test recording streaming chunk."""
        mock_span = Mock()
        mock_span.is_recording.return_value = True

        SpanRecorder.record_streaming_chunk(
            mock_span,
            chunk_index=5,
            chunk_content="test",
            timestamp_ms=123.45,
        )

        # Should add event
        assert mock_span.add_event.called
        call_args = mock_span.add_event.call_args
        assert call_args[0][0] == "llm.streaming.chunk"
        assert "chunk.index" in call_args[0][1]


class TestTraceLLMCall:
    """Test trace_llm_call context manager."""

    def test_trace_llm_call_success(self):
        """Test tracing successful LLM call."""
        config = TracingConfig(service_name="test-service", otlp_endpoint=None)
        initialize_tracing(config)

        try:
            with trace_llm_call(
                operation_name="test.operation",
                model="gpt-4",
                provider="openai",
            ) as span:
                assert span is not None
                # Should set attributes
                # Note: We can't easily verify attributes without accessing internals
        finally:
            shutdown_tracing()

    def test_trace_llm_call_with_error(self):
        """Test tracing LLM call with error."""
        config = TracingConfig(service_name="test-service", otlp_endpoint=None)
        initialize_tracing(config)

        try:
            with pytest.raises(ValueError):
                with trace_llm_call(
                    operation_name="test.operation",
                    model="gpt-4",
                    provider="openai",
                ) as span:
                    raise ValueError("Test error")
        finally:
            shutdown_tracing()


class TestSpanUtilities:
    """Test span utility functions."""

    def test_get_current_span(self):
        """Test getting current span."""
        span = get_current_span()
        # Should return a span (even if non-recording)
        assert span is not None

    def test_add_span_attribute(self):
        """Test adding span attribute."""
        config = TracingConfig(service_name="test-service", otlp_endpoint=None)
        initialize_tracing(config)

        try:
            with trace_llm_call(
                operation_name="test", model="gpt-4", provider="openai"
            ):
                # Should not raise
                add_span_attribute("test.key", "test.value")
        finally:
            shutdown_tracing()

    def test_add_span_event(self):
        """Test adding span event."""
        config = TracingConfig(service_name="test-service", otlp_endpoint=None)
        initialize_tracing(config)

        try:
            with trace_llm_call(
                operation_name="test", model="gpt-4", provider="openai"
            ):
                # Should not raise
                add_span_event("test.event", {"key": "value"})
        finally:
            shutdown_tracing()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

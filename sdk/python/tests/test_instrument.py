# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""Tests for instrumentation module."""

import pytest
from unittest.mock import Mock, MagicMock, patch
from llm_observatory.instrument import (
    instrument_openai,
    instrument_anthropic,
    instrument_azure_openai,
    _estimate_tokens,
)


class TestEstimateTokens:
    """Test token estimation utility."""

    def test_estimate_tokens_short(self):
        """Test estimating tokens for short text."""
        tokens = _estimate_tokens("Hello")
        assert tokens >= 1
        assert tokens <= 5

    def test_estimate_tokens_long(self):
        """Test estimating tokens for long text."""
        long_text = "test " * 1000
        tokens = _estimate_tokens(long_text)
        assert tokens > 100
        assert tokens < 2000

    def test_estimate_tokens_empty(self):
        """Test estimating tokens for empty text."""
        tokens = _estimate_tokens("")
        assert tokens == 1  # Minimum is 1


class TestInstrumentOpenAI:
    """Test OpenAI instrumentation."""

    def test_instrument_openai_client(self):
        """Test instrumenting OpenAI client."""
        # Create mock client with proper attributes
        mock_client = Mock()
        mock_client.chat = Mock()
        mock_client.chat.completions = Mock()
        mock_client.chat.completions.create = Mock()

        # Remove any existing instrumentation attribute
        if hasattr(mock_client, "_llm_observatory_instrumented"):
            delattr(mock_client, "_llm_observatory_instrumented")

        # Instrument client
        result = instrument_openai(mock_client)

        # Should return same client
        assert result is mock_client

        # Should mark as instrumented
        assert hasattr(mock_client, "_llm_observatory_instrumented")
        assert mock_client._llm_observatory_instrumented == True

    def test_instrument_openai_already_instrumented(self):
        """Test instrumenting already instrumented client."""
        mock_client = Mock()
        mock_client._llm_observatory_instrumented = True
        mock_client.chat = Mock()
        mock_client.chat.completions = Mock()
        original_create = Mock()
        mock_client.chat.completions.create = original_create

        # Instrument client (should be no-op)
        result = instrument_openai(mock_client)

        # Should return same client
        assert result is mock_client

        # Should not change the create method
        assert mock_client.chat.completions.create is original_create

    def test_instrument_openai_chat_wrapped(self):
        """Test that chat.completions.create is wrapped."""
        mock_client = Mock()
        mock_client.chat = Mock()
        mock_client.chat.completions = Mock()

        # Create actual function to be wrapped
        original_create = lambda *args, **kwargs: Mock()
        mock_client.chat.completions.create = original_create

        # Instrument client
        instrument_openai(mock_client)

        # Should wrap the method (function identity should change)
        assert mock_client.chat.completions.create != original_create

    def test_instrument_openai_completions_wrapped(self):
        """Test that completions.create is wrapped."""
        mock_client = Mock()
        mock_client.chat = Mock()
        mock_client.chat.completions = Mock()
        mock_client.chat.completions.create = Mock()
        mock_client.completions = Mock()

        # Create actual function to be wrapped
        original_create = lambda *args, **kwargs: Mock()
        mock_client.completions.create = original_create

        # Instrument client
        instrument_openai(mock_client)

        # Should wrap the method (function identity should change)
        assert mock_client.completions.create != original_create


class TestInstrumentAnthropic:
    """Test Anthropic instrumentation."""

    def test_instrument_anthropic_client(self):
        """Test instrumenting Anthropic client."""
        # Create mock client
        mock_client = Mock()
        mock_client.messages = Mock()
        mock_client.messages.create = Mock()

        # Remove any existing instrumentation attribute
        if hasattr(mock_client, "_llm_observatory_instrumented"):
            delattr(mock_client, "_llm_observatory_instrumented")

        # Instrument client
        result = instrument_anthropic(mock_client)

        # Should return same client
        assert result is mock_client

        # Should mark as instrumented
        assert hasattr(mock_client, "_llm_observatory_instrumented")
        assert mock_client._llm_observatory_instrumented == True

    def test_instrument_anthropic_already_instrumented(self):
        """Test instrumenting already instrumented Anthropic client."""
        mock_client = Mock()
        mock_client._llm_observatory_instrumented = True
        mock_client.messages = Mock()
        original_create = Mock()
        mock_client.messages.create = original_create

        # Instrument client (should be no-op)
        result = instrument_anthropic(mock_client)

        # Should return same client
        assert result is mock_client

        # Should not change the create method
        assert mock_client.messages.create is original_create

    def test_instrument_anthropic_messages_wrapped(self):
        """Test that messages.create is wrapped."""
        mock_client = Mock()
        mock_client.messages = Mock()

        # Create actual function to be wrapped
        original_create = lambda *args, **kwargs: Mock()
        mock_client.messages.create = original_create

        # Instrument client
        instrument_anthropic(mock_client)

        # Should wrap the method (function identity should change)
        assert mock_client.messages.create != original_create


class TestInstrumentAzureOpenAI:
    """Test Azure OpenAI instrumentation."""

    def test_instrument_azure_openai(self):
        """Test instrumenting Azure OpenAI client."""
        # Azure OpenAI uses same interface as OpenAI
        mock_client = Mock()
        mock_client.chat = Mock()
        mock_client.chat.completions = Mock()
        mock_client.chat.completions.create = Mock()

        # Remove any existing instrumentation attribute
        if hasattr(mock_client, "_llm_observatory_instrumented"):
            delattr(mock_client, "_llm_observatory_instrumented")

        # Instrument client
        result = instrument_azure_openai(mock_client)

        # Should return same client
        assert result is mock_client

        # Should mark as instrumented (via instrument_openai)
        assert hasattr(mock_client, "_llm_observatory_instrumented")
        assert mock_client._llm_observatory_instrumented == True


class TestStreamingIntegration:
    """Test streaming response handling."""

    @patch("llm_observatory.tracing.get_tracer")
    def test_openai_streaming_wrapper(self, mock_get_tracer):
        """Test OpenAI streaming response wrapper."""
        # Create mock client
        mock_client = Mock()
        mock_client.chat = Mock()
        mock_client.chat.completions = Mock()

        # Create mock response chunks
        def create_mock_chunk(content, is_last=False):
            chunk = Mock()
            chunk.choices = [Mock()]
            chunk.choices[0].delta = Mock()
            chunk.choices[0].delta.content = content
            if is_last:
                chunk.usage = Mock()
                chunk.usage.prompt_tokens = 10
                chunk.usage.completion_tokens = 20
            else:
                chunk.usage = None
            return chunk

        # Mock streaming response
        mock_stream = [
            create_mock_chunk("Hello"),
            create_mock_chunk(" world"),
            create_mock_chunk("!", is_last=True),
        ]

        mock_client.chat.completions.create = Mock(return_value=iter(mock_stream))

        # Mock tracer
        mock_span = Mock()
        mock_tracer = Mock()
        mock_tracer.start_as_current_span = MagicMock()
        mock_tracer.start_as_current_span.return_value.__enter__ = Mock(return_value=mock_span)
        mock_tracer.start_as_current_span.return_value.__exit__ = Mock(return_value=False)
        mock_get_tracer.return_value = mock_tracer

        # Instrument client
        instrument_openai(mock_client)

        # Make streaming call
        response = mock_client.chat.completions.create(
            model="gpt-4",
            messages=[{"role": "user", "content": "Test"}],
            stream=True,
        )

        # Consume stream
        chunks = list(response)
        assert len(chunks) == 3


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

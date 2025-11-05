# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""Integration tests for LLM Observatory SDK."""

import pytest
from unittest.mock import Mock, MagicMock, patch
from llm_observatory import (
    LLMObservatory,
    instrument_openai,
    instrument_anthropic,
    CostCalculator,
    ContextWindowOptimizer,
)


class TestEndToEndOpenAI:
    """End-to-end tests with OpenAI instrumentation."""

    @patch("llm_observatory.tracing.get_tracer")
    def test_basic_openai_flow(self, mock_get_tracer):
        """Test basic OpenAI instrumentation flow."""
        # Initialize observatory
        observatory = LLMObservatory(
            service_name="test-app",
            otlp_endpoint=None,
            auto_shutdown=False,
        )

        try:
            # Create mock OpenAI client
            mock_client = Mock()
            mock_client.chat = Mock()
            mock_client.chat.completions = Mock()

            # Create mock response
            mock_response = Mock()
            mock_response.choices = [Mock()]
            mock_response.choices[0].message = Mock()
            mock_response.choices[0].message.content = "Hello! How can I help?"
            mock_response.choices[0].finish_reason = "stop"
            mock_response.usage = Mock()
            mock_response.usage.prompt_tokens = 10
            mock_response.usage.completion_tokens = 8
            mock_response.usage.total_tokens = 18

            # Mock the create method
            mock_client.chat.completions.create = Mock(return_value=mock_response)

            # Mock tracer
            mock_span = Mock()
            mock_tracer = Mock()
            mock_tracer.start_as_current_span = MagicMock()
            mock_tracer.start_as_current_span.return_value.__enter__ = Mock(
                return_value=mock_span
            )
            mock_tracer.start_as_current_span.return_value.__exit__ = Mock(
                return_value=False
            )
            mock_get_tracer.return_value = mock_tracer

            # Instrument client
            instrument_openai(mock_client)

            # Make a call
            response = mock_client.chat.completions.create(
                model="gpt-4",
                messages=[{"role": "user", "content": "Hello"}],
            )

            # Verify response
            assert response is not None
            assert response.choices[0].message.content == "Hello! How can I help?"

            # Verify cost calculation
            cost = observatory.cost_calculator.calculate_cost("gpt-4", 10, 8)
            assert cost is not None
            assert cost > 0

        finally:
            observatory.shutdown()

    @patch("llm_observatory.tracing.get_tracer")
    def test_openai_streaming_flow(self, mock_get_tracer):
        """Test OpenAI streaming instrumentation flow."""
        observatory = LLMObservatory(
            service_name="test-app",
            otlp_endpoint=None,
            auto_shutdown=False,
        )

        try:
            # Create mock client
            mock_client = Mock()
            mock_client.chat = Mock()
            mock_client.chat.completions = Mock()

            # Create mock streaming chunks
            def create_chunk(content):
                chunk = Mock()
                chunk.choices = [Mock()]
                chunk.choices[0].delta = Mock()
                chunk.choices[0].delta.content = content
                chunk.usage = None
                return chunk

            final_chunk = create_chunk("")
            final_chunk.usage = Mock()
            final_chunk.usage.prompt_tokens = 10
            final_chunk.usage.completion_tokens = 15

            mock_stream = [
                create_chunk("Hello"),
                create_chunk(" world"),
                final_chunk,
            ]

            mock_client.chat.completions.create = Mock(return_value=iter(mock_stream))

            # Mock tracer
            mock_span = Mock()
            mock_tracer = Mock()
            mock_tracer.start_as_current_span = MagicMock()
            mock_tracer.start_as_current_span.return_value.__enter__ = Mock(
                return_value=mock_span
            )
            mock_tracer.start_as_current_span.return_value.__exit__ = Mock(
                return_value=False
            )
            mock_get_tracer.return_value = mock_tracer

            # Instrument client
            instrument_openai(mock_client)

            # Make streaming call
            stream = mock_client.chat.completions.create(
                model="gpt-4",
                messages=[{"role": "user", "content": "Hello"}],
                stream=True,
            )

            # Consume stream
            chunks = list(stream)
            assert len(chunks) == 3

        finally:
            observatory.shutdown()


class TestEndToEndAnthropic:
    """End-to-end tests with Anthropic instrumentation."""

    @patch("llm_observatory.tracing.get_tracer")
    def test_basic_anthropic_flow(self, mock_get_tracer):
        """Test basic Anthropic instrumentation flow."""
        observatory = LLMObservatory(
            service_name="test-app",
            otlp_endpoint=None,
            auto_shutdown=False,
        )

        try:
            # Create mock Anthropic client
            mock_client = Mock()
            mock_client.messages = Mock()

            # Create mock response
            mock_response = Mock()
            mock_response.content = [Mock()]
            mock_response.content[0].text = "Hello! I'm Claude."
            mock_response.stop_reason = "end_turn"
            mock_response.usage = Mock()
            mock_response.usage.input_tokens = 10
            mock_response.usage.output_tokens = 8

            mock_client.messages.create = Mock(return_value=mock_response)

            # Mock tracer
            mock_span = Mock()
            mock_tracer = Mock()
            mock_tracer.start_as_current_span = MagicMock()
            mock_tracer.start_as_current_span.return_value.__enter__ = Mock(
                return_value=mock_span
            )
            mock_tracer.start_as_current_span.return_value.__exit__ = Mock(
                return_value=False
            )
            mock_get_tracer.return_value = mock_tracer

            # Instrument client
            instrument_anthropic(mock_client)

            # Make a call
            response = mock_client.messages.create(
                model="claude-3-opus-20240229",
                messages=[{"role": "user", "content": "Hello"}],
                max_tokens=100,
            )

            # Verify response
            assert response is not None
            assert response.content[0].text == "Hello! I'm Claude."

            # Verify cost calculation
            cost = observatory.cost_calculator.calculate_cost(
                "claude-3-opus-20240229", 10, 8
            )
            assert cost is not None
            assert cost > 0

        finally:
            observatory.shutdown()


class TestContextWindowIntegration:
    """Integration tests for context window optimizer."""

    def test_context_window_with_cost_tracking(self):
        """Test context window optimization with cost tracking."""
        optimizer = ContextWindowOptimizer("gpt-4", max_tokens=1000)
        calculator = CostCalculator()

        # Create conversation
        messages = [
            {"role": "system", "content": "You are a helpful assistant."},
        ]
        for i in range(20):
            messages.append({"role": "user", "content": f"Question {i}" * 50})
            messages.append({"role": "assistant", "content": f"Answer {i}" * 50})

        # Check context window
        check = optimizer.check_context_window(messages)
        assert check["should_optimize"] is True

        # Optimize messages
        optimized = optimizer.optimize_messages(messages)
        assert len(optimized) < len(messages)

        # Verify optimized messages fit
        check_optimized = optimizer.check_context_window(optimized)
        assert check_optimized["fits"] is True

        # Calculate estimated cost for optimized conversation
        estimated_tokens = check_optimized["estimated_tokens"]
        # Assume 70% prompt, 30% completion
        cost = calculator.estimate_cost("gpt-4", estimated_tokens, prompt_ratio=0.7)
        assert cost is not None
        assert cost > 0


class TestMultiProviderIntegration:
    """Test using multiple providers in same application."""

    @patch("llm_observatory.tracing.get_tracer")
    def test_multiple_providers(self, mock_get_tracer):
        """Test instrumenting multiple providers."""
        observatory = LLMObservatory(
            service_name="multi-provider-app",
            otlp_endpoint=None,
            auto_shutdown=False,
        )

        try:
            # Mock tracer
            mock_span = Mock()
            mock_tracer = Mock()
            mock_tracer.start_as_current_span = MagicMock()
            mock_tracer.start_as_current_span.return_value.__enter__ = Mock(
                return_value=mock_span
            )
            mock_tracer.start_as_current_span.return_value.__exit__ = Mock(
                return_value=False
            )
            mock_get_tracer.return_value = mock_tracer

            # Create mock OpenAI client
            openai_client = Mock()
            openai_client.chat = Mock()
            openai_client.chat.completions = Mock()
            openai_client.chat.completions.create = Mock()

            # Create mock Anthropic client
            anthropic_client = Mock()
            anthropic_client.messages = Mock()
            anthropic_client.messages.create = Mock()

            # Instrument both
            instrument_openai(openai_client)
            instrument_anthropic(anthropic_client)

            # Both should be instrumented
            assert hasattr(openai_client, "_llm_observatory_instrumented")
            assert hasattr(anthropic_client, "_llm_observatory_instrumented")

            # Compare costs
            costs = observatory.cost_calculator.compare_models(
                ["gpt-4", "claude-3-opus-20240229", "gpt-3.5-turbo"],
                prompt_tokens=1000,
                completion_tokens=500,
            )

            assert len(costs) == 3
            assert all(cost is not None for cost in costs.values())

        finally:
            observatory.shutdown()


class TestErrorHandling:
    """Test error handling in instrumentation."""

    @patch("llm_observatory.tracing.get_tracer")
    def test_llm_error_captured(self, mock_get_tracer):
        """Test that LLM errors are captured in spans."""
        observatory = LLMObservatory(
            service_name="test-app",
            otlp_endpoint=None,
            auto_shutdown=False,
        )

        try:
            # Create mock client that raises error
            mock_client = Mock()
            mock_client.chat = Mock()
            mock_client.chat.completions = Mock()
            mock_client.chat.completions.create = Mock(
                side_effect=Exception("API Error")
            )

            # Mock tracer
            mock_span = Mock()
            mock_tracer = Mock()
            mock_tracer.start_as_current_span = MagicMock()
            mock_tracer.start_as_current_span.return_value.__enter__ = Mock(
                return_value=mock_span
            )
            mock_tracer.start_as_current_span.return_value.__exit__ = Mock(
                return_value=False
            )
            mock_get_tracer.return_value = mock_tracer

            # Instrument client
            instrument_openai(mock_client)

            # Make call that will fail
            with pytest.raises(Exception, match="API Error"):
                mock_client.chat.completions.create(
                    model="gpt-4",
                    messages=[{"role": "user", "content": "Hello"}],
                )

            # Verify error was recorded on span
            assert mock_span.set_attribute.called

        finally:
            observatory.shutdown()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

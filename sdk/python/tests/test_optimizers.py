# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""Tests for context window optimizer."""

import pytest
from llm_observatory.optimizers import (
    ContextWindowOptimizer,
    ContextWindowConfig,
    MODEL_CONTEXT_WINDOWS,
)


class TestContextWindowOptimizer:
    """Test ContextWindowOptimizer class."""

    def test_initialization(self):
        """Test optimizer initialization."""
        optimizer = ContextWindowOptimizer("gpt-4")
        assert optimizer.model == "gpt-4"
        assert optimizer.max_tokens == 8192
        assert optimizer.warning_threshold == 0.8
        assert optimizer.action_threshold == 0.9

    def test_custom_thresholds(self):
        """Test custom threshold configuration."""
        optimizer = ContextWindowOptimizer(
            "gpt-4",
            warning_threshold=0.7,
            action_threshold=0.85,
        )
        assert optimizer.warning_threshold == 0.7
        assert optimizer.action_threshold == 0.85

    def test_estimate_tokens(self):
        """Test token estimation."""
        optimizer = ContextWindowOptimizer("gpt-4")
        # Roughly 4 characters per token
        tokens = optimizer.estimate_tokens("Hello, world! This is a test.")
        assert tokens > 0
        assert tokens < 100

    def test_estimate_messages_tokens(self):
        """Test message token estimation."""
        optimizer = ContextWindowOptimizer("gpt-4")
        messages = [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Hello!"},
            {"role": "assistant", "content": "Hi! How can I help you?"},
        ]
        tokens = optimizer.estimate_messages_tokens(messages)
        assert tokens > 0
        assert tokens < 1000

    def test_check_context_window_fits(self):
        """Test checking context window when messages fit."""
        optimizer = ContextWindowOptimizer("gpt-4")
        messages = [
            {"role": "user", "content": "Short message."},
        ]
        check = optimizer.check_context_window(messages)
        assert check["fits"] is True
        assert check["should_warn"] is False
        assert check["should_optimize"] is False
        assert check["utilization"] < 0.1

    def test_check_context_window_warning(self):
        """Test warning threshold."""
        optimizer = ContextWindowOptimizer("gpt-4", warning_threshold=0.1)
        # Create a long message
        long_message = "test " * 1000
        messages = [{"role": "user", "content": long_message}]
        check = optimizer.check_context_window(messages)
        assert check["should_warn"] is True

    def test_truncate_old_strategy(self):
        """Test truncate_old optimization strategy."""
        optimizer = ContextWindowOptimizer("gpt-4", max_tokens=1000)
        # Create many messages
        messages = [
            {"role": "system", "content": "System prompt."},
        ]
        for i in range(50):
            messages.append({"role": "user", "content": f"Message {i}" * 50})

        optimized = optimizer.optimize_messages(messages, strategy="truncate_old")
        # Should have fewer messages
        assert len(optimized) < len(messages)
        # Should keep system message
        assert optimized[0]["role"] == "system"
        # Should fit in context window
        check = optimizer.check_context_window(optimized)
        assert check["fits"] is True

    def test_truncate_middle_strategy(self):
        """Test truncate_middle optimization strategy."""
        optimizer = ContextWindowOptimizer("gpt-4", max_tokens=1000)
        messages = [
            {"role": "system", "content": "System prompt."},
        ]
        for i in range(50):
            messages.append({"role": "user", "content": f"Message {i}" * 50})

        optimized = optimizer.optimize_messages(messages, strategy="truncate_middle")
        # Should have fewer messages
        assert len(optimized) < len(messages)
        # Should keep system message
        assert optimized[0]["role"] == "system"

    def test_get_optimization_suggestion(self):
        """Test getting optimization suggestions."""
        optimizer = ContextWindowOptimizer("gpt-4", warning_threshold=0.1)
        messages = [{"role": "user", "content": "test " * 1000}]
        suggestion = optimizer.get_optimization_suggestion(messages)
        assert suggestion is not None
        assert "utilization" in suggestion.lower() or "full" in suggestion.lower()

    def test_model_context_windows(self):
        """Test that context windows are defined for major models."""
        assert "gpt-4" in MODEL_CONTEXT_WINDOWS
        assert "gpt-4o" in MODEL_CONTEXT_WINDOWS
        assert "claude-3-opus-20240229" in MODEL_CONTEXT_WINDOWS
        assert "gemini-1.5-pro" in MODEL_CONTEXT_WINDOWS

    def test_unknown_model_fallback(self):
        """Test fallback for unknown models."""
        optimizer = ContextWindowOptimizer("unknown-model-xyz")
        # Should use default fallback
        assert optimizer.max_tokens == 4096


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

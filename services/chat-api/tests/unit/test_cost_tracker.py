"""Tests for cost tracking service."""

import pytest
from app.services.cost_tracker import CostTracker


class TestCostTracker:
    """Test cost tracking functionality."""

    def test_calculate_gpt4_cost(self):
        """Test GPT-4 cost calculation."""
        cost = CostTracker.calculate_cost(
            model="gpt-4",
            input_tokens=1000,
            output_tokens=500,
        )
        # Expected: (1000/1000 * 0.03) + (500/1000 * 0.06) = 0.03 + 0.03 = 0.06
        assert cost == 0.06

    def test_calculate_gpt35_cost(self):
        """Test GPT-3.5-turbo cost calculation."""
        cost = CostTracker.calculate_cost(
            model="gpt-3.5-turbo",
            input_tokens=1000,
            output_tokens=500,
        )
        # Expected: (1000/1000 * 0.0015) + (500/1000 * 0.002) = 0.0015 + 0.001 = 0.0025
        assert cost == 0.0025

    def test_calculate_claude_opus_cost(self):
        """Test Claude Opus cost calculation."""
        cost = CostTracker.calculate_cost(
            model="claude-3-opus-20240229",
            input_tokens=1000,
            output_tokens=500,
        )
        # Expected: (1000/1000 * 0.015) + (500/1000 * 0.075) = 0.015 + 0.0375 = 0.0525
        assert cost == 0.0525

    def test_unknown_model_returns_zero(self):
        """Test that unknown models return zero cost."""
        cost = CostTracker.calculate_cost(
            model="unknown-model",
            input_tokens=1000,
            output_tokens=500,
        )
        assert cost == 0.0

    def test_normalize_model_name_gpt4(self):
        """Test GPT-4 model name normalization."""
        assert CostTracker._normalize_model_name("gpt-4-0613") == "gpt-4"
        assert CostTracker._normalize_model_name("gpt-4-turbo-preview") == "gpt-4-turbo"
        assert CostTracker._normalize_model_name("gpt-4-32k-0613") == "gpt-4-32k"

    def test_normalize_model_name_claude(self):
        """Test Claude model name normalization."""
        assert CostTracker._normalize_model_name("claude-3-opus-20240229") == "claude-3-opus-20240229"
        assert CostTracker._normalize_model_name("claude-3-sonnet-20240229") == "claude-3-sonnet-20240229"

    def test_get_model_pricing(self):
        """Test getting model pricing information."""
        pricing = CostTracker.get_model_pricing("gpt-4")
        assert pricing is not None
        assert "input" in pricing
        assert "output" in pricing
        assert pricing["input"] == 0.03
        assert pricing["output"] == 0.06

    def test_estimate_cost(self):
        """Test cost estimation from text."""
        text = "This is a test message " * 100  # ~100 words
        cost = CostTracker.estimate_cost(
            model="gpt-4",
            text=text,
            estimated_response_tokens=50,
        )
        assert cost > 0
        assert isinstance(cost, float)

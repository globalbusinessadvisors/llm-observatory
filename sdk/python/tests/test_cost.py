# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""Tests for cost calculation module."""

import pytest
from llm_observatory.cost import CostCalculator, PricingDatabase, Pricing


class TestPricing:
    """Test Pricing dataclass."""

    def test_calculate_cost(self):
        """Test cost calculation."""
        pricing = Pricing("gpt-4", 0.03, 0.06)
        cost = pricing.calculate_cost(1000, 500)
        # (1000/1000 * 0.03) + (500/1000 * 0.06) = 0.03 + 0.03 = 0.06
        assert abs(cost - 0.06) < 0.0001

    def test_calculate_cost_breakdown(self):
        """Test cost breakdown calculation."""
        pricing = Pricing("gpt-4", 0.03, 0.06)
        prompt_cost, completion_cost, total = pricing.calculate_cost_breakdown(1000, 500)
        assert abs(prompt_cost - 0.03) < 0.0001
        assert abs(completion_cost - 0.03) < 0.0001
        assert abs(total - 0.06) < 0.0001


class TestPricingDatabase:
    """Test PricingDatabase class."""

    def test_get_pricing_openai(self):
        """Test getting OpenAI pricing."""
        db = PricingDatabase()
        pricing = db.get_pricing("gpt-4")
        assert pricing is not None
        assert pricing.model == "gpt-4"
        assert pricing.prompt_cost_per_1k == 0.03
        assert pricing.completion_cost_per_1k == 0.06

    def test_get_pricing_anthropic(self):
        """Test getting Anthropic pricing."""
        db = PricingDatabase()
        pricing = db.get_pricing("claude-3-opus-20240229")
        assert pricing is not None
        assert pricing.model == "claude-3-opus-20240229"
        assert pricing.prompt_cost_per_1k == 0.015

    def test_get_pricing_unknown_model(self):
        """Test getting pricing for unknown model."""
        db = PricingDatabase()
        pricing = db.get_pricing("unknown-model")
        assert pricing is None

    def test_has_pricing(self):
        """Test checking if pricing exists."""
        db = PricingDatabase()
        assert db.has_pricing("gpt-4") is True
        assert db.has_pricing("unknown-model") is False

    def test_list_models(self):
        """Test listing all models."""
        db = PricingDatabase()
        models = db.list_models()
        assert len(models) > 0
        assert "gpt-4" in models
        assert "claude-3-opus-20240229" in models

    def test_add_custom_pricing(self):
        """Test adding custom pricing."""
        db = PricingDatabase()
        custom = Pricing("custom-model", 0.01, 0.02)
        db.add_pricing(custom)
        pricing = db.get_pricing("custom-model")
        assert pricing is not None
        assert pricing.model == "custom-model"


class TestCostCalculator:
    """Test CostCalculator class."""

    def test_calculate_cost(self):
        """Test cost calculation."""
        calc = CostCalculator()
        cost = calc.calculate_cost("gpt-4", 1000, 500)
        assert cost is not None
        assert abs(cost - 0.06) < 0.0001

    def test_calculate_cost_unknown_model(self):
        """Test cost calculation for unknown model."""
        calc = CostCalculator()
        cost = calc.calculate_cost("unknown-model", 1000, 500)
        assert cost is None

    def test_calculate_cost_breakdown(self):
        """Test cost breakdown."""
        calc = CostCalculator()
        breakdown = calc.calculate_cost_breakdown("gpt-4", 1000, 500)
        assert breakdown is not None
        prompt_cost, completion_cost, total = breakdown
        assert abs(prompt_cost - 0.03) < 0.0001
        assert abs(completion_cost - 0.03) < 0.0001
        assert abs(total - 0.06) < 0.0001

    def test_estimate_cost(self):
        """Test cost estimation."""
        calc = CostCalculator()
        # Estimate with 1500 total tokens (70% prompt, 30% completion)
        cost = calc.estimate_cost("gpt-4", 1500, prompt_ratio=0.7)
        assert cost is not None
        # (1050/1000 * 0.03) + (450/1000 * 0.06) = 0.0315 + 0.027 = 0.0585
        assert abs(cost - 0.0585) < 0.001

    def test_compare_models(self):
        """Test model comparison."""
        calc = CostCalculator()
        models = ["gpt-4", "gpt-4o", "gpt-3.5-turbo"]
        results = calc.compare_models(models, 1000, 500)
        assert len(results) == 3
        assert "gpt-4" in results
        assert results["gpt-4"] is not None
        assert results["gpt-3.5-turbo"] is not None
        # gpt-3.5-turbo should be cheaper than gpt-4
        assert results["gpt-3.5-turbo"] < results["gpt-4"]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
Cost calculation module for LLM Observatory.

Maintains up-to-date pricing information for all major LLM providers
and calculates costs based on token usage.
"""

from typing import Optional, Dict, Tuple
from dataclasses import dataclass


@dataclass
class Pricing:
    """Pricing information for a specific model."""

    model: str
    prompt_cost_per_1k: float  # USD per 1k input tokens
    completion_cost_per_1k: float  # USD per 1k output tokens
    provider: str = ""

    def calculate_cost(
        self,
        prompt_tokens: int,
        completion_tokens: int
    ) -> float:
        """
        Calculate total cost.

        Args:
            prompt_tokens: Number of input tokens
            completion_tokens: Number of output tokens

        Returns:
            Total cost in USD
        """
        prompt_cost = (prompt_tokens / 1000.0) * self.prompt_cost_per_1k
        completion_cost = (completion_tokens / 1000.0) * self.completion_cost_per_1k
        return prompt_cost + completion_cost

    def calculate_cost_breakdown(
        self,
        prompt_tokens: int,
        completion_tokens: int
    ) -> Tuple[float, float, float]:
        """
        Calculate cost with breakdown.

        Args:
            prompt_tokens: Number of input tokens
            completion_tokens: Number of output tokens

        Returns:
            Tuple of (prompt_cost, completion_cost, total_cost) in USD
        """
        prompt_cost = (prompt_tokens / 1000.0) * self.prompt_cost_per_1k
        completion_cost = (completion_tokens / 1000.0) * self.completion_cost_per_1k
        total_cost = prompt_cost + completion_cost
        return prompt_cost, completion_cost, total_cost


class PricingDatabase:
    """
    Database of LLM pricing information.

    Pricing data is accurate as of January 2025 based on official provider
    pricing pages.
    """

    def __init__(self):
        """Initialize pricing database with current pricing data."""
        self._prices: Dict[str, Pricing] = {}
        self._load_openai_pricing()
        self._load_anthropic_pricing()
        self._load_google_pricing()
        self._load_mistral_pricing()
        self._load_azure_openai_pricing()

    def get_pricing(self, model: str) -> Optional[Pricing]:
        """
        Get pricing for a model.

        Args:
            model: Model identifier

        Returns:
            Pricing object or None if not found
        """
        # Direct lookup
        if model in self._prices:
            return self._prices[model]

        # Try normalized lookup (handle version strings)
        normalized = self._normalize_model_name(model)
        return self._prices.get(normalized)

    def has_pricing(self, model: str) -> bool:
        """Check if pricing exists for a model."""
        return self.get_pricing(model) is not None

    def add_pricing(self, pricing: Pricing) -> None:
        """Add custom pricing for a model."""
        self._prices[pricing.model] = pricing

    def list_models(self) -> list[str]:
        """List all models with pricing data."""
        return list(self._prices.keys())

    def _normalize_model_name(self, model: str) -> str:
        """Normalize model name for lookup."""
        # Remove versioning suffixes for common patterns
        if model.startswith("gpt-4-") and model.endswith(("-preview", "-vision-preview")):
            return "gpt-4-turbo"
        if model.startswith("gpt-3.5-turbo-"):
            return "gpt-3.5-turbo"
        return model

    # OpenAI Pricing (January 2025)
    # Source: https://openai.com/api/pricing/
    def _load_openai_pricing(self) -> None:
        """Load OpenAI pricing data."""
        prices = [
            # GPT-4o series (Latest flagship)
            Pricing("gpt-4o", 0.0025, 0.010, "openai"),
            Pricing("gpt-4o-2024-11-20", 0.0025, 0.010, "openai"),
            Pricing("gpt-4o-2024-08-06", 0.0025, 0.010, "openai"),
            Pricing("gpt-4o-2024-05-13", 0.0025, 0.010, "openai"),
            Pricing("gpt-4o-mini", 0.00015, 0.0006, "openai"),
            Pricing("gpt-4o-mini-2024-07-18", 0.00015, 0.0006, "openai"),

            # GPT-4 Turbo
            Pricing("gpt-4-turbo", 0.01, 0.03, "openai"),
            Pricing("gpt-4-turbo-2024-04-09", 0.01, 0.03, "openai"),
            Pricing("gpt-4-turbo-preview", 0.01, 0.03, "openai"),
            Pricing("gpt-4-0125-preview", 0.01, 0.03, "openai"),
            Pricing("gpt-4-1106-preview", 0.01, 0.03, "openai"),

            # GPT-4 (Original)
            Pricing("gpt-4", 0.03, 0.06, "openai"),
            Pricing("gpt-4-0613", 0.03, 0.06, "openai"),
            Pricing("gpt-4-32k", 0.06, 0.12, "openai"),
            Pricing("gpt-4-32k-0613", 0.06, 0.12, "openai"),

            # GPT-3.5 Turbo
            Pricing("gpt-3.5-turbo", 0.0005, 0.0015, "openai"),
            Pricing("gpt-3.5-turbo-0125", 0.0005, 0.0015, "openai"),
            Pricing("gpt-3.5-turbo-1106", 0.001, 0.002, "openai"),
            Pricing("gpt-3.5-turbo-16k", 0.003, 0.004, "openai"),

            # o1 series (Reasoning models)
            Pricing("o1-preview", 0.015, 0.06, "openai"),
            Pricing("o1-preview-2024-09-12", 0.015, 0.06, "openai"),
            Pricing("o1-mini", 0.003, 0.012, "openai"),
            Pricing("o1-mini-2024-09-12", 0.003, 0.012, "openai"),
        ]

        for price in prices:
            self._prices[price.model] = price

    # Anthropic Pricing (January 2025)
    # Source: https://www.anthropic.com/api
    def _load_anthropic_pricing(self) -> None:
        """Load Anthropic Claude pricing data."""
        prices = [
            # Claude Sonnet 4.5 (Latest)
            Pricing("claude-sonnet-4.5", 0.003, 0.015, "anthropic"),
            Pricing("claude-sonnet-4-5-20250929", 0.003, 0.015, "anthropic"),

            # Claude 3.5 Sonnet
            Pricing("claude-3-5-sonnet-20241022", 0.003, 0.015, "anthropic"),
            Pricing("claude-3-5-sonnet-20240620", 0.003, 0.015, "anthropic"),

            # Claude 3.5 Haiku
            Pricing("claude-3-5-haiku-20241022", 0.001, 0.005, "anthropic"),

            # Claude 3 Opus
            Pricing("claude-3-opus-20240229", 0.015, 0.075, "anthropic"),

            # Claude 3 Sonnet
            Pricing("claude-3-sonnet-20240229", 0.003, 0.015, "anthropic"),

            # Claude 3 Haiku
            Pricing("claude-3-haiku-20240307", 0.00025, 0.00125, "anthropic"),

            # Claude 2 (Legacy)
            Pricing("claude-2.1", 0.008, 0.024, "anthropic"),
            Pricing("claude-2.0", 0.008, 0.024, "anthropic"),

            # Claude Instant (Legacy)
            Pricing("claude-instant-1.2", 0.0008, 0.0024, "anthropic"),
        ]

        for price in prices:
            self._prices[price.model] = price

    # Google Gemini Pricing (January 2025)
    # Source: https://ai.google.dev/pricing
    def _load_google_pricing(self) -> None:
        """Load Google Gemini pricing data."""
        prices = [
            # Gemini 2.5 (Latest)
            Pricing("gemini-2.5-pro", 0.00125, 0.005, "google"),
            Pricing("gemini-2.5-pro-latest", 0.00125, 0.005, "google"),
            Pricing("gemini-2.5-flash", 0.000075, 0.0003, "google"),
            Pricing("gemini-2.5-flash-latest", 0.000075, 0.0003, "google"),

            # Gemini 1.5 Pro
            Pricing("gemini-1.5-pro", 0.00125, 0.005, "google"),
            Pricing("gemini-1.5-pro-latest", 0.00125, 0.005, "google"),
            Pricing("gemini-1.5-pro-001", 0.00125, 0.005, "google"),
            Pricing("gemini-1.5-pro-002", 0.00125, 0.005, "google"),

            # Gemini 1.5 Flash
            Pricing("gemini-1.5-flash", 0.000075, 0.0003, "google"),
            Pricing("gemini-1.5-flash-latest", 0.000075, 0.0003, "google"),
            Pricing("gemini-1.5-flash-001", 0.000075, 0.0003, "google"),
            Pricing("gemini-1.5-flash-002", 0.000075, 0.0003, "google"),

            # Gemini 1.0 Pro (Legacy)
            Pricing("gemini-1.0-pro", 0.0005, 0.0015, "google"),
            Pricing("gemini-pro", 0.0005, 0.0015, "google"),
        ]

        for price in prices:
            self._prices[price.model] = price

    # Mistral AI Pricing (January 2025)
    # Source: https://mistral.ai/technology/#pricing
    def _load_mistral_pricing(self) -> None:
        """Load Mistral AI pricing data."""
        prices = [
            # Mistral Large
            Pricing("mistral-large-latest", 0.002, 0.006, "mistral"),
            Pricing("mistral-large-2411", 0.002, 0.006, "mistral"),
            Pricing("mistral-large-2407", 0.002, 0.006, "mistral"),

            # Mistral Medium
            Pricing("mistral-medium-latest", 0.0027, 0.0081, "mistral"),
            Pricing("mistral-medium-2312", 0.0027, 0.0081, "mistral"),

            # Mistral Small
            Pricing("mistral-small-latest", 0.0002, 0.0006, "mistral"),
            Pricing("mistral-small-2409", 0.0002, 0.0006, "mistral"),

            # Mistral Tiny
            Pricing("mistral-tiny", 0.00014, 0.00042, "mistral"),

            # Open source models (self-hosted - free)
            Pricing("mistral-7b", 0.0, 0.0, "mistral"),
            Pricing("mixtral-8x7b", 0.0, 0.0, "mistral"),
        ]

        for price in prices:
            self._prices[price.model] = price

    # Azure OpenAI Pricing (January 2025)
    # Source: https://azure.microsoft.com/en-us/pricing/details/cognitive-services/openai-service/
    def _load_azure_openai_pricing(self) -> None:
        """Load Azure OpenAI pricing data (typically same as OpenAI)."""
        # Azure OpenAI typically uses the same pricing as OpenAI
        # but may vary by region. These are baseline prices.
        pass  # Already loaded via OpenAI pricing


class CostCalculator:
    """Calculate costs for LLM operations."""

    def __init__(self):
        """Initialize cost calculator with pricing database."""
        self.db = PricingDatabase()

    def calculate_cost(
        self,
        model: str,
        prompt_tokens: int,
        completion_tokens: int
    ) -> Optional[float]:
        """
        Calculate cost for an LLM operation.

        Args:
            model: Model identifier
            prompt_tokens: Number of input tokens
            completion_tokens: Number of output tokens

        Returns:
            Total cost in USD, or None if pricing not found
        """
        pricing = self.db.get_pricing(model)
        if not pricing:
            return None
        return pricing.calculate_cost(prompt_tokens, completion_tokens)

    def calculate_cost_breakdown(
        self,
        model: str,
        prompt_tokens: int,
        completion_tokens: int
    ) -> Optional[Tuple[float, float, float]]:
        """
        Calculate cost with breakdown.

        Args:
            model: Model identifier
            prompt_tokens: Number of input tokens
            completion_tokens: Number of output tokens

        Returns:
            Tuple of (prompt_cost, completion_cost, total_cost) in USD,
            or None if pricing not found
        """
        pricing = self.db.get_pricing(model)
        if not pricing:
            return None
        return pricing.calculate_cost_breakdown(prompt_tokens, completion_tokens)

    def estimate_cost(
        self,
        model: str,
        estimated_tokens: int,
        prompt_ratio: float = 0.7
    ) -> Optional[float]:
        """
        Estimate cost with approximate token count.

        Args:
            model: Model identifier
            estimated_tokens: Estimated total tokens
            prompt_ratio: Ratio of prompt to total tokens (default 0.7)

        Returns:
            Estimated cost in USD, or None if pricing not found
        """
        prompt_tokens = int(estimated_tokens * prompt_ratio)
        completion_tokens = estimated_tokens - prompt_tokens
        return self.calculate_cost(model, prompt_tokens, completion_tokens)

    def compare_models(
        self,
        models: list[str],
        prompt_tokens: int,
        completion_tokens: int
    ) -> Dict[str, Optional[float]]:
        """
        Compare costs across multiple models.

        Args:
            models: List of model identifiers
            prompt_tokens: Number of input tokens
            completion_tokens: Number of output tokens

        Returns:
            Dictionary mapping model names to costs (None if pricing not found)
        """
        results = {}
        for model in models:
            results[model] = self.calculate_cost(model, prompt_tokens, completion_tokens)
        return results

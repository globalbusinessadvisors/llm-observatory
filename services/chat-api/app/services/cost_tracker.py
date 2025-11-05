"""Cost tracking service for LLM API calls."""

from typing import Dict, Optional
from app.core.logging import get_logger

logger = get_logger(__name__)


class CostTracker:
    """Track and calculate costs for LLM API calls."""

    # Pricing per 1K tokens (as of 2024)
    PRICING: Dict[str, Dict[str, float]] = {
        # OpenAI
        "gpt-4": {"input": 0.03, "output": 0.06},
        "gpt-4-32k": {"input": 0.06, "output": 0.12},
        "gpt-4-turbo": {"input": 0.01, "output": 0.03},
        "gpt-4-turbo-preview": {"input": 0.01, "output": 0.03},
        "gpt-3.5-turbo": {"input": 0.0015, "output": 0.002},
        "gpt-3.5-turbo-16k": {"input": 0.003, "output": 0.004},

        # Anthropic
        "claude-3-opus-20240229": {"input": 0.015, "output": 0.075},
        "claude-3-sonnet-20240229": {"input": 0.003, "output": 0.015},
        "claude-3-haiku-20240307": {"input": 0.00025, "output": 0.00125},
        "claude-2.1": {"input": 0.008, "output": 0.024},
        "claude-2.0": {"input": 0.008, "output": 0.024},

        # Azure OpenAI (same as OpenAI)
        "azure-gpt-4": {"input": 0.03, "output": 0.06},
        "azure-gpt-35-turbo": {"input": 0.0015, "output": 0.002},
    }

    @classmethod
    def calculate_cost(
        cls,
        model: str,
        input_tokens: int,
        output_tokens: int,
    ) -> float:
        """Calculate cost for a model based on token usage.

        Args:
            model: Model name
            input_tokens: Number of input tokens
            output_tokens: Number of output tokens

        Returns:
            Total cost in USD
        """
        # Normalize model name
        model_key = cls._normalize_model_name(model)

        # Get pricing
        pricing = cls.PRICING.get(model_key)
        if not pricing:
            logger.warning(f"Unknown model for pricing: {model}")
            return 0.0

        # Calculate cost
        input_cost = (input_tokens / 1000) * pricing["input"]
        output_cost = (output_tokens / 1000) * pricing["output"]
        total_cost = input_cost + output_cost

        logger.debug(
            f"Cost calculated for {model}: "
            f"input={input_tokens}tok/${input_cost:.6f}, "
            f"output={output_tokens}tok/${output_cost:.6f}, "
            f"total=${total_cost:.6f}"
        )

        return round(total_cost, 8)

    @classmethod
    def _normalize_model_name(cls, model: str) -> str:
        """Normalize model name for pricing lookup.

        Args:
            model: Original model name

        Returns:
            Normalized model name
        """
        # Handle version suffixes
        if model.startswith("gpt-4-turbo"):
            return "gpt-4-turbo"
        elif model.startswith("gpt-4-32k"):
            return "gpt-4-32k"
        elif model.startswith("gpt-4"):
            return "gpt-4"
        elif model.startswith("gpt-3.5-turbo-16k"):
            return "gpt-3.5-turbo-16k"
        elif model.startswith("gpt-3.5-turbo"):
            return "gpt-3.5-turbo"

        # Handle Claude models
        if "claude-3-opus" in model:
            return "claude-3-opus-20240229"
        elif "claude-3-sonnet" in model:
            return "claude-3-sonnet-20240229"
        elif "claude-3-haiku" in model:
            return "claude-3-haiku-20240307"
        elif "claude-2.1" in model:
            return "claude-2.1"
        elif "claude-2" in model:
            return "claude-2.0"

        return model

    @classmethod
    def get_model_pricing(cls, model: str) -> Optional[Dict[str, float]]:
        """Get pricing information for a model.

        Args:
            model: Model name

        Returns:
            Pricing dict with 'input' and 'output' keys, or None
        """
        model_key = cls._normalize_model_name(model)
        return cls.PRICING.get(model_key)

    @classmethod
    def estimate_cost(
        cls,
        model: str,
        text: str,
        estimated_response_tokens: Optional[int] = None,
    ) -> float:
        """Estimate cost for a text input.

        Args:
            model: Model name
            text: Input text
            estimated_response_tokens: Estimated output tokens (default: same as input)

        Returns:
            Estimated cost in USD
        """
        # Rough estimation: 1 token ≈ 4 characters
        input_tokens = len(text) // 4
        output_tokens = estimated_response_tokens or input_tokens

        return cls.calculate_cost(model, input_tokens, output_tokens)

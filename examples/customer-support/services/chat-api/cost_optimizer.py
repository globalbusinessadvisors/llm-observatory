"""Cost optimization module for managing token usage and costs."""
import logging
from typing import List, Optional, Tuple
from models import Message, CostOptimizationResult
from config import settings


logger = logging.getLogger(__name__)


class CostOptimizer:
    """Optimizes costs by managing context windows and suggesting improvements."""

    def __init__(self):
        """Initialize cost optimizer."""
        self.max_context_tokens = settings.max_context_tokens
        self.auto_summarize_threshold = settings.auto_summarize_threshold

    def analyze_context(
        self, messages: List[Message], count_tokens_fn
    ) -> CostOptimizationResult:
        """Analyze conversation context and provide optimization recommendations.

        Args:
            messages: List of conversation messages
            count_tokens_fn: Function to count tokens for a message

        Returns:
            CostOptimizationResult with analysis and recommendations
        """
        # Count tokens in messages
        total_tokens = sum(count_tokens_fn(msg.content) for msg in messages)

        recommendations = []
        action_taken = None

        # Check if context is getting large
        usage_percent = (total_tokens / self.max_context_tokens) * 100

        if usage_percent > 90:
            recommendations.append(
                f"Context window is {usage_percent:.1f}% full. "
                "Consider summarizing or truncating conversation history."
            )

        if total_tokens > self.auto_summarize_threshold:
            recommendations.append(
                "Context exceeds auto-summarization threshold. "
                "Automatic summarization is recommended."
            )
            action_taken = "AUTO_SUMMARIZE_RECOMMENDED"

        # Check for redundant system messages
        system_messages = [msg for msg in messages if msg.role == "system"]
        if len(system_messages) > 1:
            recommendations.append(
                f"Found {len(system_messages)} system messages. "
                "Consider consolidating to a single system message."
            )

        # Check for very long individual messages
        long_messages = [
            msg for msg in messages if count_tokens_fn(msg.content) > 10000
        ]
        if long_messages:
            recommendations.append(
                f"Found {len(long_messages)} messages exceeding 10k tokens. "
                "Consider chunking or summarizing long inputs."
            )

        # Check conversation length
        if len(messages) > 50:
            recommendations.append(
                f"Conversation has {len(messages)} messages. "
                "Consider keeping only recent messages or summarizing older ones."
            )

        # General recommendations
        if not recommendations:
            recommendations.append("Context usage is optimal.")

        return CostOptimizationResult(
            original_tokens=total_tokens,
            optimized_tokens=total_tokens,  # No optimization applied yet
            savings_tokens=0,
            savings_percent=0.0,
            recommendations=recommendations,
            action_taken=action_taken,
        )

    def should_summarize(self, messages: List[Message], count_tokens_fn) -> bool:
        """Determine if conversation should be summarized.

        Args:
            messages: List of conversation messages
            count_tokens_fn: Function to count tokens

        Returns:
            True if summarization is recommended
        """
        total_tokens = sum(count_tokens_fn(msg.content) for msg in messages)
        return total_tokens > self.auto_summarize_threshold

    def truncate_context(
        self,
        messages: List[Message],
        max_tokens: int,
        count_tokens_fn,
        keep_system: bool = True,
    ) -> List[Message]:
        """Truncate conversation to fit within token limit.

        Args:
            messages: List of conversation messages
            max_tokens: Maximum tokens to keep
            count_tokens_fn: Function to count tokens
            keep_system: Whether to always keep system messages

        Returns:
            Truncated list of messages
        """
        # Separate system and conversation messages
        system_messages = []
        conversation_messages = []

        for msg in messages:
            if msg.role == "system" and keep_system:
                system_messages.append(msg)
            else:
                conversation_messages.append(msg)

        # Calculate tokens for system messages
        system_tokens = sum(count_tokens_fn(msg.content) for msg in system_messages)
        remaining_tokens = max_tokens - system_tokens

        if remaining_tokens <= 0:
            logger.warning("System messages exceed token limit")
            return system_messages[:1] if system_messages else []

        # Keep most recent messages that fit
        truncated = []
        current_tokens = 0

        for msg in reversed(conversation_messages):
            msg_tokens = count_tokens_fn(msg.content)
            if current_tokens + msg_tokens <= remaining_tokens:
                truncated.insert(0, msg)
                current_tokens += msg_tokens
            else:
                break

        return system_messages + truncated

    def generate_summary_prompt(
        self, messages: List[Message], max_summary_length: int = 500
    ) -> str:
        """Generate a prompt for summarizing conversation history.

        Args:
            messages: Messages to summarize
            max_summary_length: Maximum length for summary

        Returns:
            Prompt for generating summary
        """
        conversation_text = "\n\n".join(
            [f"{msg.role.upper()}: {msg.content}" for msg in messages]
        )

        return f"""Please provide a concise summary of the following conversation,
highlighting key points, decisions made, and important context.
Keep the summary under {max_summary_length} words.

CONVERSATION:
{conversation_text}

SUMMARY:"""

    def optimize_messages(
        self,
        messages: List[Message],
        count_tokens_fn,
        target_reduction: float = 0.3,
    ) -> Tuple[List[Message], CostOptimizationResult]:
        """Apply optimization strategies to reduce token usage.

        Args:
            messages: Original messages
            count_tokens_fn: Function to count tokens
            target_reduction: Target reduction percentage (0.0-1.0)

        Returns:
            Tuple of (optimized messages, optimization result)
        """
        original_tokens = sum(count_tokens_fn(msg.content) for msg in messages)
        target_tokens = int(original_tokens * (1 - target_reduction))

        # Strategy 1: Remove duplicate system messages
        optimized = []
        seen_system = False

        for msg in messages:
            if msg.role == "system":
                if not seen_system:
                    optimized.append(msg)
                    seen_system = True
            else:
                optimized.append(msg)

        # Strategy 2: Truncate if still too large
        current_tokens = sum(count_tokens_fn(msg.content) for msg in optimized)

        if current_tokens > target_tokens:
            optimized = self.truncate_context(
                optimized, target_tokens, count_tokens_fn
            )

        optimized_tokens = sum(count_tokens_fn(msg.content) for msg in optimized)
        savings = original_tokens - optimized_tokens
        savings_percent = (savings / original_tokens * 100) if original_tokens > 0 else 0

        result = CostOptimizationResult(
            original_tokens=original_tokens,
            optimized_tokens=optimized_tokens,
            savings_tokens=savings,
            savings_percent=savings_percent,
            recommendations=[
                f"Reduced context from {original_tokens} to {optimized_tokens} tokens",
                f"Savings: {savings_percent:.1f}%",
            ],
            action_taken="CONTEXT_TRUNCATION",
        )

        return optimized, result

    def estimate_monthly_cost(
        self,
        daily_requests: int,
        avg_prompt_tokens: int,
        avg_completion_tokens: int,
        cost_per_request: float,
    ) -> Dict:
        """Estimate monthly costs based on usage patterns.

        Args:
            daily_requests: Average daily request count
            avg_prompt_tokens: Average prompt tokens per request
            avg_completion_tokens: Average completion tokens per request
            cost_per_request: Average cost per request

        Returns:
            Dictionary with cost projections
        """
        monthly_requests = daily_requests * 30
        monthly_prompt_tokens = monthly_requests * avg_prompt_tokens
        monthly_completion_tokens = monthly_requests * avg_completion_tokens
        monthly_cost = monthly_requests * cost_per_request

        return {
            "monthly_requests": monthly_requests,
            "monthly_prompt_tokens": monthly_prompt_tokens,
            "monthly_completion_tokens": monthly_completion_tokens,
            "monthly_cost_usd": monthly_cost,
            "daily_cost_usd": monthly_cost / 30,
            "cost_per_request_usd": cost_per_request,
        }

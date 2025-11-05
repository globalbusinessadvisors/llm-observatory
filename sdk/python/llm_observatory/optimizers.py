# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
Context window optimization utilities.

This module provides tools for managing context windows and preventing
token limit errors by intelligently summarizing or truncating conversation history.
"""

from typing import List, Dict, Any, Optional, Callable
from dataclasses import dataclass


@dataclass
class ContextWindowConfig:
    """Configuration for context window management."""

    model: str
    max_tokens: int
    warning_threshold: float = 0.8  # Warn at 80% capacity
    action_threshold: float = 0.9  # Take action at 90% capacity
    reserved_tokens: int = 500  # Reserve for system prompt and response


# Model context window sizes (as of January 2025)
MODEL_CONTEXT_WINDOWS = {
    # OpenAI
    "gpt-4": 8192,
    "gpt-4-32k": 32768,
    "gpt-4-turbo": 128000,
    "gpt-4o": 128000,
    "gpt-4o-mini": 128000,
    "gpt-3.5-turbo": 16385,
    "gpt-3.5-turbo-16k": 16385,
    "o1-preview": 128000,
    "o1-mini": 128000,

    # Anthropic
    "claude-3-opus-20240229": 200000,
    "claude-3-sonnet-20240229": 200000,
    "claude-3-haiku-20240307": 200000,
    "claude-3-5-sonnet-20241022": 200000,
    "claude-3-5-haiku-20241022": 200000,
    "claude-sonnet-4.5": 200000,

    # Google
    "gemini-1.5-pro": 2000000,
    "gemini-1.5-flash": 1000000,
    "gemini-2.5-pro": 2000000,
    "gemini-2.5-flash": 1000000,
    "gemini-1.0-pro": 32768,

    # Mistral
    "mistral-large-latest": 32000,
    "mistral-medium-latest": 32000,
    "mistral-small-latest": 32000,
}


class ContextWindowOptimizer:
    """
    Optimize conversation context to fit within model token limits.

    This class monitors conversation history and provides strategies for
    managing context windows, including:
    - Token counting and estimation
    - Warning when approaching limits
    - Automatic summarization of old messages
    - Intelligent truncation strategies
    """

    def __init__(
        self,
        model: str,
        max_tokens: Optional[int] = None,
        warning_threshold: float = 0.8,
        action_threshold: float = 0.9,
        reserved_tokens: int = 500,
    ):
        """
        Initialize context window optimizer.

        Args:
            model: Model identifier
            max_tokens: Maximum tokens (if None, uses model's default)
            warning_threshold: Threshold (0-1) for warnings (default: 0.8)
            action_threshold: Threshold (0-1) for taking action (default: 0.9)
            reserved_tokens: Tokens to reserve for system prompt and response
        """
        self.model = model
        self.max_tokens = max_tokens or self._get_model_max_tokens(model)
        self.warning_threshold = warning_threshold
        self.action_threshold = action_threshold
        self.reserved_tokens = reserved_tokens
        self.available_tokens = self.max_tokens - reserved_tokens

    def _get_model_max_tokens(self, model: str) -> int:
        """Get maximum tokens for a model."""
        # Try direct lookup
        if model in MODEL_CONTEXT_WINDOWS:
            return MODEL_CONTEXT_WINDOWS[model]

        # Try partial matching (handle versioned models)
        for model_prefix, max_tokens in MODEL_CONTEXT_WINDOWS.items():
            if model.startswith(model_prefix):
                return max_tokens

        # Default fallback
        return 4096

    def estimate_tokens(self, text: str) -> int:
        """
        Estimate token count for text.

        This is a rough approximation. For accurate counts, use tiktoken
        or the provider's tokenizer.

        Args:
            text: Input text

        Returns:
            Estimated token count
        """
        # Rough approximation: ~4 characters per token for English text
        return max(1, len(text) // 4)

    def estimate_messages_tokens(self, messages: List[Dict[str, Any]]) -> int:
        """
        Estimate total tokens for a list of messages.

        Args:
            messages: List of message dictionaries

        Returns:
            Estimated total tokens
        """
        total = 0
        for msg in messages:
            # Add tokens for role
            total += 4  # Approximate overhead per message

            # Add tokens for content
            if "content" in msg:
                content = msg["content"]
                if isinstance(content, str):
                    total += self.estimate_tokens(content)
                elif isinstance(content, list):
                    # Handle multimodal content
                    for item in content:
                        if isinstance(item, dict) and "text" in item:
                            total += self.estimate_tokens(item["text"])

        return total

    def check_context_window(
        self,
        messages: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Check if messages fit within context window.

        Args:
            messages: List of message dictionaries

        Returns:
            Dictionary with:
                - fits: bool - Whether messages fit
                - estimated_tokens: int - Estimated token count
                - available_tokens: int - Available tokens
                - utilization: float - Utilization ratio (0-1)
                - should_warn: bool - Whether to warn user
                - should_optimize: bool - Whether optimization is needed
        """
        estimated_tokens = self.estimate_messages_tokens(messages)
        utilization = estimated_tokens / self.available_tokens

        return {
            "fits": estimated_tokens <= self.available_tokens,
            "estimated_tokens": estimated_tokens,
            "available_tokens": self.available_tokens,
            "max_tokens": self.max_tokens,
            "utilization": utilization,
            "should_warn": utilization >= self.warning_threshold,
            "should_optimize": utilization >= self.action_threshold,
        }

    def optimize_messages(
        self,
        messages: List[Dict[str, Any]],
        strategy: str = "truncate_old",
        summarizer: Optional[Callable[[List[Dict[str, Any]]], str]] = None,
    ) -> List[Dict[str, Any]]:
        """
        Optimize messages to fit within context window.

        Args:
            messages: List of message dictionaries
            strategy: Optimization strategy:
                - "truncate_old": Remove oldest messages
                - "truncate_middle": Keep first and last messages
                - "summarize": Summarize old messages (requires summarizer)
            summarizer: Optional function to summarize messages

        Returns:
            Optimized list of messages
        """
        check = self.check_context_window(messages)

        # If messages fit, return as-is
        if check["fits"]:
            return messages

        # Apply optimization strategy
        if strategy == "truncate_old":
            return self._truncate_old(messages)
        elif strategy == "truncate_middle":
            return self._truncate_middle(messages)
        elif strategy == "summarize" and summarizer:
            return self._summarize_old(messages, summarizer)
        else:
            # Default to truncate_old
            return self._truncate_old(messages)

    def _truncate_old(
        self,
        messages: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Truncate old messages to fit within context window.

        Keeps system message (if present) and removes oldest messages first.
        """
        if not messages:
            return messages

        # Keep system message if present
        system_messages = [m for m in messages if m.get("role") == "system"]
        other_messages = [m for m in messages if m.get("role") != "system"]

        # Try to fit as many recent messages as possible
        result = system_messages.copy()
        current_tokens = self.estimate_messages_tokens(result)

        # Add messages from most recent to oldest
        for msg in reversed(other_messages):
            msg_tokens = self.estimate_messages_tokens([msg])
            if current_tokens + msg_tokens <= self.available_tokens:
                result.append(msg)
                current_tokens += msg_tokens
            else:
                break

        # Reverse non-system messages to restore order
        if system_messages:
            return system_messages + list(reversed(result[len(system_messages):]))
        else:
            return list(reversed(result))

    def _truncate_middle(
        self,
        messages: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Truncate middle messages, keeping first and last messages.

        Useful for maintaining conversation context at both ends.
        """
        if len(messages) <= 2:
            return messages

        # Keep system message, first user message, and last few messages
        system_messages = [m for m in messages if m.get("role") == "system"]
        other_messages = [m for m in messages if m.get("role") != "system"]

        if not other_messages:
            return messages

        # Start with system messages and first message
        result = system_messages + [other_messages[0]]
        current_tokens = self.estimate_messages_tokens(result)

        # Add as many recent messages as possible
        for msg in reversed(other_messages[1:]):
            msg_tokens = self.estimate_messages_tokens([msg])
            if current_tokens + msg_tokens <= self.available_tokens:
                result.append(msg)
                current_tokens += msg_tokens
            else:
                break

        # Sort to maintain order (excluding system messages)
        if system_messages:
            non_system = sorted(result[len(system_messages):], key=lambda m: messages.index(m))
            return system_messages + non_system
        else:
            return sorted(result, key=lambda m: messages.index(m))

    def _summarize_old(
        self,
        messages: List[Dict[str, Any]],
        summarizer: Callable[[List[Dict[str, Any]]], str],
    ) -> List[Dict[str, Any]]:
        """
        Summarize old messages to fit within context window.

        Args:
            messages: List of messages
            summarizer: Function that takes messages and returns a summary

        Returns:
            Messages with old messages summarized
        """
        if not messages:
            return messages

        # Keep system message and recent messages
        system_messages = [m for m in messages if m.get("role") == "system"]
        other_messages = [m for m in messages if m.get("role") != "system"]

        # Calculate how many recent messages to keep
        recent_count = max(1, len(other_messages) // 3)
        recent_messages = other_messages[-recent_count:]
        old_messages = other_messages[:-recent_count]

        # Summarize old messages
        if old_messages:
            summary = summarizer(old_messages)
            summary_message = {
                "role": "system",
                "content": f"Previous conversation summary: {summary}"
            }
            return system_messages + [summary_message] + recent_messages
        else:
            return system_messages + recent_messages

    def get_optimization_suggestion(
        self,
        messages: List[Dict[str, Any]]
    ) -> Optional[str]:
        """
        Get a human-readable suggestion for optimizing context.

        Args:
            messages: List of messages

        Returns:
            Suggestion string or None if no optimization needed
        """
        check = self.check_context_window(messages)

        if check["should_optimize"]:
            return (
                f"Context window is {check['utilization']:.1%} full "
                f"({check['estimated_tokens']}/{check['available_tokens']} tokens). "
                f"Consider optimizing messages to avoid token limit errors."
            )
        elif check["should_warn"]:
            return (
                f"Context window is {check['utilization']:.1%} full "
                f"({check['estimated_tokens']}/{check['available_tokens']} tokens). "
                f"Approaching token limit."
            )
        else:
            return None


def create_simple_summarizer(client: Any, model: str = "gpt-3.5-turbo") -> Callable:
    """
    Create a simple summarizer using an LLM.

    Args:
        client: LLM client (OpenAI or compatible)
        model: Model to use for summarization (default: gpt-3.5-turbo)

    Returns:
        Summarizer function
    """
    def summarizer(messages: List[Dict[str, Any]]) -> str:
        """Summarize messages using an LLM."""
        # Format messages for summarization
        conversation = "\n".join(
            f"{msg['role']}: {msg['content']}"
            for msg in messages
            if isinstance(msg.get('content'), str)
        )

        # Create summarization prompt
        summary_prompt = (
            "Summarize the following conversation in 2-3 sentences, "
            "focusing on key points and decisions:\n\n"
            f"{conversation}"
        )

        # Call LLM (without instrumentation to avoid recursion)
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": summary_prompt}],
            max_tokens=150,
        )

        return response.choices[0].message.content

    return summarizer

"""Base provider interface for LLM providers."""
from abc import ABC, abstractmethod
from typing import List, Optional, AsyncIterator
from models import Message, ChatResponse, StreamChunk, Tool


class ProviderError(Exception):
    """Base exception for provider errors."""
    pass


class RateLimitError(ProviderError):
    """Rate limit exceeded error."""
    pass


class AuthenticationError(ProviderError):
    """Authentication failed error."""
    pass


class InvalidRequestError(ProviderError):
    """Invalid request error."""
    pass


class BaseProvider(ABC):
    """Base class for all LLM providers."""

    def __init__(self, api_key: str, **kwargs):
        """Initialize the provider.

        Args:
            api_key: API key for the provider
            **kwargs: Additional provider-specific configuration
        """
        self.api_key = api_key
        self.config = kwargs

    @abstractmethod
    async def complete(
        self,
        messages: List[Message],
        model: str,
        max_tokens: Optional[int] = None,
        temperature: float = 0.7,
        tools: Optional[List[Tool]] = None,
        **kwargs
    ) -> ChatResponse:
        """Generate a chat completion.

        Args:
            messages: List of chat messages
            model: Model identifier
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            tools: Optional list of tools for function calling
            **kwargs: Additional provider-specific parameters

        Returns:
            ChatResponse with the completion

        Raises:
            RateLimitError: If rate limit is exceeded
            AuthenticationError: If authentication fails
            InvalidRequestError: If request is invalid
            ProviderError: For other provider errors
        """
        pass

    @abstractmethod
    async def stream_complete(
        self,
        messages: List[Message],
        model: str,
        max_tokens: Optional[int] = None,
        temperature: float = 0.7,
        tools: Optional[List[Tool]] = None,
        **kwargs
    ) -> AsyncIterator[StreamChunk]:
        """Generate a streaming chat completion.

        Args:
            messages: List of chat messages
            model: Model identifier
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            tools: Optional list of tools for function calling
            **kwargs: Additional provider-specific parameters

        Yields:
            StreamChunk objects with partial completions

        Raises:
            RateLimitError: If rate limit is exceeded
            AuthenticationError: If authentication fails
            InvalidRequestError: If request is invalid
            ProviderError: For other provider errors
        """
        pass

    @abstractmethod
    def count_tokens(self, text: str, model: str) -> int:
        """Count tokens in text for the given model.

        Args:
            text: Text to count tokens for
            model: Model identifier

        Returns:
            Number of tokens
        """
        pass

    @abstractmethod
    def estimate_cost(self, prompt_tokens: int, completion_tokens: int, model: str) -> float:
        """Estimate cost for token usage.

        Args:
            prompt_tokens: Number of prompt tokens
            completion_tokens: Number of completion tokens
            model: Model identifier

        Returns:
            Estimated cost in USD
        """
        pass

    @property
    @abstractmethod
    def name(self) -> str:
        """Get the provider name."""
        pass

    @property
    @abstractmethod
    def supported_models(self) -> List[str]:
        """Get list of supported models."""
        pass

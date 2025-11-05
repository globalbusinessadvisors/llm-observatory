"""Provider manager with fallback and load balancing logic."""
import asyncio
import logging
from typing import List, Optional, AsyncIterator, Dict, Any
from datetime import datetime

from providers import (
    BaseProvider,
    OpenAIProvider,
    AnthropicProvider,
    AzureOpenAIProvider,
    RateLimitError,
)
from models import Message, ChatResponse, StreamChunk, Tool
from config import settings


logger = logging.getLogger(__name__)


class ProviderManager:
    """Manages multiple LLM providers with fallback logic."""

    def __init__(self):
        """Initialize provider manager."""
        self.providers: Dict[str, BaseProvider] = {}
        self.fallback_order: List[str] = []
        self._initialize_providers()

    def _initialize_providers(self):
        """Initialize available providers based on configuration."""
        # Initialize OpenAI
        if settings.openai_api_key:
            try:
                self.providers["openai"] = OpenAIProvider(settings.openai_api_key)
                self.fallback_order.append("openai")
                logger.info("OpenAI provider initialized")
            except Exception as e:
                logger.warning(f"Failed to initialize OpenAI provider: {e}")

        # Initialize Anthropic
        if settings.anthropic_api_key:
            try:
                self.providers["anthropic"] = AnthropicProvider(settings.anthropic_api_key)
                self.fallback_order.append("anthropic")
                logger.info("Anthropic provider initialized")
            except Exception as e:
                logger.warning(f"Failed to initialize Anthropic provider: {e}")

        # Initialize Azure OpenAI
        if settings.azure_openai_api_key and settings.azure_openai_endpoint:
            try:
                self.providers["azure"] = AzureOpenAIProvider(
                    api_key=settings.azure_openai_api_key,
                    endpoint=settings.azure_openai_endpoint,
                )
                self.fallback_order.append("azure")
                logger.info("Azure OpenAI provider initialized")
            except Exception as e:
                logger.warning(f"Failed to initialize Azure provider: {e}")

        if not self.providers:
            raise RuntimeError("No LLM providers configured")

        logger.info(f"Initialized providers: {list(self.providers.keys())}")
        logger.info(f"Fallback order: {self.fallback_order}")

    def get_provider(self, provider_name: Optional[str] = None) -> BaseProvider:
        """Get a specific provider or default provider.

        Args:
            provider_name: Name of provider to get, or None for default

        Returns:
            BaseProvider instance

        Raises:
            ValueError: If provider not found
        """
        if provider_name is None:
            provider_name = settings.default_provider

        if provider_name not in self.providers:
            available = ", ".join(self.providers.keys())
            raise ValueError(
                f"Provider '{provider_name}' not available. "
                f"Available providers: {available}"
            )

        return self.providers[provider_name]

    def select_model_for_provider(
        self, provider: BaseProvider, requested_model: Optional[str] = None
    ) -> str:
        """Select appropriate model for provider.

        Args:
            provider: Provider instance
            requested_model: Requested model name, or None for default

        Returns:
            Model identifier for the provider
        """
        supported = provider.supported_models

        if requested_model and requested_model in supported:
            return requested_model

        # Return first supported model as default
        if supported:
            default = supported[0]
            if requested_model:
                logger.warning(
                    f"Model '{requested_model}' not supported by {provider.name}, "
                    f"using '{default}' instead"
                )
            return default

        raise ValueError(f"No supported models for provider {provider.name}")

    async def complete_with_fallback(
        self,
        messages: List[Message],
        model: Optional[str] = None,
        provider_name: Optional[str] = None,
        max_tokens: Optional[int] = None,
        temperature: float = 0.7,
        tools: Optional[List[Tool]] = None,
        **kwargs,
    ) -> ChatResponse:
        """Complete with automatic fallback on rate limits.

        Args:
            messages: List of chat messages
            model: Model identifier
            provider_name: Preferred provider name
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            tools: Optional list of tools
            **kwargs: Additional parameters

        Returns:
            ChatResponse from successful provider

        Raises:
            Exception: If all providers fail
        """
        # Determine provider order
        if provider_name:
            provider_order = [provider_name] + [
                p for p in self.fallback_order if p != provider_name
            ]
        else:
            provider_order = self.fallback_order.copy()

        last_error = None
        attempts = []

        for attempt, prov_name in enumerate(provider_order, 1):
            if prov_name not in self.providers:
                continue

            provider = self.providers[prov_name]

            # Select appropriate model for this provider
            provider_model = self.select_model_for_provider(provider, model)

            try:
                logger.info(
                    f"Attempt {attempt}/{len(provider_order)}: "
                    f"Using {prov_name} with model {provider_model}"
                )

                response = await provider.complete(
                    messages=messages,
                    model=provider_model,
                    max_tokens=max_tokens,
                    temperature=temperature,
                    tools=tools,
                    **kwargs,
                )

                logger.info(
                    f"Successfully completed with {prov_name}, "
                    f"tokens: {response.usage.total_tokens}, "
                    f"cost: ${response.usage.estimated_cost:.4f}"
                )

                return response

            except RateLimitError as e:
                last_error = e
                attempts.append(f"{prov_name}: Rate limit exceeded")
                logger.warning(
                    f"Rate limit hit for {prov_name}, "
                    f"attempting fallback ({attempt}/{len(provider_order)})"
                )

                if settings.enable_fallback and attempt < len(provider_order):
                    # Exponential backoff before trying next provider
                    wait_time = min(2**attempt, 10)
                    logger.info(f"Waiting {wait_time}s before fallback...")
                    await asyncio.sleep(wait_time)
                    continue
                else:
                    break

            except Exception as e:
                last_error = e
                attempts.append(f"{prov_name}: {str(e)}")
                logger.error(f"Error with {prov_name}: {e}")

                if settings.enable_fallback and attempt < len(provider_order):
                    continue
                else:
                    break

        # All providers failed
        error_summary = "; ".join(attempts)
        raise Exception(
            f"All providers failed. Attempts: {error_summary}. "
            f"Last error: {last_error}"
        )

    async def stream_with_fallback(
        self,
        messages: List[Message],
        model: Optional[str] = None,
        provider_name: Optional[str] = None,
        max_tokens: Optional[int] = None,
        temperature: float = 0.7,
        tools: Optional[List[Tool]] = None,
        **kwargs,
    ) -> AsyncIterator[StreamChunk]:
        """Stream completion with automatic fallback.

        Args:
            messages: List of chat messages
            model: Model identifier
            provider_name: Preferred provider name
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            tools: Optional list of tools
            **kwargs: Additional parameters

        Yields:
            StreamChunk objects

        Raises:
            Exception: If all providers fail
        """
        # Determine provider order
        if provider_name:
            provider_order = [provider_name] + [
                p for p in self.fallback_order if p != provider_name
            ]
        else:
            provider_order = self.fallback_order.copy()

        last_error = None

        for attempt, prov_name in enumerate(provider_order, 1):
            if prov_name not in self.providers:
                continue

            provider = self.providers[prov_name]
            provider_model = self.select_model_for_provider(provider, model)

            try:
                logger.info(
                    f"Streaming attempt {attempt}: "
                    f"Using {prov_name} with model {provider_model}"
                )

                async for chunk in provider.stream_complete(
                    messages=messages,
                    model=provider_model,
                    max_tokens=max_tokens,
                    temperature=temperature,
                    tools=tools,
                    **kwargs,
                ):
                    yield chunk

                return  # Success, exit

            except RateLimitError as e:
                last_error = e
                logger.warning(f"Rate limit hit for {prov_name} during streaming")

                if settings.enable_fallback and attempt < len(provider_order):
                    wait_time = min(2**attempt, 10)
                    await asyncio.sleep(wait_time)
                    continue
                else:
                    break

            except Exception as e:
                last_error = e
                logger.error(f"Streaming error with {prov_name}: {e}")

                if settings.enable_fallback and attempt < len(provider_order):
                    continue
                else:
                    break

        raise Exception(f"All streaming providers failed. Last error: {last_error}")

    def get_available_providers(self) -> List[Dict[str, Any]]:
        """Get list of available providers with their details.

        Returns:
            List of provider information dictionaries
        """
        return [
            {
                "name": name,
                "supported_models": provider.supported_models,
                "is_default": name == settings.default_provider,
            }
            for name, provider in self.providers.items()
        ]

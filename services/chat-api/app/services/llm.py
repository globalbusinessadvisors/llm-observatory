"""LLM service for handling chat completions."""

import time
from typing import Optional, List, Dict, Any, AsyncIterator
from openai import AsyncOpenAI, AsyncAzureOpenAI, OpenAIError
from anthropic import AsyncAnthropic, AnthropicError

from app.core.config import settings
from app.core.logging import get_logger
from app.services.cost_tracker import CostTracker
from app.database.models import ProviderEnum, MessageRoleEnum

logger = get_logger(__name__)


class LLMService:
    """Service for LLM chat completions with multi-provider support."""

    def __init__(self):
        """Initialize LLM clients."""
        # OpenAI client
        self.openai_client = None
        if settings.OPENAI_API_KEY:
            self.openai_client = AsyncOpenAI(
                api_key=settings.OPENAI_API_KEY,
                organization=settings.OPENAI_ORG_ID,
                max_retries=settings.OPENAI_MAX_RETRIES,
                timeout=settings.OPENAI_TIMEOUT,
            )

        # Azure OpenAI client
        self.azure_client = None
        if settings.AZURE_OPENAI_API_KEY and settings.AZURE_OPENAI_ENDPOINT:
            self.azure_client = AsyncAzureOpenAI(
                api_key=settings.AZURE_OPENAI_API_KEY,
                azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
                api_version=settings.AZURE_OPENAI_API_VERSION,
                max_retries=settings.OPENAI_MAX_RETRIES,
                timeout=settings.OPENAI_TIMEOUT,
            )

        # Anthropic client
        self.anthropic_client = None
        if settings.ANTHROPIC_API_KEY:
            self.anthropic_client = AsyncAnthropic(
                api_key=settings.ANTHROPIC_API_KEY,
            )

        self.cost_tracker = CostTracker()

    async def chat_completion(
        self,
        messages: List[Dict[str, str]],
        provider: Optional[str] = None,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """Generate a chat completion.

        Args:
            messages: List of message dicts with 'role' and 'content'
            provider: LLM provider (openai, anthropic, azure_openai)
            model: Model name
            temperature: Sampling temperature
            max_tokens: Maximum tokens in response
            **kwargs: Additional provider-specific parameters

        Returns:
            Dict with response, usage, and metadata
        """
        provider = provider or settings.DEFAULT_PROVIDER
        temperature = temperature or settings.TEMPERATURE
        max_tokens = max_tokens or settings.MAX_TOKENS

        # Route to appropriate provider
        if provider == ProviderEnum.OPENAI.value:
            return await self._openai_completion(
                messages, model, temperature, max_tokens, **kwargs
            )
        elif provider == ProviderEnum.ANTHROPIC.value:
            return await self._anthropic_completion(
                messages, model, temperature, max_tokens, **kwargs
            )
        elif provider == ProviderEnum.AZURE_OPENAI.value:
            return await self._azure_openai_completion(
                messages, model, temperature, max_tokens, **kwargs
            )
        else:
            raise ValueError(f"Unsupported provider: {provider}")

    async def stream_completion(
        self,
        messages: List[Dict[str, str]],
        provider: Optional[str] = None,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        **kwargs
    ) -> AsyncIterator[Dict[str, Any]]:
        """Stream a chat completion.

        Args:
            messages: List of message dicts
            provider: LLM provider
            model: Model name
            temperature: Sampling temperature
            max_tokens: Maximum tokens in response
            **kwargs: Additional parameters

        Yields:
            Dicts with chunk data
        """
        provider = provider or settings.DEFAULT_PROVIDER
        temperature = temperature or settings.TEMPERATURE
        max_tokens = max_tokens or settings.MAX_TOKENS

        # Route to appropriate provider
        if provider == ProviderEnum.OPENAI.value:
            async for chunk in self._openai_stream(
                messages, model, temperature, max_tokens, **kwargs
            ):
                yield chunk
        elif provider == ProviderEnum.ANTHROPIC.value:
            async for chunk in self._anthropic_stream(
                messages, model, temperature, max_tokens, **kwargs
            ):
                yield chunk
        elif provider == ProviderEnum.AZURE_OPENAI.value:
            async for chunk in self._azure_openai_stream(
                messages, model, temperature, max_tokens, **kwargs
            ):
                yield chunk
        else:
            raise ValueError(f"Unsupported provider: {provider}")

    async def _openai_completion(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str],
        temperature: float,
        max_tokens: int,
        **kwargs
    ) -> Dict[str, Any]:
        """OpenAI chat completion."""
        if not self.openai_client:
            raise ValueError("OpenAI client not configured")

        model = model or settings.OPENAI_DEFAULT_MODEL
        start_time = time.time()

        try:
            response = await self.openai_client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                **kwargs
            )

            latency_ms = int((time.time() - start_time) * 1000)

            # Extract response data
            content = response.choices[0].message.content
            usage = response.usage

            # Calculate cost
            cost_usd = self.cost_tracker.calculate_cost(
                model,
                usage.prompt_tokens,
                usage.completion_tokens,
            )

            return {
                "content": content,
                "provider": ProviderEnum.OPENAI.value,
                "model": model,
                "prompt_tokens": usage.prompt_tokens,
                "completion_tokens": usage.completion_tokens,
                "total_tokens": usage.total_tokens,
                "cost_usd": cost_usd,
                "latency_ms": latency_ms,
                "finish_reason": response.choices[0].finish_reason,
            }

        except OpenAIError as e:
            logger.error(f"OpenAI API error: {e}")
            raise

    async def _openai_stream(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str],
        temperature: float,
        max_tokens: int,
        **kwargs
    ) -> AsyncIterator[Dict[str, Any]]:
        """OpenAI streaming completion."""
        if not self.openai_client:
            raise ValueError("OpenAI client not configured")

        model = model or settings.OPENAI_DEFAULT_MODEL
        start_time = time.time()
        first_token_time = None
        total_content = ""

        try:
            stream = await self.openai_client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=True,
                **kwargs
            )

            async for chunk in stream:
                if chunk.choices[0].delta.content:
                    if first_token_time is None:
                        first_token_time = time.time()

                    content = chunk.choices[0].delta.content
                    total_content += content

                    yield {
                        "content": content,
                        "done": False,
                    }

            # Final chunk with metadata
            latency_ms = int((time.time() - start_time) * 1000)
            ttft_ms = int((first_token_time - start_time) * 1000) if first_token_time else None

            yield {
                "content": "",
                "done": True,
                "provider": ProviderEnum.OPENAI.value,
                "model": model,
                "latency_ms": latency_ms,
                "time_to_first_token_ms": ttft_ms,
                "total_content": total_content,
            }

        except OpenAIError as e:
            logger.error(f"OpenAI streaming error: {e}")
            raise

    async def _anthropic_completion(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str],
        temperature: float,
        max_tokens: int,
        **kwargs
    ) -> Dict[str, Any]:
        """Anthropic chat completion."""
        if not self.anthropic_client:
            raise ValueError("Anthropic client not configured")

        model = model or settings.ANTHROPIC_DEFAULT_MODEL
        start_time = time.time()

        try:
            # Convert messages to Anthropic format
            system_message = next(
                (m["content"] for m in messages if m["role"] == "system"),
                None
            )
            anthropic_messages = [
                {"role": m["role"], "content": m["content"]}
                for m in messages
                if m["role"] != "system"
            ]

            response = await self.anthropic_client.messages.create(
                model=model,
                messages=anthropic_messages,
                system=system_message,
                temperature=temperature,
                max_tokens=max_tokens,
                **kwargs
            )

            latency_ms = int((time.time() - start_time) * 1000)

            # Extract response data
            content = response.content[0].text
            usage = response.usage

            # Calculate cost
            cost_usd = self.cost_tracker.calculate_cost(
                model,
                usage.input_tokens,
                usage.output_tokens,
            )

            return {
                "content": content,
                "provider": ProviderEnum.ANTHROPIC.value,
                "model": model,
                "prompt_tokens": usage.input_tokens,
                "completion_tokens": usage.output_tokens,
                "total_tokens": usage.input_tokens + usage.output_tokens,
                "cost_usd": cost_usd,
                "latency_ms": latency_ms,
                "finish_reason": response.stop_reason,
            }

        except AnthropicError as e:
            logger.error(f"Anthropic API error: {e}")
            raise

    async def _anthropic_stream(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str],
        temperature: float,
        max_tokens: int,
        **kwargs
    ) -> AsyncIterator[Dict[str, Any]]:
        """Anthropic streaming completion."""
        if not self.anthropic_client:
            raise ValueError("Anthropic client not configured")

        model = model or settings.ANTHROPIC_DEFAULT_MODEL
        start_time = time.time()
        first_token_time = None
        total_content = ""

        try:
            # Convert messages
            system_message = next(
                (m["content"] for m in messages if m["role"] == "system"),
                None
            )
            anthropic_messages = [
                {"role": m["role"], "content": m["content"]}
                for m in messages
                if m["role"] != "system"
            ]

            async with self.anthropic_client.messages.stream(
                model=model,
                messages=anthropic_messages,
                system=system_message,
                temperature=temperature,
                max_tokens=max_tokens,
                **kwargs
            ) as stream:
                async for text in stream.text_stream:
                    if first_token_time is None:
                        first_token_time = time.time()

                    total_content += text

                    yield {
                        "content": text,
                        "done": False,
                    }

            # Final chunk
            latency_ms = int((time.time() - start_time) * 1000)
            ttft_ms = int((first_token_time - start_time) * 1000) if first_token_time else None

            yield {
                "content": "",
                "done": True,
                "provider": ProviderEnum.ANTHROPIC.value,
                "model": model,
                "latency_ms": latency_ms,
                "time_to_first_token_ms": ttft_ms,
                "total_content": total_content,
            }

        except AnthropicError as e:
            logger.error(f"Anthropic streaming error: {e}")
            raise

    async def _azure_openai_completion(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str],
        temperature: float,
        max_tokens: int,
        **kwargs
    ) -> Dict[str, Any]:
        """Azure OpenAI chat completion."""
        if not self.azure_client:
            raise ValueError("Azure OpenAI client not configured")

        # Use same implementation as OpenAI with azure client
        model = model or settings.OPENAI_DEFAULT_MODEL
        start_time = time.time()

        try:
            response = await self.azure_client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                **kwargs
            )

            latency_ms = int((time.time() - start_time) * 1000)
            content = response.choices[0].message.content
            usage = response.usage

            cost_usd = self.cost_tracker.calculate_cost(
                f"azure-{model}",
                usage.prompt_tokens,
                usage.completion_tokens,
            )

            return {
                "content": content,
                "provider": ProviderEnum.AZURE_OPENAI.value,
                "model": model,
                "prompt_tokens": usage.prompt_tokens,
                "completion_tokens": usage.completion_tokens,
                "total_tokens": usage.total_tokens,
                "cost_usd": cost_usd,
                "latency_ms": latency_ms,
                "finish_reason": response.choices[0].finish_reason,
            }

        except OpenAIError as e:
            logger.error(f"Azure OpenAI API error: {e}")
            raise

    async def _azure_openai_stream(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str],
        temperature: float,
        max_tokens: int,
        **kwargs
    ) -> AsyncIterator[Dict[str, Any]]:
        """Azure OpenAI streaming completion."""
        # Same as OpenAI streaming but with azure client
        async for chunk in self._openai_stream(messages, model, temperature, max_tokens, **kwargs):
            if chunk.get("done"):
                chunk["provider"] = ProviderEnum.AZURE_OPENAI.value
            yield chunk


# Global LLM service instance
llm_service = LLMService()

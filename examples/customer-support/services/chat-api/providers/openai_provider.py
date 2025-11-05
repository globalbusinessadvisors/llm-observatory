"""OpenAI provider implementation."""
import asyncio
from typing import List, Optional, AsyncIterator
from openai import AsyncOpenAI, RateLimitError as OpenAIRateLimitError
from openai import AuthenticationError as OpenAIAuthError
from openai import APIError

from models import Message, ChatResponse, StreamChunk, Tool, UsageStats
from providers.base import (
    BaseProvider,
    RateLimitError,
    AuthenticationError,
    InvalidRequestError,
    ProviderError,
)


class OpenAIProvider(BaseProvider):
    """OpenAI provider implementation."""

    # Pricing per 1M tokens (as of 2024)
    PRICING = {
        "gpt-4-turbo-preview": {"prompt": 10.0, "completion": 30.0},
        "gpt-4": {"prompt": 30.0, "completion": 60.0},
        "gpt-3.5-turbo": {"prompt": 0.5, "completion": 1.5},
        "gpt-3.5-turbo-16k": {"prompt": 3.0, "completion": 4.0},
    }

    def __init__(self, api_key: str, **kwargs):
        """Initialize OpenAI provider."""
        super().__init__(api_key, **kwargs)
        self.client = AsyncOpenAI(api_key=api_key)

    async def complete(
        self,
        messages: List[Message],
        model: str,
        max_tokens: Optional[int] = None,
        temperature: float = 0.7,
        tools: Optional[List[Tool]] = None,
        **kwargs
    ) -> ChatResponse:
        """Generate a chat completion using OpenAI."""
        try:
            # Convert messages to OpenAI format
            openai_messages = [
                {"role": msg.role, "content": msg.content} for msg in messages
            ]

            # Prepare request parameters
            request_params = {
                "model": model,
                "messages": openai_messages,
                "temperature": temperature,
            }

            if max_tokens:
                request_params["max_tokens"] = max_tokens

            # Add function calling if tools provided
            if tools:
                request_params["tools"] = [
                    {
                        "type": "function",
                        "function": {
                            "name": tool.name,
                            "description": tool.description,
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    name: {
                                        "type": param.type,
                                        "description": param.description,
                                        **({"enum": param.enum} if param.enum else {}),
                                    }
                                    for name, param in tool.parameters.items()
                                },
                                "required": [
                                    name
                                    for name, param in tool.parameters.items()
                                    if param.required
                                ],
                            },
                        },
                    }
                    for tool in tools
                ]
                request_params["tool_choice"] = "auto"

            # Make API call
            response = await self.client.chat.completions.create(**request_params)

            # Extract response data
            choice = response.choices[0]
            message_content = choice.message.content or ""

            # Handle tool calls
            tool_calls = None
            if choice.message.tool_calls:
                tool_calls = [
                    {
                        "id": tc.id,
                        "name": tc.function.name,
                        "arguments": tc.function.arguments,
                    }
                    for tc in choice.message.tool_calls
                ]

            # Calculate usage
            usage = response.usage
            estimated_cost = self.estimate_cost(
                usage.prompt_tokens, usage.completion_tokens, model
            )

            return ChatResponse(
                message=Message(role="assistant", content=message_content),
                usage=UsageStats(
                    prompt_tokens=usage.prompt_tokens,
                    completion_tokens=usage.completion_tokens,
                    total_tokens=usage.total_tokens,
                    estimated_cost=estimated_cost,
                ),
                provider=self.name,
                model=model,
                tool_calls=tool_calls,
                finish_reason=choice.finish_reason,
            )

        except OpenAIRateLimitError as e:
            raise RateLimitError(f"OpenAI rate limit exceeded: {e}")
        except OpenAIAuthError as e:
            raise AuthenticationError(f"OpenAI authentication failed: {e}")
        except APIError as e:
            raise ProviderError(f"OpenAI API error: {e}")
        except Exception as e:
            raise ProviderError(f"Unexpected error: {e}")

    async def stream_complete(
        self,
        messages: List[Message],
        model: str,
        max_tokens: Optional[int] = None,
        temperature: float = 0.7,
        tools: Optional[List[Tool]] = None,
        **kwargs
    ) -> AsyncIterator[StreamChunk]:
        """Generate a streaming chat completion using OpenAI."""
        try:
            # Convert messages to OpenAI format
            openai_messages = [
                {"role": msg.role, "content": msg.content} for msg in messages
            ]

            # Prepare request parameters
            request_params = {
                "model": model,
                "messages": openai_messages,
                "temperature": temperature,
                "stream": True,
            }

            if max_tokens:
                request_params["max_tokens"] = max_tokens

            if tools:
                request_params["tools"] = [
                    {
                        "type": "function",
                        "function": {
                            "name": tool.name,
                            "description": tool.description,
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    name: {
                                        "type": param.type,
                                        "description": param.description,
                                        **({"enum": param.enum} if param.enum else {}),
                                    }
                                    for name, param in tool.parameters.items()
                                },
                                "required": [
                                    name
                                    for name, param in tool.parameters.items()
                                    if param.required
                                ],
                            },
                        },
                    }
                    for tool in tools
                ]

            # Make streaming API call
            stream = await self.client.chat.completions.create(**request_params)

            prompt_tokens = 0
            completion_tokens = 0

            async for chunk in stream:
                if not chunk.choices:
                    continue

                choice = chunk.choices[0]
                delta_content = choice.delta.content or ""

                if delta_content:
                    completion_tokens += 1
                    yield StreamChunk(delta=delta_content, finish_reason=None)

                if choice.finish_reason:
                    # Estimate prompt tokens (rough approximation)
                    prompt_tokens = sum(
                        self.count_tokens(msg.content, model) for msg in messages
                    )
                    estimated_cost = self.estimate_cost(
                        prompt_tokens, completion_tokens, model
                    )

                    yield StreamChunk(
                        delta="",
                        finish_reason=choice.finish_reason,
                        usage=UsageStats(
                            prompt_tokens=prompt_tokens,
                            completion_tokens=completion_tokens,
                            total_tokens=prompt_tokens + completion_tokens,
                            estimated_cost=estimated_cost,
                        ),
                    )

        except OpenAIRateLimitError as e:
            raise RateLimitError(f"OpenAI rate limit exceeded: {e}")
        except OpenAIAuthError as e:
            raise AuthenticationError(f"OpenAI authentication failed: {e}")
        except APIError as e:
            raise ProviderError(f"OpenAI API error: {e}")
        except Exception as e:
            raise ProviderError(f"Unexpected error: {e}")

    def count_tokens(self, text: str, model: str) -> int:
        """Count tokens using rough approximation.

        Note: For production, use tiktoken library for accurate counts.
        """
        # Rough approximation: ~4 characters per token
        return len(text) // 4

    def estimate_cost(self, prompt_tokens: int, completion_tokens: int, model: str) -> float:
        """Estimate cost for token usage."""
        pricing = self.PRICING.get(model, {"prompt": 10.0, "completion": 30.0})
        prompt_cost = (prompt_tokens / 1_000_000) * pricing["prompt"]
        completion_cost = (completion_tokens / 1_000_000) * pricing["completion"]
        return prompt_cost + completion_cost

    @property
    def name(self) -> str:
        """Get the provider name."""
        return "openai"

    @property
    def supported_models(self) -> List[str]:
        """Get list of supported models."""
        return list(self.PRICING.keys())

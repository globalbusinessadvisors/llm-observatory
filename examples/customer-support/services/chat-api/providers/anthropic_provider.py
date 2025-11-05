"""Anthropic provider implementation."""
from typing import List, Optional, AsyncIterator
from anthropic import AsyncAnthropic, RateLimitError as AnthropicRateLimitError
from anthropic import AuthenticationError as AnthropicAuthError
from anthropic import APIError

from models import Message, ChatResponse, StreamChunk, Tool, UsageStats
from providers.base import (
    BaseProvider,
    RateLimitError,
    AuthenticationError,
    InvalidRequestError,
    ProviderError,
)


class AnthropicProvider(BaseProvider):
    """Anthropic Claude provider implementation."""

    # Pricing per 1M tokens (as of 2024)
    PRICING = {
        "claude-3-opus-20240229": {"prompt": 15.0, "completion": 75.0},
        "claude-3-sonnet-20240229": {"prompt": 3.0, "completion": 15.0},
        "claude-3-haiku-20240307": {"prompt": 0.25, "completion": 1.25},
        "claude-2.1": {"prompt": 8.0, "completion": 24.0},
        "claude-2.0": {"prompt": 8.0, "completion": 24.0},
    }

    def __init__(self, api_key: str, **kwargs):
        """Initialize Anthropic provider."""
        super().__init__(api_key, **kwargs)
        self.client = AsyncAnthropic(api_key=api_key)

    async def complete(
        self,
        messages: List[Message],
        model: str,
        max_tokens: Optional[int] = None,
        temperature: float = 0.7,
        tools: Optional[List[Tool]] = None,
        **kwargs
    ) -> ChatResponse:
        """Generate a chat completion using Anthropic."""
        try:
            # Separate system message from conversation
            system_message = None
            conversation_messages = []

            for msg in messages:
                if msg.role == "system":
                    system_message = msg.content
                else:
                    conversation_messages.append(
                        {"role": msg.role, "content": msg.content}
                    )

            # Prepare request parameters
            request_params = {
                "model": model,
                "messages": conversation_messages,
                "max_tokens": max_tokens or 4096,
                "temperature": temperature,
            }

            if system_message:
                request_params["system"] = system_message

            # Add tools if provided
            if tools:
                request_params["tools"] = [
                    {
                        "name": tool.name,
                        "description": tool.description,
                        "input_schema": {
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
                    }
                    for tool in tools
                ]

            # Make API call
            response = await self.client.messages.create(**request_params)

            # Extract response data
            message_content = ""
            tool_calls = None

            for content_block in response.content:
                if content_block.type == "text":
                    message_content += content_block.text
                elif content_block.type == "tool_use":
                    if tool_calls is None:
                        tool_calls = []
                    tool_calls.append(
                        {
                            "id": content_block.id,
                            "name": content_block.name,
                            "arguments": content_block.input,
                        }
                    )

            # Calculate usage
            estimated_cost = self.estimate_cost(
                response.usage.input_tokens, response.usage.output_tokens, model
            )

            return ChatResponse(
                message=Message(role="assistant", content=message_content),
                usage=UsageStats(
                    prompt_tokens=response.usage.input_tokens,
                    completion_tokens=response.usage.output_tokens,
                    total_tokens=response.usage.input_tokens + response.usage.output_tokens,
                    estimated_cost=estimated_cost,
                ),
                provider=self.name,
                model=model,
                tool_calls=tool_calls,
                finish_reason=response.stop_reason,
            )

        except AnthropicRateLimitError as e:
            raise RateLimitError(f"Anthropic rate limit exceeded: {e}")
        except AnthropicAuthError as e:
            raise AuthenticationError(f"Anthropic authentication failed: {e}")
        except APIError as e:
            raise ProviderError(f"Anthropic API error: {e}")
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
        """Generate a streaming chat completion using Anthropic."""
        try:
            # Separate system message from conversation
            system_message = None
            conversation_messages = []

            for msg in messages:
                if msg.role == "system":
                    system_message = msg.content
                else:
                    conversation_messages.append(
                        {"role": msg.role, "content": msg.content}
                    )

            # Prepare request parameters
            request_params = {
                "model": model,
                "messages": conversation_messages,
                "max_tokens": max_tokens or 4096,
                "temperature": temperature,
                "stream": True,
            }

            if system_message:
                request_params["system"] = system_message

            if tools:
                request_params["tools"] = [
                    {
                        "name": tool.name,
                        "description": tool.description,
                        "input_schema": {
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
                    }
                    for tool in tools
                ]

            # Make streaming API call
            async with self.client.messages.stream(**request_params) as stream:
                async for event in stream:
                    if event.type == "content_block_delta":
                        if hasattr(event.delta, "text"):
                            yield StreamChunk(delta=event.delta.text, finish_reason=None)

                    elif event.type == "message_delta":
                        if event.delta.stop_reason:
                            # Get final usage from the message
                            final_message = await stream.get_final_message()
                            estimated_cost = self.estimate_cost(
                                final_message.usage.input_tokens,
                                final_message.usage.output_tokens,
                                model,
                            )

                            yield StreamChunk(
                                delta="",
                                finish_reason=event.delta.stop_reason,
                                usage=UsageStats(
                                    prompt_tokens=final_message.usage.input_tokens,
                                    completion_tokens=final_message.usage.output_tokens,
                                    total_tokens=final_message.usage.input_tokens
                                    + final_message.usage.output_tokens,
                                    estimated_cost=estimated_cost,
                                ),
                            )

        except AnthropicRateLimitError as e:
            raise RateLimitError(f"Anthropic rate limit exceeded: {e}")
        except AnthropicAuthError as e:
            raise AuthenticationError(f"Anthropic authentication failed: {e}")
        except APIError as e:
            raise ProviderError(f"Anthropic API error: {e}")
        except Exception as e:
            raise ProviderError(f"Unexpected error: {e}")

    def count_tokens(self, text: str, model: str) -> int:
        """Count tokens using rough approximation.

        Note: For production, use official Anthropic token counting.
        """
        # Rough approximation: ~4 characters per token
        return len(text) // 4

    def estimate_cost(self, prompt_tokens: int, completion_tokens: int, model: str) -> float:
        """Estimate cost for token usage."""
        pricing = self.PRICING.get(model, {"prompt": 3.0, "completion": 15.0})
        prompt_cost = (prompt_tokens / 1_000_000) * pricing["prompt"]
        completion_cost = (completion_tokens / 1_000_000) * pricing["completion"]
        return prompt_cost + completion_cost

    @property
    def name(self) -> str:
        """Get the provider name."""
        return "anthropic"

    @property
    def supported_models(self) -> List[str]:
        """Get list of supported models."""
        return list(self.PRICING.keys())

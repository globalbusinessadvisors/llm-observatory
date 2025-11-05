"""Tests for provider implementations."""
import pytest
from unittest.mock import Mock, AsyncMock, patch

from models import Message
from providers import OpenAIProvider, AnthropicProvider
from providers.base import RateLimitError, AuthenticationError


@pytest.mark.asyncio
class TestOpenAIProvider:
    """Tests for OpenAI provider."""

    async def test_initialization(self):
        """Test provider initialization."""
        provider = OpenAIProvider(api_key="test-key")
        assert provider.name == "openai"
        assert len(provider.supported_models) > 0
        assert provider.api_key == "test-key"

    async def test_count_tokens(self):
        """Test token counting."""
        provider = OpenAIProvider(api_key="test-key")
        text = "Hello, world!"
        tokens = provider.count_tokens(text, "gpt-4")
        assert tokens > 0
        assert tokens == len(text) // 4  # Rough approximation

    async def test_estimate_cost(self):
        """Test cost estimation."""
        provider = OpenAIProvider(api_key="test-key")
        cost = provider.estimate_cost(1000, 500, "gpt-4")
        assert cost > 0
        assert isinstance(cost, float)

    @patch("providers.openai_provider.AsyncOpenAI")
    async def test_complete_success(self, mock_client):
        """Test successful completion."""
        # Mock response
        mock_response = Mock()
        mock_response.choices = [
            Mock(
                message=Mock(content="Test response", tool_calls=None),
                finish_reason="stop",
            )
        ]
        mock_response.usage = Mock(
            prompt_tokens=10, completion_tokens=5, total_tokens=15
        )

        mock_client_instance = AsyncMock()
        mock_client_instance.chat.completions.create = AsyncMock(
            return_value=mock_response
        )
        mock_client.return_value = mock_client_instance

        provider = OpenAIProvider(api_key="test-key")
        messages = [Message(role="user", content="Hello")]

        response = await provider.complete(
            messages=messages, model="gpt-4", temperature=0.7
        )

        assert response.message.content == "Test response"
        assert response.usage.total_tokens == 15
        assert response.provider == "openai"

    @patch("providers.openai_provider.AsyncOpenAI")
    async def test_complete_rate_limit(self, mock_client):
        """Test rate limit handling."""
        from openai import RateLimitError as OpenAIRateLimitError

        mock_client_instance = AsyncMock()
        mock_client_instance.chat.completions.create = AsyncMock(
            side_effect=OpenAIRateLimitError("Rate limit exceeded", response=None, body=None)
        )
        mock_client.return_value = mock_client_instance

        provider = OpenAIProvider(api_key="test-key")
        messages = [Message(role="user", content="Hello")]

        with pytest.raises(RateLimitError):
            await provider.complete(messages=messages, model="gpt-4")


@pytest.mark.asyncio
class TestAnthropicProvider:
    """Tests for Anthropic provider."""

    async def test_initialization(self):
        """Test provider initialization."""
        provider = AnthropicProvider(api_key="test-key")
        assert provider.name == "anthropic"
        assert len(provider.supported_models) > 0

    async def test_estimate_cost(self):
        """Test cost estimation."""
        provider = AnthropicProvider(api_key="test-key")
        cost = provider.estimate_cost(1000, 500, "claude-3-sonnet-20240229")
        assert cost > 0
        assert isinstance(cost, float)

    @patch("providers.anthropic_provider.AsyncAnthropic")
    async def test_complete_with_system_message(self, mock_client):
        """Test completion with system message."""
        mock_response = Mock()
        mock_response.content = [Mock(type="text", text="Test response")]
        mock_response.stop_reason = "end_turn"
        mock_response.usage = Mock(input_tokens=10, output_tokens=5)

        mock_client_instance = AsyncMock()
        mock_client_instance.messages.create = AsyncMock(return_value=mock_response)
        mock_client.return_value = mock_client_instance

        provider = AnthropicProvider(api_key="test-key")
        messages = [
            Message(role="system", content="You are helpful"),
            Message(role="user", content="Hello"),
        ]

        response = await provider.complete(
            messages=messages, model="claude-3-sonnet-20240229", max_tokens=100
        )

        assert response.message.content == "Test response"
        assert response.provider == "anthropic"

        # Verify system message was passed separately
        call_args = mock_client_instance.messages.create.call_args
        assert "system" in call_args.kwargs
        assert call_args.kwargs["system"] == "You are helpful"

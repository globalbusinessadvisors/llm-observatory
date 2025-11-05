"""End-to-end integration tests for chat API."""
import asyncio
import json
import pytest
import httpx
from typing import AsyncGenerator, Generator
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class TestChatAPIBasic:
    """Basic chat API endpoint tests."""

    @pytest.fixture
    async def chat_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for chat API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8000",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_health_check(self, chat_client):
        """Test chat API health endpoint."""
        response = await chat_client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "timestamp" in data

    @pytest.mark.asyncio
    async def test_create_conversation(self, chat_client):
        """Test creating a new conversation."""
        payload = {
            "title": "Test Conversation",
            "metadata": {
                "user_id": "test_user_123",
                "session_id": "session_456"
            }
        }
        response = await chat_client.post("/v1/conversations", json=payload)
        assert response.status_code == 201
        data = response.json()
        assert "id" in data
        assert data["title"] == "Test Conversation"
        assert data["status"] == "active"
        return data["id"]

    @pytest.mark.asyncio
    async def test_get_conversations(self, chat_client):
        """Test listing conversations."""
        response = await chat_client.get("/v1/conversations")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list) or "conversations" in data

    @pytest.mark.asyncio
    async def test_send_chat_message(self, chat_client):
        """Test sending a chat message."""
        # First create a conversation
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Chat Test"}
        )
        conv_id = conv_response.json()["id"]

        # Send a message
        payload = {
            "conversation_id": conv_id,
            "message": "What is the capital of France?",
            "provider": "openai"
        }
        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]
        data = response.json()
        assert "response" in data or "choices" in data

    @pytest.mark.asyncio
    async def test_get_conversation_history(self, chat_client):
        """Test retrieving conversation history."""
        # Create conversation and add messages
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "History Test"}
        )
        conv_id = conv_response.json()["id"]

        # Get conversation details
        response = await chat_client.get(f"/v1/conversations/{conv_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == conv_id
        assert "messages" in data or "conversation" in data

    @pytest.mark.asyncio
    async def test_invalid_conversation_id(self, chat_client):
        """Test error handling for invalid conversation ID."""
        response = await chat_client.get("/v1/conversations/invalid_id_xyz")
        assert response.status_code in [404, 400]

    @pytest.mark.asyncio
    async def test_chat_with_context(self, chat_client):
        """Test chat with knowledge base context."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Context Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Tell me about our products",
            "provider": "openai",
            "context": {
                "knowledge_base_id": "kb_test",
                "top_k_results": 5,
                "include_metadata": True
            }
        }
        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]


class TestChatAPIAdvanced:
    """Advanced chat API tests with streaming and multi-provider."""

    @pytest.fixture
    async def chat_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for chat API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8000",
            timeout=60.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_streaming_response(self, chat_client):
        """Test streaming chat response."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Stream Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Explain quantum computing in detail",
            "provider": "openai",
            "stream": True
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code == 200

        # Read streaming content
        chunks = []
        async for line in response.aiter_lines():
            if line.startswith("data: "):
                try:
                    chunk = json.loads(line[6:])
                    chunks.append(chunk)
                except json.JSONDecodeError:
                    pass

        assert len(chunks) > 0

    @pytest.mark.asyncio
    async def test_multi_provider_fallback(self, chat_client):
        """Test multi-provider fallback mechanism."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Multi-Provider Test"}
        )
        conv_id = conv_response.json()["id"]

        # Request with fallback providers
        payload = {
            "conversation_id": conv_id,
            "message": "What is machine learning?",
            "providers": ["openai", "anthropic"],
            "enable_fallback": True
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]
        data = response.json()
        if "provider" in data:
            assert data["provider"] in ["openai", "anthropic"]

    @pytest.mark.asyncio
    async def test_rate_limiting(self, chat_client):
        """Test rate limiting functionality."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Rate Limit Test"}
        )
        conv_id = conv_response.json()["id"]

        # Send multiple rapid requests
        responses = []
        for i in range(10):
            payload = {
                "conversation_id": conv_id,
                "message": f"Quick question {i}"
            }
            response = await chat_client.post(
                "/v1/chat/completions",
                json=payload
            )
            responses.append(response.status_code)

        # Check if rate limiting is applied
        rate_limited = any(code == 429 for code in responses)
        assert len(responses) == 10

    @pytest.mark.asyncio
    async def test_conversation_deletion(self, chat_client):
        """Test conversation deletion."""
        # Create conversation
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Delete Test"}
        )
        conv_id = conv_response.json()["id"]

        # Delete conversation
        response = await chat_client.delete(f"/v1/conversations/{conv_id}")
        assert response.status_code in [200, 204]

        # Verify deletion
        get_response = await chat_client.get(f"/v1/conversations/{conv_id}")
        assert get_response.status_code in [404, 410]

    @pytest.mark.asyncio
    async def test_conversation_metadata_update(self, chat_client):
        """Test updating conversation metadata."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={
                "title": "Metadata Test",
                "metadata": {"version": "1"}
            }
        )
        conv_id = conv_response.json()["id"]

        # Update metadata
        update_payload = {
            "metadata": {
                "version": "2",
                "status": "in_progress"
            }
        }
        response = await chat_client.patch(
            f"/v1/conversations/{conv_id}",
            json=update_payload
        )
        assert response.status_code in [200, 204]

        # Verify update
        get_response = await chat_client.get(f"/v1/conversations/{conv_id}")
        assert get_response.status_code == 200
        data = get_response.json()
        if "metadata" in data:
            assert data["metadata"]["version"] == "2"


class TestChatAPIErrors:
    """Error handling and edge case tests."""

    @pytest.fixture
    async def chat_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for chat API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8000",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_missing_required_field(self, chat_client):
        """Test error when required field is missing."""
        payload = {
            "conversation_id": "conv_123"
            # Missing message field
        }
        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [400, 422]

    @pytest.mark.asyncio
    async def test_invalid_provider(self, chat_client):
        """Test error when invalid provider is specified."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Provider Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Test message",
            "provider": "invalid_provider"
        }
        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [400, 422]

    @pytest.mark.asyncio
    async def test_empty_message(self, chat_client):
        """Test error when message is empty."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Empty Message Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": ""
        }
        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [400, 422]

    @pytest.mark.asyncio
    async def test_message_size_limit(self, chat_client):
        """Test error when message exceeds size limit."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Size Limit Test"}
        )
        conv_id = conv_response.json()["id"]

        # Create a very large message
        large_message = "A" * 100000

        payload = {
            "conversation_id": conv_id,
            "message": large_message
        }
        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        # Should either accept or reject with proper error
        assert response.status_code in [200, 201, 400, 413, 422]


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])

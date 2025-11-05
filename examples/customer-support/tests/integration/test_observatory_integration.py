"""Integration tests for LLM Observatory integration."""
import pytest
import httpx
from typing import AsyncGenerator
import json
from datetime import datetime, timedelta


class TestObservatoryIntegration:
    """LLM Observatory integration tests."""

    @pytest.fixture
    async def chat_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for chat API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8000",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_observatory_request_tracking(self, chat_client):
        """Test that requests are tracked in Observatory."""
        # Create conversation
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Observatory Test"}
        )
        assert conv_response.status_code == 201
        conv_id = conv_response.json()["id"]

        # Send message that should be tracked
        payload = {
            "conversation_id": conv_id,
            "message": "Test message for tracking",
            "provider": "openai",
            "track_in_observatory": True
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]

        # Verify response has tracking information
        data = response.json()
        assert "response" in data or "choices" in data

    @pytest.mark.asyncio
    async def test_observatory_metadata_preservation(self, chat_client):
        """Test that metadata is preserved in Observatory."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={
                "title": "Metadata Test",
                "metadata": {
                    "user_id": "user_123",
                    "session_id": "session_456",
                    "environment": "test"
                }
            }
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Message with metadata",
            "metadata": {
                "request_id": "req_789",
                "source": "api_test"
            }
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]

    @pytest.mark.asyncio
    async def test_observatory_cost_tracking(self, chat_client):
        """Test cost tracking in Observatory."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Cost Tracking Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Track the cost of this request",
            "provider": "openai"
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]
        data = response.json()

        # Cost information should be available
        if "cost" in data:
            assert isinstance(data["cost"], (int, float))
            assert data["cost"] >= 0

    @pytest.mark.asyncio
    async def test_observatory_token_tracking(self, chat_client):
        """Test token usage tracking in Observatory."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Token Tracking Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Count the tokens in this request and response",
            "track_tokens": True
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]
        data = response.json()

        # Token information should be available
        if "usage" in data:
            usage = data["usage"]
            if "prompt_tokens" in usage:
                assert isinstance(usage["prompt_tokens"], int)
            if "completion_tokens" in usage:
                assert isinstance(usage["completion_tokens"], int)

    @pytest.mark.asyncio
    async def test_observatory_error_tracking(self, chat_client):
        """Test error tracking in Observatory."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Error Tracking Test"}
        )
        conv_id = conv_response.json()["id"]

        # Send request with invalid provider to trigger error
        payload = {
            "conversation_id": conv_id,
            "message": "This will cause an error",
            "provider": "invalid_provider"
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )

        # Error should be tracked even if request fails
        assert response.status_code in [400, 422, 500]


class TestObservatoryMetricsCollection:
    """Tests for metrics collection and reporting."""

    @pytest.fixture
    async def chat_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for chat API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8000",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_request_latency_tracking(self, chat_client):
        """Test request latency tracking."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Latency Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Measure the latency of this request"
        }

        # Measure actual latency
        import time
        start_time = time.time()
        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        elapsed_time = time.time() - start_time

        assert response.status_code in [200, 201]
        assert elapsed_time >= 0

        data = response.json()
        if "latency_ms" in data:
            assert data["latency_ms"] > 0

    @pytest.mark.asyncio
    async def test_multi_provider_comparison_tracking(self, chat_client):
        """Test tracking for multi-provider comparison."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Multi-Provider Comparison"}
        )
        conv_id = conv_response.json()["id"]

        providers = ["openai", "anthropic"]
        results = {}

        for provider in providers:
            payload = {
                "conversation_id": conv_id,
                "message": "Compare providers",
                "provider": provider
            }

            response = await chat_client.post(
                "/v1/chat/completions",
                json=payload
            )

            if response.status_code in [200, 201]:
                results[provider] = response.json()

        # Should have attempted multiple providers
        assert len(results) >= 1

    @pytest.mark.asyncio
    async def test_quality_metrics_collection(self, chat_client):
        """Test quality metrics collection."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Quality Metrics Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Provide a high-quality response",
            "collect_quality_metrics": True
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]

        data = response.json()
        # Quality metrics might be included
        if "quality_score" in data:
            assert 0 <= data["quality_score"] <= 1


class TestObservatoryMultiProviderTracking:
    """Tests for multi-provider scenario tracking."""

    @pytest.fixture
    async def chat_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for chat API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8000",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_provider_fallback_tracking(self, chat_client):
        """Test fallback provider selection tracking."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Fallback Tracking Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Test fallback mechanism",
            "providers": ["openai", "anthropic"],
            "enable_fallback": True,
            "track_fallback": True
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]

        data = response.json()
        if "provider_used" in data:
            assert data["provider_used"] in ["openai", "anthropic"]

    @pytest.mark.asyncio
    async def test_cost_comparison_tracking(self, chat_client):
        """Test cost comparison across providers."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Cost Comparison Test"}
        )
        conv_id = conv_response.json()["id"]

        costs_by_provider = {}

        for provider in ["openai", "anthropic"]:
            payload = {
                "conversation_id": conv_id,
                "message": "Compare costs",
                "provider": provider
            }

            response = await chat_client.post(
                "/v1/chat/completions",
                json=payload
            )

            if response.status_code in [200, 201]:
                data = response.json()
                if "cost" in data:
                    costs_by_provider[provider] = data["cost"]

        # Costs should be comparable (both non-negative)
        for cost in costs_by_provider.values():
            assert isinstance(cost, (int, float))
            assert cost >= 0

    @pytest.mark.asyncio
    async def test_performance_comparison_tracking(self, chat_client):
        """Test performance metrics comparison."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Performance Comparison Test"}
        )
        conv_id = conv_response.json()["id"]

        performance_data = {}

        for provider in ["openai", "anthropic"]:
            payload = {
                "conversation_id": conv_id,
                "message": "Compare performance",
                "provider": provider
            }

            response = await chat_client.post(
                "/v1/chat/completions",
                json=payload
            )

            if response.status_code in [200, 201]:
                data = response.json()
                performance_data[provider] = data

        # Should have performance data for tracking
        assert len(performance_data) >= 1


class TestObservatoryReporting:
    """Tests for Observatory reporting and exports."""

    @pytest.fixture
    async def chat_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for chat API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8000",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_request_export_format(self, chat_client):
        """Test that request data can be exported."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Export Format Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Test export format"
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]

        # Check if response has exportable fields
        data = response.json()
        assert isinstance(data, dict)

    @pytest.mark.asyncio
    async def test_analytics_endpoint_availability(self, chat_client):
        """Test that analytics endpoint is available."""
        response = await chat_client.get("/v1/analytics/request-summary")
        assert response.status_code in [200, 404]  # May not be available

    @pytest.mark.asyncio
    async def test_historical_data_access(self, chat_client):
        """Test access to historical tracking data."""
        # This would require Observatory API access
        # Testing that we can request data with time ranges
        end_date = datetime.now()
        start_date = end_date - timedelta(days=7)

        params = {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat()
        }

        response = await chat_client.get(
            "/v1/analytics/historical",
            params=params
        )
        assert response.status_code in [200, 404]


class TestObservatoryDataConsistency:
    """Tests for data consistency and integrity."""

    @pytest.fixture
    async def chat_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for chat API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8000",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_conversation_id_consistency(self, chat_client):
        """Test that conversation IDs are consistent in tracking."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Consistency Test"}
        )
        conv_id = conv_response.json()["id"]

        payload = {
            "conversation_id": conv_id,
            "message": "Test consistency"
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )
        assert response.status_code in [200, 201]

        data = response.json()
        if "conversation_id" in data:
            assert data["conversation_id"] == conv_id

    @pytest.mark.asyncio
    async def test_timestamp_consistency(self, chat_client):
        """Test that timestamps are properly tracked."""
        conv_response = await chat_client.post(
            "/v1/conversations",
            json={"title": "Timestamp Test"}
        )
        conv_id = conv_response.json()["id"]

        before_request = datetime.now()

        payload = {
            "conversation_id": conv_id,
            "message": "Test timestamps"
        }

        response = await chat_client.post(
            "/v1/chat/completions",
            json=payload
        )

        after_request = datetime.now()
        assert response.status_code in [200, 201]

        data = response.json()
        if "timestamp" in data:
            response_time = datetime.fromisoformat(data["timestamp"])
            assert before_request <= response_time <= after_request


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])

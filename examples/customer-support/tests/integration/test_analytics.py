"""Integration tests for analytics API."""
import pytest
import httpx
from typing import AsyncGenerator
from datetime import datetime, timedelta
import json


class TestAnalyticsAPIBasic:
    """Basic analytics API tests."""

    @pytest.fixture
    async def analytics_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for analytics API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8002",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_analytics_health_check(self, analytics_client):
        """Test analytics API health endpoint."""
        response = await analytics_client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data.get("status") == "ok"

    @pytest.mark.asyncio
    async def test_get_metrics_summary(self, analytics_client):
        """Test getting metrics summary."""
        response = await analytics_client.get("/v1/metrics/summary")
        assert response.status_code == 200
        data = response.json()
        assert "summary" in data or "metrics" in data


class TestAnalyticsConversationMetrics:
    """Conversation metrics tests."""

    @pytest.fixture
    async def analytics_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for analytics API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8002",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_conversation_metrics(self, analytics_client):
        """Test retrieving conversation metrics."""
        response = await analytics_client.get("/v1/metrics/conversations")
        assert response.status_code == 200
        data = response.json()
        assert "conversations" in data or "metrics" in data

    @pytest.mark.asyncio
    async def test_conversation_metrics_with_filters(self, analytics_client):
        """Test conversation metrics with date filters."""
        end_date = datetime.now()
        start_date = end_date - timedelta(days=7)

        params = {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "conversation_id": "conv_123"
        }

        response = await analytics_client.get(
            "/v1/metrics/conversations",
            params=params
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_conversation_count(self, analytics_client):
        """Test getting conversation count."""
        response = await analytics_client.get("/v1/metrics/conversations/count")
        assert response.status_code == 200
        data = response.json()
        assert "count" in data or "total" in data

    @pytest.mark.asyncio
    async def test_average_response_time(self, analytics_client):
        """Test getting average response time."""
        response = await analytics_client.get(
            "/v1/metrics/conversations/avg-response-time"
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_user_engagement_metrics(self, analytics_client):
        """Test user engagement metrics."""
        response = await analytics_client.get("/v1/metrics/engagement")
        assert response.status_code == 200


class TestAnalyticsCostMetrics:
    """Cost tracking and analysis tests."""

    @pytest.fixture
    async def analytics_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for analytics API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8002",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_cost_analysis(self, analytics_client):
        """Test cost analysis endpoint."""
        response = await analytics_client.get("/v1/metrics/costs")
        assert response.status_code == 200
        data = response.json()
        assert "costs" in data or "total_cost" in data

    @pytest.mark.asyncio
    async def test_cost_by_provider(self, analytics_client):
        """Test cost breakdown by provider."""
        response = await analytics_client.get("/v1/metrics/costs/by-provider")
        assert response.status_code == 200
        data = response.json()
        # Should have cost information
        assert isinstance(data, (dict, list))

    @pytest.mark.asyncio
    async def test_cost_by_model(self, analytics_client):
        """Test cost breakdown by model."""
        response = await analytics_client.get("/v1/metrics/costs/by-model")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_cost_forecast(self, analytics_client):
        """Test cost forecasting."""
        params = {
            "days": 30
        }
        response = await analytics_client.get(
            "/v1/metrics/costs/forecast",
            params=params
        )
        assert response.status_code in [200, 404]  # May not be implemented

    @pytest.mark.asyncio
    async def test_cost_trends(self, analytics_client):
        """Test cost trends over time."""
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)

        params = {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "granularity": "daily"
        }

        response = await analytics_client.get(
            "/v1/metrics/costs/trends",
            params=params
        )
        assert response.status_code in [200, 404]


class TestAnalyticsPerformanceMetrics:
    """Performance metrics tests."""

    @pytest.fixture
    async def analytics_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for analytics API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8002",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_performance_summary(self, analytics_client):
        """Test performance metrics summary."""
        response = await analytics_client.get("/v1/metrics/performance")
        assert response.status_code == 200
        data = response.json()
        # Should have performance data
        assert isinstance(data, dict)

    @pytest.mark.asyncio
    async def test_latency_percentiles(self, analytics_client):
        """Test latency percentile metrics."""
        response = await analytics_client.get(
            "/v1/metrics/performance/latency-percentiles"
        )
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_throughput_metrics(self, analytics_client):
        """Test throughput metrics."""
        response = await analytics_client.get("/v1/metrics/performance/throughput")
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_error_rate(self, analytics_client):
        """Test error rate metrics."""
        response = await analytics_client.get("/v1/metrics/performance/error-rate")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_token_usage_metrics(self, analytics_client):
        """Test token usage metrics."""
        response = await analytics_client.get("/v1/metrics/performance/token-usage")
        assert response.status_code in [200, 404]


class TestAnalyticsLLMMetrics:
    """LLM-specific metrics tests."""

    @pytest.fixture
    async def analytics_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for analytics API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8002",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_llm_request_metrics(self, analytics_client):
        """Test LLM request metrics."""
        response = await analytics_client.get("/v1/metrics/llm/requests")
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_model_usage_distribution(self, analytics_client):
        """Test model usage distribution."""
        response = await analytics_client.get("/v1/metrics/llm/models")
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_prompt_metrics(self, analytics_client):
        """Test prompt-related metrics."""
        response = await analytics_client.get("/v1/metrics/llm/prompts")
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_quality_metrics(self, analytics_client):
        """Test quality metrics."""
        response = await analytics_client.get("/v1/metrics/llm/quality")
        assert response.status_code in [200, 404]


class TestAnalyticsAggregations:
    """Data aggregation and grouping tests."""

    @pytest.fixture
    async def analytics_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for analytics API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8002",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_metrics_by_time_period(self, analytics_client):
        """Test metrics aggregated by time period."""
        params = {
            "granularity": "hourly",
            "limit": 24
        }
        response = await analytics_client.get(
            "/v1/metrics/timeseries",
            params=params
        )
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_metrics_by_user(self, analytics_client):
        """Test metrics grouped by user."""
        response = await analytics_client.get("/v1/metrics/by-user")
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_metrics_by_endpoint(self, analytics_client):
        """Test metrics grouped by endpoint."""
        response = await analytics_client.get("/v1/metrics/by-endpoint")
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_comparison_metrics(self, analytics_client):
        """Test metrics comparison."""
        params = {
            "metric1": "cost",
            "metric2": "performance",
            "period": "week"
        }
        response = await analytics_client.get(
            "/v1/metrics/compare",
            params=params
        )
        assert response.status_code in [200, 404]


class TestAnalyticsErrors:
    """Error handling tests."""

    @pytest.fixture
    async def analytics_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for analytics API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8002",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_invalid_date_range(self, analytics_client):
        """Test error with invalid date range."""
        params = {
            "start_date": "2025-01-01",
            "end_date": "2024-01-01"  # End before start
        }
        response = await analytics_client.get(
            "/v1/metrics/conversations",
            params=params
        )
        assert response.status_code in [400, 422]

    @pytest.mark.asyncio
    async def test_invalid_granularity(self, analytics_client):
        """Test error with invalid granularity."""
        params = {
            "granularity": "invalid"
        }
        response = await analytics_client.get(
            "/v1/metrics/timeseries",
            params=params
        )
        assert response.status_code in [400, 404, 422]

    @pytest.mark.asyncio
    async def test_nonexistent_metric(self, analytics_client):
        """Test error when requesting nonexistent metric."""
        response = await analytics_client.get("/v1/metrics/nonexistent")
        assert response.status_code in [404, 400]


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])

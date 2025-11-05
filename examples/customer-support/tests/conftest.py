"""Pytest configuration and fixtures for integration tests."""
import pytest
import asyncio
import httpx
from typing import AsyncGenerator, Generator
import logging
import os
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@pytest.fixture(scope='session')
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def test_user_id():
    """Generate test user ID."""
    return f"test_user_{int(datetime.now().timestamp())}"


@pytest.fixture
def test_session_id():
    """Generate test session ID."""
    return f"test_session_{int(datetime.now().timestamp())}"


@pytest.fixture
async def chat_api_client() -> AsyncGenerator[httpx.AsyncClient, None]:
    """Fixture for chat API client."""
    async with httpx.AsyncClient(
        base_url="http://localhost:8000",
        timeout=30.0
    ) as client:
        yield client


@pytest.fixture
async def kb_api_client() -> AsyncGenerator[httpx.AsyncClient, None]:
    """Fixture for KB API client."""
    async with httpx.AsyncClient(
        base_url="http://localhost:8001",
        timeout=30.0
    ) as client:
        yield client


@pytest.fixture
async def analytics_api_client() -> AsyncGenerator[httpx.AsyncClient, None]:
    """Fixture for analytics API client."""
    async with httpx.AsyncClient(
        base_url="http://localhost:8002",
        timeout=30.0
    ) as client:
        yield client


@pytest.fixture
def api_timeout():
    """API timeout in seconds."""
    return 30


@pytest.fixture
def test_data_dir():
    """Get test data directory."""
    return os.path.join(os.path.dirname(__file__), 'data')


@pytest.fixture
def sample_conversation_payload(test_user_id, test_session_id):
    """Sample conversation creation payload."""
    return {
        "title": f"Test Conversation {datetime.now().isoformat()}",
        "metadata": {
            "user_id": test_user_id,
            "session_id": test_session_id,
            "environment": "test",
        }
    }


@pytest.fixture
def sample_message_payload():
    """Sample chat message payload."""
    return {
        "message": "What is customer support?",
        "provider": "openai"
    }


@pytest.fixture
def sample_search_payload():
    """Sample knowledge base search payload."""
    return {
        "query": "password reset",
        "top_k": 5
    }


@pytest.fixture(autouse=True)
def reset_modules():
    """Reset modules between tests."""
    yield
    # Cleanup can go here if needed


@pytest.fixture(scope='session', autouse=True)
def setup_test_environment():
    """Setup test environment."""
    logger.info("Setting up test environment...")

    # Verify services are accessible
    try:
        import httpx
        with httpx.Client(timeout=5) as client:
            # Check chat API
            try:
                response = client.get("http://localhost:8000/health")
                logger.info(f"Chat API health: {response.status_code}")
            except Exception as e:
                logger.warning(f"Chat API not ready: {e}")

            # Check KB API
            try:
                response = client.get("http://localhost:8001/health")
                logger.info(f"KB API health: {response.status_code}")
            except Exception as e:
                logger.warning(f"KB API not ready: {e}")

            # Check Analytics API
            try:
                response = client.get("http://localhost:8002/health")
                logger.info(f"Analytics API health: {response.status_code}")
            except Exception as e:
                logger.warning(f"Analytics API not ready: {e}")
    except Exception as e:
        logger.error(f"Error checking service health: {e}")

    yield

    logger.info("Tearing down test environment...")


# Pytest marks for test categorization
def pytest_configure(config):
    """Register custom markers."""
    config.addinivalue_line(
        "markers", "integration: marks tests as integration tests"
    )
    config.addinivalue_line(
        "markers", "unit: marks tests as unit tests"
    )
    config.addinivalue_line(
        "markers", "slow: marks tests as slow running"
    )
    config.addinivalue_line(
        "markers", "chat: marks tests related to chat API"
    )
    config.addinivalue_line(
        "markers", "kb: marks tests related to KB API"
    )
    config.addinivalue_line(
        "markers", "analytics: marks tests related to analytics API"
    )
    config.addinivalue_line(
        "markers", "observatory: marks tests related to observatory integration"
    )

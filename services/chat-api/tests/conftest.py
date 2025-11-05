"""Pytest configuration and fixtures."""

import asyncio
from typing import AsyncGenerator, Generator
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool

from app.main import app
from app.database.models import Base
from app.database.session import get_db
from app.core.config import settings


# Test database URL
TEST_DATABASE_URL = "postgresql+asyncpg://postgres:postgres@localhost:5432/llm_observatory_test"


@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="function")
async def test_engine():
    """Create test database engine."""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        echo=False,
        poolclass=NullPool,
    )

    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield engine

    # Drop tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest.fixture(scope="function")
async def test_db(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """Create test database session."""
    TestSessionLocal = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with TestSessionLocal() as session:
        yield session


@pytest.fixture(scope="function")
async def client(test_db) -> AsyncGenerator[AsyncClient, None]:
    """Create test HTTP client."""

    async def override_get_db():
        yield test_db

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest.fixture
def sample_conversation_data():
    """Sample conversation data for testing."""
    return {
        "user_id": "test_user_123",
        "title": "Test Conversation",
        "metadata": {"source": "test"},
    }


@pytest.fixture
def sample_message_data():
    """Sample message data for testing."""
    return {
        "content": "Hello, this is a test message",
        "role": "user",
        "metadata": {"test": True},
    }


@pytest.fixture
def sample_chat_request():
    """Sample chat request data."""
    return {
        "message": "What is the weather today?",
        "provider": "openai",
        "model": "gpt-3.5-turbo",
        "temperature": 0.7,
        "max_tokens": 100,
    }


@pytest.fixture
def mock_llm_response():
    """Mock LLM response data."""
    return {
        "content": "This is a mock response from the LLM.",
        "provider": "openai",
        "model": "gpt-3.5-turbo",
        "prompt_tokens": 50,
        "completion_tokens": 25,
        "total_tokens": 75,
        "cost_usd": 0.000150,
        "latency_ms": 500,
        "finish_reason": "stop",
    }

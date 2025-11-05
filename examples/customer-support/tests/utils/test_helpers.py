"""Helper functions for tests."""
import httpx
from typing import Optional, Dict, Any
import json


async def create_test_conversation(
    client: httpx.AsyncClient,
    title: str = "Test Conversation",
    metadata: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """Create a test conversation."""
    payload = {
        "title": title,
        "metadata": metadata or {}
    }

    response = await client.post(
        "/v1/conversations",
        json=payload
    )

    if response.status_code in [200, 201]:
        return response.json()
    else:
        raise Exception(f"Failed to create conversation: {response.status_code}")


async def send_test_message(
    client: httpx.AsyncClient,
    conversation_id: str,
    message: str,
    provider: str = "openai",
    **kwargs
) -> Dict[str, Any]:
    """Send a test message to a conversation."""
    payload = {
        "conversation_id": conversation_id,
        "message": message,
        "provider": provider,
        **kwargs
    }

    response = await client.post(
        "/v1/chat/completions",
        json=payload
    )

    if response.status_code in [200, 201]:
        return response.json()
    else:
        raise Exception(f"Failed to send message: {response.status_code}")


async def get_conversation_history(
    client: httpx.AsyncClient,
    conversation_id: str
) -> Dict[str, Any]:
    """Get conversation history."""
    response = await client.get(f"/v1/conversations/{conversation_id}")

    if response.status_code == 200:
        return response.json()
    else:
        raise Exception(f"Failed to get conversation: {response.status_code}")


async def search_knowledge_base(
    client: httpx.AsyncClient,
    query: str,
    top_k: int = 5,
    **kwargs
) -> Dict[str, Any]:
    """Search knowledge base."""
    payload = {
        "query": query,
        "top_k": top_k,
        **kwargs
    }

    response = await client.post(
        "/v1/search",
        json=payload
    )

    if response.status_code == 200:
        return response.json()
    else:
        raise Exception(f"Failed to search: {response.status_code}")


async def create_test_document(
    client: httpx.AsyncClient,
    filename: str,
    content: str,
    metadata: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """Create and upload a test document."""
    files = {
        'file': (filename, content.encode(), 'text/plain'),
    }

    data = {}
    if metadata:
        data['metadata'] = json.dumps(metadata)

    response = await client.post(
        "/v1/documents",
        files=files,
        data=data
    )

    if response.status_code in [200, 201]:
        return response.json()
    else:
        raise Exception(f"Failed to create document: {response.status_code}")


class TestContextManager:
    """Context manager for test cleanup."""

    def __init__(self, client: httpx.AsyncClient):
        self.client = client
        self.created_conversations = []
        self.created_documents = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Clean up created resources."""
        # Delete created conversations
        for conv_id in self.created_conversations:
            try:
                await self.client.delete(f"/v1/conversations/{conv_id}")
            except Exception:
                pass

        # Delete created documents
        for doc_id in self.created_documents:
            try:
                await self.client.delete(f"/v1/documents/{doc_id}")
            except Exception:
                pass

    async def create_conversation(self, **kwargs):
        """Create conversation and track for cleanup."""
        conv = await create_test_conversation(self.client, **kwargs)
        self.created_conversations.append(conv['id'])
        return conv

    async def create_document(self, **kwargs):
        """Create document and track for cleanup."""
        doc = await create_test_document(self.client, **kwargs)
        self.created_documents.append(doc.get('id') or doc.get('document_id'))
        return doc


def assert_valid_timestamp(timestamp_str: str) -> bool:
    """Assert timestamp is valid ISO format."""
    from datetime import datetime
    try:
        datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
        return True
    except (ValueError, TypeError):
        return False


def assert_valid_uuid(uuid_str: str) -> bool:
    """Assert UUID is valid."""
    import re
    uuid_pattern = re.compile(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        re.IGNORECASE
    )
    return bool(uuid_pattern.match(str(uuid_str)))


def assert_valid_cost(cost: Any) -> bool:
    """Assert cost is a valid number."""
    try:
        cost_float = float(cost)
        return cost_float >= 0
    except (ValueError, TypeError):
        return False

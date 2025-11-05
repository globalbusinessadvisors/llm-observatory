"""Integration tests for conversation endpoints."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestConversationEndpoints:
    """Test conversation CRUD operations."""

    async def test_create_conversation(self, client: AsyncClient, sample_conversation_data):
        """Test creating a conversation."""
        response = await client.post(
            "/api/v1/conversations",
            json=sample_conversation_data,
        )

        assert response.status_code == 201
        data = response.json()
        assert "id" in data
        assert data["user_id"] == sample_conversation_data["user_id"]
        assert data["title"] == sample_conversation_data["title"]
        assert "created_at" in data
        assert "updated_at" in data

    async def test_list_conversations(self, client: AsyncClient, sample_conversation_data):
        """Test listing conversations."""
        # Create a conversation first
        create_response = await client.post(
            "/api/v1/conversations",
            json=sample_conversation_data,
        )
        assert create_response.status_code == 201

        # List conversations
        response = await client.get("/api/v1/conversations")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1

    async def test_list_conversations_with_user_filter(
        self, client: AsyncClient, sample_conversation_data
    ):
        """Test listing conversations filtered by user."""
        # Create conversation
        create_response = await client.post(
            "/api/v1/conversations",
            json=sample_conversation_data,
        )
        assert create_response.status_code == 201

        # List with filter
        response = await client.get(
            "/api/v1/conversations",
            params={"user_id": sample_conversation_data["user_id"]},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert all(c["user_id"] == sample_conversation_data["user_id"] for c in data)

    async def test_get_conversation(self, client: AsyncClient, sample_conversation_data):
        """Test getting a conversation by ID."""
        # Create conversation
        create_response = await client.post(
            "/api/v1/conversations",
            json=sample_conversation_data,
        )
        conversation_id = create_response.json()["id"]

        # Get conversation
        response = await client.get(f"/api/v1/conversations/{conversation_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == conversation_id
        assert "messages" in data
        assert isinstance(data["messages"], list)

    async def test_get_nonexistent_conversation(self, client: AsyncClient):
        """Test getting a conversation that doesn't exist."""
        response = await client.get(
            "/api/v1/conversations/00000000-0000-0000-0000-000000000000"
        )
        assert response.status_code == 404

    async def test_update_conversation(self, client: AsyncClient, sample_conversation_data):
        """Test updating a conversation."""
        # Create conversation
        create_response = await client.post(
            "/api/v1/conversations",
            json=sample_conversation_data,
        )
        conversation_id = create_response.json()["id"]

        # Update conversation
        update_data = {"title": "Updated Title"}
        response = await client.patch(
            f"/api/v1/conversations/{conversation_id}",
            json=update_data,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Updated Title"

    async def test_delete_conversation(self, client: AsyncClient, sample_conversation_data):
        """Test deleting a conversation."""
        # Create conversation
        create_response = await client.post(
            "/api/v1/conversations",
            json=sample_conversation_data,
        )
        conversation_id = create_response.json()["id"]

        # Delete conversation
        response = await client.delete(f"/api/v1/conversations/{conversation_id}")
        assert response.status_code == 204

        # Verify deletion
        get_response = await client.get(f"/api/v1/conversations/{conversation_id}")
        assert get_response.status_code == 404

    async def test_create_feedback(self, client: AsyncClient, sample_conversation_data):
        """Test creating feedback for a conversation."""
        # Create conversation
        create_response = await client.post(
            "/api/v1/conversations",
            json=sample_conversation_data,
        )
        conversation_id = create_response.json()["id"]

        # Create feedback
        feedback_data = {
            "feedback_type": "thumbs_up",
            "rating": 5,
            "comment": "Great conversation!",
        }
        response = await client.post(
            f"/api/v1/conversations/{conversation_id}/feedback",
            json=feedback_data,
        )
        assert response.status_code == 201
        data = response.json()
        assert data["conversation_id"] == conversation_id
        assert data["feedback_type"] == "thumbs_up"
        assert data["rating"] == 5

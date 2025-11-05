"""Integration tests for knowledge base API."""
import pytest
import httpx
from typing import AsyncGenerator
import json
import tempfile
import os
from pathlib import Path


class TestKBAPIBasic:
    """Basic knowledge base API tests."""

    @pytest.fixture
    async def kb_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for KB API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8001",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_kb_health_check(self, kb_client):
        """Test KB API health endpoint."""
        response = await kb_client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data.get("status") == "ok"

    @pytest.mark.asyncio
    async def test_list_documents(self, kb_client):
        """Test listing documents."""
        response = await kb_client.get("/v1/documents")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list) or "documents" in data

    @pytest.mark.asyncio
    async def test_search_empty_query(self, kb_client):
        """Test search with empty knowledge base."""
        payload = {
            "query": "test query",
            "top_k": 5
        }
        response = await kb_client.post("/v1/search", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "results" in data or isinstance(data, list)

    @pytest.mark.asyncio
    async def test_search_with_filters(self, kb_client):
        """Test search with metadata filters."""
        payload = {
            "query": "customer support",
            "top_k": 5,
            "filters": {
                "category": "faq",
                "language": "en"
            }
        }
        response = await kb_client.post("/v1/search", json=payload)
        assert response.status_code == 200


class TestKBAPIDocumentOperations:
    """Document upload and management tests."""

    @pytest.fixture
    async def kb_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for KB API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8001",
            timeout=60.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_upload_text_document(self, kb_client):
        """Test uploading a text document."""
        with tempfile.NamedTemporaryFile(
            mode='w',
            suffix='.txt',
            delete=False
        ) as f:
            f.write("This is a test document about customer support.")
            temp_path = f.name

        try:
            with open(temp_path, 'rb') as f:
                files = {
                    'file': ('test.txt', f, 'text/plain'),
                }
                data = {
                    'metadata': json.dumps({
                        'category': 'faq',
                        'language': 'en'
                    })
                }
                response = await kb_client.post(
                    "/v1/documents",
                    files=files,
                    data=data
                )
            assert response.status_code in [200, 201]
            result = response.json()
            assert "id" in result or "document_id" in result
        finally:
            os.unlink(temp_path)

    @pytest.mark.asyncio
    async def test_upload_multiple_documents(self, kb_client):
        """Test uploading multiple documents."""
        results = []

        for i in range(3):
            with tempfile.NamedTemporaryFile(
                mode='w',
                suffix='.txt',
                delete=False
            ) as f:
                f.write(f"Document {i}: This is test content.")
                temp_path = f.name

            try:
                with open(temp_path, 'rb') as f:
                    files = {
                        'file': (f'test_{i}.txt', f, 'text/plain'),
                    }
                    response = await kb_client.post(
                        "/v1/documents",
                        files=files
                    )
                assert response.status_code in [200, 201]
                results.append(response.json())
            finally:
                os.unlink(temp_path)

        assert len(results) == 3

    @pytest.mark.asyncio
    async def test_get_document(self, kb_client):
        """Test retrieving document details."""
        # First upload a document
        with tempfile.NamedTemporaryFile(
            mode='w',
            suffix='.txt',
            delete=False
        ) as f:
            f.write("Test document content")
            temp_path = f.name

        try:
            with open(temp_path, 'rb') as f:
                files = {
                    'file': ('test.txt', f, 'text/plain'),
                }
                upload_response = await kb_client.post(
                    "/v1/documents",
                    files=files
                )
            assert upload_response.status_code in [200, 201]
            doc_id = upload_response.json().get("id") or upload_response.json().get("document_id")

            # Get document
            if doc_id:
                response = await kb_client.get(f"/v1/documents/{doc_id}")
                assert response.status_code == 200
                data = response.json()
                assert "id" in data or "document_id" in data
        finally:
            os.unlink(temp_path)

    @pytest.mark.asyncio
    async def test_delete_document(self, kb_client):
        """Test deleting a document."""
        # Upload document
        with tempfile.NamedTemporaryFile(
            mode='w',
            suffix='.txt',
            delete=False
        ) as f:
            f.write("Document to delete")
            temp_path = f.name

        try:
            with open(temp_path, 'rb') as f:
                files = {
                    'file': ('delete_test.txt', f, 'text/plain'),
                }
                upload_response = await kb_client.post(
                    "/v1/documents",
                    files=files
                )
            assert upload_response.status_code in [200, 201]
            doc_id = upload_response.json().get("id") or upload_response.json().get("document_id")

            # Delete document
            if doc_id:
                response = await kb_client.delete(f"/v1/documents/{doc_id}")
                assert response.status_code in [200, 204]
        finally:
            os.unlink(temp_path)

    @pytest.mark.asyncio
    async def test_document_versioning(self, kb_client):
        """Test document versioning."""
        with tempfile.NamedTemporaryFile(
            mode='w',
            suffix='.txt',
            delete=False
        ) as f:
            f.write("Version 1 content")
            temp_path = f.name

        try:
            with open(temp_path, 'rb') as f:
                files = {
                    'file': ('versioned.txt', f, 'text/plain'),
                }
                upload_response = await kb_client.post(
                    "/v1/documents",
                    files=files
                )
            assert upload_response.status_code in [200, 201]
            doc_id = upload_response.json().get("id") or upload_response.json().get("document_id")

            # Update with new version
            if doc_id:
                with tempfile.NamedTemporaryFile(
                    mode='w',
                    suffix='.txt',
                    delete=False
                ) as f2:
                    f2.write("Version 2 content")
                    temp_path2 = f2.name

                try:
                    with open(temp_path2, 'rb') as f2:
                        files = {
                            'file': ('versioned.txt', f2, 'text/plain'),
                        }
                        update_response = await kb_client.put(
                            f"/v1/documents/{doc_id}",
                            files=files
                        )
                    assert update_response.status_code in [200, 204]
                finally:
                    os.unlink(temp_path2)
        finally:
            os.unlink(temp_path)


class TestKBAPISearch:
    """Advanced search functionality tests."""

    @pytest.fixture
    async def kb_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for KB API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8001",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_semantic_search(self, kb_client):
        """Test semantic search capability."""
        payload = {
            "query": "How to reset password",
            "top_k": 5,
            "search_type": "semantic"
        }
        response = await kb_client.post("/v1/search", json=payload)
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_hybrid_search(self, kb_client):
        """Test hybrid search (semantic + keyword)."""
        payload = {
            "query": "login issues",
            "top_k": 5,
            "search_type": "hybrid",
            "weights": {
                "semantic": 0.7,
                "keyword": 0.3
            }
        }
        response = await kb_client.post("/v1/search", json=payload)
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_search_with_metadata_filtering(self, kb_client):
        """Test search with metadata filtering."""
        payload = {
            "query": "billing",
            "top_k": 5,
            "filters": {
                "category": ["billing", "payments"],
                "language": "en"
            }
        }
        response = await kb_client.post("/v1/search", json=payload)
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_search_result_ranking(self, kb_client):
        """Test search result ranking and ordering."""
        payload = {
            "query": "account",
            "top_k": 10,
            "ranking": "relevance"
        }
        response = await kb_client.post("/v1/search", json=payload)
        assert response.status_code == 200
        data = response.json()

        # Verify results are properly ranked
        if "results" in data and data["results"]:
            for i, result in enumerate(data["results"]):
                if i > 0:
                    prev_score = data["results"][i-1].get("score", 0)
                    curr_score = result.get("score", 0)
                    # Score should be non-increasing
                    assert curr_score <= prev_score or prev_score == 0


class TestKBAPIErrors:
    """Error handling tests for KB API."""

    @pytest.fixture
    async def kb_client(self) -> AsyncGenerator[httpx.AsyncClient, None]:
        """Create async HTTP client for KB API."""
        async with httpx.AsyncClient(
            base_url="http://localhost:8001",
            timeout=30.0
        ) as client:
            yield client

    @pytest.mark.asyncio
    async def test_invalid_search_query(self, kb_client):
        """Test search with invalid query."""
        payload = {
            "query": "",
            "top_k": 5
        }
        response = await kb_client.post("/v1/search", json=payload)
        assert response.status_code in [400, 422]

    @pytest.mark.asyncio
    async def test_invalid_top_k(self, kb_client):
        """Test search with invalid top_k."""
        payload = {
            "query": "test",
            "top_k": -1
        }
        response = await kb_client.post("/v1/search", json=payload)
        assert response.status_code in [400, 422]

    @pytest.mark.asyncio
    async def test_nonexistent_document(self, kb_client):
        """Test retrieving nonexistent document."""
        response = await kb_client.get("/v1/documents/nonexistent_id")
        assert response.status_code in [404, 400]

    @pytest.mark.asyncio
    async def test_unsupported_file_type(self, kb_client):
        """Test uploading unsupported file type."""
        with tempfile.NamedTemporaryFile(
            mode='wb',
            suffix='.xyz',
            delete=False
        ) as f:
            f.write(b"Unsupported content")
            temp_path = f.name

        try:
            with open(temp_path, 'rb') as f:
                files = {
                    'file': ('test.xyz', f, 'application/octet-stream'),
                }
                response = await kb_client.post(
                    "/v1/documents",
                    files=files
                )
            # Should either reject or handle gracefully
            assert response.status_code in [200, 201, 400, 415, 422]
        finally:
            os.unlink(temp_path)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])

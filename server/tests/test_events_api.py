"""Tests for event ingestion API."""

import json
from datetime import datetime

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient) -> None:
    response = await client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_create_text_event(client: AsyncClient) -> None:
    metadata = {
        "id": "test-001",
        "type": "text",
        "timestamp": datetime.now().isoformat(),
        "text_content": "Hello, this is a test note.",
    }
    response = await client.post(
        "/api/events",
        data={"metadata": json.dumps(metadata)},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "test-001"
    assert data["type"] == "text"
    assert data["text_content"] == "Hello, this is a test note."
    assert data["upload_status"] == "received"
    assert data["processing_status"] == "pending"


@pytest.mark.asyncio
async def test_create_audio_event_with_file(client: AsyncClient, tmp_path) -> None:
    # Create a dummy audio file
    audio_file = tmp_path / "test.wav"
    audio_file.write_bytes(b"fake audio data for testing")

    metadata = {
        "id": "test-002",
        "type": "audio",
        "timestamp": datetime.now().isoformat(),
        "checksum": "abc123",
    }

    with open(audio_file, "rb") as f:
        response = await client.post(
            "/api/events",
            data={"metadata": json.dumps(metadata)},
            files={"file": ("test.wav", f, "audio/wav")},
        )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "test-002"
    assert data["type"] == "audio"
    assert data["server_checksum"] is not None


@pytest.mark.asyncio
async def test_list_events(client: AsyncClient) -> None:
    # Create two events
    for i in range(2):
        metadata = {
            "id": f"list-{i}",
            "type": "text",
            "timestamp": datetime.now().isoformat(),
            "text_content": f"Note {i}",
        }
        await client.post("/api/events", data={"metadata": json.dumps(metadata)})

    response = await client.get("/api/events")
    assert response.status_code == 200
    events = response.json()
    assert len(events) == 2


@pytest.mark.asyncio
async def test_get_event_by_id(client: AsyncClient) -> None:
    metadata = {
        "id": "get-001",
        "type": "text",
        "timestamp": datetime.now().isoformat(),
        "text_content": "Findable note",
    }
    await client.post("/api/events", data={"metadata": json.dumps(metadata)})

    response = await client.get("/api/events/get-001")
    assert response.status_code == 200
    assert response.json()["text_content"] == "Findable note"


@pytest.mark.asyncio
async def test_get_nonexistent_event(client: AsyncClient) -> None:
    response = await client.get("/api/events/nonexistent")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_reprocess_event(client: AsyncClient) -> None:
    metadata = {
        "id": "reprocess-001",
        "type": "audio",
        "timestamp": datetime.now().isoformat(),
    }
    await client.post("/api/events", data={"metadata": json.dumps(metadata)})

    response = await client.post("/api/events/reprocess-001/reprocess")
    assert response.status_code == 200
    assert response.json()["processing_status"] == "pending"


@pytest.mark.asyncio
async def test_reprocess_nonexistent_event(client: AsyncClient) -> None:
    response = await client.post("/api/events/nonexistent/reprocess")
    assert response.status_code == 404

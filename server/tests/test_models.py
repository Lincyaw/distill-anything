"""Tests for model serialization."""

from datetime import datetime

from distill_anything.models.event import (
    EventCreate,
    EventResponse,
    EventType,
    ProcessingStatus,
    UploadStatus,
)


def test_event_create_from_dict() -> None:
    data = {
        "id": "test-001",
        "type": "audio",
        "timestamp": "2026-04-12T14:30:00",
    }
    event = EventCreate(**data)
    assert event.type == EventType.audio
    assert event.timestamp == datetime(2026, 4, 12, 14, 30, 0)


def test_event_response_serialization() -> None:
    resp = EventResponse(
        id="test-001",
        type=EventType.text,
        timestamp=datetime(2026, 4, 12, 14, 30, 0),
        text_content="Hello",
        upload_status=UploadStatus.received,
        processing_status=ProcessingStatus.pending,
    )
    data = resp.model_dump()
    assert data["id"] == "test-001"
    assert data["type"] == "text"

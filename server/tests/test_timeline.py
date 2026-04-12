"""Tests for timeline service."""

from datetime import datetime
from pathlib import Path

import pytest

from distill_anything.models.event import Event, EventType
from distill_anything.services.timeline import TimelineService


@pytest.mark.asyncio
async def test_append_event(tmp_path: Path) -> None:
    service = TimelineService(kb_root=tmp_path)

    event = Event(
        id="t1",
        type=EventType.text,
        timestamp=datetime(2026, 4, 12, 14, 30, 0),
        text_content="Hello world",
    )

    path = await service.append_event(event)
    assert path.exists()
    content = path.read_text()
    assert "2026-04-12" in content
    assert "Hello world" in content
    assert "14:30:00" in content
    # Check YAML frontmatter
    assert "---" in content
    assert "date: 2026-04-12" in content
    assert "tags: [daily-log]" in content


@pytest.mark.asyncio
async def test_append_multiple_events(tmp_path: Path) -> None:
    service = TimelineService(kb_root=tmp_path)

    for i in range(3):
        event = Event(
            id=f"t{i}",
            type=EventType.text,
            timestamp=datetime(2026, 4, 12, 14, i, 0),
            text_content=f"Note {i}",
        )
        await service.append_event(event)

    path = tmp_path / "timeline" / "2026-04-12.md"
    content = path.read_text()
    assert "Note 0" in content
    assert "Note 1" in content
    assert "Note 2" in content


@pytest.mark.asyncio
async def test_append_event_with_topic_links(tmp_path: Path) -> None:
    service = TimelineService(kb_root=tmp_path)

    event = Event(
        id="t1",
        type=EventType.text,
        timestamp=datetime(2026, 4, 12, 14, 30, 0),
        text_content="Discussion about Python",
    )

    await service.append_event(event, topic_links=["Python", "Programming"])
    content = (tmp_path / "timeline" / "2026-04-12.md").read_text()
    assert "[[Python]]" in content
    assert "[[Programming]]" in content
    assert "**Topics:**" in content


@pytest.mark.asyncio
async def test_append_event_with_transcription(tmp_path: Path) -> None:
    service = TimelineService(kb_root=tmp_path)

    event = Event(
        id="a1",
        type=EventType.audio,
        timestamp=datetime(2026, 4, 12, 10, 0, 0),
        transcription="This is a transcription",
    )

    await service.append_event(event)
    content = (tmp_path / "timeline" / "2026-04-12.md").read_text()
    assert "**Transcription:** This is a transcription" in content


@pytest.mark.asyncio
async def test_get_recent_events(tmp_path: Path) -> None:
    service = TimelineService(kb_root=tmp_path)

    # Create events on two days
    for day_offset in range(2):
        event = Event(
            id=f"e{day_offset}",
            type=EventType.text,
            timestamp=datetime(2026, 4, 12 - day_offset, 14, 0, 0),
            text_content=f"Event on day {day_offset}",
        )
        await service.append_event(event)

    # Mock datetime.now to return 2026-04-12
    import unittest.mock

    with unittest.mock.patch(
        "distill_anything.services.timeline.datetime"
    ) as mock_dt:
        mock_dt.now.return_value = datetime(2026, 4, 12, 23, 59, 59)
        mock_dt.side_effect = lambda *args, **kw: datetime(*args, **kw)
        events = await service.get_recent_events(days=3)

    assert len(events) >= 2
    texts = [e["text"] for e in events]
    assert any("Event on day 0" in t for t in texts)
    assert any("Event on day 1" in t for t in texts)


@pytest.mark.asyncio
async def test_frontmatter_only_once(tmp_path: Path) -> None:
    """Frontmatter should only appear at the top, not duplicated per event."""
    service = TimelineService(kb_root=tmp_path)

    for i in range(3):
        event = Event(
            id=f"t{i}",
            type=EventType.text,
            timestamp=datetime(2026, 4, 12, 14, i, 0),
            text_content=f"Note {i}",
        )
        await service.append_event(event)

    content = (tmp_path / "timeline" / "2026-04-12.md").read_text()
    # Frontmatter date: field appears only once (in frontmatter, not per event)
    assert content.count("date: 2026-04-12") == 1
    # Daily Log header appears only once
    assert content.count("# 2026-04-12 Daily Log") == 1

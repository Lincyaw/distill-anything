"""Knowledge base API endpoints."""

from fastapi import APIRouter, Query

from ..config import settings
from ..knowledge_base.topic_manager import TopicManager
from ..services.timeline import TimelineService
from ..services.topic_aggregation import TopicAggregationService

router = APIRouter()
timeline = TimelineService()
topic_manager = TopicManager(settings.knowledge_base_root / "topics")
topic_aggregation = TopicAggregationService()


@router.get("/knowledge-base/timeline")
async def list_timeline_files() -> list[str]:
    """List available daily timeline files."""
    timeline_dir = settings.knowledge_base_root / "timeline"
    if not timeline_dir.exists():
        return []
    return sorted([f.stem for f in timeline_dir.glob("*.md")], reverse=True)


@router.get("/knowledge-base/timeline/{date}")
async def get_timeline(date: str) -> dict:
    """Get timeline content for a specific date."""
    file_path = settings.knowledge_base_root / "timeline" / f"{date}.md"
    if not file_path.exists():
        return {"date": date, "content": ""}
    return {"date": date, "content": file_path.read_text(encoding="utf-8")}


@router.get("/knowledge-base/topics")
async def list_topics() -> list[str]:
    """List all topic names."""
    return topic_manager.list_topics()


@router.get("/knowledge-base/topics/search")
async def search_topics(q: str = Query(..., min_length=1)) -> list[str]:
    """Search topics by keyword."""
    return topic_manager.search_topics(q)


@router.get("/knowledge-base/topics/{topic_name}")
async def get_topic(topic_name: str) -> dict:
    """Get topic content."""
    content = topic_manager.get_topic_content(topic_name)
    if content is None:
        return {"topic": topic_name, "content": ""}
    return {"topic": topic_name, "content": content}


@router.post("/knowledge-base/generate")
async def trigger_generation(days: int = Query(1, ge=1, le=30)) -> dict:
    """Trigger knowledge base generation for recent events.

    Collects recent events from timeline files and runs topic aggregation.
    """
    events = await timeline.get_recent_events(days=days)
    updated_topics = await topic_aggregation.process_events(events)
    return {
        "status": "completed",
        "events_processed": len(events),
        "topics_updated": updated_topics,
    }

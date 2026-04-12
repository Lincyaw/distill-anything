"""Topic creation, update, and wiki-link management."""

import re
from pathlib import Path

from .writer import MarkdownWriter


class TopicManager:
    """Manage topic notes in the knowledge base."""

    def __init__(self, topics_dir: Path) -> None:
        self.topics_dir = topics_dir
        self.writer = MarkdownWriter()

    def get_or_create_topic(self, topic_name: str) -> Path:
        """Get existing topic file or create a new one."""
        safe_name = topic_name.replace("/", "-").replace("\\", "-")
        topic_path = self.topics_dir / f"{safe_name}.md"
        if not topic_path.exists():
            self.writer.write_note(topic_path, topic_name, "", tags=[topic_name])
        return topic_path

    def add_event_to_topic(self, topic_name: str, event_summary: str, event_date: str) -> Path:
        """Add an event reference to a topic note."""
        topic_path = self.get_or_create_topic(topic_name)
        timeline_link = MarkdownWriter.create_wiki_link(event_date)
        content = f"- {timeline_link}: {event_summary}"
        MarkdownWriter.append_to_note(topic_path, content)
        return topic_path

    def list_topics(self) -> list[str]:
        """List all topic names."""
        if not self.topics_dir.exists():
            return []
        return sorted(p.stem for p in self.topics_dir.glob("*.md"))

    def search_topics(self, query: str) -> list[str]:
        """Search topics by keyword (case-insensitive)."""
        if not self.topics_dir.exists():
            return []

        query_lower = query.lower()
        results: list[str] = []
        for path in self.topics_dir.glob("*.md"):
            # Check filename
            if query_lower in path.stem.lower():
                results.append(path.stem)
                continue
            # Check file content
            content = path.read_text(encoding="utf-8").lower()
            if query_lower in content:
                results.append(path.stem)

        return sorted(results)

    def get_topic_content(self, topic_name: str) -> str | None:
        """Read topic file content. Returns None if topic doesn't exist."""
        safe_name = topic_name.replace("/", "-").replace("\\", "-")
        topic_path = self.topics_dir / f"{safe_name}.md"
        if not topic_path.exists():
            return None
        return topic_path.read_text(encoding="utf-8")

    def get_related_topics(self, topic_name: str) -> list[str]:
        """Find topics that contain a wiki-link to the given topic."""
        if not self.topics_dir.exists():
            return []

        pattern = re.compile(rf"\[\[{re.escape(topic_name)}\]\]")
        related: list[str] = []
        for path in self.topics_dir.glob("*.md"):
            if path.stem == topic_name:
                continue
            content = path.read_text(encoding="utf-8")
            if pattern.search(content):
                related.append(path.stem)

        return sorted(related)

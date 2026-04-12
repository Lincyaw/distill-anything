"""Event timeline log generation — Obsidian-compatible markdown."""

import logging
from datetime import datetime, timedelta
from pathlib import Path

from ..config import settings
from ..knowledge_base.writer import MarkdownWriter
from ..models.event import Event

logger = logging.getLogger(__name__)

_EMOJI_MAP = {
    "audio": "\U0001f399\ufe0f",
    "photo": "\U0001f4f7",
    "video": "\U0001f3a5",
    "text": "\U0001f4dd",
}


class TimelineService:
    """Generate daily timeline log files in Obsidian markdown format."""

    def __init__(self, kb_root: Path | None = None) -> None:
        self.kb_root = kb_root or settings.knowledge_base_root
        self.timeline_dir = self.kb_root / "timeline"

    def _daily_file(self, date: datetime) -> Path:
        return self.timeline_dir / f"{date.strftime('%Y-%m-%d')}.md"

    async def append_event(self, event: Event, topic_links: list[str] | None = None) -> Path:
        """Append an event entry to the daily timeline log."""
        self.timeline_dir.mkdir(parents=True, exist_ok=True)
        file_path = self._daily_file(event.timestamp)

        if not file_path.exists():
            date_str = event.timestamp.strftime("%Y-%m-%d")
            frontmatter = (
                "---\n"
                f"date: {date_str}\n"
                "tags: [daily-log]\n"
                "---\n\n"
                f"# {date_str} Daily Log\n\n"
            )
            file_path.write_text(frontmatter, encoding="utf-8")

        entry = self._format_entry(event, topic_links)
        with open(file_path, "a", encoding="utf-8") as f:
            f.write(entry)

        return file_path

    def _format_entry(self, event: Event, topic_links: list[str] | None = None) -> str:
        time_str = event.timestamp.strftime("%H:%M:%S")
        type_emoji = _EMOJI_MAP.get(event.type.value, "\U0001f4cc")

        lines = [f"## {time_str} {type_emoji} {event.type.value}\n\n"]

        if event.text_content:
            lines.append(f"{event.text_content}\n\n")
        if event.transcription:
            lines.append(f"**Transcription:** {event.transcription}\n\n")
        if event.description:
            lines.append(f"**Description:** {event.description}\n\n")
        if event.annotation:
            lines.append(f"*Note: {event.annotation}*\n\n")

        if topic_links:
            wiki_links = [MarkdownWriter.create_wiki_link(t) for t in topic_links]
            lines.append(f"**Topics:** {', '.join(wiki_links)}\n\n")

        lines.append("---\n\n")
        return "".join(lines)

    async def generate_daily_summary(self, date: datetime) -> str:
        """Summarize the day's events using LLM.

        Returns the generated summary text, or an empty string on failure.
        """
        file_path = self._daily_file(date)
        if not file_path.exists():
            return ""

        content = file_path.read_text(encoding="utf-8")
        if not content.strip():
            return ""

        try:
            from openai import AsyncOpenAI
        except ImportError:
            logger.warning("openai package not installed, skipping daily summary")
            return ""

        client = AsyncOpenAI(base_url=settings.llm_base_url, api_key="not-needed")
        date_str = date.strftime("%Y-%m-%d")

        prompt = (
            f"请总结以下 {date_str} 的事件记录，提取关键信息，生成简洁的每日摘要。\n\n"
            f"{content}"
        )

        try:
            response = await client.chat.completions.create(
                model=settings.llm_model,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=1000,
            )
            summary = response.choices[0].message.content or ""

            # Append summary to the daily file
            summary_section = f"\n## Daily Summary\n\n{summary}\n"
            MarkdownWriter.append_to_note(file_path, summary_section)

            return summary

        except Exception:
            logger.exception("Failed to generate daily summary for %s", date_str)
            return ""

    async def get_recent_events(self, days: int = 7) -> list[dict]:
        """Collect event text from recent timeline files for topic aggregation.

        Returns a list of dicts with keys: id, type, timestamp, text.
        Each dict represents one event section parsed from timeline files.
        """
        events: list[dict] = []
        today = datetime.now()

        for offset in range(days):
            day = today - timedelta(days=offset)
            file_path = self._daily_file(day)
            if not file_path.exists():
                continue

            content = file_path.read_text(encoding="utf-8")
            date_str = day.strftime("%Y-%m-%d")

            # Parse sections from the markdown file
            sections = content.split("\n## ")
            for section in sections[1:]:  # skip header/frontmatter
                lines = section.strip().split("\n")
                if not lines:
                    continue

                header = lines[0]
                # Header format: "HH:MM:SS <emoji> <type>"
                parts = header.split(" ", 2)
                if len(parts) < 3:
                    continue

                time_str = parts[0]
                event_type = parts[-1].strip()
                body = "\n".join(lines[1:]).strip().rstrip("---").strip()

                if body:
                    events.append({
                        "id": f"{date_str}_{time_str}",
                        "type": event_type,
                        "timestamp": f"{date_str}T{time_str}",
                        "text": body,
                    })

        return events

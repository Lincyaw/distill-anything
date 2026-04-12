"""Topic-based note aggregation using LLM."""

import json
import logging
from datetime import datetime
from pathlib import Path

from ..config import settings
from ..knowledge_base.topic_manager import TopicManager
from ..knowledge_base.writer import MarkdownWriter

logger = logging.getLogger(__name__)


class TopicAggregationService:
    """Aggregate events into topic-based Obsidian notes using LLM."""

    def __init__(self, kb_root: Path | None = None) -> None:
        self.kb_root = kb_root or settings.knowledge_base_root
        self.topics_dir = self.kb_root / "topics"
        self.topic_manager = TopicManager(self.topics_dir)
        self.writer = MarkdownWriter()

    async def process_events(self, events_text: list[dict]) -> list[str]:
        """Analyze events and identify topics.

        Each event dict has: id, type, timestamp, text (transcription/description/text_content).

        Returns list of topic names that were created/updated.
        """
        if not events_text:
            return []

        try:
            from openai import AsyncOpenAI
        except ImportError:
            logger.warning("openai package not installed, skipping topic aggregation")
            return []

        client = AsyncOpenAI(base_url=settings.llm_base_url, api_key="not-needed")

        # Build context from events
        events_context = "\n".join(
            f"[{e['timestamp']}] ({e['type']}) {e['text'][:500]}"
            for e in events_text
            if e.get("text")
        )

        if not events_context:
            return []

        prompt = (
            "分析以下事件记录，识别出主要话题/主题。对每个话题：\n"
            "1. 给出话题名称（简短、可作为文件名）\n"
            "2. 总结相关内容\n"
            "3. 列出关键信息点\n\n"
            "事件记录：\n"
            f"{events_context}\n\n"
            "以JSON格式返回：\n"
            '[{"topic": "话题名称", "summary": "内容摘要", "key_points": ["要点1", "要点2"]}]'
        )

        try:
            response = await client.chat.completions.create(
                model=settings.llm_model,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=2000,
            )

            content = response.choices[0].message.content or "[]"
            # Handle case where LLM wraps JSON in markdown code block
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]

            topics_data = json.loads(content.strip())

            updated_topics: list[str] = []
            for topic_info in topics_data:
                topic_name = topic_info.get("topic", "").strip()
                if not topic_name:
                    continue

                summary = topic_info.get("summary", "")
                key_points = topic_info.get("key_points", [])

                # Create/update topic note
                topic_path = self.topic_manager.get_or_create_topic(topic_name)

                # Build content to append
                date_str = datetime.now().strftime("%Y-%m-%d")
                content_lines = [f"\n## Update {date_str}\n"]
                if summary:
                    content_lines.append(f"{summary}\n")
                if key_points:
                    content_lines.append("\n**Key Points:**")
                    for point in key_points:
                        content_lines.append(f"- {point}")
                content_lines.append("")

                # Add related timeline links
                for e in events_text:
                    if e.get("text") and any(
                        kw in e["text"] for kw in topic_name.split() if len(kw) > 1
                    ):
                        ts = e["timestamp"][:10]  # YYYY-MM-DD
                        timeline_link = MarkdownWriter.create_wiki_link(ts)
                        content_lines.append(f"- Source: {timeline_link}")

                MarkdownWriter.append_to_note(topic_path, "\n".join(content_lines))
                updated_topics.append(topic_name)

            return updated_topics

        except Exception:
            logger.exception("Topic aggregation failed")
            return []

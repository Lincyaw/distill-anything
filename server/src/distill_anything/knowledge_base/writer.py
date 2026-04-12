"""Obsidian markdown file writer."""

from pathlib import Path

import yaml


class MarkdownWriter:
    """Write Obsidian-compatible markdown files."""

    @staticmethod
    def write_note(path: Path, title: str, content: str, tags: list[str] | None = None) -> None:
        """Write a markdown note with YAML frontmatter."""
        path.parent.mkdir(parents=True, exist_ok=True)

        frontmatter: dict[str, object] = {"title": title}
        if tags:
            frontmatter["tags"] = tags

        fm_str = yaml.dump(frontmatter, allow_unicode=True, default_flow_style=True).strip()
        full_content = f"---\n{fm_str}\n---\n\n# {title}\n\n{content}\n"
        path.write_text(full_content, encoding="utf-8")

    @staticmethod
    def append_to_note(path: Path, content: str) -> None:
        """Append content to an existing note."""
        with open(path, "a", encoding="utf-8") as f:
            f.write(f"\n{content}\n")

    @staticmethod
    def create_wiki_link(topic: str) -> str:
        """Create an Obsidian wiki-link."""
        return f"[[{topic}]]"

    @staticmethod
    def update_frontmatter(path: Path, updates: dict[str, object]) -> None:
        """Update YAML frontmatter fields in an existing note.

        Reads the file, parses frontmatter, merges updates, writes back.
        """
        text = path.read_text(encoding="utf-8")

        if not text.startswith("---\n"):
            # No frontmatter — prepend one
            fm_str = yaml.dump(updates, allow_unicode=True, default_flow_style=True).strip()
            path.write_text(f"---\n{fm_str}\n---\n\n{text}", encoding="utf-8")
            return

        parts = text.split("---\n", 2)
        if len(parts) < 3:
            return

        existing = yaml.safe_load(parts[1]) or {}
        existing.update(updates)
        fm_str = yaml.dump(existing, allow_unicode=True, default_flow_style=True).strip()
        path.write_text(f"---\n{fm_str}\n---\n{parts[2]}", encoding="utf-8")

    @staticmethod
    def add_wiki_links(path: Path, links: list[str]) -> None:
        """Append a wiki-links section to a note."""
        if not links:
            return

        wiki_links = [MarkdownWriter.create_wiki_link(link) for link in links]
        section = "\n## Related\n\n" + "\n".join(f"- {wl}" for wl in wiki_links) + "\n"
        MarkdownWriter.append_to_note(path, section)

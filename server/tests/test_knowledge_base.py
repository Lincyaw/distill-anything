"""Tests for knowledge base generation."""

from pathlib import Path

from distill_anything.knowledge_base.topic_manager import TopicManager
from distill_anything.knowledge_base.writer import MarkdownWriter


def test_write_note(tmp_path: Path) -> None:
    path = tmp_path / "test.md"
    MarkdownWriter.write_note(path, "Test Topic", "Some content", tags=["test"])
    content = path.read_text()
    assert "title: Test Topic" in content
    assert "# Test Topic" in content
    assert "Some content" in content
    assert "test" in content


def test_append_to_note(tmp_path: Path) -> None:
    path = tmp_path / "test.md"
    MarkdownWriter.write_note(path, "Test", "Initial")
    MarkdownWriter.append_to_note(path, "Appended content")
    content = path.read_text()
    assert "Initial" in content
    assert "Appended content" in content


def test_wiki_link() -> None:
    link = MarkdownWriter.create_wiki_link("2026-04-12")
    assert link == "[[2026-04-12]]"


def test_update_frontmatter(tmp_path: Path) -> None:
    path = tmp_path / "test.md"
    MarkdownWriter.write_note(path, "Test", "Content", tags=["original"])
    MarkdownWriter.update_frontmatter(path, {"status": "updated"})
    content = path.read_text()
    assert "status" in content
    assert "updated" in content
    assert "title: Test" in content


def test_update_frontmatter_no_existing(tmp_path: Path) -> None:
    path = tmp_path / "test.md"
    path.write_text("Just plain text", encoding="utf-8")
    MarkdownWriter.update_frontmatter(path, {"title": "New"})
    content = path.read_text()
    assert "---" in content
    assert "title: New" in content
    assert "Just plain text" in content


def test_add_wiki_links(tmp_path: Path) -> None:
    path = tmp_path / "test.md"
    MarkdownWriter.write_note(path, "Test", "Content")
    MarkdownWriter.add_wiki_links(path, ["TopicA", "TopicB"])
    content = path.read_text()
    assert "[[TopicA]]" in content
    assert "[[TopicB]]" in content
    assert "## Related" in content


def test_add_wiki_links_empty(tmp_path: Path) -> None:
    path = tmp_path / "test.md"
    MarkdownWriter.write_note(path, "Test", "Content")
    original = path.read_text()
    MarkdownWriter.add_wiki_links(path, [])
    assert path.read_text() == original


def test_topic_manager_create(tmp_path: Path) -> None:
    manager = TopicManager(tmp_path)
    path = manager.get_or_create_topic("test-topic")
    assert path.exists()
    assert "test-topic" in path.read_text()


def test_topic_manager_list(tmp_path: Path) -> None:
    manager = TopicManager(tmp_path)
    manager.get_or_create_topic("topic-a")
    manager.get_or_create_topic("topic-b")
    topics = manager.list_topics()
    assert "topic-a" in topics
    assert "topic-b" in topics


def test_topic_manager_add_event(tmp_path: Path) -> None:
    manager = TopicManager(tmp_path)
    manager.add_event_to_topic("my-topic", "Something happened", "2026-04-12")
    content = manager.get_or_create_topic("my-topic").read_text()
    assert "[[2026-04-12]]" in content
    assert "Something happened" in content


def test_topic_manager_search(tmp_path: Path) -> None:
    manager = TopicManager(tmp_path)
    manager.get_or_create_topic("python-tips")
    manager.get_or_create_topic("rust-notes")
    manager.add_event_to_topic("rust-notes", "Ownership model", "2026-04-12")

    results = manager.search_topics("python")
    assert "python-tips" in results
    assert "rust-notes" not in results

    results = manager.search_topics("rust")
    assert "rust-notes" in results


def test_topic_manager_get_content(tmp_path: Path) -> None:
    manager = TopicManager(tmp_path)
    manager.get_or_create_topic("my-topic")
    content = manager.get_topic_content("my-topic")
    assert content is not None
    assert "my-topic" in content

    assert manager.get_topic_content("nonexistent") is None


def test_topic_manager_related(tmp_path: Path) -> None:
    manager = TopicManager(tmp_path)
    manager.get_or_create_topic("topic-a")
    manager.get_or_create_topic("topic-b")
    # Add a wiki-link from topic-b to topic-a
    topic_b_path = manager.get_or_create_topic("topic-b")
    MarkdownWriter.append_to_note(topic_b_path, "See also [[topic-a]]")

    related = manager.get_related_topics("topic-a")
    assert "topic-b" in related
    assert "topic-a" not in related

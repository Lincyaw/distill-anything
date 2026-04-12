"""Tests for processing models and services."""

from distill_anything.models.processing import ImageDescriptionResult, TranscriptionResult
from distill_anything.services.image_description import ImageDescriptionService


def test_transcription_result_model() -> None:
    result = TranscriptionResult(event_id="e1", text="你好世界", language="zh")
    assert result.text == "你好世界"
    assert result.chunks == []


def test_image_description_result_model() -> None:
    result = ImageDescriptionResult(event_id="e1", description="一张照片", tags=["照片"])
    assert result.description == "一张照片"
    assert len(result.tags) == 1


def test_extract_tags() -> None:
    tags = ImageDescriptionService._extract_tags("一个美丽的公园，有很多树木和花朵。")
    assert isinstance(tags, list)
    assert len(tags) <= 10

"""Processing result models."""

from pydantic import BaseModel


class TranscriptionResult(BaseModel):
    """Result of audio/video transcription."""

    event_id: str
    text: str
    language: str = "zh"
    duration_seconds: float | None = None
    chunks: list[dict[str, str | float]] = []


class ImageDescriptionResult(BaseModel):
    """Result of image description."""

    event_id: str
    description: str
    tags: list[str] = []

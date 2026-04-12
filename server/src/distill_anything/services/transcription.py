"""Audio-to-text transcription via FunASR/Paraformer."""

import logging
from pathlib import Path

from ..config import settings
from ..models.processing import TranscriptionResult

logger = logging.getLogger(__name__)


class TranscriptionService:
    """Transcribe audio files to text using FunASR Paraformer."""

    def __init__(self, model_name: str | None = None) -> None:
        self.model_name = model_name or settings.funasr_model
        self._model = None

    def _load_model(self):  # noqa: ANN202
        """Lazy-load the FunASR model."""
        if self._model is None:
            try:
                from funasr import AutoModel

                self._model = AutoModel(model=self.model_name)
                logger.info("Loaded FunASR model: %s", self.model_name)
            except ImportError:
                logger.warning("FunASR not installed. Install with: uv sync --extra conversion")
                raise
        return self._model

    async def transcribe(self, audio_path: Path, event_id: str) -> TranscriptionResult:
        """Transcribe an audio file. Handles long recordings by chunking."""
        import asyncio

        model = self._load_model()

        # Run transcription in thread pool (FunASR is synchronous)
        result = await asyncio.to_thread(self._transcribe_sync, model, audio_path)

        text_parts = []
        chunks: list[dict[str, str | float]] = []
        for item in result:
            text = item.get("text", "")
            text_parts.append(text)
            chunks.append({
                "text": text,
                "start": (
                    item.get("timestamp", [[0, 0]])[0][0] / 1000
                    if item.get("timestamp")
                    else 0
                ),
                "end": (
                    item.get("timestamp", [[0, 0]])[-1][-1] / 1000
                    if item.get("timestamp")
                    else 0
                ),
            })

        full_text = "".join(text_parts)
        return TranscriptionResult(
            event_id=event_id,
            text=full_text,
            language="zh",
            chunks=chunks,
        )

    @staticmethod
    def _transcribe_sync(model, audio_path: Path) -> list[dict]:  # noqa: ANN001
        """Synchronous transcription."""
        result = model.generate(input=str(audio_path))
        if isinstance(result, list):
            return result
        return [result] if result else []

"""Video audio extraction and transcription."""

import asyncio
import logging
import subprocess
import tempfile
from pathlib import Path

from ..models.processing import TranscriptionResult
from .transcription import TranscriptionService

logger = logging.getLogger(__name__)


class VideoExtractionService:
    """Extract audio from video and transcribe."""

    def __init__(self) -> None:
        self.transcription_service = TranscriptionService()

    async def extract_audio(self, video_path: Path) -> Path:
        """Extract audio track from video using ffmpeg."""
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp.close()
        output = Path(tmp.name)
        cmd = [
            "ffmpeg",
            "-i",
            str(video_path),
            "-vn",
            "-acodec",
            "pcm_s16le",
            "-ar",
            "16000",
            "-ac",
            "1",
            str(output),
            "-y",
        ]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        _, stderr = await proc.communicate()
        if proc.returncode != 0:
            raise RuntimeError(f"ffmpeg failed: {stderr.decode()}")
        return output

    async def extract_and_transcribe(
        self, video_path: Path, event_id: str
    ) -> TranscriptionResult:
        """Extract audio track from video, then transcribe."""
        audio_path = await self.extract_audio(video_path)
        try:
            return await self.transcription_service.transcribe(audio_path, event_id)
        finally:
            audio_path.unlink(missing_ok=True)

    async def extract_key_frames(
        self, video_path: Path, event_id: str, interval_seconds: float = 10.0
    ) -> list[Path]:
        """Extract key frames from video at given interval."""
        output_dir = Path(tempfile.mkdtemp())
        output_pattern = str(output_dir / f"{event_id}_frame_%04d.jpg")
        cmd = [
            "ffmpeg",
            "-i",
            str(video_path),
            "-vf",
            f"fps=1/{interval_seconds}",
            output_pattern,
            "-y",
        ]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        await proc.communicate()
        return sorted(output_dir.glob("*.jpg"))

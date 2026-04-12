"""Background processing worker for event conversion."""

import asyncio
import logging
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.event import Event, EventType, ProcessingStatus
from ..services.database import async_session
from .image_description import ImageDescriptionService
from .timeline import TimelineService
from .transcription import TranscriptionService
from .video_extraction import VideoExtractionService

logger = logging.getLogger(__name__)


class ProcessingWorker:
    """Background worker that processes pending events."""

    def __init__(self) -> None:
        self._transcription: TranscriptionService | None = None
        self._video: VideoExtractionService | None = None
        self._image: ImageDescriptionService | None = None
        self._timeline: TimelineService | None = None
        self._running = False

    @property
    def transcription(self) -> TranscriptionService:
        if self._transcription is None:
            self._transcription = TranscriptionService()
        return self._transcription

    @property
    def video(self) -> VideoExtractionService:
        if self._video is None:
            self._video = VideoExtractionService()
        return self._video

    @property
    def timeline(self) -> TimelineService:
        if self._timeline is None:
            self._timeline = TimelineService()
        return self._timeline

    @property
    def image(self) -> ImageDescriptionService:
        if self._image is None:
            self._image = ImageDescriptionService()
        return self._image

    async def start(self, poll_interval: float = 5.0) -> None:
        """Start processing loop."""
        self._running = True
        logger.info("Processing worker started")
        while self._running:
            try:
                await self._process_pending()
            except Exception:
                logger.exception("Error in processing loop")
            await asyncio.sleep(poll_interval)

    def stop(self) -> None:
        self._running = False

    async def _process_pending(self) -> None:
        """Find and process pending events."""
        async with async_session() as session:
            result = await session.execute(
                select(Event)
                .where(Event.processing_status == ProcessingStatus.pending)
                .where(Event.type != EventType.text)
                .limit(10)
            )
            events = result.scalars().all()

            for event in events:
                await self._process_event(session, event)

    async def _process_event(self, session: AsyncSession, event: Event) -> None:
        """Process a single event."""
        event.processing_status = ProcessingStatus.processing  # type: ignore[assignment]
        await session.commit()

        try:
            if event.type == EventType.audio and event.raw_file_path:
                result = await self.transcription.transcribe(
                    Path(event.raw_file_path), event.id
                )
                event.transcription = result.text  # type: ignore[assignment]

            elif event.type == EventType.video and event.raw_file_path:
                result = await self.video.extract_and_transcribe(
                    Path(event.raw_file_path), event.id
                )
                event.transcription = result.text  # type: ignore[assignment]

            elif event.type == EventType.photo and event.raw_file_path:
                img_result = await self.image.describe(
                    Path(event.raw_file_path), event.id
                )
                event.description = img_result.description  # type: ignore[assignment]

            event.processing_status = ProcessingStatus.completed  # type: ignore[assignment]

            # Generate timeline entry after successful processing
            try:
                await self.timeline.append_event(event)
            except Exception:
                logger.exception("Failed to write timeline for event %s", event.id)

            logger.info("Processed event %s (%s)", event.id, event.type.value)

        except Exception:
            event.processing_status = ProcessingStatus.failed  # type: ignore[assignment]
            logger.exception("Failed to process event %s", event.id)

        await session.commit()

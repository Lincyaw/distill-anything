"""Event ingestion API endpoints."""

import json
import tempfile
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.event import Event, EventCreate, EventResponse, EventType, ProcessingStatus
from ..services.checksum import compute_file_checksum
from ..services.database import get_session
from ..services.storage import StorageService

router = APIRouter()
storage = StorageService()


@router.post("/events", response_model=EventResponse)
async def create_event(
    metadata: str = Form(...),
    file: UploadFile | None = File(None),
    session: AsyncSession = Depends(get_session),
) -> EventResponse:
    """Ingest a new event with optional media file."""
    try:
        event_data = EventCreate(**json.loads(metadata))
    except (json.JSONDecodeError, ValueError) as e:
        raise HTTPException(status_code=400, detail=f"Invalid metadata: {e}")

    server_checksum: str | None = None
    raw_file_path: str | None = None

    if file is not None:
        # Save uploaded file to temp, compute checksum, move to storage
        with tempfile.NamedTemporaryFile(
            delete=False, suffix=Path(file.filename or "").suffix
        ) as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = Path(tmp.name)

        server_checksum = compute_file_checksum(tmp_path)
        dest = storage.store_file(tmp_path, event_data.id, event_data.timestamp)
        raw_file_path = str(dest)

    db_event = Event(
        id=event_data.id,
        type=event_data.type,
        timestamp=event_data.timestamp,
        raw_file_path=raw_file_path,
        text_content=event_data.text_content,
        annotation=event_data.annotation,
        checksum=event_data.checksum,
        file_size_bytes=event_data.file_size_bytes,
    )
    session.add(db_event)
    await session.commit()
    await session.refresh(db_event)

    return EventResponse(
        id=db_event.id,
        type=db_event.type,
        timestamp=db_event.timestamp,
        text_content=db_event.text_content,
        annotation=db_event.annotation,
        checksum=db_event.checksum,
        server_checksum=server_checksum,
        file_size_bytes=db_event.file_size_bytes,
        upload_status=db_event.upload_status,
        processing_status=db_event.processing_status,
        transcription=db_event.transcription,
        description=db_event.description,
        created_at=db_event.created_at,
    )


@router.get("/events", response_model=list[EventResponse])
async def list_events(
    event_type: EventType | None = Query(None),
    since: datetime | None = Query(None),
    until: datetime | None = Query(None),
    limit: int = Query(100, le=1000),
    offset: int = Query(0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> list[EventResponse]:
    """List events with optional filters."""
    query = select(Event).order_by(Event.timestamp.desc())

    if event_type is not None:
        query = query.where(Event.type == event_type)
    if since is not None:
        query = query.where(Event.timestamp >= since)
    if until is not None:
        query = query.where(Event.timestamp <= until)

    query = query.offset(offset).limit(limit)
    result = await session.execute(query)
    events = result.scalars().all()

    return [
        EventResponse(
            id=e.id,
            type=e.type,
            timestamp=e.timestamp,
            text_content=e.text_content,
            annotation=e.annotation,
            checksum=e.checksum,
            file_size_bytes=e.file_size_bytes,
            upload_status=e.upload_status,
            processing_status=e.processing_status,
            transcription=e.transcription,
            description=e.description,
            created_at=e.created_at,
        )
        for e in events
    ]


@router.get("/events/{event_id}", response_model=EventResponse)
async def get_event(
    event_id: str,
    session: AsyncSession = Depends(get_session),
) -> EventResponse:
    """Get a single event by ID."""
    result = await session.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")

    return EventResponse(
        id=event.id,
        type=event.type,
        timestamp=event.timestamp,
        text_content=event.text_content,
        annotation=event.annotation,
        checksum=event.checksum,
        file_size_bytes=event.file_size_bytes,
        upload_status=event.upload_status,
        processing_status=event.processing_status,
        transcription=event.transcription,
        description=event.description,
        created_at=event.created_at,
    )


@router.post("/events/{event_id}/reprocess", response_model=EventResponse)
async def reprocess_event(
    event_id: str,
    session: AsyncSession = Depends(get_session),
) -> EventResponse:
    """Reset event processing status to trigger reprocessing."""
    result = await session.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")
    event.processing_status = ProcessingStatus.pending  # type: ignore[assignment]
    event.transcription = None  # type: ignore[assignment]
    event.description = None  # type: ignore[assignment]
    await session.commit()
    await session.refresh(event)
    return EventResponse(
        id=event.id,
        type=event.type,
        timestamp=event.timestamp,
        text_content=event.text_content,
        annotation=event.annotation,
        checksum=event.checksum,
        file_size_bytes=event.file_size_bytes,
        upload_status=event.upload_status,
        processing_status=event.processing_status,
        transcription=event.transcription,
        description=event.description,
        created_at=event.created_at,
    )

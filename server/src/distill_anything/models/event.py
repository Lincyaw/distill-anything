"""Event data models — SQLAlchemy ORM + Pydantic schemas."""

import enum
from datetime import UTC, datetime

from pydantic import BaseModel
from sqlalchemy import Column, DateTime, Enum, Integer, String, Text
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


class EventType(enum.StrEnum):
    audio = "audio"
    photo = "photo"
    video = "video"
    text = "text"


class UploadStatus(enum.StrEnum):
    received = "received"
    verified = "verified"
    failed = "failed"


class ProcessingStatus(enum.StrEnum):
    pending = "pending"
    processing = "processing"
    completed = "completed"
    failed = "failed"


class Event(Base):
    __tablename__ = "events"

    id = Column(String, primary_key=True)
    type = Column(Enum(EventType), nullable=False)
    timestamp = Column(DateTime, nullable=False)
    raw_file_path = Column(String, nullable=True)
    text_content = Column(Text, nullable=True)
    annotation = Column(Text, nullable=True)
    checksum = Column(String, nullable=True)
    file_size_bytes = Column(Integer, nullable=True)
    upload_status = Column(Enum(UploadStatus), default=UploadStatus.received)
    processing_status = Column(Enum(ProcessingStatus), default=ProcessingStatus.pending)
    transcription = Column(Text, nullable=True)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(UTC))


class EventCreate(BaseModel):
    """Schema for event creation request metadata."""

    id: str
    type: EventType
    timestamp: datetime
    text_content: str | None = None
    annotation: str | None = None
    checksum: str | None = None
    file_size_bytes: int | None = None


class EventResponse(BaseModel):
    """Schema for event API response."""

    id: str
    type: EventType
    timestamp: datetime
    text_content: str | None = None
    annotation: str | None = None
    checksum: str | None = None
    server_checksum: str | None = None
    file_size_bytes: int | None = None
    upload_status: UploadStatus
    processing_status: ProcessingStatus
    transcription: str | None = None
    description: str | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}

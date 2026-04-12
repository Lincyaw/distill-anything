"""Tests for file storage service."""

from datetime import datetime
from pathlib import Path

from distill_anything.services.storage import StorageService


def test_store_file(tmp_storage: Path, tmp_path: Path) -> None:
    service = StorageService(root=tmp_storage)
    src = tmp_path / "test.wav"
    src.write_bytes(b"test audio data")

    timestamp = datetime(2026, 4, 12, 14, 30, 0)
    dest = service.store_file(src, "evt-001", timestamp)

    assert dest.exists()
    assert "2026/04/12" in str(dest)
    assert dest.name == "evt-001.wav"


def test_get_storage_usage(tmp_storage: Path, tmp_path: Path) -> None:
    service = StorageService(root=tmp_storage)

    # Initially empty
    assert service.get_storage_usage() == 0

    # Store a file
    src = tmp_path / "test.txt"
    src.write_bytes(b"hello world")
    service.store_file(src, "evt-002", datetime(2026, 1, 1))

    assert service.get_storage_usage() > 0


def test_delete_file(tmp_storage: Path, tmp_path: Path) -> None:
    service = StorageService(root=tmp_storage)
    src = tmp_path / "test.txt"
    src.write_bytes(b"data")
    dest = service.store_file(src, "evt-003", datetime(2026, 1, 1))

    assert service.delete_file(dest)
    assert not dest.exists()
    assert not service.delete_file(dest)  # Already deleted

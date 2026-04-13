"""Raw file storage — organized by date (YYYY/MM/DD/)."""

import shutil
from datetime import datetime
from pathlib import Path

from ..config import settings


class StorageService:
    """Manages raw event file storage on disk."""

    def __init__(self, root: Path | None = None) -> None:
        self.root = root or settings.storage_root

    def _date_path(self, timestamp: datetime) -> Path:
        return self.root / timestamp.strftime("%Y/%m/%d")

    def store_file(self, file_path: Path, event_id: str, timestamp: datetime) -> Path:
        """Store a file in date-organized directory. Returns the destination path."""
        dest_dir = self._date_path(timestamp)
        dest_dir.mkdir(parents=True, exist_ok=True)
        suffix = file_path.suffix
        dest = dest_dir / f"{event_id}{suffix}"
        shutil.move(str(file_path), str(dest))
        return dest

    def get_file_path(self, event_id: str, timestamp: datetime, suffix: str) -> Path:
        """Get expected file path for an event."""
        return self._date_path(timestamp) / f"{event_id}{suffix}"

    def delete_file(self, file_path: Path) -> bool:
        """Delete a stored file. Returns True if deleted."""
        try:
            file_path.unlink()
            return True
        except FileNotFoundError:
            return False

    def get_storage_usage(self) -> int:
        """Return total bytes used by stored files."""
        total = 0
        if self.root.exists():
            for f in self.root.rglob("*"):
                if f.is_file():
                    total += f.stat().st_size
        return total

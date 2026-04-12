"""Checksum computation for data integrity verification."""

import hashlib
from pathlib import Path


def compute_file_checksum(file_path: Path, algorithm: str = "sha256") -> str:
    """Compute checksum of a file."""
    h = hashlib.new(algorithm)
    with open(file_path, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()


def compute_bytes_checksum(data: bytes, algorithm: str = "sha256") -> str:
    """Compute checksum of bytes."""
    h = hashlib.new(algorithm)
    h.update(data)
    return h.hexdigest()

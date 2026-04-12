"""Tests for checksum service."""

from pathlib import Path

from distill_anything.services.checksum import compute_bytes_checksum, compute_file_checksum


def test_file_checksum(tmp_path: Path) -> None:
    f = tmp_path / "test.bin"
    f.write_bytes(b"hello")
    cs1 = compute_file_checksum(f)
    cs2 = compute_file_checksum(f)
    assert cs1 == cs2
    assert len(cs1) == 64  # SHA256 hex digest


def test_bytes_checksum() -> None:
    cs1 = compute_bytes_checksum(b"hello")
    cs2 = compute_bytes_checksum(b"hello")
    assert cs1 == cs2

    cs3 = compute_bytes_checksum(b"world")
    assert cs3 != cs1


def test_checksum_consistency(tmp_path: Path) -> None:
    """File checksum should match bytes checksum for same content."""
    data = b"integrity check"
    f = tmp_path / "test.bin"
    f.write_bytes(data)

    assert compute_file_checksum(f) == compute_bytes_checksum(data)

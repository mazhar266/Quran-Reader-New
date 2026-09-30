"""Idempotent extraction of the resource archives into build/pipeline/extract."""

import zipfile
from pathlib import Path

from .paths import EXTRACT, KFGQPC, QUL


def _unzip(archive: Path, dest: Path) -> Path:
    marker = dest / ".done"
    if marker.exists():
        return dest
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        z.extractall(dest)
    marker.touch()
    return dest


def kfgqpc_package(zip_name: str) -> Path:
    """Extracts one KFGQPC riwayah package and returns its directory."""
    return _unzip(KFGQPC / zip_name, EXTRACT / "kfgqpc" / Path(zip_name).stem)


def qul_layout_db(db_name: str) -> Path:
    """Extracts one QUL layout DB (``<name>.db.zip``) and returns the .db path."""
    dest = _unzip(QUL / "mushafs" / f"{db_name}.zip", EXTRACT / "qul" / db_name)
    matches = list(dest.rglob("*.db"))
    if len(matches) != 1:
        raise RuntimeError(f"expected one .db in {dest}, found {matches}")
    return matches[0]


def find_one(directory: Path, pattern: str) -> Path:
    matches = sorted(directory.rglob(pattern))
    if len(matches) != 1:
        raise RuntimeError(f"expected one {pattern} under {directory}, found {matches}")
    return matches[0]

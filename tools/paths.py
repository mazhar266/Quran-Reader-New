"""Well-known locations used by every pipeline step."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "resources"
KFGQPC = RESOURCES / "quran complex"
QUL = RESOURCES / "qul"

BUILD = ROOT / "build" / "pipeline"
EXTRACT = BUILD / "extract"

ASSETS = ROOT / "assets"
ASSET_DB = ASSETS / "db" / "quran_reader.db"
ASSET_FONTS = ASSETS / "fonts"

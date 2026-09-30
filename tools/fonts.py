"""Bundled font assets and per-mushaf page geometry derived from real shaping."""

import re
import shutil
from pathlib import Path

from fontTools.ttLib import TTFont

from .paths import ASSET_FONTS, QUL

# asset file → source file under resources/qul
BUNDLED = {
    "KFGQPC-Hafs.ttf": "fonts/UthmanicHafs_V22.ttf/UthmanicHafs_V22.ttf",
    "KFGQPC-Warsh.ttf": "fonts/uthmanic-warsh-v21.ttf/uthmanic-warsh-v21.ttf",
    "KFGQPC-Qaloun.ttf": "fonts/uthmanic-qaloun-v21.ttf/uthmanic-qaloun-v21.ttf",
    "KFGQPC-Douri.ttf": "fonts/uthmanic-douri-v20.ttf/uthmanic-douri-v20.ttf",
    "KFGQPC-Shuba.ttf": "fonts/uthmanic-shuba-v20.ttf/uthmanic-shuba-v20.ttf",
    "KFGQPC-Sousi.ttf": "fonts/uthmanic-sousi-v20.ttf/uthmanic-sousi-v20.ttf",
    "AlQuranIndoPak.ttf": "font.ttf",
    "SurahNameV2.ttf": "fonts/surah-name-v2.ttf/surah-name-v2.ttf",
    "QuranCommon.ttf": "fonts/quran-common.ttf/quran-common.ttf",
}


def source(asset: str) -> Path:
    return QUL / BUNDLED[asset]


def copy_bundled() -> None:
    ASSET_FONTS.mkdir(parents=True, exist_ok=True)
    for asset in BUNDLED:
        dest = ASSET_FONTS / asset
        src = source(asset)
        if not dest.exists() or dest.read_bytes() != src.read_bytes():
            shutil.copyfile(src, dest)


def cmap(asset: str) -> set[int]:
    return set(TTFont(source(asset)).getBestCmap())


_LETTER = re.compile("[\u0621-\u064a\u0671-\u06d3\uf61f]")


def line_words(text: str) -> list[str]:
    """The app's word units (lib/domain/quran_text.dart `lineWords`): a token
    without an Arabic letter stays with the word before it."""
    out: list[str] = []
    for token in text.split(" "):
        if not token:
            continue
        if out and not _LETTER.search(token):
            out[-1] += " " + token
        else:
            out.append(token)
    return out


def page_geometry(asset: str, lines: list) -> tuple[float, float]:
    """Returns (font_scale K, line_scale L) for a mushaf.

    The app sets ``fontSize = textWidth / K``. Printed lines vary a lot in
    natural width (a median Madinah line is 30 % shorter than the widest), so
    K is not the widest line: it is the 99.9th percentile of the lines'
    *tight* width, i.e. with spaces shrunk to half, which the app allows
    before it squeezes a line. Shorter lines are filled with kashida.
    L is the smallest line pitch (in em) that keeps the ink of adjacent lines
    apart: 99th percentile of descent plus 1st percentile of ascent.
    """
    from PIL import ImageFont

    size = 200
    font = ImageFont.truetype(str(source(asset)), size, layout_engine=ImageFont.Layout.RAQM)
    space = font.getlength(" ") / size
    widths, tops, bottoms = [], [], []
    for i, ln in enumerate(lines):
        if ln.kind != "ayah" or not ln.text:
            continue
        if not ln.centered:
            gaps = len(line_words(ln.text)) - 1
            natural = font.getlength(ln.text, direction="rtl", language="ar") / size
            widths.append(natural - 0.5 * space * gaps)
        if i % 5 == 0:
            box = font.getbbox(ln.text, direction="rtl", language="ar", anchor="ls")
            tops.append(-box[1] / size)
            bottoms.append(box[3] / size)
    widths.sort()
    tops.sort()
    bottoms.sort()
    k = round(widths[int(len(widths) * 0.999)] * 1.005, 2)
    lead = tops[int(len(tops) * 0.99)] + bottoms[int(len(bottoms) * 0.99)]
    return k, round(lead, 2)

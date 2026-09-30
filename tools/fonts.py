"""Bundled font assets and per-mushaf page geometry derived from real shaping."""

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


def page_geometry(asset: str, lines: list) -> tuple[float, float]:
    """Returns (font_scale K, line_scale L) for a mushaf.

    K is the widest justified line's natural width in em (plus 1 %), so the
    app can set ``fontSize = textWidth / K`` without squeezing any line.
    L is the smallest line pitch (in em) that keeps the ink of adjacent lines
    apart: 99th percentile of descent plus 1st percentile of ascent.
    """
    from PIL import ImageFont

    size = 200
    font = ImageFont.truetype(str(source(asset)), size, layout_engine=ImageFont.Layout.RAQM)
    widths, tops, bottoms = [], [], []
    for i, ln in enumerate(lines):
        if ln.kind != "ayah" or not ln.text:
            continue
        if not ln.centered:
            widths.append(font.getlength(ln.text, direction="rtl", language="ar") / size)
        if i % 5 == 0:
            box = font.getbbox(ln.text, direction="rtl", language="ar", anchor="ls")
            tops.append(-box[1] / size)
            bottoms.append(box[3] / size)
    tops.sort()
    bottoms.sort()
    k = round(max(widths) * 1.01, 2)
    lead = tops[int(len(tops) * 0.99)] + bottoms[int(len(bottoms) * 0.99)]
    return k, round(lead, 2)

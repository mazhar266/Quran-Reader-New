"""Generates the launcher icons from the calligraphic emblem in quran-common.

    python3 -m tools.icons

Android mipmaps and every image in the iOS AppIcon set are rewritten at
their existing sizes.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from .paths import ASSET_FONTS, ROOT

GREEN = (31, 111, 80)
CREAM = (246, 238, 220)
EMBLEM = "\ue076"  # القرآن الكريم


def render(size: int, rounded: bool) -> Image.Image:
    scale = 4  # supersample for smooth edges
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if rounded:
        d.rounded_rectangle((0, 0, s - 1, s - 1), radius=int(s * 0.22), fill=GREEN)
    else:
        d.rectangle((0, 0, s, s), fill=GREEN)
    inset = int(s * 0.07)
    d.rounded_rectangle((inset, inset, s - inset, s - inset), radius=int(s * 0.17), outline=CREAM, width=max(2, s // 64))
    font = ImageFont.truetype(str(ASSET_FONTS / "QuranCommon.ttf"), int(s * 0.5))
    box = d.textbbox((0, 0), EMBLEM, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    d.text(((s - w) / 2 - box[0], (s - h) / 2 - box[1]), EMBLEM, font=font, fill=CREAM)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    res = ROOT / "android/app/src/main/res"
    for icon in res.glob("mipmap-*/ic_launcher.png"):
        size = Image.open(icon).size[0]
        render(size, rounded=True).save(icon)
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for image in json.loads((ios / "Contents.json").read_text())["images"]:
        path = ios / image["filename"]
        size = Image.open(path).size[0]
        # iOS applies its own mask and rejects transparency.
        render(size, rounded=False).convert("RGB").save(path)
    render(1024, rounded=True).save(ROOT / "docs/images/app-icon.png")


if __name__ == "__main__":
    main()

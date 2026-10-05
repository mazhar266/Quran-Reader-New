"""Checks on a printed book (docs/ereader-pdf/04 §1) and preview images."""

from __future__ import annotations

from pathlib import Path

from ..paths import ROOT
from .books import Book
from .render import OUT, front_matter_count
from .tajweed import COLOUR

PAGE_PT = (257.04, 347.53)  # 90.8 × 122.6 mm
EXPECTED_FONTS = {"Mushaf", "SurahName", "QuranCommon", "Latin"}


def check_pdf(book: Book, pdf: Path) -> dict:
    import pymupdf

    doc = pymupdf.open(pdf)
    first = front_matter_count(book)
    expected_pages = first + len(book.screens)
    assert doc.page_count == expected_pages, f"{doc.page_count} pages, expected {expected_pages}"

    # Every screen displays as a portrait 6-inch page (landscape ones rotated).
    for i in (0, first, first + len(book.screens) // 2, expected_pages - 1):
        r = doc[i].rect  # displayed size, rotation applied
        assert abs(r.width - PAGE_PT[0]) < 0.5 and abs(r.height - PAGE_PT[1]) < 0.5, f"page {i}: {r}"

    # Only the declared fonts, all embedded: a fallback font means a missing glyph.
    fonts = set()
    for i in range(0, doc.page_count, max(1, doc.page_count // 60)):
        for f in doc[i].get_fonts(full=True):
            if f[2] != "Type3":  # large glyphs (the title emblem) are drawn as vector paths
                fonts.add(f[3].split("+")[-1])
    unexpected = {f for f in fonts if not any(e.lower() in f.lower() for e in
                                                  ("KFGQPC", "Uthman", "IndoPak", "surah", "quran", "DejaVu", "QCF"))}
    assert not unexpected, f"unexpected fonts {unexpected}"

    # Ink stays inside the paper with a 1 mm safety band on sampled screens.
    overflow = []
    step = max(1, len(book.screens) // 40)
    for i in range(first, expected_pages, step):
        page = doc[i]
        pix = page.get_pixmap(dpi=60, colorspace=pymupdf.csGRAY)
        w, h = pix.width, pix.height
        band = max(1, round(60 / 25.4))  # 1 mm
        data = pix.samples
        edge = any(
            data[y * w + x] < 128
            for y in range(h) for x in list(range(band)) + list(range(w - band, w))
        ) or any(data[y * w + x] < 128 for y in list(range(band)) + list(range(h - band, h)) for x in range(w))
        if edge:
            overflow.append(i + 1)
    assert not overflow, f"ink at the page edge on pages {overflow}"
    size_mb = pdf.stat().st_size / 1e6
    result = {"pages": doc.page_count, "size_mb": round(size_mb, 1), "fonts": sorted(fonts)}
    if book.tajweed:
        result.update(check_tajweed(book, doc))
    return result


def check_tajweed(book: Book, doc) -> dict:
    """The palette is on the text, and the ink of sampled screens is that of
    the plain book (so the coloured runs did not change the shaping)."""
    import pymupdf

    first = front_matter_count(book)
    colours = set()
    for i in range(first, doc.page_count, max(1, len(book.screens) // 60)):
        for block in doc[i].get_text("dict")["blocks"]:
            for line in block.get("lines", []):
                for span in line["spans"]:
                    colours.add(span["color"])
    palette = {int(c[1:], 16) for c in COLOUR.values()}
    assert len(colours & palette) >= 10, f"only {len(colours & palette)} tajwid colours found"
    result = {"colours": len(colours & palette)}
    plain = plain_book(book)
    if plain is not None:
        plain_doc = pymupdf.open(plain)
        result["ink_match"] = ink_match(book, doc, plain_doc)
        result["stray_ink_px"] = stray_ink(book, doc, plain_doc)
    return result


def plain_book(book: Book) -> Path | None:
    """The same book without tajwid colours, if it has been built or published."""
    name = book.file_name.replace("-tajweed", "")
    for candidate in (OUT / name, ROOT / "ereader-books" / name):
        if candidate.is_file():
            return candidate
    return None


def _ink(page) -> list[bool]:
    """Non-white pixels at 100 ppi (coloured ink counts as ink)."""
    import pymupdf

    pix = page.get_pixmap(dpi=100, colorspace=pymupdf.csRGB)
    s, n = pix.samples, pix.n
    return [min(s[i], s[i + 1], s[i + 2]) < 240 for i in range(0, len(s), n)]


def _ink_mask(page, dpi: int = 200):
    """Ink (darkest channel below 240) as a Pillow bilevel image."""
    import pymupdf
    from PIL import Image, ImageChops

    pix = page.get_pixmap(dpi=dpi, colorspace=pymupdf.csRGB)
    r, g, b = Image.frombytes("RGB", (pix.width, pix.height), pix.samples).split()
    return ImageChops.darker(ImageChops.darker(r, g), b).point(lambda v: 255 if v < 240 else 0)


def stray_ink(book: Book, doc, plain) -> int:
    """Ink pixels of the sampled screens, at 200 ppi, farther than one pixel
    from the plain book's ink, in either direction. Colouring runs of a word
    must leave every glyph where it was: a broken join or a displaced mark
    shows up as hundreds of stray pixels, anti-aliasing as a handful.
    (The text layers themselves are not comparable: Chrome encodes the split
    runs differently, so character positions read back differ harmlessly.)"""
    from PIL import ImageChops, ImageFilter

    first = front_matter_count(book)
    plain_first = first - 1
    stray = 0
    for idx in preview_pages(book):
        if idx < first:
            continue
        a, b = _ink_mask(doc[idx]), _ink_mask(plain[plain_first + idx - first])
        grown_a, grown_b = a.filter(ImageFilter.MaxFilter(3)), b.filter(ImageFilter.MaxFilter(3))
        stray += sum(1 for v in ImageChops.subtract(a, grown_b).get_flattened_data() if v)
        stray += sum(1 for v in ImageChops.subtract(b, grown_a).get_flattened_data() if v)
    assert stray <= 50, f"{stray} ink pixels of the sampled screens are not where the plain book has ink"
    return stray


def ink_match(book: Book, doc, plain) -> float:
    """Worst intersection-over-union of the ink of the sampled screens with
    the plain book's: 1.0 means identical glyph shapes and positions."""
    first = front_matter_count(book)
    plain_first = first - 1  # no legend screen
    assert plain.page_count == plain_first + len(book.screens), "plain book has a different screen count"
    worst = 1.0
    for idx in preview_pages(book):
        if idx < first:
            continue
        a, b = _ink(doc[idx]), _ink(plain[plain_first + idx - first])
        inter = sum(1 for x, y in zip(a, b) if x and y)
        union = sum(1 for x, y in zip(a, b) if x or y)
        worst = min(worst, inter / union if union else 1.0)
    assert worst >= 0.97, f"ink differs from the plain book (IoU {worst:.3f})"
    return round(worst, 4)


def preview_pages(book: Book) -> list[int]:
    """0-based PDF pages to preview: title, index, and fixed text samples."""
    first = front_matter_count(book)
    wanted = [0, 1, 2]
    for page in (1, 2, 3, 50, 77, 255, 507, 604, 1000):
        idx = next((i for i, s in enumerate(book.screens) if s.pages[0] <= page <= s.pages[1]), None)
        if idx is not None:
            wanted.append(first + idx)
    return sorted(set(wanted))


def preview_dir(book: Book) -> Path:
    return OUT / "previews" / Path(book.file_name).stem


def previews(book: Book, pdf: Path, dpi: int = 300) -> list[Path]:
    """Renders sample screens at the panel's 300 ppi (1072 × 1448 px); in
    colour for a tajwid book."""
    import pymupdf

    doc = pymupdf.open(pdf)
    out_dir = preview_dir(book)
    out_dir.mkdir(parents=True, exist_ok=True)
    colorspace = pymupdf.csRGB if book.tajweed else pymupdf.csGRAY
    paths = []
    for i in preview_pages(book):
        if i >= doc.page_count:
            continue
        p = out_dir / f"screen-{i + 1:04d}.png"
        doc[i].get_pixmap(dpi=dpi, colorspace=colorspace).save(p)
        paths.append(p)
    return paths

"""Checks on a printed book (docs/ereader-pdf/04 §1) and preview images."""

from __future__ import annotations

from pathlib import Path

from .books import Book
from .render import OUT, front_matter_count

PAGE_PT = (257.04, 347.53)  # 90.8 × 122.6 mm
EXPECTED_FONTS = {"Mushaf", "SurahName", "QuranCommon", "Latin"}


def check_pdf(book: Book, pdf: Path) -> dict:
    import pymupdf

    doc = pymupdf.open(pdf)
    first = front_matter_count()
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
    return {"pages": doc.page_count, "size_mb": round(size_mb, 1), "fonts": sorted(fonts)}


def preview_pages(book: Book) -> list[int]:
    """0-based PDF pages to preview: title, index, and fixed text samples."""
    first = front_matter_count()
    wanted = [0, 1, 2]
    for page in (1, 2, 3, 50, 77, 255, 507, 604, 1000):
        idx = next((i for i, s in enumerate(book.screens) if s.pages[0] <= page <= s.pages[1]), None)
        if idx is not None:
            wanted.append(first + idx)
    return sorted(set(wanted))


def previews(book: Book, pdf: Path, dpi: int = 300) -> list[Path]:
    """Renders sample screens at the panel's 300 ppi (1072 × 1448 px)."""
    import pymupdf

    doc = pymupdf.open(pdf)
    out_dir = OUT / "previews" / Path(book.file_name).stem
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for i in preview_pages(book):
        p = out_dir / f"screen-{i + 1:04d}.png"
        doc[i].get_pixmap(dpi=dpi, colorspace=pymupdf.csGRAY).save(p)
        paths.append(p)
    return paths

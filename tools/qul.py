"""QUL page layouts rendered with Unicode text (mode 'unicode').

- Mushaf Qatar: QUL line ranges (global word ids) filled with KFGQPC Hafs words.
- Indopak 9 lines (Gaba): QUL layout rows zipped with the per-page Word export
  (one paragraph per ayah line, IndoPak Unicode with private-use markers).
"""

import io
import re
import sqlite3
import zipfile
from dataclasses import dataclass

from . import docx
from .extract import qul_layout_db
from .kfgqpc import Line
from .paths import QUL
from .words import Word, join_words


@dataclass
class LayoutRow:
    page: int
    line: int
    kind: str  # QUL: 'ayah' | 'surah_name' | 'basmallah'
    centered: bool
    first_word: int | None
    last_word: int | None
    surah: int | None


def read_layout(db_name: str) -> list[LayoutRow]:
    con = sqlite3.connect(qul_layout_db(db_name))
    rows = con.execute(
        "SELECT page_number, line_number, line_type, is_centered, first_word_id, last_word_id, surah_number "
        "FROM pages ORDER BY page_number, line_number"
    ).fetchall()
    con.close()

    def num(v):
        return None if v in ("", None) else int(v)

    return [LayoutRow(p, l, t, bool(c), num(f), num(la), num(s)) for p, l, t, c, f, la, s in rows]


def qatar_lines(words: list[Word]) -> list[Line]:
    out: list[Line] = []
    surah = 0
    for r in read_layout("mushaf-qatar-layout.db"):
        # Pages 1–2 are set in a small decorated block: centre them like the
        # Madinah prints instead of justifying short lines.
        centered = r.centered or r.page <= 2
        if r.kind == "surah_name":
            surah = r.surah
            out.append(Line(r.page, r.line, "surah", True, surah, ""))
        elif r.kind == "basmallah":
            out.append(Line(r.page, r.line, "basmala", True, surah, ""))
        else:
            ws = words[r.first_word - 1 : r.last_word]
            ln = Line(r.page, r.line, "ayah", centered, None, join_words(ws))
            ln.first = (ws[0].surah, ws[0].ayah)
            last = ws[-1]
            ln.last = (last.surah, last.ayah)
            out.append(ln)
    return out


# Ayah-end glyphs of the AlQuran IndoPak font (see docs/01 §5.3): numbered
# circles U+F500 + n − 1, the empty circle U+F61E and variants that carry a
# sajdah/ruku annotation. U+F63E, U+F658 and U+F68F are annotations only.
GABA_ENDS = frozenset(
    (set(range(0xF500, 0xF61F)) | set(range(0xF631, 0xF63E)) | set(range(0xF681, 0xF694))) - {0xF68F}
)


def gaba_ends(text: str) -> int:
    return sum(1 for ch in text if ord(ch) in GABA_ENDS)


_LETTER = re.compile("[ء-يٱ-ۓ\uf61f]")


def _ends_with_ayah(text: str) -> bool:
    """True when no word follows the line's last ayah-end glyph."""
    idx = max((i for i, ch in enumerate(text) if ord(ch) in GABA_ENDS), default=-1)
    return idx >= 0 and not _LETTER.search(text, idx + 1)


def gaba_lines() -> list[Line]:
    rows = read_layout("indopak-9-lines-gaba.db")
    by_page: dict[int, list[LayoutRow]] = {}
    for r in rows:
        by_page.setdefault(r.page, []).append(r)
    out: list[Line] = []
    surah, ayah = 0, 1
    with zipfile.ZipFile(QUL / "mushafs" / "pages.zip") as z:
        for page in sorted(by_page):
            paras = docx.read_paragraphs(io.BytesIO(z.read(f"{page}.docx")))
            ayah_rows = [r for r in by_page[page] if r.kind == "ayah"]
            if len(paras) != len(ayah_rows):
                raise AssertionError(f"gaba p{page}: {len(paras)} paragraphs, {len(ayah_rows)} ayah rows")
            it = iter(paras)
            for r in by_page[page]:
                if r.kind == "surah_name":
                    surah, ayah = r.surah, 1
                    out.append(Line(page, r.line, "surah", True, surah, ""))
                elif r.kind == "basmallah":
                    out.append(Line(page, r.line, "basmala", True, surah, ""))
                else:
                    p = next(it)
                    text = re.sub(" +", " ", p.text.strip())
                    ln = Line(page, r.line, "ayah", r.centered or p.align == "center", None, text)
                    ln.first = (surah, ayah)
                    ayah += gaba_ends(text)
                    ln.last = (surah, ayah - 1) if _ends_with_ayah(text) else (surah, ayah)
                    out.append(ln)
    return out

"""Validation suite: structural counts, font coverage and database sanity."""

import sqlite3
from collections import Counter

from . import fonts
from .paths import ASSET_DB

# Expected (surah headers, basmala rows) per mushaf. Riwayat that do not count
# the Fatihah basmala as an ayah print it as a separate basmala line.
EXPECTED_ROWS = {
    "madinah_hafs": (114, 112),
    "madinah_shuba": (114, 112),
    "madinah_warsh": (114, 113),
    "madinah_qaloun": (114, 113),
    "madinah_douri": (114, 113),
    "madinah_sousi": (114, 113),
    "qatar": (114, 112),
    "indopak_9_gaba": (114, 1),
}


def expect(cond: bool, message: str) -> None:
    if not cond:
        raise AssertionError(message)


def check_mushaf(m) -> None:
    per_page = Counter(ln.page for ln in m.lines)
    expect(sorted(per_page) == list(range(1, m.pages + 1)), f"{m.id}: pages are not 1..{m.pages}")
    expect(max(per_page.values()) == m.lines_per_page, f"{m.id}: more than {m.lines_per_page} lines on a page")
    for page, n in per_page.items():
        lines = sorted(ln.line for ln in m.lines if ln.page == page)
        expect(lines == list(range(1, n + 1)), f"{m.id} p{page}: line numbers {lines}")
    kinds = Counter(ln.kind for ln in m.lines)
    expect((kinds["surah"], kinds["basmala"]) == EXPECTED_ROWS[m.id], f"{m.id}: kinds {dict(kinds)}")
    headers = [ln.surah for ln in m.lines if ln.kind == "surah"]
    expect(headers == list(range(1, 115)), f"{m.id}: surah headers out of order")

    # Every character of every line must be in the mushaf font.
    covered = fonts.cmap(m.font_asset) | {0x20, 0xA0, 0x200D, 0x200F}
    missing = Counter()
    for ln in m.lines:
        for ch in ln.text or "":
            if ord(ch) not in covered:
                missing[f"U+{ord(ch):04X}"] += 1
    missing_basmala = [ch for ch in m.basmala if ord(ch) not in covered]
    expect(not missing and not missing_basmala, f"{m.id}: font lacks {dict(missing)} {missing_basmala}")


def check_db() -> None:
    con = sqlite3.connect(ASSET_DB)
    q = lambda sql, *a: con.execute(sql, a).fetchall()  # noqa: E731
    mushafs = q("SELECT id, pages FROM mushafs ORDER BY sort")
    expect(len(mushafs) == len(EXPECTED_ROWS), f"{len(mushafs)} mushafs in DB")
    expect(q("SELECT COUNT(*) FROM surahs") == [(114,)], "surahs")
    expect(q("SELECT COUNT(*) FROM ayah_text") == [(6236,)], "ayah_text")
    for mid, pages in mushafs:
        expect(q("SELECT COUNT(DISTINCT page) FROM pages WHERE mushaf_id=?", mid) == [(pages,)], f"{mid}: pages")
        expect(q("SELECT COUNT(*) FROM mushaf_surahs WHERE mushaf_id=?", mid) == [(114,)], f"{mid}: surahs")
        expect(q("SELECT COUNT(*) FROM mushaf_juz WHERE mushaf_id=?", mid) == [(30,)], f"{mid}: juz")
        juz = q("SELECT page FROM mushaf_juz WHERE mushaf_id=? ORDER BY juz", mid)
        expect([p for (p,) in juz] == sorted(p for (p,) in juz), f"{mid}: juz pages not increasing")
        expect(q("SELECT page FROM mushaf_surahs WHERE mushaf_id=? AND surah=114", mid) == [(pages,)],
               f"{mid}: An-Nas is not on the last page")
    con.close()

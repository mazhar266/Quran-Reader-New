"""Builds assets/db/quran_reader.db and assets/fonts/ from resources/.

    python3 -m tools.build

Every step validates its output; the build stops on the first mismatch.
"""

import sqlite3
import sys
import time
from collections import Counter
from dataclasses import dataclass

from . import checks, fonts, kfgqpc, qul, words
from .kfgqpc import Line
from .paths import ASSET_DB, BUILD

DB_VERSION = 1

HAFS_BASMALA = "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"
INDOPAK_BASMALA = "بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِیْمِ"

KFGQPC_SOURCE = "King Fahd Glorious Quran Printing Complex (KFGQPC), qurancomplex.gov.sa"
QUL_SOURCE = "Quranic Universal Library (QUL) by Tarteel, qul.tarteel.ai"


@dataclass
class Mushaf:
    id: str
    name: str
    name_ar: str
    description: str
    riwayah: str
    script: str
    pages: int
    lines_per_page: int
    font_asset: str
    font_family: str
    header_basmala: bool
    basmala: str
    edition_note: str
    source: str
    sort: int
    lines: list[Line]
    ayah_juz: dict[tuple[int, int], int]  # (surah, ayah) → juz in this mushaf's numbering
    ayah_counts: dict[int, int]  # surah → ayah count in this mushaf's numbering


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def kfgqpc_mushafs() -> tuple[list[Mushaf], list[kfgqpc.Ayah]]:
    out = []
    hafs_ayahs: list[kfgqpc.Ayah] = []
    for r in kfgqpc.RIWAYAT:
        ayahs, _ = kfgqpc.load_json(r)
        lines = kfgqpc.load_lines(r)
        problems = kfgqpc.assign_ayahs(lines, ayahs)
        # Spelling differences between the docx and the JSON are expected
        # (a handful, the docx is the layout we render); anything else fails.
        hard = [p for p in problems if "spelled differently" not in p]
        for p in problems:
            log(f"  {r.id}: {p}")
        if hard:
            sys.exit(f"{r.id}: docx and JSON disagree")
        checks.expect(len(ayahs) == r.ayahs, f"{r.id}: {len(ayahs)} ayahs")
        if r.id == "madinah_hafs":
            hafs_ayahs = ayahs
        name = r.name.split(" · ")[1]
        out.append(
            Mushaf(
                id=r.id, name=r.name, name_ar=r.name_ar,
                description=f"Riwāyah of {r.edition.split(' · ')[0]} · 15 lines, 604 pages",
                riwayah=r.id.removeprefix("madinah_"), script="uthmani",
                pages=604, lines_per_page=15, font_asset=r.font_asset, font_family=r.family,
                header_basmala=False,
                basmala=next(ln.text for ln in lines if ln.kind == "basmala"),
                edition_note=r.edition, source=KFGQPC_SOURCE + f" · Uthmanic {name} package",
                sort=r.sort, lines=lines,
                ayah_juz={(a.surah, a.ayah): a.juz for a in ayahs},
                ayah_counts=dict(Counter(a.surah for a in ayahs)),
            )
        )
        log(f"{r.id}: {len(lines)} lines, {len(ayahs)} ayahs")
    return out, hafs_ayahs


def qul_mushafs(hafs: list[kfgqpc.Ayah]) -> list[Mushaf]:
    hafs_juz = {(a.surah, a.ayah): a.juz for a in hafs}
    hafs_counts = dict(Counter(a.surah for a in hafs))
    word_table = words.build_words(hafs)
    log(f"words: {len(word_table)} (matches QUL)")
    qatar = Mushaf(
        id="qatar", name="Mushaf Qatar · Hafs", name_ar="مصحف قطر · رواية حفص عن عاصم",
        description="Qatar print layout · 15 lines, 604 pages",
        riwayah="hafs", script="uthmani", pages=604, lines_per_page=15,
        font_asset="KFGQPC-Hafs.ttf", font_family="KFGQPC Hafs", header_basmala=False,
        basmala=HAFS_BASMALA,
        edition_note="Mushaf Qatar line layout (QUL) set in the KFGQPC Hafs text and font",
        source=QUL_SOURCE + " (layout) · " + KFGQPC_SOURCE + " (text, font)",
        sort=70, lines=qul.qatar_lines(word_table), ayah_juz=hafs_juz, ayah_counts=hafs_counts,
    )
    log(f"qatar: {len(qatar.lines)} lines")
    gaba = Mushaf(
        id="indopak_9_gaba", name="Indopak · 9 lines (Gaba)", name_ar="المصحف الهندي · ٩ أسطر",
        description="Indo-Pak script, Gaba print · 9 lines, 1890 pages",
        riwayah="hafs", script="indopak", pages=1890, lines_per_page=9,
        font_asset="AlQuranIndoPak.ttf", font_family="AlQuran IndoPak", header_basmala=True,
        basmala=INDOPAK_BASMALA,
        edition_note="Indopak 9-line (Gaba) layout and text from QUL, AlQuran IndoPak typeface by QuranWBW",
        source=QUL_SOURCE + " (layout, text) · QuranWBW (AlQuran IndoPak font)",
        sort=80, lines=qul.gaba_lines(), ayah_juz=hafs_juz, ayah_counts=hafs_counts,
    )
    log(f"indopak_9_gaba: {len(gaba.lines)} lines")
    return [qatar, gaba]


def ayah_rows(m: Mushaf) -> list[tuple]:
    """First page/line of every ayah, from the line ranges."""
    first: dict[tuple[int, int], tuple[int, int]] = {}
    for ln in m.lines:
        if ln.kind != "ayah" or ln.first is None:
            continue
        s, a0 = ln.first
        s1, a1 = ln.last
        checks.expect(s == s1 and a0 <= a1, f"{m.id} p{ln.page} l{ln.line}: range {ln.first}..{ln.last}")
        for a in range(a0, a1 + 1):
            first.setdefault((s, a), (ln.page, ln.line))
    expected = sum(m.ayah_counts.values())
    checks.expect(len(first) == expected, f"{m.id}: {len(first)} ayahs located, expected {expected}")
    return [(m.id, s, a, p, l, m.ayah_juz[(s, a)]) for (s, a), (p, l) in sorted(first.items())]


def write_db(mushafs: list[Mushaf], hafs: list[kfgqpc.Ayah]) -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    tmp = BUILD / "quran_reader.db"
    tmp.unlink(missing_ok=True)
    con = sqlite3.connect(tmp)
    con.executescript((fonts.Path(__file__).parent / "schema.sql").read_text())
    con.execute("INSERT INTO meta VALUES ('db_version', ?)", (str(DB_VERSION),))

    hafs_rows = kfgqpc.load_json(kfgqpc.RIWAYAT[0])[1]
    names = {}
    for row in hafs_rows:
        names.setdefault(int(row["sura_no"]), (row["sura_name_ar"].strip(), row["sura_name_en"].strip()))
    counts = Counter(a.surah for a in hafs)
    con.executemany(
        "INSERT INTO surahs VALUES (?,?,?,?)",
        [(n, names[n][0], names[n][1], counts[n]) for n in range(1, 115)],
    )
    con.executemany("INSERT INTO ayah_text VALUES (?,?,?)", [(a.surah, a.ayah, a.text_plain) for a in hafs])

    for m in mushafs:
        k, lead = fonts.page_geometry(m.font_asset, m.lines)
        log(f"{m.id}: font_scale K={k} em, line_scale L={lead} em")
        con.execute(
            "INSERT INTO mushafs VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (m.id, m.name, m.name_ar, m.description, m.riwayah, m.script, m.pages, m.lines_per_page,
             "unicode", m.font_family, None, k, lead, int(m.header_basmala), m.basmala,
             m.edition_note, m.source, m.sort),
        )
        con.executemany(
            "INSERT INTO pages VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            [
                (m.id, ln.page, ln.line, ln.kind, int(ln.centered), ln.surah,
                 ln.text or (m.basmala if ln.kind == "basmala" else None),
                 *(ln.first or (None, None)), *(ln.last or (None, None)))
                for ln in m.lines
            ],
        )
        rows = ayah_rows(m)
        con.executemany("INSERT INTO ayahs VALUES (?,?,?,?,?,?)", rows)
        surah_pages = {}
        for ln in m.lines:
            if ln.kind == "surah":
                surah_pages.setdefault(ln.surah, ln.page)
        con.executemany(
            "INSERT INTO mushaf_surahs VALUES (?,?,?,?)",
            [(m.id, s, surah_pages[s], m.ayah_counts[s]) for s in range(1, 115)],
        )
        juz_first: dict[int, tuple] = {}
        for _, s, a, p, _, j in rows:
            juz_first.setdefault(j, (p, s, a))
        con.executemany(
            "INSERT INTO mushaf_juz VALUES (?,?,?,?,?)",
            [(m.id, j, *juz_first[j]) for j in sorted(juz_first)],
        )
    con.commit()
    con.execute("VACUUM")
    con.close()
    ASSET_DB.parent.mkdir(parents=True, exist_ok=True)
    ASSET_DB.write_bytes(tmp.read_bytes())
    log(f"wrote {ASSET_DB.relative_to(ASSET_DB.parents[2])} ({ASSET_DB.stat().st_size / 1e6:.1f} MB)")


def main() -> None:
    log("fonts")
    fonts.copy_bundled()
    log("KFGQPC riwayat")
    mushafs, hafs = kfgqpc_mushafs()
    log("QUL layouts")
    mushafs += qul_mushafs(hafs)
    for m in mushafs:
        checks.check_mushaf(m)
    log("database")
    write_db(mushafs, hafs)
    checks.check_db()
    log("done")


if __name__ == "__main__":
    main()

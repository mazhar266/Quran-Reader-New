"""Book composition: from the content database to screens of laid-out rows.

Three modes (docs/ereader-pdf/01 §4):

- ``reflow``: the text flows in lines filled with kashida, at a large size;
  printed page numbers appear as small markers where each printed page begins.
- ``rotated``: the exact printed lines, five per screen, laid along the long
  side of the screen (the PDF page is rotated, the reader turns the device).
- ``faithful``: one printed page per screen (the 9-line Gaba print).

Any Hafs book can also be a tajwid edition (``tajweed=True``): the letters
are coloured by the rule that applies to them (see ``tajweed.py``).
"""

from __future__ import annotations

import math
import sqlite3
from dataclasses import dataclass, field

from ..paths import ASSET_DB, ASSET_FONTS
from .layout import Line, Measure, ayah_ends, justify, line_tokens, line_words, token_groups, trailing_overhang
from .tajweed import Tajweed

MM_PER_PT = 25.4 / 72


@dataclass(frozen=True)
class Geometry:
    """Screen geometry in mm (6-inch panel, 90.8 × 122.6 mm)."""

    width: float
    height: float
    margin: float = 3.0
    header: float = 4.5
    footer: float = 4.5

    @property
    def block_width(self) -> float:
        return self.width - 2 * self.margin

    @property
    def block_height(self) -> float:
        return self.height - 2 * self.margin - self.header - self.footer


PORTRAIT = Geometry(90.8, 122.6)
LANDSCAPE = Geometry(122.6, 90.8)


@dataclass(frozen=True)
class Mushaf:
    id: str
    name: str
    name_ar: str
    riwayah: str
    pages: int
    lines_per_page: int
    font_file: str
    font_scale: float
    line_scale: float
    header_basmala: bool
    basmala: str
    edition_note: str
    source: str


# ---------------------------------------------------------------- screens


@dataclass
class Row:
    kind: str  # 'text' | 'surah' | 'basmala'
    top: float  # mm from the top of the text block
    height: float  # mm
    font_size: float  # mm
    line: Line | None = None
    surah: int | None = None
    basmala: Line | None = None  # under a surah frame (Indopak prints)
    key: tuple[int, int] | None = None  # first ayah on a text row
    pages: tuple[int, int] | None = None  # printed pages a text row spans


@dataclass
class Screen:
    rows: list[Row] = field(default_factory=list)
    juz: int = 1
    surah: int = 1
    pages: tuple[int, int] = (1, 1)  # printed pages shown
    part: tuple[int, int] | None = None  # (k, n) for a printed page split over n screens
    anchors: list[str] = field(default_factory=list)  # 's12', 'j3'
    landscape: bool = False


@dataclass
class Book:
    file_name: str
    title: str
    title_ar: str
    mode: str
    mushaf: Mushaf
    geometry: Geometry
    font_pt: float
    screens: list[Screen]
    surah_screens: dict[int, int]  # surah → index into screens
    juz_screens: dict[int, int]
    surah_pages: dict[int, int]  # surah → printed page
    juz_pages: dict[int, int]
    stats: dict
    tajweed: bool = False


# ---------------------------------------------------------------- data


class Content:
    def __init__(self, db_path=ASSET_DB):
        self.con = sqlite3.connect(db_path)
        self.con.row_factory = sqlite3.Row
        self.surahs = {r["number"]: dict(r) for r in self.con.execute("SELECT * FROM surahs")}

    def mushaf(self, mushaf_id: str) -> Mushaf:
        r = self.con.execute("SELECT * FROM mushafs WHERE id = ?", (mushaf_id,)).fetchone()
        font_files = {
            "KFGQPC Hafs": "KFGQPC-Hafs.ttf", "KFGQPC Warsh": "KFGQPC-Warsh.ttf",
            "KFGQPC Qaloun": "KFGQPC-Qaloun.ttf", "KFGQPC Douri": "KFGQPC-Douri.ttf",
            "KFGQPC Shuba": "KFGQPC-Shuba.ttf", "KFGQPC Sousi": "KFGQPC-Sousi.ttf",
            "AlQuran IndoPak": "AlQuranIndoPak.ttf",
        }
        return Mushaf(
            r["id"], r["name"], r["name_ar"], r["riwayah"], r["pages"], r["lines_per_page"],
            font_files[r["font_family"]], r["font_scale"], r["line_scale"], bool(r["header_basmala"]),
            r["basmala"], r["edition_note"], r["source"],
        )

    def lines(self, mushaf_id: str) -> list[sqlite3.Row]:
        return self.con.execute(
            "SELECT * FROM pages WHERE mushaf_id = ? ORDER BY page, line", (mushaf_id,)
        ).fetchall()

    def ayah_juz(self, mushaf_id: str) -> dict[tuple[int, int], int]:
        return {
            (r["surah"], r["ayah"]): r["juz"]
            for r in self.con.execute("SELECT surah, ayah, juz FROM ayahs WHERE mushaf_id = ?", (mushaf_id,))
        }

    def juz_starts(self, mushaf_id: str) -> dict[int, tuple[int, int, int]]:
        return {
            r["juz"]: (r["surah"], r["ayah"], r["page"])
            for r in self.con.execute("SELECT * FROM mushaf_juz WHERE mushaf_id = ?", (mushaf_id,))
        }

    def surah_pages(self, mushaf_id: str) -> dict[int, int]:
        return {
            r["surah"]: r["page"]
            for r in self.con.execute("SELECT surah, page FROM mushaf_surahs WHERE mushaf_id = ?", (mushaf_id,))
        }


def measure_for(mushaf: Mushaf) -> Measure:
    return Measure(ASSET_FONTS / mushaf.font_file)


def tight_width_percentile(lines, m: Measure, q: float) -> float:
    """q-th quantile of the justified lines' widths with spaces halved (em)."""
    widths = []
    for ln in lines:
        if ln["kind"] != "ayah" or ln["centered"] or not ln["text"]:
            continue
        units = line_words(ln["text"])
        widths.append(sum(m.width(u) for u in units) + m.space * 0.5 * (len(units) - 1))
    widths.sort()
    return widths[min(len(widths) - 1, int(len(widths) * q))]


def _finalize(screens: list[Screen], surah_screens: dict[int, int], juz_screens: dict[int, int],
              juz_of: dict[tuple[int, int], int]) -> None:
    """Header labels (surah, juz, printed pages) and link anchors per screen."""
    surah, juz, pages = 1, 1, (1, 1)
    for sc in screens:
        first = sc.rows[0] if sc.rows else None
        if first is not None:
            surah = first.surah if first.kind == "surah" else (first.key[0] if first.key else surah)
        keys = [r.key for r in sc.rows if r.key]
        if keys:
            juz = juz_of.get(keys[0], juz)
        spans = [r.pages for r in sc.rows if r.pages]
        if spans:
            pages = (spans[0][0], spans[-1][1])
        elif sc.part is None:
            pages = (pages[1], pages[1])
        sc.surah, sc.juz = surah, juz
        if sc.part is None or not spans:
            sc.pages = pages
    for s, idx in surah_screens.items():
        screens[idx].anchors.append(f"s{s}")
    for j, idx in juz_screens.items():
        screens[idx].anchors.append(f"j{j}")


def _word_keys(first: tuple[int, int], units: list[str]) -> list[tuple[int, int]]:
    surah, ayah = first
    keys = []
    for u in units:
        keys.append((surah, ayah))
        ayah += ayah_ends(u)
    return keys


def _units(text: str, token_colours: list | None) -> tuple[list[str], list | None]:
    """Justification units of a line and, from per-token colours, each unit's
    per-character colours (tokens glued to a word are joined by an
    uncoloured space)."""
    tokens = line_tokens(text)
    groups = token_groups(tokens)
    units = [" ".join(tokens[i] for i in g) for g in groups]
    if token_colours is None:
        return units, None
    colours = []
    for g in groups:
        c: list = []
        for n, i in enumerate(g):
            if n:
                c.append(None)
            c.extend(token_colours[i])
        colours.append(c)
    return units, colours


def _basmala(text: str, width_em: float, m: Measure, taj: Tajweed | None) -> Line:
    """A centred basmala line, coloured like 1:1 in a tajwid book."""
    units, colours = _units(text, taj.text_colours(text, (1, 1)) if taj else None)
    return justify(units, width_em, m, centered=True, colours=colours)


# ---------------------------------------------------------------- exact-line books


def exact_book(content: Content, mushaf_id: str, *, rotated: bool, lines_per_screen: int,
               width_quantile: float, pitch_em: float, file_name: str, title: str, title_ar: str,
               tajweed: bool = False) -> Book:
    """Printed lines, ``lines_per_screen`` per screen (all of a page when equal
    to the mushaf's lines per page). ``tajweed`` colours the letters by rule."""
    mushaf = content.mushaf(mushaf_id)
    m = measure_for(mushaf)
    taj = Tajweed(content, mushaf_id) if tajweed else None
    geo = LANDSCAPE if rotated else PORTRAIT
    rows = content.lines(mushaf_id)
    juz_of = content.ayah_juz(mushaf_id)
    juz_starts = content.juz_starts(mushaf_id)
    juz_first = {(s, a): j for j, (s, a, _) in juz_starts.items()}

    pitch = geo.block_height / lines_per_screen
    wide = tight_width_percentile(rows, m, width_quantile)
    font = min(geo.block_width / wide, pitch / pitch_em)
    width_em = geo.block_width / font

    by_page: dict[int, list[sqlite3.Row]] = {}
    for r in rows:
        by_page.setdefault(r["page"], []).append(r)

    screens: list[Screen] = []
    surah_screens: dict[int, int] = {}
    juz_screens: dict[int, int] = {}
    squeezed = elongated = justified = 0
    min_scale = 1.0
    for page in range(1, mushaf.pages + 1):
        lines = by_page[page]
        last_slot = max(r["line"] for r in lines)
        n_parts = math.ceil(last_slot / lines_per_screen) if last_slot > lines_per_screen else 1
        if page <= 2 and n_parts > 1:
            per = math.ceil(last_slot / n_parts)  # 8 lines → 4 + 4
        else:
            per = lines_per_screen
        first_ayah = next(((r["first_surah"], r["first_ayah"]) for r in lines if r["first_surah"]), (1, 1))
        page_juz = juz_of.get(first_ayah, 1)  # the printed page's juz, for every part
        for part in range(n_parts):
            slots = range(part * per + 1, min(last_slot, (part + 1) * per) + 1)
            chunk = [r for r in lines if r["line"] in slots]
            screen = Screen(juz=page_juz, pages=(page, page), landscape=rotated,
                            part=(part + 1, n_parts) if n_parts > 1 else None)
            # Few lines (opening pages): centre them vertically.
            top0 = (lines_per_screen - len(slots)) * pitch / 2 if len(slots) < lines_per_screen else 0.0
            for r in chunk:
                top = top0 + (r["line"] - slots[0]) * pitch
                if r["kind"] == "surah":
                    s = r["surah"]
                    surah_screens.setdefault(s, len(screens))
                    has_row = any(x["kind"] == "basmala" and x["surah"] == s for x in lines)
                    bas = None
                    if mushaf.header_basmala and s not in (1, 9) and not has_row:
                        bas = _basmala(mushaf.basmala, width_em / 0.8, m, taj)
                    screen.rows.append(Row("surah", top, pitch, font, surah=s, basmala=bas))
                elif r["kind"] == "basmala":
                    screen.rows.append(Row("basmala", top, pitch, font, line=_basmala(r["text"], width_em, m, taj)))
                else:
                    units, colours = _units(r["text"], taj.line_colours(page, r["line"]) if taj else None)
                    inset = 0.3 if units and trailing_overhang(units[-1]) else 0.0
                    ln = justify(units, width_em, m, centered=bool(r["centered"]), right_inset=inset, colours=colours)
                    if not r["centered"]:
                        justified += 1
                        elongated += ln.kashida > 0
                        if ln.scale < 0.999:
                            squeezed += 1
                            min_scale = min(min_scale, ln.scale)
                    screen.rows.append(Row("text", top, pitch, font, line=ln,
                                           key=(r["first_surah"], r["first_ayah"]), pages=(page, page)))
                    for key in _word_keys((r["first_surah"], r["first_ayah"]), units):
                        if key in juz_first and juz_first[key] not in juz_screens:
                            juz_screens[juz_first[key]] = len(screens)
            screens.append(screen)
    _finalize(screens, surah_screens, juz_screens, juz_of)
    for sc in screens:  # a printed page keeps the juz of its first ayah on every part
        sc.pages = (sc.pages[0], sc.pages[0])

    stats = {
        "font_pt": round(font / MM_PER_PT, 1), "width_em": round(width_em, 2), "pitch_em": round(pitch / font, 2),
        "justified_lines": justified, "kashida_lines": elongated, "squeezed_lines": squeezed,
        "min_scale": round(min_scale, 3),
    }
    if taj:
        stats["tajweed"] = taj.stats
    return Book(file_name, title, title_ar, "rotated" if rotated else "faithful", mushaf, geo, font / MM_PER_PT,
                screens, surah_screens, juz_screens, content.surah_pages(mushaf_id),
                {j: p for j, (_, _, p) in juz_starts.items()}, stats, tajweed=taj is not None)


# ---------------------------------------------------------------- reflow books


@dataclass
class _Unit:
    text: str
    key: tuple[int, int]
    page_marker: int | None = None
    colours: list | None = None  # per character, in a tajwid book


def page_marker(page: int) -> str:
    """Unit text of a printed-page marker (rendered as a small boxed number)."""
    return f"\x00P{page}"


class _ReflowMeasure(Measure):
    """Measures page markers as a small boxed number."""

    def __init__(self, base: Measure):
        self.__dict__.update(base.__dict__)
        self._base = base

    def width(self, text: str) -> float:
        if text.startswith("\x00P"):
            return 0.3 * len(text[2:]) + 0.35
        return self._base.width(text)


def reflow_book(content: Content, mushaf_id: str, *, font_pt: float, pitch_em: float, file_name: str,
                title: str, title_ar: str, tajweed: bool = False) -> Book:
    mushaf = content.mushaf(mushaf_id)
    m = _ReflowMeasure(measure_for(mushaf))
    taj = Tajweed(content, mushaf_id) if tajweed else None
    geo = PORTRAIT
    font = font_pt * MM_PER_PT
    width_em = geo.block_width / font
    slots = int(geo.block_height // (font * pitch_em))
    pitch = geo.block_height / slots
    juz_of = content.ayah_juz(mushaf_id)
    juz_starts = content.juz_starts(mushaf_id)
    juz_first = {(s, a): j for j, (s, a, _) in juz_starts.items()}

    # The text stream, surah by surah, with printed-page markers.
    surahs: list[tuple[int, str | None, list[_Unit]]] = []  # (surah, basmala, units)
    last_page = 0
    for r in content.lines(mushaf_id):
        if r["kind"] == "surah":
            surahs.append((r["surah"], None, []))
            continue
        if r["kind"] == "basmala":
            s, _, units = surahs[-1]
            surahs[-1] = (s, r["text"], units)
            continue
        units, colours = _units(r["text"], taj.line_colours(r["page"], r["line"]) if taj else None)
        keys = _word_keys((r["first_surah"], r["first_ayah"]), units)
        out = surahs[-1][2]
        for i, (u, k) in enumerate(zip(units, keys)):
            if r["page"] != last_page and i == 0:
                last_page = r["page"]
                out.append(_Unit(page_marker(r["page"]), k, r["page"]))
            out.append(_Unit(u, k, colours=colours[i] if colours else None))
    # Indopak prints put the basmala in the heading; reflow shows it as a line.
    if mushaf.header_basmala:
        surahs = [(s, b or (mushaf.basmala if s not in (1, 9) else None), u) for s, b, u in surahs]

    screens: list[Screen] = [Screen()]
    used = 0
    surah_screens: dict[int, int] = {}
    juz_screens: dict[int, int] = {}
    elongated = justified = squeezed = 0

    def place(row: Row) -> None:
        nonlocal used
        if used >= slots:
            screens.append(Screen())
            used = 0
        row.top = used * pitch
        screens[-1].rows.append(row)
        used += 1

    current_page = 1
    for s, basmala, units in surahs:
        # Header, basmala and the first line stay together.
        need = 2 + (1 if basmala else 0)
        if used and used + need > slots:
            screens.append(Screen())
            used = 0
        place(Row("surah", 0, pitch, font, surah=s))
        surah_screens[s] = len(screens) - 1
        if basmala:
            place(Row("basmala", 0, pitch, font, line=_basmala(basmala, width_em, m, taj)))
        # Greedy line breaking at natural spacing; kashida then fills each line.
        i = 0
        while i < len(units):
            j = i
            w = 0.0
            while j < len(units):
                add = m.width(units[j].text) + (m.space if j > i else 0.0)
                if w + add > width_em and j > i:
                    break
                w += add
                j += 1
            # Never end a line with a page marker: it belongs to the next word.
            if j - i > 1 and units[j - 1].page_marker is not None and j < len(units):
                j -= 1
            chunk = units[i:j]
            last = j >= len(units)
            texts = [u.text for u in chunk]
            natural = sum(m.width(t) for t in texts) + m.space * (len(texts) - 1)
            centered = last and natural < 0.7 * width_em
            inset = 0.3 if trailing_overhang(texts[-1]) else 0.0
            colours = [u.colours for u in chunk] if taj else None
            ln = justify(texts, width_em, m, centered=centered, right_inset=inset, colours=colours)
            if not centered:
                justified += 1
                elongated += ln.kashida > 0
                squeezed += ln.scale < 0.999
            start_page = current_page if chunk[0].page_marker is None else chunk[0].page_marker
            for u in chunk:
                if u.page_marker:
                    current_page = u.page_marker
            place(Row("text", 0, pitch, font, line=ln, key=chunk[0].key, pages=(start_page, current_page)))
            for u in chunk:
                if u.key in juz_first and juz_first[u.key] not in juz_screens:
                    juz_screens[juz_first[u.key]] = len(screens) - 1
            i = j
    _finalize(screens, surah_screens, juz_screens, juz_of)

    stats = {
        "font_pt": font_pt, "width_em": round(width_em, 2), "pitch_em": round(pitch / font, 2),
        "lines_per_screen": slots, "justified_lines": justified, "kashida_lines": elongated,
        "squeezed_lines": squeezed,
    }
    if taj:
        stats["tajweed"] = taj.stats
    return Book(file_name, title, title_ar, "reflow", mushaf, geo, font_pt, screens, surah_screens, juz_screens,
                content.surah_pages(mushaf_id), {j: p for j, (_, _, p) in juz_starts.items()}, stats,
                tajweed=taj is not None)

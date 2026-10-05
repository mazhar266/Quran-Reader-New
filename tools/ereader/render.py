"""Books → HTML (every word positioned) → PDF with Chromium → outline, rotation, metadata."""

from __future__ import annotations

import datetime
import html
import os
from pathlib import Path

from ..paths import ASSET_FONTS, BUILD
from .books import Book, Row, Screen
from .layout import Line
from .tajweed import COLOUR, LEGEND, RULE_BY_SLUG

OUT = BUILD.parent / "ereader"
LATIN_FONT = Path(__file__).parent / "fonts" / "DejaVuSans.ttf"


def chromium_path() -> str | None:
    """$CHROMIUM, a pre-installed Playwright Chromium, a system Chrome, or
    (None) Playwright's own Chromium."""
    if os.environ.get("CHROMIUM"):
        return os.environ["CHROMIUM"]
    found = sorted(Path("/opt/pw-browsers").glob("chromium-*/chrome-linux/chrome"))
    if found:
        return str(found[-1])
    for root in (os.environ.get("PROGRAMFILES"), os.environ.get("PROGRAMFILES(X86)"), os.environ.get("LOCALAPPDATA")):
        if root and (Path(root) / "Google/Chrome/Application/chrome.exe").is_file():
            return str(Path(root) / "Google/Chrome/Application/chrome.exe")
    for linux in ("/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser"):
        if Path(linux).is_file():
            return linux
    return None


FRAME_ADVANCE = 8240 / 1024  # quran-common U+E000, in em

ARABIC_DIGITS = str.maketrans("0123456789", "\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669")


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def name_glyph(surah: int) -> str:
    return chr(0xE102 if surah == 102 else 0xE000 + surah)


# ---------------------------------------------------------------- CSS


def css(book: Book) -> str:
    fonts = {
        "Mushaf": ASSET_FONTS / book.mushaf.font_file,
        "SurahName": ASSET_FONTS / "SurahNameV2.ttf",
        "QuranCommon": ASSET_FONTS / "QuranCommon.ttf",
        "Latin": LATIN_FONT,
    }
    faces = "\n".join(f"@font-face {{ font-family: '{k}'; src: url('{v.as_uri()}'); }}" for k, v in fonts.items())
    rules = "\n".join(f".line .t-{slug} {{ color: {colour}; }}" for slug, colour in COLOUR.items())
    return f"""
{faces}
@page {{ size: 90.8mm 122.6mm; margin: 0; }}
@page landscape {{ size: 122.6mm 90.8mm; margin: 0; }}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ background: #fff; color: #000; }}
.screen {{ position: relative; width: 90.8mm; height: 122.6mm; overflow: hidden;
          break-after: page; font-family: 'Latin'; }}
.screen.landscape {{ page: landscape; width: 122.6mm; height: 90.8mm; }}
.hdr, .ftr {{ position: absolute; left: 3mm; right: 3mm; height: 4.5mm; direction: rtl; display: flex;
             justify-content: space-between; align-items: center; color: #333; }}
.hdr {{ top: 3mm; border-bottom: 0.2mm solid #999; }}
.ftr {{ bottom: 3mm; justify-content: center; font-size: 2.7mm; direction: ltr; }}
.hdr .sura {{ font-family: 'SurahName'; font-size: 4.1mm; line-height: 4.5mm; }}
.hdr .juz {{ font-family: 'QuranCommon'; font-size: 4.1mm; line-height: 4.5mm; }}
.block {{ position: absolute; left: 3mm; right: 3mm; top: 7.5mm; bottom: 7.5mm; }}
.row {{ position: absolute; left: 0; right: 0; }}
.line {{ position: absolute; inset: 0; direction: rtl; font-family: 'Mushaf', 'Latin'; transform-origin: right center; }}
.line > span {{ position: absolute; top: 0; white-space: pre; }}
.line span.pg {{ font-family: 'Latin'; text-align: center; }}
.line span.pg b {{ display: inline-block; font-weight: normal; font-size: 0.34em; line-height: 1.35;
                  padding: 0 0.25em; border: 0.15mm solid #666; border-radius: 0.3mm; background: #eee;
                  color: #333; vertical-align: 1.3em; }}
{rules}
.frame, .fname {{ position: absolute; left: 0; right: 0; text-align: center; white-space: pre; }}
.frame {{ font-family: 'QuranCommon'; }}
.fname {{ font-family: 'SurahName'; }}
/* front matter */
.fm {{ position: absolute; left: 5mm; right: 5mm; top: 6mm; bottom: 6mm; font-size: 3.1mm; line-height: 1.45; }}
.fm h1 {{ font-size: 4.6mm; margin: 0 0 2mm; }}
.fm h2 {{ font-size: 3.6mm; margin: 3mm 0 1mm; }}
.fm p {{ margin: 0 0 1.6mm; }}
.fm .ar {{ font-family: 'Mushaf', 'Latin'; direction: rtl; }}
.fm a {{ color: #000; text-decoration: none; }}
.title {{ text-align: center; }}
.title .emblem {{ font-family: 'QuranCommon'; font-size: 30mm; line-height: 1.25; margin-top: 2mm; }}
.title .ar {{ font-size: 6.2mm; line-height: 1.6; }}
.idx {{ width: 100%; border-collapse: collapse; }}
.idx td {{ height: 7.6mm; border-bottom: 0.15mm solid #bbb; vertical-align: middle; }}
.idx .n {{ width: 7mm; }}
.idx .ar {{ font-size: 4.6mm; text-align: right; }}
.idx .num {{ text-align: right; width: 12mm; font-size: 2.9mm; color: #333; }}
.legend {{ width: 100%; border-collapse: collapse; margin-top: 1mm; }}
.legend td {{ height: 5.6mm; border-bottom: 0.15mm solid #ccc; vertical-align: middle; font-size: 2.7mm; line-height: 1.2; }}
.legend td.ar {{ font-family: 'Mushaf', 'Latin'; font-size: 3.8mm; direction: rtl; text-align: right; width: 36mm; }}
.legend small {{ color: #333; font-size: 2.3mm; }}
"""


# ---------------------------------------------------------------- screens


def _line_html(line: Line, font_mm: float, height_mm: float) -> str:
    style = f"font-size:{font_mm:.3f}mm;line-height:{height_mm:.3f}mm"
    if line.scale < 0.999:
        style += f";transform:scaleX({line.scale:.4f})"
    spans = []
    for i, (word, width, off) in enumerate(zip(line.words, line.widths, line.offsets)):
        if word.startswith("\x00P"):
            spans.append(f'<span class="pg" style="right:{off:.4f}em;width:{width:.4f}em"><b>{word[2:]}</b></span>')
        else:
            colours = line.colours[i] if line.colours else None
            spans.append(f'<span style="right:{off:.4f}em">{_runs_html(word, colours)}</span>')
    return f'<div class="line" style="{style}">{"".join(spans)}</div>'


def _runs_html(word: str, colours: list | None) -> str:
    """The word's characters, consecutive characters under one tajwid rule
    wrapped in a coloured ``<c>``. Chromium shapes across these inline
    boundaries, so joins and mark positions are those of the plain word."""
    if not colours:
        return esc(word)
    assert len(colours) == len(word), (word, colours)
    out = []
    i = 0
    while i < len(word):
        j = i
        while j < len(word) and colours[j] == colours[i]:
            j += 1
        text = esc(word[i:j])
        out.append(f'<c class="t-{colours[i]}">{text}</c>' if colours[i] else text)
        i = j
    return "".join(out)


def _row_html(row: Row, block_width: float) -> str:
    inner = ""
    if row.kind in ("text", "basmala"):
        inner = _line_html(row.line, row.font_size, row.height)
    elif row.kind == "surah":
        frame_h = row.height * (0.58 if row.basmala else 1.0)
        size = min(block_width * 0.98 / FRAME_ADVANCE, frame_h * 0.92)
        inner = (
            f'<div class="frame" style="top:0;height:{frame_h:.3f}mm;font-size:{size:.3f}mm;line-height:{frame_h:.3f}mm">\ue000</div>'
            f'<div class="fname" style="top:0;height:{frame_h:.3f}mm;font-size:{size * 0.82:.3f}mm;line-height:{frame_h:.3f}mm">{name_glyph(row.surah)}</div>'
        )
        if row.basmala:
            rest = row.height - frame_h
            inner += (f'<div class="row" style="top:{frame_h:.3f}mm;height:{rest:.3f}mm">'
                      f'{_line_html(row.basmala, row.font_size * 0.8, rest)}</div>')
    return f'<div class="row" style="top:{row.top:.3f}mm;height:{row.height:.3f}mm">{inner}</div>'


def _page_label(screen: Screen) -> str:
    a, b = screen.pages
    label = str(a) if a == b else f"{a}–{b}"
    if screen.part:
        label += f"  ({screen.part[0]}/{screen.part[1]})"
    return label


def screen_html(book: Book, screen: Screen) -> str:
    geo = book.geometry
    ids = "".join(f'<a id="{a}"></a>' for a in screen.anchors)
    rows = "".join(_row_html(r, geo.block_width) for r in screen.rows)
    cls = "screen landscape" if screen.landscape else "screen"
    return (
        f'<section class="{cls}">{ids}'
        f'<div class="hdr"><span class="sura">{name_glyph(screen.surah)}</span>'
        f'<span class="juz">{chr(0xE000 + screen.juz)}</span></div>'
        f'<div class="block">{rows}</div>'
        f'<div class="ftr">{_page_label(screen)}</div></section>'
    )


# ---------------------------------------------------------------- front matter

ROWS_PER_INDEX_SCREEN = 12

MODE_NOTES = {
    "reflow": (
        "The text flows in lines filled the way printed mushafs fill them, by elongating letter joins "
        "(kashida). A small boxed number marks where each page of the printed mushaf begins; the footer "
        "shows the printed pages on the screen."
    ),
    "rotated": (
        "Each screen shows five lines of the printed mushaf, exactly as printed, laid along the long side "
        "of the screen. Hold the reader sideways. The footer shows the printed page and which third of it "
        "is on the screen."
    ),
    "faithful": "Each screen shows one page of the printed mushaf with its exact lines.",
}

TAJWEED_NOTE = (
    "Letters where a rule of recitation applies are coloured, in the colour scheme of the Complex's tajwid "
    "mushaf as used by quran.com and the Quranic Universal Library; the legend on the next screen lists the "
    "rules. The annotation describes the Hafs recitation. Pause signs, ayah marks and ornaments stay black. "
    "On a greyscale e-ink screen the colours show as shades of grey; a colour e-ink screen shows them as intended."
)


def legend_screen() -> str:
    rows = []
    for slugs, label, counts in LEGEND:
        arabic = " · ".join(RULE_BY_SLUG[s].arabic for s in slugs)
        detail = f"<br><small>{esc(counts)}</small>" if counts else ""
        rows.append(f'<tr><td>{esc(label)}{detail}</td><td class="ar" style="color:{COLOUR[slugs[0]]}">{esc(arabic)}</td></tr>')
    return (
        '<section class="screen"><div class="fm"><h1>Tajwid colours</h1>'
        '<p>Each colour marks the letters where one rule applies; counts are the harakat the letter is held.</p>'
        f'<table class="legend">{"".join(rows)}</table></div></section>'
    )


def front_matter(book: Book, first_content: int) -> list[str]:
    """Title, about, surah index, juz index. ``first_content`` is the PDF page
    number (1-based) of the first content screen."""
    m = book.mushaf
    today = datetime.date.today().isoformat()
    screens = []
    screens.append(
        '<section class="screen"><div class="fm title">'
        '<div class="emblem">\ue076</div>'
        f'<p class="ar">{esc(m.name_ar)}</p>'
        f'<h1>{esc(book.title)}</h1>'
        f'<p>{esc(m.edition_note)}</p>'
        f'<p>{book.font_pt:.1f} pt · {len(book.screens)} screens · 6-inch e-readers</p>'
        '</div></section>'
    )
    tajweed_note = f"<p>{esc(TAJWEED_NOTE)}</p>" if book.tajweed else ""
    tajweed_source = (
        " Tajwid annotation: QPC Hafs tajweed by the King Fahd Glorious Quran Printing Complex, through the "
        "Quranic Universal Library." if book.tajweed else ""
    )
    screens.append(
        '<section class="screen"><div class="fm">'
        '<h1>About this book</h1>'
        f'<p>{esc(MODE_NOTES[book.mode])}</p>'
        f'{tajweed_note}'
        '<p>Use the reader\'s table of contents (Go to / Contents) to jump to a surah or juz, or the indexes '
        'on the next screens: “p.” is the page of the printed mushaf, “#” the screen in this book. '
        'On Kindle choose “Fit page”; on KOReader set zoom to “page” and turn cropping off.</p>'
        '<h2>Sources</h2>'
        f'<p>{esc(m.source)}.{tajweed_source}</p>'
        '<p>The Quran text is reproduced unaltered, free of charge and with attribution. Line filling '
        '(kashida) is typographic only. Fonts: KFGQPC Uthmanic Script; surah-name and ornament fonts '
        'from the Quranic Universal Library; AlQuran IndoPak by QuranWBW.</p>'
        f'<p>Generated {today} with the Quran Reader book tools.</p>'
        '</div></section>'
    )
    if book.tajweed:
        screens.append(legend_screen())

    def index(title: str, rows: list[str]) -> None:
        for k in range(0, len(rows), ROWS_PER_INDEX_SCREEN):
            chunk = "".join(rows[k : k + ROWS_PER_INDEX_SCREEN])
            head = f"<h1>{title}</h1>" if k == 0 else ""
            screens.append(f'<section class="screen"><div class="fm">{head}<table class="idx">{chunk}</table></div></section>')

    from .books import Content  # local import: names only

    names = Content().surahs
    surah_rows = []
    for s in range(1, 115):
        target = first_content + book.surah_screens[s]
        surah_rows.append(
            f'<tr><td class="n"><a href="#s{s}">{s}</a></td>'
            f'<td><a href="#s{s}">{esc(names[s]["name_en"])}</a></td>'
            f'<td class="ar"><a href="#s{s}">{esc(names[s]["name_ar"])}</a></td>'
            f'<td class="num">p. {book.surah_pages[s]}<br>#{target}</td></tr>'
        )
    index("Surahs", surah_rows)
    juz_rows = []
    for j in range(1, 31):
        target = first_content + book.juz_screens[j]
        juz_rows.append(
            f'<tr><td class="n"><a href="#j{j}">{j}</a></td>'
            f'<td><a href="#j{j}">Juz {j}</a></td>'
            f'<td class="ar" style="font-family:QuranCommon;font-size:5.4mm"><a href="#j{j}">{chr(0xE000 + j)}</a></td>'
            f'<td class="num">p. {book.juz_pages[j]}<br>#{target}</td></tr>'
        )
    index("Juz", juz_rows)
    return screens


def front_matter_count(book: Book) -> int:
    """Title, about, (tajwid legend), surah index and juz index screens."""
    per = ROWS_PER_INDEX_SCREEN
    return 2 + (1 if book.tajweed else 0) + -(-114 // per) + -(-30 // per)


def book_html(book: Book, limit: int | None = None) -> str:
    first = front_matter_count(book) + 1
    parts = front_matter(book, first)
    assert len(parts) == first - 1
    parts += [screen_html(book, s) for s in book.screens[:limit]]
    return (
        f'<!doctype html><html lang="ar"><head><meta charset="utf-8"><title>{esc(book.title)}</title>'
        f"<style>{css(book)}</style></head><body>{''.join(parts)}</body></html>"
    )


# ---------------------------------------------------------------- PDF


def print_pdf(html_path: Path, pdf_path: Path) -> None:
    from playwright.sync_api import sync_playwright

    with sync_playwright() as pw:
        browser = pw.chromium.launch(executable_path=chromium_path(), args=["--allow-file-access-from-files"])
        page = browser.new_page()
        page.goto(html_path.as_uri(), wait_until="load", timeout=600_000)
        page.evaluate("document.fonts.ready")
        page.pdf(path=str(pdf_path), prefer_css_page_size=True, print_background=True)
        browser.close()


def postprocess(book: Book, raw: Path, out: Path) -> None:
    """Rotates landscape screens, adds the outline and metadata."""
    from pypdf import PdfReader, PdfWriter
    from pypdf.generic import NameObject, TextStringObject

    from .books import Content

    reader = PdfReader(raw)
    writer = PdfWriter(clone_from=reader)
    writer.pdf_header = reader.pdf_header  # keep Chromium's version (pypdf defaults to 1.3)
    first = front_matter_count(book)
    for i, sc in enumerate(book.screens):
        if sc.landscape:
            writer.pages[first + i].rotate(90)
    names = Content().surahs
    if book.tajweed:
        writer.add_outline_item("Tajwid colours · \u0623\u0644\u0648\u0627\u0646 \u0627\u0644\u062a\u062c\u0648\u064a\u062f", 2)
    writer.add_outline_item("Surah index · \u0641\u0647\u0631\u0633 \u0627\u0644\u0633\u0648\u0631", 3 if book.tajweed else 2)
    surahs = writer.add_outline_item("Surahs · \u0627\u0644\u0633\u0648\u0631", first + book.surah_screens[1])
    for s in range(1, 115):
        writer.add_outline_item(f"{s} {names[s]['name_ar']} · {names[s]['name_en']}", first + book.surah_screens[s],
                                parent=surahs)
    juzs = writer.add_outline_item("Juz · \u0627\u0644\u0623\u062c\u0632\u0627\u0621", first + book.juz_screens[1])
    for j in range(1, 31):
        writer.add_outline_item(f"Juz {j} · \u0627\u0644\u062c\u0632\u0621 {str(j).translate(ARABIC_DIGITS)}", first + book.juz_screens[j],
                                parent=juzs)
    writer.add_metadata({
        "/Title": book.title,
        "/Author": "King Fahd Glorious Quran Printing Complex; Quranic Universal Library",
        "/Subject": f"{book.mushaf.id} · {book.mode} · 6in · {book.font_pt:.1f} pt" + (" · tajwid colours" if book.tajweed else ""),
        "/Creator": "Quran Reader book tools (tools/ereader)",
    })
    writer._root_object[NameObject("/Lang")] = TextStringObject("ar")
    writer.page_mode = "/UseOutlines"
    with open(out, "wb") as f:
        writer.write(f)


def build_pdf(book: Book, limit: int | None = None) -> Path:
    """The finished PDF; with ``limit``, only the first screens and unfinished
    (no outline, no rotation), for a quick look."""
    OUT.mkdir(parents=True, exist_ok=True)
    html_path = OUT / (Path(book.file_name).stem + ".html")
    raw = OUT / (Path(book.file_name).stem + ".raw.pdf")
    out = OUT / book.file_name
    html_path.write_text(book_html(book, limit), encoding="utf-8")
    if limit is not None:
        print_pdf(html_path, out)
        return out
    print_pdf(html_path, raw)
    postprocess(book, raw, out)
    raw.unlink()
    return out

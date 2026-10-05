"""Builds the e-reader PDF books into build/ereader/.

    python3 -m tools.ereader.build                 # every book
    python3 -m tools.ereader.build hafs-reflow     # books whose key starts with this
    python3 -m tools.ereader.build --list
    python3 -m tools.ereader.build gaba-tajweed --limit 40   # a quick look at the first screens

Sizes follow docs/ereader-pdf/01 §5, with readability first: the smallest
text in any book is 16 pt (docs tier "comfortable"); nothing is generated at
the 10–11 pt "pocket mushaf" sizes. The ``-tajweed`` keys are the same books
with tajwid colours (Hafs only: the annotation describes the Hafs recitation).
"""

from __future__ import annotations

import argparse
import json
import sys
import time

from . import checks
from .books import Book, Content, exact_book, reflow_book
from .render import OUT, build_pdf

RIWAYAT = {
    "hafs": ("madinah_hafs", "Hafs", "حفص"),
    "warsh": ("madinah_warsh", "Warsh", "ورش"),
    "qaloun": ("madinah_qaloun", "Qaloun", "قالون"),
    "douri": ("madinah_douri", "Douri", "الدوري"),
    "shuba": ("madinah_shuba", "Shu'bah", "شعبة"),
    "sousi": ("madinah_sousi", "Sousi", "السوسي"),
}


def catalogue() -> dict[str, callable]:
    books = {}
    for key, (mid, name, _) in RIWAYAT.items():
        books[f"{key}-reflow"] = lambda c, mid=mid, key=key, name=name: reflow_book(
            c, mid, font_pt=16, pitch_em=1.9, file_name=f"quran-{key}-madinah-reflow-16pt-6in.pdf",
            title=f"The Quran · Madinah Mushaf · {name} · flowing text 16 pt", title_ar="")
        books[f"{key}-rotated"] = lambda c, mid=mid, key=key, name=name: exact_book(
            c, mid, rotated=True, lines_per_screen=5, width_quantile=0.99, pitch_em=1.9,
            file_name=f"quran-{key}-madinah-rotated-6in.pdf",
            title=f"The Quran · Madinah Mushaf · {name} · printed lines, sideways", title_ar="")
    books["hafs-reflow-large"] = lambda c: reflow_book(
        c, "madinah_hafs", font_pt=20, pitch_em=1.9, file_name="quran-hafs-madinah-reflow-20pt-6in.pdf",
        title="The Quran · Madinah Mushaf · Hafs · large print 20 pt", title_ar="")
    books["gaba"] = lambda c: exact_book(
        c, "indopak_9_gaba", rotated=False, lines_per_screen=9, width_quantile=0.999, pitch_em=1.9,
        file_name="quran-indopak-gaba-9-lines-6in.pdf",
        title="The Quran · Indopak script · 9-line Gaba print", title_ar="")
    # Tajwid editions of the Hafs books (Madinah and the Indopak Gaba print).
    books["hafs-reflow-tajweed"] = lambda c: reflow_book(
        c, "madinah_hafs", font_pt=16, pitch_em=1.9, tajweed=True,
        file_name="quran-hafs-madinah-reflow-16pt-tajweed-6in.pdf",
        title="The Quran · Madinah Mushaf · Hafs · flowing text 16 pt · tajwid colours", title_ar="")
    books["hafs-reflow-large-tajweed"] = lambda c: reflow_book(
        c, "madinah_hafs", font_pt=20, pitch_em=1.9, tajweed=True,
        file_name="quran-hafs-madinah-reflow-20pt-tajweed-6in.pdf",
        title="The Quran · Madinah Mushaf · Hafs · large print 20 pt · tajwid colours", title_ar="")
    books["hafs-rotated-tajweed"] = lambda c: exact_book(
        c, "madinah_hafs", rotated=True, lines_per_screen=5, width_quantile=0.99, pitch_em=1.9, tajweed=True,
        file_name="quran-hafs-madinah-rotated-tajweed-6in.pdf",
        title="The Quran · Madinah Mushaf · Hafs · printed lines, sideways · tajwid colours", title_ar="")
    books["gaba-tajweed"] = lambda c: exact_book(
        c, "indopak_9_gaba", rotated=False, lines_per_screen=9, width_quantile=0.999, pitch_em=1.9, tajweed=True,
        file_name="quran-indopak-gaba-9-lines-tajweed-6in.pdf",
        title="The Quran · Indopak script · 9-line Gaba print · tajwid colours", title_ar="")
    return books


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("keys", nargs="*", help="book keys or prefixes (default: all)")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--no-pdf", action="store_true", help="compose and report only")
    ap.add_argument("--limit", type=int, help="print only the first N screens, unfinished, for a quick look")
    args = ap.parse_args()
    books = catalogue()
    if args.list:
        print("\n".join(books))
        return
    keys = [k for k in books if not args.keys or any(k.startswith(p) for p in args.keys)]
    if not keys:
        sys.exit(f"no book matches {args.keys}")
    content = Content()
    report = {}
    for key in keys:
        t = time.time()
        book: Book = books[key](content)
        line = f"{key}: {len(book.screens)} screens, {json.dumps(book.stats)}"
        if args.limit:
            pdf = build_pdf(book, args.limit)
            checks.previews(book, pdf)
            line += f"\n    {pdf.name}: first {args.limit} screens, previews in {checks.preview_dir(book)}"
        elif not args.no_pdf:
            pdf = build_pdf(book)
            result = checks.check_pdf(book, pdf)
            checks.previews(book, pdf)
            line += f"\n    {pdf.name}: {result}"
            report[key] = {"file": pdf.name, **book.stats, **result}
        print(f"{line}  ({time.time() - t:.0f} s)", flush=True)
    if report:
        (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()

# E-reader PDF books · planning docs

Second document series. Goal: produce PDF mushafs that read well on **6-inch e-ink readers** (Kindle, Kobo, PocketBook, Tolino, KOReader) from the same KFGQPC and QUL data described in [../01-resource-inventory.md](../01-resource-inventory.md).

| document | what it answers |
|---|---|
| [01-targets-and-page-geometry.md](01-targets-and-page-geometry.md) | Device profiles, page size, margins, e-ink constraints, the three reading modes, and the measured typography numbers |
| [02-book-specifications.md](02-book-specifications.md) | The catalogue of books to generate, page anatomy, front matter, outline, naming, sizes, licensing |
| [03-generation-pipeline.md](03-generation-pipeline.md) | Toolchain (HTML/CSS + headless Chrome), scripts, algorithms per mode, post-processing, checks |
| [04-qa-and-devices.md](04-qa-and-devices.md) | QA checklist, device testing matrix, transfer methods, known reader quirks |
| [images/](images/) | 300 ppi renders of the prototype pages produced while writing this series |

## Findings in one screen

1. **Everything needed is local.** Google Chrome (headless PDF printing with font embedding and outline generation), Pillow with Raqm (HarfBuzz shaping for measurements), poppler (`pdfinfo`, `pdffonts`, `pdftoppm`), `pypdf` and PyMuPDF are installed. No new dependencies are required.
2. **Exact-line books are limited by the widest line, not by height.** Re-measured: the safe line pitch is only 1.8 em (Hafs), 2.05 em (QCF) and 1.85 em (Gaba), so height is rarely the constraint. One screen per printed page reaches 11.3 pt (pocket-mushaf size) with a ≤ 7 % shrink on fewer than 1 % of lines; a half page per screen only reaches 12.7 pt for Hafs and leaves the lower half empty. Portrait exact-line text therefore stays at 11–13 pt (Hafs) or 15 pt (QCF) whatever the line count.
3. **Rotated screens use the long side.** Five printed lines per screen laid along the 122.6 mm side (PDF `/Rotate 90`, three screens per printed page) give 17.4 pt for Hafs and 20.5 pt for QCF V2 with the exact printed lines. Prototypes: `images/hafs-rotated-5-lines-17pt-page-3a.png`, `images/qcf-v2-rotated-5-lines-20pt-page-50a.png`.
4. **Reflow remains the readable portrait option.** Wrapping the KFGQPC text at 16 pt gives about 1,000 screens per mushaf; 20 pt about 1,480. Prototype: `images/hafs-reflow-16pt-screen-4.png`. QCF V2 in portrait: half page per screen at 15 pt (`images/qcf-v2-split-flex-15pt-page-3a.png`).
5. **The Indopak 9-line Gaba print is a natural fit.** Its widest line is 13.2 em, so a faithful page renders at about 18 pt on a 6-inch screen with `qul/font.ttf`. Prototype: `images/gaba-faithful-9-lines-page-1000.png`.
6. **Justification is the main quality issue.** Fonts that are not page-specific cannot stretch calligraphically, so forcing the printed line breaks leaves inter-word gaps (median stretch 1.27× for Hafs, larger for Gaba). The Complex's own A4 PDFs have the same look. The spec caps justification and falls back to right-aligned lines.
7. **Tajweed colours are pointless on grayscale e-ink.** QCF V4 is only worth generating for colour e-ink devices, later.
8. **Two generator pitfalls are documented** (01 §5.4): the QCF V2 page fonts have no space glyph, so lines must be laid out as flex boxes of word spans, and glyph ink overhangs the advance width at line ends, so lines must be fitted by ink extent.

## Suggested order of work

Reuse the app content database from [../03-data-pipeline.md](../03-data-pipeline.md) as the single source of lines. Then: Hafs reflow 16 pt → Hafs rotated 17 pt → QCF V2 split 15 pt and rotated 20 pt → Gaba faithful → the five other riwayat (reflow + rotated) → faithful reference books → device testing round → publish.

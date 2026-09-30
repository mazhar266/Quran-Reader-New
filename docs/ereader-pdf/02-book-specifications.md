# 02 · Book specifications

## 1. Catalogue (first release)

| file | mushaf | mode | screens (approx.) | font size | size estimate |
|---|---|---|---|---|---|
| `quran-hafs-madinah-reflow-6in.pdf` | Madinah Hafs, KFGQPC Hafs v2.2 | R | ~1,000 | 16 pt | 6–8 MB (prototype: 1.9 MB for 301 screens) |
| `quran-hafs-madinah-reflow-large-6in.pdf` | Madinah Hafs | R | ~1,480 | 20 pt | 8–10 MB |
| `quran-hafs-madinah-rotated-6in.pdf` | Madinah Hafs, exact printed lines | L | 1,808 | 17.4 pt | 6–9 MB |
| `quran-hafs-madinah-pages-6in.pdf` | Madinah Hafs, one printed page per screen | F | 604 (+ front matter) | 11.3 pt | 3–5 MB |
| `quran-hafs-qcf-v2-split-6in.pdf` | Madinah 1421H, QCF V2 per-page fonts | S | 1,206 | 15 pt | 60–140 MB (604 embedded page fonts; measure after hint stripping) |
| `quran-hafs-qcf-v2-rotated-6in.pdf` | Madinah 1421H, QCF V2 | L | 1,808 | 20.5 pt | as above |
| `quran-warsh-madinah-reflow-6in.pdf` (+ `-rotated-`, `-pages-`) | Warsh v2.1 | R, L, F | as Hafs | 16 / 17 / 11.3 pt | |
| `quran-qaloun-…`, `quran-douri-…`, `quran-shuba-…`, `quran-sousi-…` | the other riwayat | R, L, F | as Hafs | | |
| `quran-indopak-gaba-9-lines-6in.pdf` | Indopak 9-line Gaba, AlQuran IndoPak font | F | 1,890 | 17.6 pt | 4–6 MB |

Sizes follow [01 §5.3](01-targets-and-page-geometry.md); the portrait half-page (S) books are generated only for QCF V2, because for the Unicode riwayat fonts they gain little over F and leave half the screen empty.

Later: 7-inch variants (`-7in`), QCF V4 tajweed for colour e-ink, a Hafs split book for readers who want both line fidelity and larger text.

## 2. Screen anatomy

- **Header** (4.5 mm): right = `الجزء N`, centre = surah name in Arabic (from `sura_name_ar`), left = printed page label (`50`, `50 (1/2)`, or in reflow the printed page that starts or continues on this screen). Font: the mushaf font at 2.6–2.8 mm; digits in Arabic-Indic or Western numerals (setting per book, default Western so page numbers match the app and the printed mushaf numbering).
- **Text block** (84.8 × 107.6 mm portrait, 116.6 × 75.8 mm rotated): lines as described per mode below.
- **Footer** (4.5 mm): the PDF screen number in the centre. In F mode it equals the printed page number.
- **Surah header line**: the printed `سُورَةُ …` text of the docx (modes F/S for KFGQPC riwayat) or the `surah-name-v2` glyph (QCF) inside a thin double border. In reflow it becomes a real `<h1>` so it feeds the PDF outline, kept together with the basmala (`break-inside: avoid`).
- **Basmala line**: centred; KFGQPC riwayat use their own font text; QCF uses the `quran-common` glyph U+FDFD; Gaba basmalas are ordinary text lines.
- **Rub'/hizb ornament ۞** stays inline as in the data; **sajdah** sign likewise.

## 3. Mode rules

### F · faithful
- One printed page per screen; `N` lines of equal height (15 or 9); line `k` of the DB is line `k` of the screen, including surah header and basmala rows, so the page geometry matches the print.
- Font size = min(height limit, width limit) computed once per book (01 §5.3), not per page, so the size never jumps between pages. Lines wider than the block get a per-line shrink (at most 16 %, on at most the widest 5 % of lines; for Hafs F this touches fewer than 1 % of lines).
- Justification: see §4.

### S · split
- Screen A = lines 1–8, screen B = lines 9–15 of the printed page (8 + 7). Pages 1 and 2 (8 lines) get one screen. Screen label `page (1/2)` / `page (2/2)`.
- Generated for QCF V2 only: font size ≈ 5.3 mm (15 pt) from a 15.75 em typical line plus ink overhang; the few wider lines beside surah headers shrink ≤ 13 %.

### L · rotated
- The HTML page is landscape (122.6 × 90.8 mm) with the same 3 mm margins and 4.5 mm header/footer, text block 116.6 × 75.8 mm; after printing, every PDF page gets `/Rotate 90` (with `pypdf`, `page.rotate(90)`), so readers display a portrait page whose lines run along the long side. The user turns the device a quarter turn; page turns stay the same gesture.
- Screens A, B, C = lines 1–5, 6–10, 11–15 of the printed page (pages 1–2: 4 + 4). Label `page (1/3)` … `(3/3)`. Line pitch 15.16 mm.
- Font size per book: Hafs 6.15 mm (17.4 pt, 95th-percentile width, ≤ 16 % shrink on ≤ 5 % of lines); other riwayat about 6.0 mm; QCF V2 7.3 mm (20.5 pt).
- Header and footer stay along the short side of the landscape page, so they read correctly with the text.

### R · reflow
- The text of the whole mushaf as one flow: `<h1>` per surah, `<p class="basmala">`, then ayah text with the ayah mark and a no-break space kept together.
- 16 pt, line height 1.85, `text-align: justify` (browser justification of wrapped lines is moderate and reads well; see `images/hafs-reflow-16pt-screen-4.png`).
- **Printed page markers**: a small superscript number in a rounded box inserted before the first word of each printed page, generated from `ayahs.page` (page changes mid-ayah on 4–5 ayahs in Warsh/Douri/Sousi/Qaloun; place the marker at the ayah start and accept the small imprecision, or use the docx line data to place it at the exact word).
- Header shows the printed page(s) visible on the screen; computed after rendering by reading back marker positions with PyMuPDF (`page.get_text("dict")` finds the marker glyph boxes), then the header text is injected in a second pass, or simpler: header shows the surah and juz only, and the markers carry the page information. **Decision: simpler variant first.**
- Screen breaks never split a surah header from its basmala or from its first line.

## 4. Justification policy

Fonts that are not page-specific cannot stretch calligraphically; forced justification of a printed line leaves inter-word gaps (01 §5). Rules:

1. QCF V2: always justify after fitting the line's font size to the block width. Gaps are negligible because the glyphs are already sized for the line. Layout is a flex line of word spans (`justify-content: space-between`), never space characters: the V2 page fonts have no space glyph and a fallback space breaks the line width (01 §5.4).
2. KFGQPC riwayat, F and S modes: justify a line only if its natural width ≥ `justify_min` (default 0.78 × block width, i.e. stretch ≤ 1.28); otherwise right-align it (ragged left edge). Lines flagged `centered` in the source are centred.
3. Gaba, F mode: same rule with `justify_min` 0.8. Most lines end up right-aligned, which reads better than the 1.5× gaps of forced justification (`images/gaba-faithful-9-lines-page-1000.png` shows the forced variant for comparison).
4. Reflow: browser justification, last line of each paragraph left ragged (default behaviour).
5. Kashida (tatweel insertion) is **not** used: it alters the Quranic text stream and the fonts' kashida glyphs are not designed for automatic insertion. Revisit only with a font that ships proper justification alternates.

> **Superseded (05 §2).** The generated books fill lines with kashida exactly as the app does, with
> measured tatweel widths and no insertion inside lam-alef or the name of Allah. On the device this
> reads like the printed mushaf instead of leaving gaps or ragged lines; the cost is that the PDF text
> layer contains the inserted tatweels.

## 5. Front matter and navigation

- Title screen: mushaf name (Arabic and English), riwayah, edition/source line (e.g. "King Fahd Glorious Quran Printing Complex, Hafs Uthmanic Script v2.2, current Madinah edition"), generation date and tool version.
- Sources and licence screen: the attributions required by KFGQPC and QUL, and a note that the text was not altered.
- Surah index: 114 rows, Arabic name, ayah count, printed page and PDF screen; each row an internal link (works on Kobo, PocketBook, KOReader; Kindle ignores links but the outline still works).
- Juz index: 30 rows with printed page and screen.
- **PDF outline**: two levels, juz → surah (or surah → juz), generated by Chrome from headings (`--generate-pdf-document-outline`, verified working) and, for F/S books whose headers are not headings, added afterwards with `pypdf` from the DB.
- PDF metadata: Title, Author (source complex), Language `ar`, Subject with mushaf id and mode.

## 6. Naming and versioning

`quran-<riwayah>-<edition>-<mode>-<profile>.pdf`, e.g. `quran-hafs-madinah-reflow-6in.pdf`. Embed the data build id (from the content DB `meta` table) in the PDF Subject so a book can be traced to the exact data version.

## 7. Licensing

Same conditions as the app (inventory §7): KFGQPC fonts and texts are for non-commercial use with attribution and unaltered text; the generated PDFs embed subsetted fonts, which the Complex's own PDFs also do. Distribute free of charge with the sources screen included in every file.

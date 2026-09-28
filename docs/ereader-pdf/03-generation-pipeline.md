# 03 · Generation pipeline

## 1. Toolchain (all present on this machine)

| step | tool | why |
|---|---|---|
| line data | the app content DB `quran_reader.db` built by [../03-data-pipeline.md](../03-data-pipeline.md) (`pages`, `ayahs`, `surahs`, `juz`) | one source of truth for both the app and the books |
| measurement | Pillow ≥ 10 with Raqm (`ImageFont.truetype(..., layout_engine=ImageFont.Layout.RAQM)`, `font.getlength(...)` for advances and `font.getbbox(..., anchor='ls')` for ink extents, both with `direction='rtl', language='ar'`) | HarfBuzz shaping, the same engine family Chrome uses; used to pick font sizes, per-line scale and ink overhang |
| layout + PDF | Google Chrome headless: `google-chrome --headless=new --disable-gpu --no-pdf-header-footer --generate-pdf-document-outline --print-to-pdf=out.pdf file.html` (add `--allow-file-access-from-files` for `file://` fonts) | correct Arabic shaping, `@page` sizes, flex layout for justified lines, `@font-face` per page font, subset font embedding, outline from headings |
| post-processing | `pypdf` (outline, metadata, merging front matter), PyMuPDF (`fitz`) (text positions, thumbnails, page cropping) | |
| verification | poppler `pdfinfo`, `pdffonts`, `pdftoppm -r 300` | counts, embedded fonts, visual checks |

Alternatives considered: Pango/Cairo from Python (PyGObject is installed; fine for a pure-Python path but needs manual justification code), WeasyPrint (not installed; needs a venv), LaTeX/Typst (not installed), the `pdf` Dart package (weak Arabic shaping). Chrome wins on shaping fidelity and effort.

**Quick baseline without any pipeline**: the Complex ships `uthmanic_<riwayah>_v2-x.pdf` (604 A4 pages, text block 194 × 270 mm, Word-justified). Cropping each page to its text block with PyMuPDF and setting the media box to 90.8 × 122.6 mm gives a 10 pt faithful book in minutes. Useful for first device tests; not a substitute for the generated books (Times headers, Word gaps, no outline).

## 2. Repository layout

```
tools/ereader/
  build_books.py        CLI: --mushaf hafs --mode reflow --profile 6in [--pages 1-10 for previews]
  profiles.py           page geometry per profile (6in, 7in): size, margins, header/footer, line-height factor
  measure.py            width measurements with Pillow/Raqm; caches per (font, text) in build/ereader/cache.sqlite
  html_faithful.py      mode F and S screen builder
  html_reflow.py        mode R document builder (surah headings, basmalas, page markers)
  css/                  base.css, faithful.css, reflow.css (templates with {{placeholders}})
  fit.js                in-page safety fit: shrinks any line whose scrollWidth exceeds its box before printing
  postprocess.py        front matter merge, outline, metadata, filename
  checks.py             validation
build/ereader/          html, pdf, png previews (git-ignored)
```

## 3. Algorithms

### 3.1 Common
1. Load `mushafs` row → mode capabilities, font family, font file.
2. Load `pages` rows for the mushaf (line text, kind, centered, surah) and `ayahs` (page, juz, surah names).
3. Profile numbers: portrait `PW=90.8, PH=122.6, M=3, HDR=4.5, FTR=4.5 → TW=84.8, TH=107.6` (mm); rotated `PW=122.6, PH=90.8 → TW=116.6, TH=75.8`.
3b. When parsing the docx sources, match text runs with `<w:t(?:\s[^>]*)?>(.*?)</w:t>`; the looser `<w:t[^>]*>` also captures `<w:tabs>` elements and produced one bogus 80 em "line" in Warsh.
4. Register fonts through `@font-face` with `file://` URLs (bundled copies from `assets/fonts/`, per-page QCF fonts from the pack folder).

### 3.2 Mode F / S (fixed lines)
1. `LPS` = lines per screen (15, 9, 8/7 for split, 5 for rotated). `LH = TH / LPS`.
2. Book font size: `FS = min(LH / pitch_em, TW / W_book)` with `pitch_em` = 1.8 (KFGQPC fonts), 2.05 (QCF), 1.85 (AlQuran IndoPak) and `W_book` = the ink width (em) the book must show unshrunk: 95th percentile of line ink widths for the Unicode riwayat (per-line shrink allowed on the rest), 15.75 em + overhang for QCF, 13.22 em + 0.46 em overhang for Gaba. Cache measurements per (font, text).
3. Per line, split into words on U+0020 (keep U+00A0 inside words so ayah marks stay attached). Ink width `ink = Σ advance(word) + overhang_left + overhang_right` (from `getbbox` of the whole line). If `ink × FS > TW` set the line's own `font-size` to `FS × TW / (ink × FS)` (shrink, never grow); log it. Class: `just` when `ink × fs ≥ justify_min × TW` and the line is not `centered`, else `right`; `center` when flagged.
4. Emit one `<section class="page">` per screen: header, `<main>` with one `<div class="line …">` per row (`display: flex; align-items: baseline`, fixed `height`/`line-height` = `LH`) containing one `<span>` per word, footer. No space characters between spans: `space-between` distributes the slack, `gap: 0.35em` separates words on right-aligned and centred lines. `white-space: nowrap`.
5. Surah rows: a single span with a 0.35 mm double border, font 0.9 × FS (Unicode text) or the `surah-name-v2` glyph at 1.5 × FS (QCF). Basmala rows: one span, centred.
6. `fit.js` stays as a safety net (shrink a `.line` whose `scrollWidth` exceeds `clientWidth` by 0.5 % steps) but must not be relied on: ink overhang and fallback glyphs are invisible to it.
7. Print with Chrome. For mode L rotate every page by 90° with `pypdf` (`page.rotate(90)`). Then `postprocess.py` adds outline (surah → first screen; juz → first screen), metadata and front matter.
8. Header and footer numerals: render them in the mushaf font when it has digits (KFGQPC fonts do), otherwise declare one Latin font explicitly, so no unplanned fallback font is embedded.

### 3.3 Mode R (reflow)
1. Build one HTML document: for each surah `<h1 class="surah" id="s{n}"><span>name</span></h1>`, then `<p class="basmala">` unless surah 1 or 9, then the ayah texts joined by spaces inside one `<article>`. Before the first ayah of each printed page insert `<span class="pgmark"><b>{page}</b></span>` (font 7 pt, thin rounded border, `vertical-align: super`).
2. CSS: `@page { size: 90.8mm 122.6mm; margin: 3mm 3mm 7mm 3mm; @bottom-center { content: counter(page) } }`, `article { font-size: 16pt; line-height: 1.85; text-align: justify }`, `h1 { break-inside: avoid; break-after: avoid }`.
3. Print with `--generate-pdf-document-outline` (verified: the 114 `<h1>` become outline entries). Add juz entries afterwards with `pypdf` using the screen on which each juz marker lands (found with PyMuPDF text search for the marker string).
4. Front matter is a separate small HTML printed to its own PDF and merged in front; its links target screen numbers from the main PDF.

### 3.4 QCF V2 specifics
- Line strings come from `pages.text` (glyph codes from the QUL V4 docx; pages 256 and 270 need the V2 word codes, see inventory §5.1). The `@font-face` family for page `p` is `QCF2_p{p}` with `src: url('file://…/qcf_v2/p{p}.ttf')`.
- The V2 page fonts map **no U+0020**: a space in the HTML is drawn with a fallback font (0.25 em instead of the 0.04 em `.notdef` a measurement returns) and lines overflow by about 10 mm. The flex word layout of §3.2 avoids spaces entirely. V4 fonts do map U+0020 and U+00A0 but get the same layout for consistency.
- Chrome subsets each page font into the PDF; the prototype embedded three page fonts in a 710 KB file, so expect 100 MB or more for 604 pages. Try stripping hinting tables (`fpgm`, `prep`, `cvt `, `hdmx`, `VDMX`, `LTSH`) with fontTools before building, and compare with a PyMuPDF `save(garbage=4, deflate=True)` pass. Report the final size in the catalogue.
- Surah headers use `surah-name-v2` (U+E000 + surah; surah 102 at U+E102) and basmalas `quran-common` U+FDFD, both verified in the prototype.

### 3.5 Gaba specifics
- Text from `pages.text` of `indopak_9_gaba` (PUA markers intact); font `AlQuran IndoPak` (`qul/font.ttf`).
- `LPS = 9`, `W_book = 13.22 em + 0.46 em` ink overhang → FS ≈ 6.2 mm (17.6 pt). Justification per 02 §4 rule 3.
- Surah header rows: the layout DB has only the surah number; render `سُوْرَةُ` + the Arabic name from `surahs` in the IndoPak font inside the border, or the `surah-name-v2` glyph for consistency across books (choose one for all Gaba books).

## 4. CSS essentials (from the working prototypes)

```css
@font-face { font-family: 'Hafs'; src: url('file:///…/KFGQPC-Hafs.ttf'); }
@page { size: 90.8mm 122.6mm; margin: 0; }            /* mode L: size: 122.6mm 90.8mm, then /Rotate 90 */
.page { width: 90.8mm; height: 122.6mm; box-sizing: border-box; padding: 3mm;
        page-break-after: always; direction: rtl; font-family: 'Hafs'; }
header, footer { height: 4.5mm; line-height: 4.5mm; font-size: 2.6mm; display: flex; justify-content: space-between; }
main { height: 107.6mm; }
.line { height: var(--lh); line-height: var(--lh); font-size: var(--fs);
        display: flex; align-items: baseline; white-space: nowrap; }   /* one span per word, no spaces */
.line.just   { justify-content: space-between; }        /* justified, including one-line paragraphs */
.line.right  { justify-content: flex-start; gap: 0.35em; }
.line.center { justify-content: center; gap: 0.35em; }
.line span { flex: 0 0 auto; }
.line span.surah { border: 0.35mm double #000; padding: 0 4mm; }
```

Ayah marks: keep the data's `U+00A0` + `U+FC00+n−1` form so the mark never separates from its word and needs no contextual substitution.

## 5. Checks (`tools/ereader/checks.py`)

- Screen counts: F = pages (+ front matter); S = 2 × pages − 2; Gaba F = 1890; R ≈ expected ± 5 %.
- `pdffonts`: every font embedded and subset (`emb=yes sub=yes`), and the font list equals the declared set. Any unplanned font (Liberation, DejaVu, Times) means a character fell back: a space in a QCF book, a digit outside the mushaf font, or a code point the font lacks.
- No line overflow: rasterise every screen at 300 ppi and assert the ink of the text band stays inside the margins (the prototype check: ink x-range within 3.0 … 87.8 mm), and compare the count of shrunk lines with the expected percentage.
- Round trip: concatenated text of all screens (minus headers, markers, footers) equals the DB text of the mushaf.
- Visual: `pdftoppm -r 300` for a fixed sample (screens for pages 1, 2, 3, 50, 77, 255, 507, 604) into `build/ereader/previews/` and eyeball; keep the set as golden images once approved.

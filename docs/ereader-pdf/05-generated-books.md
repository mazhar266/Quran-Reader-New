# 05 · Generated books

What `tools/ereader/` builds, how, and how the result was checked. September 2026.

## 1. The books

Every book is a fixed-layout PDF with 90.8 × 122.6 mm screens (the 6-inch panel at 300 ppi), vector
text with embedded, subsetted fonts, a two-level outline (surahs, juz), a surah index and a juz index
with internal links, and a sources screen. **The smallest Quran text in any book is 16 pt**; the
10–11 pt one-page-per-screen editions of 01 §5.3 are deliberately not generated, because they are too
small for comfortable reading.

| file | what a screen shows | text size | screens |
|---|---|---|---|
| `quran-hafs-madinah-reflow-16pt-6in.pdf` | flowing text, 10 lines | 16 pt | 1,049 |
| `quran-hafs-madinah-reflow-20pt-6in.pdf` | flowing text, 8 lines (large print) | 20 pt | 1,654 |
| `quran-hafs-madinah-rotated-6in.pdf` | 5 printed lines, exact, sideways | 17.1 pt | 1,810 |
| `quran-{warsh,qaloun,douri,shuba,sousi}-madinah-reflow-16pt-6in.pdf` | flowing text, 10 lines | 16 pt | 1,057–1,084 |
| `quran-{warsh,qaloun,douri,shuba,sousi}-madinah-rotated-6in.pdf` | 5 printed lines, sideways | 16.6–16.9 pt | 1,810 |
| `quran-indopak-gaba-9-lines-6in.pdf` | one printed 9-line page, exact | 17.8 pt | 1,890 |

Each file also has 15 front-matter screens (title, about, 10 surah-index, 3 juz-index screens).
Sizes: 7–10 MB per book, well under the 50 MB Send-to-Kindle e-mail limit.

Which book to read with:

- **Daily reading**: the 16 pt flowing book of your riwayah; the 20 pt book for large print. Small
  boxed numbers mark where each page of the printed mushaf begins, and the footer shows the printed
  pages on the screen, so page-based reading plans still work.
- **The printed lines, large**: the sideways book (hold the reader in landscape). Each printed page
  is three screens, lines 1–5, 6–10 and 11–15, labelled `50 (1/3)` … `(3/3)`.
- **Indopak readers**: the Gaba book, one printed page per screen at 17.8 pt.

## 2. How lines are filled

Books use the same rules as the app ([../04-implementation.md](../04-implementation.md) §3): each
word is shaped with HarfBuzz, spaces grow by at most a quarter, and the rest of each line is filled
with kashida (tatweel) at the word's best place, never inside lam-alef or the name of Allah, at most
five per word. Tatweels are added in measured rounds because their width depends on the letters
around them. This replaces the policy of 02 §4, which would have left lines ragged or with wide gaps:
on the device the lines now read like the printed mushaf.

Consequence: the PDF's text layer contains the inserted tatweels, so a PDF search for a word that was
elongated on that line will not find it. The letters and marks themselves are unchanged. Readers do
not search e-reader PDFs of Arabic text in practice (Kindle and Kobo search is unreliable for RTL
text anyway), so readability was preferred.

Flowing books break lines greedily at natural spacing and then fill each line; the last line of a
surah is centred when it is shorter than 70 % of the width. A surah header, its basmala and the first
line always share a screen. Exact-line books size the text so that 99 % (sideways) or 99.9 % (Gaba)
of lines fit with their spaces tightened; the rest (about 1 % of lines in the sideways books) are
squeezed horizontally, by at most 10 % in Hafs and 14 % in the widest Warsh/Qaloun lines.

## 3. Layout and printing

- `tools/ereader/layout.py`: word units, kashida places, justification (Python port of the app).
- `tools/ereader/books.py`: screens for the three modes from `assets/db/quran_reader.db`.
- `tools/ereader/render.py`: HTML with every word absolutely positioned (Chromium's shaping matches
  Pillow/Raqm to within 0.0003 em, so the layout computed in Python is exact), printed by headless
  Chromium through Playwright; pypdf then rotates the sideways screens (`/Rotate 90`), adds the
  outline, metadata and `/Lang ar`.
- `tools/ereader/checks.py`: page count and size, embedded fonts (a fallback font means a missing
  glyph), no ink within 1 mm of the page edge on sampled screens, 300 ppi previews of fixed sample
  screens into `build/ereader/previews/`.

```sh
pip install pillow fonttools playwright pypdf pymupdf
python3 -m tools.ereader.build --list
python3 -m tools.ereader.build                  # all books into build/ereader/ (≈ 15 min)
python3 -m tools.ereader.build hafs-reflow      # books whose key starts with this
```

Chromium: set `$CHROMIUM` to a Chrome/Chromium binary, or let Playwright use its own
(`playwright install chromium`). Front matter, footers and page markers use the bundled
`tools/ereader/fonts/DejaVuSans.ttf`.

## 4. Verification (this build)

The build report is written to `build/ereader/report.json`. For every book: page count equals front
matter + screens; displayed page size 257.0 × 347.5 pt (rotated screens included); fonts are exactly
the mushaf font, `surah-name-v2`, `quran-common` and DejaVu Sans; no ink at the page edges.

| book | text | screens | size | lines justified | with kashida | squeezed (min scale) |
|---|---|---|---|---|---|---|
| Hafs flowing | 16 pt | 1,049 | 7.2 MB | 10,150 | 70 % | 0 |
| Hafs flowing, large print | 20 pt | 1,654 | 8.3 MB | 12,874 | 73 % | 0 |
| Warsh / Qaloun / Douri / Shu'bah / Sousi flowing | 16 pt | 1,084 / 1,083 / 1,059 / 1,058 / 1,057 | 6.9–7.0 MB | ≈ 10,300 | 69–70 % | 0 |
| Hafs sideways | 17.1 pt | 1,810 | 8.6 MB | 8,807 | 93 % | 86 (0.904) |
| Warsh sideways | 16.6 pt | 1,810 | 8.0 MB | 8,807 | 93 % | 88 (0.874) |
| Qaloun sideways | 16.6 pt | 1,810 | 8.0 MB | 8,807 | 93 % | 86 (0.864) |
| Douri sideways | 16.9 pt | 1,810 | 8.2 MB | 8,807 | 93 % | 85 (0.915) |
| Shu'bah sideways | 16.9 pt | 1,810 | 8.2 MB | 8,807 | 93 % | 87 (0.895) |
| Sousi sideways | 16.9 pt | 1,810 | 8.1 MB | 8,807 | 93 % | 86 (0.913) |
| Indopak Gaba | 17.8 pt | 1,890 | 9.3 MB | 16,815 | 100 % | 0 |

(Flowing lines are broken close to full, so fewer need kashida.) Sample renders:
`images/book-hafs-reflow-16pt.png`, `images/book-hafs-reflow-20pt.png`,
`images/book-hafs-rotated-50a.png` (shown upright), `images/book-gaba-page-3.png`.

## 5. Still to do

- Device round (04 §2) on Kindle, Kobo, PocketBook and KOReader.
- QCF V2 books (1421H print, per-page fonts): need the V2 glyph lines in the content database and
  ≈ 120 MB of fonts per book.
- 7-inch profile: `PORTRAIT`/`LANDSCAPE` in `books.py` are the only numbers to change.

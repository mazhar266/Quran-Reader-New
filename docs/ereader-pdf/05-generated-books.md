# 05 · Generated books

What `tools/ereader/` builds, how, and how the result was checked. September 2026; tajwid editions (§6) October 2026.

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
| `quran-hafs-madinah-reflow-16pt-tajweed-6in.pdf` | the Hafs 16 pt book with tajwid colours (§6) | 16 pt | 1,049 |
| `quran-hafs-madinah-reflow-20pt-tajweed-6in.pdf` | the Hafs 20 pt book with tajwid colours | 20 pt | 1,654 |
| `quran-hafs-madinah-rotated-tajweed-6in.pdf` | the Hafs sideways book with tajwid colours | 17.1 pt | 1,810 |
| `quran-indopak-gaba-9-lines-tajweed-6in.pdf` | the Gaba book with tajwid colours | 17.8 pt | 1,890 |

Each file also has 15 front-matter screens (title, about, 10 surah-index, 3 juz-index screens); the
tajwid editions have a 16th, the colour legend, after the about screen.
Sizes: 7–10 MB per book, well under the 50 MB Send-to-Kindle e-mail limit.
The built files are committed in [`ereader-books/`](../../ereader-books/README.md).

Which book to read with:

- **Daily reading**: the 16 pt flowing book of your riwayah; the 20 pt book for large print. Small
  boxed numbers mark where each page of the printed mushaf begins, and the footer shows the printed
  pages on the screen, so page-based reading plans still work.
- **The printed lines, large**: the sideways book (hold the reader in landscape). Each printed page
  is three screens, lines 1–5, 6–10 and 11–15, labelled `50 (1/3)` … `(3/3)`.
- **Indopak readers**: the Gaba book, one printed page per screen at 17.8 pt.
- **Tajwid colours, on a colour e-ink reader**: the `-tajweed-` edition of any of the Hafs books; same
  screens, letters coloured by rule (§6).

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
  Widths come from HarfBuzz through Pillow + Raqm where Pillow has it (Linux) and through
  `uharfbuzz` otherwise (Windows, macOS); both give the same numbers (the Windows build of the
  books reproduced the Linux line statistics below exactly).
- `tools/ereader/tajweed.py`: tajwid rules per letter of each mushaf's text, from QUL's annotation (§6).
- `tools/ereader/books.py`: screens for the three modes from `assets/db/quran_reader.db`.
- `tools/ereader/render.py`: HTML with every word absolutely positioned (Chromium's shaping matches
  Pillow/Raqm to within 0.0003 em, so the layout computed in Python is exact), printed by headless
  Chromium through Playwright; pypdf then rotates the sideways screens (`/Rotate 90`), adds the
  outline, metadata and `/Lang ar`.
- `tools/ereader/checks.py`: page count and size, embedded fonts (a fallback font means a missing
  glyph), no ink within 1 mm of the page edge on sampled screens, 300 ppi previews of fixed sample
  screens into `build/ereader/previews/`.

```sh
pip install pillow fonttools playwright pypdf pymupdf uharfbuzz
python3 -m tools.ereader.build --list
python3 -m tools.ereader.build                  # all books into build/ereader/ (≈ 20 min)
python3 -m tools.ereader.build hafs-reflow      # books whose key starts with this (incl. -large, -tajweed)
python3 -m tools.ereader.build gaba-tajweed --limit 40   # the first 40 screens only, for a quick look
```

Chromium: set `$CHROMIUM` to a Chrome/Chromium binary, or let the tools find an installed Google
Chrome (Windows, Linux), or let Playwright use its own (`playwright install chromium`). Front
matter, footers and page markers use the bundled `tools/ereader/fonts/DejaVuSans.ttf`.

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

- Device round (04 §2) on Kindle, Kobo, PocketBook and KOReader; the tajwid editions on a colour
  e-ink reader (Kobo Clara Colour, Kindle Colorsoft, PocketBook Color).
- Tajwid for the other riwayat would need an annotation of their recitation; QUL has none.
- QCF V2 books (1421H print, per-page fonts): need the V2 glyph lines in the content database and
  ≈ 120 MB of fonts per book.
- 7-inch profile: `PORTRAIT`/`LANDSCAPE` in `books.py` are the only numbers to change.

## 6. Tajwid editions

The four Hafs books exist a second time with tajwid colours: the same screens, line for line, with the
letters coloured by the rule of recitation that applies to them, a legend screen after the about
screen, and `· tajwid colours` in the title and PDF subject. Only the Hafs books: the annotation
describes the Hafs recitation, and the Gaba print is Hafs in the IndoPak script. The books are meant
for colour e-ink readers; on a greyscale panel the colours show as greys (03 §7, 01 README finding 7).

| book | pages | size | letters coloured | rules without a letter | palette colours on sampled screens | ink identical to the plain book |
|---|---|---|---|---|---|---|
| Hafs flowing 16 pt, tajwid | 1,065 | 7.7 MB | 73,140 | 0 | 14 of 14 | IoU 0.986, 2 stray px |
| Hafs flowing 20 pt, tajwid | 1,670 | 8.7 MB | 73,140 | 0 | 13 | IoU 0.988, 6 stray px |
| Hafs sideways, tajwid | 1,826 | 9.0 MB | 73,140 | 0 | 13 | IoU 0.979, 2 stray px |
| Indopak Gaba, tajwid | 1,906 | 9.9 MB | 74,479 | 93 | 13 | IoU 0.986, 1 stray px |

Sample renders: `images/book-hafs-reflow-16pt-tajweed.png`, `images/book-gaba-page-1000-tajweed.png`,
`images/book-tajweed-legend.png`.

### 6.1 Source and palette

QUL's export of KFGQPC's **QPC Hafs tajwid text** (`resources/qul/qpc-hafs-tajweed.json.zip`, see
[../01-resource-inventory.md](../01-resource-inventory.md) §4): every word of the mushaf with inline
`<rule class=…>` markup over the letters a rule applies to, in 18 classes. The colours are the standard
palette of quran.com and QUL, the same the Quran Researcher app uses (`tools/ereader/tajweed.py`,
`RULES`): hamzat al-wasl, silent letters and lam shamsiyyah grey `#AAAAAA`; normal, permissible,
necessary and obligatory madd four blues; ghunnah orange; ikhfa purple and ikhfa shafawi magenta;
idgham with and without ghunnah green, idgham shafawi light green, idgham mutajanisayn and
mutaqaribayn two teals; iqlab light blue; qalqalah red. Rules that share a colour share a legend row
(14 rows).

### 6.2 Moving the rules onto the books' texts

The annotated text is an older encoding of the Hafs text: tatweel before the dagger alef (`مَـٰ` for
`مَٰ`), U+06E1 for the sukun, alef maqsura where KFGQPC v2.2 writes yeh, a zero-width non-joiner before
pause signs; 5,550 of the 6,236 ayahs differ from the Madinah text in at least one code point, and the
IndoPak text of the Gaba print differs far more (Farsi yeh, written-out alefs, its own hamza forms,
private-use ligatures). Character offsets therefore cannot be copied. Instead, per ayah:

1. Both texts are reduced to their **base letters** (marks, tatweel, joiners, pause signs, ayah marks
   and ornaments dropped), with the letter shapes the two texts write differently folded together
   (yeh forms, alef forms, kaf forms, teh marbuta, heh).
2. The two letter sequences are **aligned** (`difflib.SequenceMatcher`, no junk heuristic). For the
   Madinah books every ayah aligns completely; for Gaba 14 very short ayahs align below 90 % (one
   letter of six to eight, e.g. 53:37 where the font writes `وَفَّىٰٓ` with a private-use ligature).
3. Every annotated letter hands its rule to the letter it aligns with. A span that covers only marks
   (the madd sign `ـٰ`, a shadda) belongs to the letter the marks sit on. Nested spans: the inner one
   wins. A letter of the book's text that the annotation does not have (an alef the IndoPak print
   writes out where Madinah has a small alef) continues a madd, or a rule that holds on both sides of
   it within the word; otherwise it stays black.
4. The rule colours the letter **with its marks**; pause signs (U+06D6–U+06DC, the IndoPak small
   tah/zain and stop signs), the rub' and sajdah ornaments, ayah marks and the IndoPak margin
   annotations stay black. The basmala rows and the Gaba header basmalas are coloured like 1:1.
5. Kashida: `layout.justify` carries the per-character colours through the tatweel insertion, and each
   inserted tatweel takes the colour of the letter it extends (so a blue madd stretches blue).

Figures: Madinah 73,140 letters coloured and no annotated rule left without a letter; Gaba 74,479
letters (the written-out alefs under a madd add to the count) and 93 rules lost on letters the font
draws as private-use ligatures (`أُنثَىٰ` in eleven places, `وَفَّىٰٓ`, `شَاطِئِ` …), which stay black.

### 6.3 Rendering and checks

Each positioned word span holds `<c class="t-rule">` runs (`render._runs_html`). Chromium shapes a
text node across inline boundaries whose font is the same, so the joins, ligatures and mark positions
are those of the plain word; the PDF text layer is the same text, split into more runs. `checks.py`
verifies this on every build of a tajwid book against the plain book (`plain_book`: the same file name
without `-tajweed`, from `build/ereader/` or `ereader-books/`):

- **`stray_ink`**: the sampled screens are rendered at 200 ppi in both books; no ink pixel of one may
  lie farther than one pixel from the ink of the other. A broken join or a displaced mark gives
  hundreds of stray pixels; the builds give 1–6 (anti-aliased edges of coloured strokes), limit 50.
- **`ink_match`**: intersection over union of the two ink masks at 100 ppi, 0.979–0.988 (coloured
  edges are lighter than black ones, so a few edge pixels fall under the ink threshold); limit 0.97.
- **`colours`**: the palette colours found on the text of the sampled screens (every 60th), at least
  10; 13–14 found (the rarest teals do not land on every sample).
- The usual checks: page count, 257.0 × 347.5 pt displayed, exactly the declared fonts, no ink at the
  page edges. Previews of tajwid books are rendered in colour.

Comparing the text layers character by character is not a valid check: Chrome encodes the split runs
differently, so PyMuPDF reads back different character counts and positions although the glyphs are
the same; the ink comparison is what proves the shaping unchanged.

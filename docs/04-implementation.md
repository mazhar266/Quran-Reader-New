# 04 · Implementation status

What of the [app plan](02-app-plan.md) is built, how it was verified, and what the implementation
learned about the data. September 2026.

## 1. Scope delivered

| plan item | status |
|---|---|
| Milestone 0: `flutter create` with id `fi.mazhar.quran.reader`, CI | done (`.github/workflows/ci.yml`: analyze + test) |
| Milestone 1: data pipeline `tools/` → `assets/db/quran_reader.db` + fonts, with validation | done |
| Milestone 2: picker, reader, `QuranLine`, headers/basmala, navigation, last position, bookmarks, themes | done |
| Milestone 3: the six KFGQPC riwayat, data-only | done |
| Milestone 4 (app side): about/sources, i18n (en, ar), icons, no network use | done; store listings and signing are the owner's |
| v1.2: Mushaf Qatar, Indopak 9-line Gaba, two-page spread | done |
| v1.1: QCF V2 / V4 tajweed font packs | not started (needs a pack host and the COLR spike on devices) |
| Hizb / rub' navigation | not started (metadata not in `resources/`) |

## 2. App structure

```
lib/
  main.dart                    opens the databases, restores the last mushaf/page
  app/                         MaterialApp.router, go_router routes, Riverpod providers, themes
  core/db/                     ContentDatabase (read-only asset copy), UserDatabase (bookmarks)
  core/prefs/                  Settings and reading positions (shared_preferences)
  domain/                      models, line segmentation (lineWords, ayahEnds)
  features/picker/             home: mushaf cards with a live page-1 rendering
  features/reader/             ReaderScreen, MushafPageView, QuranLine, SurahHeader, PageGeometry
  features/navigate/           go-to sheet: surahs, juz, page
  features/bookmarks/, settings/, about/
  l10n/                        app_en.arb, app_ar.arb (+ generated localizations)
```

Routes: `/` picker; `/read/:mushaf?page=n`, `/bookmarks`, `/settings`, `/about` above it, so Back from
the reader always lands on the picker. The first launch opens the picker, later launches the last
page read.

## 3. Rendering

- **`QuranLine`** (`features/reader/quran_line.dart`) is a `RenderBox` that shapes each word with its
  own `TextPainter` and lays the words out right to left, sharing the slack evenly between them
  (justified) or centring the line. A line wider than its box is squeezed horizontally, never wrapped.
  Words are split on plain spaces; the ayah mark and the rub' ornament are glued to their word with a
  no-break space, and a token with no Arabic letter (an IndoPak ayah circle or pause sign) stays with
  the word before it. Long-press hit-tests a word, which maps to its ayah by counting ayah-end marks.
- **Geometry** (`page_geometry.dart`): `fontSize = textWidth / K`; in whole-page fit it is also limited
  so that all lines fit at the minimum pitch `L × fontSize`. The remaining height spreads the lines up
  to 3 em apart. Full-width fit scrolls when the page is taller than the screen.
- **Headers**: frame glyph U+E000 of `quran-common` with the `surah-name-v2` glyph centred in it. The
  page labels use the same fonts (surah name glyph, calligraphic juz names U+E001–U+E01E).
- **Opening pages** (1–2) are centred vertically; when all their lines are centred (Madinah prints)
  the text is set 1.3× larger, as printed.

K and L are measured by the pipeline with HarfBuzz (Pillow + Raqm):

| mushaf | K (em) | L (em) |
|---|---|---|
| Hafs | 22.77 | 1.78 |
| Warsh | 23.99 | 1.71 |
| Qaloun | 24.22 | 1.70 |
| Douri | 22.85 | 1.75 |
| Shu'bah | 23.29 | 1.76 |
| Sousi | 22.85 | 1.75 |
| Qatar | 22.81 | 1.77 |
| Indopak Gaba | 13.36 | 1.84 |

K is the widest justified line plus 1 %; the KFGQPC Word documents themselves set 22 pt text on a
523 pt measure (23.8 em), which agrees.

## 4. Verification

- **Pipeline** (`python3 -m tools.build`): for every riwayah, 604 pages (602 × 15 lines, 2 × 8), 114
  surah headers in order, every ayah's page and line span derived from the docx equals the JSON's
  `page`/`line_start`/`line_end` (all 6 × ~6,220 ayahs), per-ayah tokens equal the JSON's, every
  character of every line is in the mushaf font's cmap, 30 juz and 114 surah starts per mushaf.
- **Flutter tests** (`flutter test`):
  - `quran_text_test`: segmentation and word → ayah mapping.
  - `content_database_test`: catalogue, navigation tables, riwayah-specific numbering.
  - `line_fit_test`: renders ~40 pages of each mushaf on a phone; over 4,700 lines not one needed
    any horizontal squeeze (smallest scale 1.0), so the pipeline's K matches Flutter's shaping.
  - `app_flow_test`: picker → reader → swipe → chrome → bookmark → go to surah/page → back to picker
    with the position remembered → bookmarks list; long-press ayah sheet; IndoPak with sepia and dark
    themes; two-page spread in landscape; Arabic UI.
- Screenshots of these flows are in [images/screens/](images/screens/).

## 5. Findings about the data (corrections to 01/03)

1. **Basmala lines per riwayah.** Hafs and Shu'bah count the Fatihah basmala as ayah 1, so they have
   112 basmala lines; Warsh, Qaloun, Douri and Sousi print it as an unnumbered line: 113. Some basmalas
   start with a shadda on the ba (`بِّسۡمِ`, idgham with the previous surah's end).
2. **Docx vs. JSON spelling**: two tokens differ (Warsh 16:123, Shu'bah 2:286); the app renders the
   docx lines, which carry the layout.
3. **KFGQPC ↔ QUL word segmentation** differs in exactly four ayahs (the pages 262, 378, 441, 451 of
   the inventory): 15:7 `لَّوۡمَا`, 27:20 `مَالِيَ`, 36:22 `وَمَالِيَ` are one KFGQPC token but two QUL
   words; 37:130 `إِلۡ يَاسِينَ` is two tokens but one word. With that override table
   (`tools/words.py`) the 83,668 QUL word ids map onto the KFGQPC Hafs text, which the Qatar layout uses.
4. **Gaba basmalas are not inline text.** Apart from Al-Fatihah (ayah 1) and the single `basmallah`
   row on page 2, the Gaba lines after a surah header start directly with ayah 1: the print puts the
   basmala in the surah heading. The app draws it under the header frame (`mushafs.header_basmala`).
5. **Gaba ayah ends**: U+F500–U+F61E plus the variants U+F631–U+F63D and U+F681–U+F693 end an ayah;
   U+F63E, U+F658 and U+F68F are annotations. With this set every surah has its Hafs ayah count. The
   print numbers Al-Fatihah Madani-style (basmala an empty circle), so ayah keys come from counting
   ends, not from the printed numbers.
6. **SQLite on Flutter**: `sqlite3_flutter_libs` is end-of-life; `package:sqlite3` 3.x bundles SQLite
   through a build hook. `pubspec.yaml` selects the system library on Linux (tests) and the package's
   checksummed binaries elsewhere. For builds without GitHub access the hook can compile the
   amalgamation instead (`source: source`, `path: …/sqlite3.c`).

## 6. Spike 5: QCF pack sizes

Measured on a sample of every 30th–40th page font with fontTools:

| pack | raw | hinting tables removed | + glyph instructions removed, zipped |
|---|---|---|---|
| QCF V2 (604 fonts) | 208 MB | ~207 MB | ~122 MB |
| QCF V4 tajweed, COLR (604 fonts) | 167 MB | ~167 MB | ~67 MB |

Dropping `fpgm`/`prep`/`cvt `/`hdmx`/`VDMX`/`LTSH` saves under 1 %: the outlines themselves dominate.
Both packs must stay out of the app bundle. A single 122 MB download is fragile on mobile data, so
split each pack into parts of 50–100 pages (which also lets the reader start before the whole pack
arrives), or use Play Asset Delivery / On-Demand Resources.

## 7. Next steps

- v1.1 QCF packs: extend the pipeline with pack building (instructions stripped, split packs,
  manifest), add a `PackManager` and the glyph rendering mode; run the COLR spike on Android and iOS.
- Hizb/rub' navigation from Tanzil metadata.
- Release: signing config, store listings, device checks on the sample pages of milestone 2.

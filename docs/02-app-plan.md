# 02 · App plan: Quran Reader

- **Name**: Quran Reader
- **Bundle / application id**: `fi.mazhar.quran.reader`
- **Platform**: Flutter (Android + iOS first; desktop/web later if wanted)
- **Purpose**: read the Quran page by page in several mushafs, exactly as printed. No tafsir, translation, audio, or study tools in scope. Any such feature is a later, optional add-on.

## 1. Product scope

### 1.1 MVP (v1.0)

1. **Mushaf picker**: choose which mushaf to read. Ships with the six KFGQPC Madinah mushafs (Hafs, Warsh, Qaloun, Douri, Shu'bah, Sousi). Each is a faithful 604-page, 15-line layout.
2. **Page reader**: horizontal, right-to-left page swiping; every page rendered line by line at the correct line breaks, with surah headers and basmalas; page number, surah name and juz shown in a thin header/footer.
3. **Navigation**: go to page, surah (index list), juz; jump from the header. Remember the last page per mushaf and reopen there.
4. **Bookmarks**: bookmark a page (or an ayah by long-press), list them, jump back.
5. **Display settings**: light / sepia / dark page themes, keep-screen-on, fit-to-width vs. fit-to-page, optional tablet two-page spread in landscape.
6. **About / sources** screen with the attributions required by KFGQPC and QUL.

### 1.2 v1.x (after MVP)

7. **QCF V2 mushaf** (1421H print, King Fahd Complex per-page fonts) as a downloadable pack (~200 MB, smaller after hint stripping).
8. **QCF V4 tajweed mushaf** (colour-coded tajweed) as a downloadable pack (~160 MB), gated on the COLR spike (see §6).
9. **Mushaf Qatar** layout (uses the KFGQPC Hafs font, no extra download).
10. Ayah-level highlighting on tap and ayah bookmarks in QCF mushafs (word-id mapping).
11. **Indopak 9-line (Gaba) mushaf**: layout DB, per-line text and the `AlQuran IndoPak` font are all present; no download needed (font 311 KB).

### 1.3 Later / backlog

- Indopak 15- and 13-line mushafs (word text is derivable from the Gaba lines; the printed Nastaleeq fonts are missing, `AlQuran IndoPak` can stand in), Digital Khatt, QPC Nastaleeq: layouts are present but fonts and/or word texts are missing (inventory §6).
- Text search (Hafs `aya_text_emlaey` is available), tap-for-Gharib glossary, tap-for-Tafseer al-Muyassar. Deliberately excluded from the MVP to keep the app a reader.
- Continuous "flow" reading mode (not page-faithful) using the `me_quran` or KFGQPC font.
- Widgets, reading streaks, khatmah planner, audio: out of scope unless requested.

## 2. Mushaf catalog

The app is data-driven: a mushaf is a row in the content database plus a rendering mode. Adding a mushaf must never require code changes beyond adding assets.

| id | name | pages × lines | rendering mode | text source | font(s) | ships in |
|---|---|---|---|---|---|---|
| `madinah_hafs` | Madinah Mushaf · Hafs | 604 × 15 | **A** Unicode lines | KFGQPC Hafs docx lines | KFGQPC Hafs (v2.2 from QUL, fallback v2.0) | v1.0 |
| `madinah_warsh` | Madinah Mushaf · Warsh | 604 × 15 | A | Warsh docx | KFGQPC Warsh v2.1 | v1.0 |
| `madinah_qaloun` | Madinah Mushaf · Qaloun | 604 × 15 | A | Qaloun docx | KFGQPC Qaloun v2.1 | v1.0 |
| `madinah_douri` | Madinah Mushaf · Douri | 604 × 15 | A | Douri docx | KFGQPC Douri v2.0 | v1.0 |
| `madinah_shuba` | Madinah Mushaf · Shu'bah | 604 × 15 | A | Shu'bah docx | KFGQPC Shu'bah v2.0 | v1.0 |
| `madinah_sousi` | Madinah Mushaf · Sousi | 604 × 15 | A | Sousi docx | KFGQPC Sousi v2.0 | v1.0 |
| `qcf_v2` | Madinah Mushaf 1421H · QCF V2 | 604 × 15 | **B** glyph-code lines | QUL V4 docx codes (+ V2 word codes for p256/270) + V2 layout DB | 604 per-page fonts (pack) | v1.1 |
| `qcf_v4_tajweed` | Madinah Mushaf · Tajweed (QCF V4) | 604 × 15 | B (colour) | QUL V4 docx codes + V4 layout DB | 604 COLR fonts (pack) | v1.1 |
| `qatar` | Mushaf Qatar | 604 × 15 | A | QUL Qatar layout + KFGQPC Hafs words | KFGQPC Hafs | v1.2 |
| `indopak_9_gaba` | Indopak 9 lines (Gaba) | 1890 × 9 | A | QUL `pages.zip` lines + Gaba layout DB | AlQuran IndoPak (`qul/font.ttf`) | v1.2 |
| `indopak_15_qudratullah`, `indopak_13_*` | Indopak 15 / 13 lines | 610 × 15, 849/847 × 13 | A | Gaba-derived IndoPak words by QUL word id | AlQuran IndoPak as a stand-in (Naskh style, so not the printed Nastaleeq look; label it "layout of X, QuranWBW typeface") or the missing Nastaleeq fonts | backlog |
| `digital_khatt`, `nastaleeq` | … | 604 × 15, 610 × 15 | A | needs missing assets | needs missing fonts | backlog |

In the Gaba mushaf the basmalas are ordinary text lines inside the page (the layout DB has a single `basmallah` row), and the ayah number glyphs are part of the line text, so ayah keys per line come from those glyphs rather than from word ids.

Surah headers and basmalas in every mode: header glyph from `surah-name-v2` (`U+E000+surah`, surah 102 at `U+E102`) inside a frame (painted, or a frame glyph from `quran-common`); basmala rendered as Unicode text in the mushaf's own font (mode A) or as the page's own basmala glyphs (mode B, they are part of the page code run on QCF pages where the DB has a `basmallah` row — verify in the spike; otherwise use `quran-common` U+FDFD).

## 3. Architecture

### 3.1 Stack

| concern | choice | why |
|---|---|---|
| Flutter | stable channel, Dart 3, Material 3 | local toolchain present (`~/flutter`, Android SDK, JDK 25) |
| State | `flutter_riverpod` (no codegen) | simple, testable, scoped providers for reader state |
| Routing | `go_router` | deep links to `/mushaf/:id/page/:n` later |
| Database | `sqlite3` + `sqlite3_flutter_libs` | synchronous, fast reads of a read-only content DB; small user DB for bookmarks |
| Preferences | `shared_preferences` | theme, last mushaf, per-mushaf last page |
| Files/paths | `path_provider`, `path` | copy content DB and downloaded font packs to app support dir |
| Downloads | `dio` (or `http`) + `archive` | font packs with progress and checksum |
| Screen | `wakelock_plus` | keep screen on while reading |
| i18n | `flutter_localizations` + `intl` (ARB) | UI in English and Arabic at launch (Finnish optional) |
| Tests | `flutter_test`, golden tests for page rendering | catch layout regressions per mushaf |

### 3.2 Layers and folders

```
lib/
  main.dart
  app/                 MaterialApp, theme (light/sepia/dark), router
  core/
    db/                ContentDatabase (read-only), UserDatabase (bookmarks, positions)
    fonts/             FontRegistry: bundled fonts + runtime FontLoader for per-page fonts, LRU bookkeeping
    downloads/         PackManager: manifest, download, verify, install, delete
    prefs/             Settings store
  domain/
    models/            Mushaf, MushafPage, PageLine (kind: ayah|surahHeader|basmala; text|codes; centered; ayah refs), Surah, Bookmark
    repositories/      MushafRepository, PageRepository, BookmarkRepository (interfaces)
  data/                repository implementations over SQLite
  features/
    picker/            mushaf list, pack status, download UI
    reader/            ReaderScreen (PageView.builder, RTL), MushafPageWidget, QuranLine (custom layout), header/footer overlay, gestures
    navigate/          go-to sheet: surah index, juz list, page field
    bookmarks/
    settings/
    about/
tools/                 Python pipeline (see 03-data-pipeline.md)
assets/
  db/quran_reader.db   content database (built by tools/, ~10 MB)
  fonts/               bundled fonts only (riwayah fonts, surah-name-v2, quran-common)
packs/                 (not in repo) zipped per-page font packs published on a release server
```

### 3.3 Content database (read-only, built offline)

Core tables (final DDL in `03-data-pipeline.md`):

- `mushafs(id, name, name_ar, pages, lines_per_page, mode, font_family, pack_id, edition_note)`
- `surahs(number, name_ar, name_en, ayah_count_hafs, revelation, first_page_by_mushaf JSON)`
- `pages(mushaf_id, page, line, kind, centered, surah_number, text, first_ayah_key, last_ayah_key)`: one row per printed line. `text` holds Unicode text (mode A) or the glyph-code string (mode B).
- `ayahs(mushaf_id, surah, ayah, page, line_start, line_end, text, text_plain)`: for lookups, highlighting, bookmarks and (later) search.
- `words(word_id, surah, ayah, position, text_hafs)` and `mushaf_words(mushaf_id, page, line, word_id, code)`: only for mode B mushafs, enables tap-to-ayah.
- `juz(number, surah, ayah, page_by_mushaf)`, `hizb_quarters(...)`, `sajdahs(...)`.

Bookmarks and reading positions live in a separate writable DB so the content DB can be replaced on update without migration pain.

### 3.4 Rendering modes

**Mode A – Unicode text lines (KFGQPC riwayat, Qatar).**
Each line is a `QuranLine` widget: a custom `RenderBox` that measures each word with `TextPainter` in the mushaf font at the page's font size and lays the words out right-to-left, distributing the slack evenly between words (justified) or centring the line when `centered`. Reasons for a custom layout instead of `Text(textAlign: justify)`:

- Flutter never justifies the last line of a paragraph, and each printed line *is* a one-line paragraph.
- Per-word boxes give free hit-testing for ayah highlighting and bookmarks.
- Word measurement is safe: Arabic shaping never crosses a space.

Ayah-end marks use the precomposed `U+FC00+n−1` glyphs from the data files (robust, no contextual GSUB needed), placed with a no-break space so they stay attached to the previous word.

**Mode B – glyph-code lines (QCF V2 / V4).**
Same `QuranLine` widget, but the "words" are the code-point groups of the line string and the font family is the page's own font (`QCF2_p{n}` / `QCF4_p{n}`) loaded at runtime with `FontLoader`. The fonts are designed so that a full line at the design size spans the page width; the app derives one font size for the whole mushaf from the page width and only nudges spacing to absorb rounding. V4 colour comes from the font's COLR table; nothing to do in code if the spike passes.

**Page geometry (both modes).**
`fontSize = pageWidth / K` (K tuned per mushaf, stored in `mushafs`), `lineHeight = fontSize × L` (L per mushaf), page height = 15 × lineHeight + margins. Portrait phones: fit width, allow slight vertical scroll if the 15 lines overflow a short screen; tablets/landscape: fit height, optional two-page spread with even page on the left (RTL reading order).

**Page caching.** `PageView.builder` with `cacheExtent` of one page each side; page data loaded from SQLite on demand (a page is ~15 rows, sub-millisecond). For mode B, pre-load the fonts of pages n±2 in the background.

### 3.5 Font packs (mode B)

- Bundled app stays small (< 30 MB): only DB + mode-A fonts.
- Packs are zips of 604 fonts (V2 ~198 MB raw; try stripping hinting tables `fpgm`, `prep`, `cvt`, `hdmx`, `VDMX`, `LTSH` with fontTools in the pipeline; expect a large reduction). Publish per pack with a manifest (`version`, `sha256`, `bytes`) on GitHub Releases or a small static host.
- Alternative for stores: Play Asset Delivery (on-demand) and iOS On-Demand Resources. Decide in v1.1 after measuring pack sizes; the app-side `PackManager` abstraction keeps either option possible.
- Flutter cannot unload fonts; the registry only loads a page font once per process and keeps the count low (fonts of visited pages: ~300 KB each, so 200 pages ≈ 60 MB). Acceptable; document it.

## 4. UX outline

- **Home = mushaf picker** on first launch; afterwards open directly at the last mushaf/page. Picker shows each mushaf with a thumbnail of its page 1, edition note, and download state for pack-based ones.
- **Reader**: full-bleed page; tap toggles a translucent overlay (surah · juz · page, back, go-to, bookmark, settings). Swipe RTL to advance (page n+1 is to the left). Long-press a line/word (modes with word data) to bookmark an ayah.
- **Go-to sheet**: tabs Surah / Juz / Page; surah list shows Arabic name (from `sura_name_ar`) and transliteration; juz list shows juz start page per mushaf.
- **Settings**: page theme (light, sepia, dark with inverted ink), brightness lock, keep screen on, fit mode, two-page spread, UI language.
- Accessibility: page text exposed as one semantics node per line with the plain ayah text (`aya_text_emlaey` where available); large-text OS setting does not scale the mushaf (faithful pages) but scales UI chrome.

## 5. Milestones

| # | milestone | contents | done when |
|---|---|---|---|
| 0 | Project setup + spikes | `flutter create` with id `fi.mazhar.quran.reader`; CI (`flutter analyze`, tests); spikes in §6 | spike results written into `docs/` |
| 1 | Data pipeline | `tools/` scripts produce `quran_reader.db` and asset font folder from `resources/` with validation | `pytest`-style checks pass (604/15/6236 …) |
| 2 | Reader MVP (Hafs) | picker, reader, `QuranLine`, headers/basmala, navigation, last position, bookmarks, themes | Hafs pages visually match the printed Madinah mushaf on sample pages (1, 2, 50, 77, 255, 604) |
| 3 | Six riwayat | remaining five mushafs enabled through data only; per-riwayah golden pages | all six pass the same visual check |
| 4 | Release v1.0 | about/sources, i18n (en, ar), icons, store listings, privacy (no network use in v1.0) | published |
| 5 | QCF packs (v1.1) | pack manager, V2 and V4 mushafs, per-page font loading, tap-to-ayah | packs download, verify, render on Android + iOS |
| 6 | Qatar + Gaba + polish (v1.2) | Qatar layout from QUL DB + Hafs words; Indopak 9-line Gaba from `pages.zip` + `font.ttf`; two-page spread, tablet layout | |
| 7 | Backlog | Indopak / Digital Khatt / Nastaleeq after fetching missing assets; search; glossary | |

## 6. Spikes (do these before milestone 2 and 5)

1. **Shaping fidelity**: render pages 1, 2, 50, 604 of Hafs and Warsh with the QUL (small) and Complex (large) builds of the KFGQPC fonts on Android and iOS; confirm identical glyphs, correct ayah marks (`U+FC00…`), ۞ and sajdah signs. Pick the smaller build if identical.
2. **Justification**: prototype `QuranLine` and compare with `Text(textAlign: justify)`; confirm right-to-left word order and per-word hit-testing.
3. **COLR v0 on Flutter (Impeller and Skia)**: load `ttf/p1.ttf` via `FontLoader` and render `U+FC41…`; check colours on Android and iOS. If unsupported, fall back to monochrome V4 fonts (strip `COLR`/`CPAL`) and drop tajweed colours until Flutter supports it.
4. **Per-page font loading cost**: measure `FontLoader` time and memory for 50 consecutive pages; decide pre-load distance.
5. **Pack size**: measure V2/V4 zip sizes with and without hinting tables; decide hosting.

## 7. Risks and open questions

- **Edition mismatch**: KFGQPC lines (current edition) vs. QUL V2/V4 lines (1421H) differ on ~16 % of lines. Show the edition in the picker and never mix sources within one mushaf.
- **Ayah numbering differs per riwayah** (6236 / 6214 / 6217). Bookmarks store `(mushaf, page)` plus `(surah, ayah)` in that mushaf's numbering; switching mushaf keeps the page number for 604-page mushafs and falls back to surah start otherwise. A cross-riwayah ayah concordance is a later improvement.
- **Font licences**: confirm KFGQPC non-commercial terms fit the intended distribution (free app, no ads is safest).
- **App size and store limits**: packs must stay out of the base APK/IPA.
- **Flutter font unloading** is impossible; mitigate with load-once bookkeeping.
- **Hizb/rub' metadata** is not in the resources; fetch Tanzil metadata and reconcile with the ۞ positions (199 in Hafs).
- **Open question**: should the app be Android-only at first? The plan assumes both, but every spike should be run on both platforms because font rendering differs.

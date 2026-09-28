# 01 · Resource inventory and analysis

Everything below was verified by extracting and inspecting the files in `resources/` (September 2026). Counts, code ranges and quirks are measured, not assumed.

## 1. Folder overview

```
resources/
├── quran complex/                 King Fahd Glorious Quran Printing Complex (KFGQPC) packages, 83 MB
│   ├── UthmanicHafs_v2-0.zip      Hafs text data + font + Word document of the whole mushaf
│   ├── UthmanicWarsh_v2-1.zip     Warsh          (same structure)
│   ├── UthmanicQaloun_v2-1.zip    Qaloun         (same structure)
│   ├── UthmanicDouri_v2-0.zip     Douri          (same structure)
│   ├── UthmanicShuba_v2-0.zip     Shu'bah        (same structure)
│   ├── UthmanicSousi_v2-0.zip     Sousi          (same structure)
│   ├── kfgqpc_hafs_smart_4.zip    "Hafs Smart" PUA font + ayah-level data (v0.8)
│   ├── hafs_tafseerMouaser_v3.zip Tafseer al-Muyassar per ayah + Uthman Taha Naskh fonts
│   ├── MuyassarGhareeb.docx       Glossary of uncommon words (Gharib), per surah/ayah
│   └── Tajweed_Muyassar.docx      "Al-Tajweed al-Muyassar" book (176 pages, 4th ed. 1442H)
└── qul/                           Quranic Universal Library (Tarteel) exports, 381 MB
    ├── font.ttf                   "AlQuran IndoPak by QuranWBW", 311 KB: the font for the Indopak page text
    ├── mushafs/                   9 page-layout SQLite DBs + 2 per-page Word exports
    └── fonts/                     13 single fonts + 2 sets of 604 per-page fonts
```

Note: every entry under `qul/fonts/` that looks like a font file (`*.ttf`, `*.otf`) is actually a **directory** containing the font of the same name. `ttf/` and `QPC V2 Font.ttf/` each hold 604 per-page fonts `p1.ttf` … `p604.ttf`.

## 2. KFGQPC riwayah packages (the six "Uthmanic" zips)

Each zip contains a `data` folder and a `font` folder.

### 2.1 Data files

Same content in 7 formats: `csv`, `json`, `sql`, `xml`, `xlsx`, `txt` (tab separated), `html`. Columns:

| column | meaning |
|---|---|
| `id` | sequential row id |
| `jozz` | juz number (1–30) |
| `page` | Madinah mushaf page (1–604). **`varchar` in Warsh/Qaloun/Douri/Sousi**: a handful of ayahs span two pages and are written as `85-86` |
| `sura_no`, `sura_name_en`, `sura_name_ar` | surah number, transliterated name (`Al-Fātiḥah`), Arabic name |
| `line_start`, `line_end` | first/last line (1–15) of the ayah on that page |
| `aya_no` | ayah number in that riwayah's numbering |
| `aya_text` | Uthmani text for the riwayah font |
| `aya_text_emlaey` | plain (imla'i) spelling for search. **Only in Hafs, Hafs Smart, and Tafseer data.** |

Measured facts:

| riwayah | ayahs | ayahs spanning 2 pages | font family (as embedded) | font file |
|---|---|---|---|---|
| Hafs | 6236 | 0 | `kfgqpc_hafs_uthmanic _script` (v2.0) | `uthmanic_hafs_v20.ttf` 795 KB |
| Warsh | 6214 | 4 | `kfgqpc_warsh_uthmanic_script` (v2.1) | `uthmanic_warsh_v21.ttf` 872 KB |
| Qaloun | 6214 | 4 | `kfgqpc_qaloun_uthmanic_script` (v2.1) | `uthmanic_qaloun_v21.ttf` 879 KB |
| Douri | 6217 | 5 | `kfgqpc_douri_uthmanic_script` (v2.0) | `uthmanic_douri_v20.ttf` 800 KB |
| Shu'bah | 6236 | 0 | `kfgqpc_shuba_uthmanic_script` (v2.0) | `uthmanic_shuba_v20.ttf` 721 KB |
| Sousi | 6217 | 5 | `kfgqpc_sousi_uthmanic _script` (v2.0) | `uthmanic_sousi_v20.ttf` 800 KB |

All six cover pages 1–604, juz 1–30, 114 surahs, 15 lines per page. Ayah numbering differs between riwayat (Kufi vs. Madani counts), so an ayah key is only meaningful *within* a riwayah.

Text encoding details (important for rendering):

- Arabic text is standard Unicode (Arabic block U+0600–U+06FF), shaped by the font's OpenType tables (GSUB/GPOS). It needs a real shaping engine (Flutter has HarfBuzz, fine).
- The **ayah-end mark** is a precomposed glyph in the Arabic Presentation Forms-A range: ayah `n` ↦ `U+FC00 + n − 1` (so `ﰀ` = 1 … up to 286). Verified for every ayah in all six sets (one row in Shu'bah lacks the mark). The data puts a **no-break space (U+00A0)** before the mark.
- The **rub' al-hizb ornament ۞ (U+06DE)** is placed at the start of the ayah text followed by U+00A0. Hafs/Shu'bah have 199, the other riwayat 428–435 (they mark more subdivisions). Treat it as an ornament, not a word.
- **Sajdah** sign U+06E9 appears 12–15 times per riwayah. Waqf marks are the standard small-high letters U+06D6–U+06DC.
- The riwayah fonts map U+0600–U+06FF, U+FC00–U+FD1D (ayah marks), U+FD50–U+FD7D (extra presentation forms), and digits.

### 2.2 The Word documents: an exact page layout for every riwayah

Each `font` folder has a `.docx` of the whole mushaf. It is not just prose: it contains **603 explicit page breaks and ~8,700 explicit line breaks**. Parsing them yields, for **each of the six riwayat**:

- 604 pages: 602 pages with exactly 15 lines, pages 1–2 with 8 lines. This is the Madinah layout to the word.
- Line types are recognisable: surah header lines start with `سُورَةُ …` (paragraph alignment `center`), basmala lines are centered, ayah lines are `both` (justified) or `center` (short last line of a surah).
- The ayah number in the docx is written as Arabic-Indic digits after a no-break space (e.g. `…ٱلۡعَٰلَمِينَ ١`), unlike the data files which use the U+FC00 marks.

Cross-checks performed on Hafs:

- The docx line breaks agree with `line_start`/`line_end` of the JSON data on every page (the only apparent mismatches were on pages 597–598 and traced to the checking script's basmala heuristic, not the data).
- Word tokens per page (excluding ۞) match the JSON tokens on all 604 pages.
- Compared with the QUL "QCF V2 (1421H print)" layout, **1,413 of 9,046 lines differ by one word at a line boundary**. Page boundaries are identical. In other words the KFGQPC docx encodes the *current* Madinah edition's line breaks, while the QUL V2/V4 layouts encode the 1421H print. The app must treat them as two distinct layouts.

Consequence: **the six riwayat can be rendered as faithful 15-line pages using only KFGQPC material** (font + docx-derived lines). The `line_start`/`line_end` columns are then only needed for validation and for ayah lookups.

### 2.3 Hafs Smart (kfgqpc_hafs_smart_4.zip)

- Font `KFGQPC Hafs Smart` (v0.8, 301 KB) maps **private-use code points U+E000–U+EAB4**: every letter shape is a separate glyph, no OpenType shaping required. Intended for ayah-level display (search results, lists), explicitly *not* for page layout (its readme says so).
- Data has the same columns as Hafs (incl. `page`, `line_start`, `line_end`, `aya_text_emlaey`), but `aya_text` is PUA text interleaved with U+200F marks.
- Its docx is one paragraph per ayah, no page structure.
- Useful as a robust fallback for ayah snippets; not needed for mushaf pages.

### 2.4 Tafseer al-Muyassar v3 (hafs_tafseerMouaser_v3.zip)

- Same 6236 rows as Hafs, plus `aya_tafseer` (Arabic tafsir text, with `<span class='aya'>…</span>` around quoted Quran words). Ships `uthmanic_hafs_v20.ttf` and two `kfgqpc_uthman_taha_naskh` fonts for the prose.
- Out of scope for a reading-only app; keep for a possible later "tap ayah → short tafsir" option.

### 2.5 Standalone documents

- `MuyassarGhareeb.docx`: 5,325 paragraphs, structure `سورة X` then `(n) ﴿word﴾: meaning. ﴿word﴾: meaning.` per ayah. Parseable into a per-ayah glossary. Optional feature only.
- `Tajweed_Muyassar.docx`: the book itself (front matter, chapters, one table). Reference material; no app data to extract.

## 3. QUL mushaf layouts (`qul/mushafs/*.db.zip`)

All nine databases share one schema:

```sql
CREATE TABLE info  (name TEXT, number_of_pages INTEGER, lines_per_page INTEGER, font_name TEXT);
CREATE TABLE pages (page_number INTEGER, line_number INTEGER, line_type TEXT,   -- 'ayah' | 'surah_name' | 'basmallah'
                    is_centered INTEGER, first_word_id INTEGER, last_word_id INTEGER, surah_number INTEGER);
```

- `first_word_id`/`last_word_id` are **global word ids** (1 … 83,668) in reading order, and **ayah-number markers count as words**. The same id space is used by every layout, so one word table serves all of them.
- For `surah_name` rows `surah_number` is set and the word ids are empty; for `basmallah` rows all three are empty.
- **No word text is included** in any layout DB. Word text/glyph codes must come from elsewhere (see §6).

| file | `info.name` | pages | lines | `font_name` | notes |
|---|---|---|---|---|---|
| `qpc-v2-15-lines.db` | QCF V2 (1421H print) | 604 | 15 | `v2` | 9,046 rows; 8,820 ayah lines, 114 surah lines, 112 basmala lines |
| `qpc-v4-tajweed-15-lines.db` | QPC v4 tajweed | 604 | 15 | `v4-tajweed` | identical structure to V2 (a few `is_centered` flags differ) |
| `mushaf-qatar-layout.db` | Mushaf Qatar | 604 | 15 | `qpc-hafs` | 15-line Qatar print; word ids differ from V2 on many lines |
| `digital-khatt-15-lines.db` | Digital Khatt (QPC v2 1421H layout) | 604 | 15 | `digitalkhatt` | same line breaks as V2 |
| `qpc-nastaleeq-15-lines.db` | QPC Hafs Nastaleeq 15 lines | 610 | 15 | `qpc-nastaleeq` | only 1 `surah_name` row, no basmala rows; 84 pages have 13 lines; word-id sum ≠ max (5 overlapping ids) |
| `qudratullah-indopak-15-lines.db` | Indopak 15 lines (Qudratullah) | 610 | 15 | `indopak-nastaleeq` | |
| `indopak-13-lines-layout-qudratullah.db` | Indopak 13 lines – Qudratullah | 849 | 13 | `mushaf-indopak-nastaleeq-hanafi-compressed` | |
| `indopak-13-lines-taj-company.db` | Indopak 13 lines – Taj company | 847 | 13 | `indopak-nastaleeq` | |
| `indopak-9-lines-gaba.db` | Indopak 9 lines (Gaba) | 1890 | 9 | `indopak` | only 1 basmala row (basmalas are inline in this print) |

### 3.1 Word segmentation vs. KFGQPC

Splitting the KFGQPC Hafs `aya_text` on spaces (ignoring ۞) gives 83,666 tokens; QUL has 83,668 words. Per-page comparison shows the difference is local to **four pages: 262, 378, 441, 451** (±1 word each). Everywhere else the two segmentations agree, so KFGQPC Hafs words can be mapped onto QUL word ids with a 4-entry override table. This is what lets the app know which ayah a QUL line belongs to.

The Indopak 9-line Gaba lines (§4) also align with the QUL word ranges once two rules are applied: a space-separated token without Arabic letters (pause marks, small-meem markers) is merged into the preceding word, and a token carrying an ayah-end sign counts as a word. With those rules 16,972 of 17,004 lines match; the remaining 32 lines are off by one around rare ayah-number variant glyphs (U+F631–U+F63E, U+F681–U+F693, U+F658) and need a short override list. Rendering the Gaba mushaf does not need this alignment at all: ayah boundaries can be read directly from the ayah-number glyphs in the line text, and surah starts come from the layout rows. The alignment only matters for reusing the IndoPak word text in the 15- and 13-line layouts.

## 4. QUL per-page Word exports

- `pages-KFGQPC-v4.zip`: `1.docx` … `604.docx`. Each paragraph is one **ayah line** of the V4 layout, written as **glyph codes for the matching per-page font** (e.g. `ﱁ ﱂ ﱃ ﱄ ﱅ`). Surah header and basmala lines are omitted (line counts per page: 506×15, 83×13, 8×11, …, exactly the number of `ayah` rows in the V4 DB).
- `pages.zip`: `1.docx` … `1890.docx`, the **Indopak 9-line (Gaba)** layout, one paragraph per line, in real IndoPak Unicode text. Line counts match the layout DB's `ayah` rows on every page. Ayah numbers are private-use codes (`U+F4FF + n`, so U+F500 = ١) and there are other PUA markers (U+F61E, U+F64A, U+F652, U+F68F, U+F650 …). The matching font is `qul/font.ttf` (§5.3): it covers **all 418 code points** used across the 1890 pages, and shaped test renders of pages 1, 2, 4, 1000 and 1890 look correct (see `images/gaba-9-line-page-1.png` and `images/gaba-9-line-page-1000.png`).

## 5. QUL fonts (`qul/fonts/`)

### 5.1 Per-page fonts

| set | directory | family in file | count / size | tables | code assignment |
|---|---|---|---|---|---|
| QCF V2 | `QPC V2 Font.ttf/` | `QCF2001` … `QCF2604` | 604 files, **198 MB** | TrueType with heavy hinting tables (`fpgm`, `hdmx`, `VDMX`, `LTSH`) | words of page p are `U+FC41, U+FC42, …` in reading order; ayah-number marks are glyphs in the same run; on p1/p2 extra ranges U+F777–U+F8A6 (juz/hizb labels) and U+FD5A–U+FD79 (header frame pieces) |
| QCF V4 tajweed | `ttf/` | `QCF4001_COLOR` … | 604 files, **159 MB** | TrueType + **COLR v0 / CPAL** (layered colour glyphs for tajweed) | same `U+FC41…` run as V2 |

Verified: the length of the `U+FC41…` run is identical between V2 and V4 on 602 pages; **pages 256 and 270 differ** (V2 has 15 and 8 more codes), so the V4 docx strings cannot be reused blindly for V2 on those two pages. Some words occupy two codes (word + separate pause mark), so a line's code count is not its word count; the docx strings and the DB word ranges must both be kept.

### 5.2 Single fonts

| file | family | what it is | use |
|---|---|---|---|
| `UthmanicHafs_V22.ttf` (298 KB) | KFGQPC HAFS Uthmanic Script v2.2 | newer build of the KFGQPC Hafs font (Complex zip ships v2.0) | primary Hafs page font |
| `uthmanic-warsh-v21`, `-qaloun-v21`, `-douri-v20`, `-shuba-v20`, `-sousi-v20` (250–262 KB) | KFGQPC … Uthmanic Script | smaller builds of the riwayah fonts (hinting stripped?) than the Complex zips (720–880 KB) | riwayah page fonts (prefer these if they render identically; spike) |
| `surah-name-v2.ttf` (580 KB) | surah-name-v2 | calligraphic header "سُورَةُ X" as one glyph: `U+E000 + surah` (quirk: surah 102 is at U+E102, U+E066 is absent; U+E103 also present) | surah headers |
| `surah-name-v4.ttf` (216 KB) | surah-name-v4 | `U+E000` = the word "سورة", `U+E001…U+E072` = surah names only, `U+E073` extra | surah headers (V4 style) |
| `quran-common.ttf` (125 KB) | quran-common | `U+E000–U+E01E` decorative header frames; `U+E073–U+E076`, `U+E900–U+E91D` tiny juz/hizb labels; `U+FC22/FC23`, `U+FDFD/FDFE` basmala and misc | frames, basmala |
| `surah_names.ttf` (1.1 MB) | QCF_FullSurah_HD_COLOR-v1 | **SVG-in-OpenType** colour font | not usable in Flutter, ignore |
| `me_quran_volt_newmet.ttf` (460 KB) | me_quran | classic Madinah-style Uthmani font (VOLT-built) | optional "flow text" fallback |
| `KFGQPCNastaleeq-Regular.ttf` (255 KB) | KFGQPC Nastaleeq | font for the QPC Nastaleeq layout | later, needs its own text data |
| `DigitalKhattIndoPak.otf` (495 KB) | DigitalKhatt IndoPak | CFF2 variable IndoPak font, standard Unicode (no PUA); covers only 62 of the 418 code points used by the Gaba pages | not usable for the QUL Indopak text as is |
| `../font.ttf` (311 KB, 992 glyphs) | AlQuran IndoPak by QuranWBW (credits Al Qalam, Ghandhara, KFGQPC) | Naskh-style IndoPak font with GSUB/GPOS shaping and all the PUA markers used by QUL's Indopak text | **Indopak 9-line Gaba mushaf**, and a stand-in for the 15/13-line Indopak layouts |

### 5.3 PUA map of `font.ttf` (AlQuran IndoPak by QuranWBW)

Verified by rendering (`images/alquran-indopak-pua-markers.png`):

| code points | glyph | used in Gaba pages |
|---|---|---|
| U+F500 … U+F61D | ayah number 1 … 286 inside the IndoPak circle | 6,236 ayah ends (plus rare variants below) |
| U+F61E | empty circle (end of the Al-Fatihah basmala line) | 1 |
| U+F61F | alif with hamzat-wasl sign, used as the first letter of some words (e.g. `لَّذِیْ`) | 54 |
| U+F631 … U+F63E, U+F681 … U+F693, U+F658 | ayah-number variants carrying an extra mark (sajdah / ruku annotation above the circle) | one or two uses each |
| U+F64A, U+F64B, U+F64C, U+F65D, U+F66B, U+F66D | small meem (iqlab / ghunnah marker) at different vertical positions | 120 / 144 / 30 / 244 / 9 / 31 |
| U+F650 … U+F653 | margin ornaments for hizb quarters (`١/٤`, `١/٢`, `٣/٤`) and hizb start | 30 / 22 / 34 / 5 |
| U+F662 … U+F664 | `وقف لازم` annotation variants | 20 / 12 / 17 |
| U+F68F | `لا` + `ص` pause annotation | 54 |
| U+E000, U+E001 | honorifics `رضي الله عنه`, `عليه السلام` | rare |
| U+E00E | ruku sign `ع` | (ruku numbers appear above the ayah circle) |

Typeface caveat: this is a **Naskh-style** IndoPak font (the QuranWBW / Al Qalam design). It reproduces the 9-line Gaba print faithfully, whose text is set in this style. The 15-line Qudratullah and 13-line Taj Company / Qudratullah prints are set in **Nastaleeq**; rendering their layouts with this font keeps their line breaks and page numbers but gives a different typeface than the printed editions. Label such mushafs accordingly in the app until the Nastaleeq fonts are obtained.

## 6. What is missing (cannot be built from these resources alone)

| needed for | missing item | where to get it |
|---|---|---|
| QCF V2 on pages 256, 270 and word-level ayah mapping | per-word V2 glyph codes | QUL "Quran script → QCF V2 glyph codes" export |
| Digital Khatt layout | `digitalkhatt` Madina font | digitalkhatt.org (open source) |
| Indopak 15/13-line layouts (print-faithful) | the Nastaleeq fonts `indopak-nastaleeq` and `mushaf-indopak-nastaleeq-hanafi-compressed`; IndoPak word text per QUL word id (derivable from the Gaba lines with the 32-line override list, or QUL's "Indopak script" word export). `font.ttf` can stand in for the fonts with a different typeface | QUL |
| QPC Nastaleeq layout | KFGQPC Nastaleeq text data (610-page edition) | qurancomplex.gov.sa "Nastaleeq" package |
| Hizb / rub' / sajdah / manzil navigation | standard metadata table | Tanzil metadata or quran.com; cross-check with ۞ positions |
| Tajweed colours without COLR support | monochrome V4 fonts | QUL (V4 non-colour variant) |

## 7. Licensing notes (verify before release)

- KFGQPC fonts and texts: free to use for non-commercial purposes with attribution and without altering the Quranic text (per the Complex's published terms). Confirm the exact terms for an app-store release.
- QUL (Tarteel) resources: redistributable with attribution; the QCF fonts inside QUL originate from KFGQPC and carry the same conditions.
- Keep an in-app "About / Sources" screen listing every source and version (Hafs v2.0/v2.2, Warsh v2.1, …).

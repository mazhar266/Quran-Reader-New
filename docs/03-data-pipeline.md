# 03 · Data pipeline: from `resources/` to app assets

Goal: a reproducible, scripted conversion of the raw KFGQPC and QUL resources into one small SQLite content database plus font assets. Nothing in `resources/` is read by the app at runtime.

## 1. Tooling

- Python 3.12 (present), `sqlite3` module (present) and CLI (installed), `fontTools` (`pip install fonttools`) for font inspection, subsetting and hint stripping.
- Scripts live in `tools/` and are run with `python -m tools.build` from the repo root. Inputs are the zips in `resources/`; outputs go to `assets/db/`, `assets/fonts/` and `build/packs/`.
- Every step ends with assertions; the build fails loudly on any count mismatch.

```
tools/
  build.py              orchestrates the steps below
  extract.py            unzips into build/extract/ (idempotent)
  kfgqpc_data.py        loads the JSON of each riwayah → ayah rows
  kfgqpc_docx.py        parses the whole-mushaf docx → page/line rows
  qul_layout.py         reads the QUL layout DBs
  qul_docx.py           parses pages-KFGQPC-v4 (glyph lines) and pages.zip (Gaba lines)
  words.py              builds the global word table and the KFGQPC↔QUL id alignment
  fonts.py              copies/renames fonts, strips hinting, builds packs + manifest
  schema.sql            content DB DDL
  checks.py             validation suite
```

## 2. Content database schema

```sql
CREATE TABLE mushafs (
  id TEXT PRIMARY KEY,            -- 'madinah_hafs', 'qcf_v2', ...
  name TEXT, name_ar TEXT,
  pages INTEGER, lines_per_page INTEGER,
  mode TEXT,                      -- 'unicode' | 'glyph'
  font_family TEXT,               -- mode unicode: family name; mode glyph: family prefix ('QCF2_p')
  pack_id TEXT,                   -- NULL when bundled
  font_scale REAL, line_scale REAL,   -- K and L from the app plan
  edition_note TEXT,              -- e.g. 'KFGQPC Hafs v2.2, current Madinah edition'
  source TEXT                     -- attribution line
);
CREATE TABLE surahs (
  number INTEGER PRIMARY KEY, name_ar TEXT, name_en TEXT, ayah_count INTEGER   -- Hafs count
);
CREATE TABLE pages (
  mushaf_id TEXT, page INTEGER, line INTEGER,
  kind TEXT,                      -- 'ayah' | 'surah' | 'basmala'
  centered INTEGER,               -- 1 = centre, 0 = justify
  surah INTEGER,                  -- for kind='surah'
  text TEXT,                      -- Unicode line or glyph-code line; NULL for surah/basmala rows
  first_surah INTEGER, first_ayah INTEGER, last_surah INTEGER, last_ayah INTEGER,
  PRIMARY KEY (mushaf_id, page, line)
);
CREATE TABLE ayahs (
  mushaf_id TEXT, surah INTEGER, ayah INTEGER,
  page INTEGER, line_start INTEGER, line_end INTEGER,
  juz INTEGER, text TEXT, text_plain TEXT,
  PRIMARY KEY (mushaf_id, surah, ayah)
);
CREATE INDEX ayahs_page ON ayahs (mushaf_id, page);
CREATE TABLE words (               -- QUL global word ids, Hafs numbering
  word_id INTEGER PRIMARY KEY, surah INTEGER, ayah INTEGER, position INTEGER, is_ayah_mark INTEGER, text TEXT
);
CREATE TABLE line_words (          -- mode glyph mushafs only
  mushaf_id TEXT, page INTEGER, line INTEGER, first_word_id INTEGER, last_word_id INTEGER,
  PRIMARY KEY (mushaf_id, page, line)
);
CREATE TABLE juz (number INTEGER PRIMARY KEY, surah INTEGER, ayah INTEGER);
CREATE TABLE hizb_quarters (idx INTEGER PRIMARY KEY, surah INTEGER, ayah INTEGER);   -- from Tanzil metadata (to fetch)
CREATE TABLE sajdahs (surah INTEGER, ayah INTEGER, kind TEXT);
```

Size estimate: six riwayat × (9,046 lines + ~6,230 ayahs) plus two glyph mushafs ≈ 8–12 MB uncompressed. Ship it as an asset and copy it to the app support directory on first run (keyed by a `db_version` in a `meta` table).

## 3. Steps

### 3.1 KFGQPC riwayat (mode A)

For each of Hafs, Warsh, Qaloun, Douri, Shu'bah, Sousi:

1. Load `*Data*.json` → `ayahs` rows. Normalise:
   - `page` `'85-86'` → keep `page = 85` for the row and add a second `ayahs` entry for page 86 with the same key only if needed by lookups; simplest: store `page` as the first page and `page_end` as the second (add column). Four to five rows per riwayah.
   - Strip leading `۞` + U+00A0 from `text` into a boolean `has_rub_mark` (keep it in the line text, see below).
   - Verify the ayah mark is `U+FC00 + ayah − 1`; if missing (one Shu'bah row) append it.
   - `text_plain` from `aya_text_emlaey` (Hafs only); for other riwayat derive a diacritics-stripped fallback.
2. Parse the docx (`word/document.xml`): walk paragraphs; `<w:br w:type="page"/>` ends a page; `<w:br/>` ends a line; the paragraph's `w:jc` gives `centered` (`center`) vs justified (`both`). Classify lines: starts with `سُورَةُ` → `surah` (map the name to a surah number via the JSON's `sura_name_ar`, or by order); centered basmala text (without an ayah number) → `basmala`; else `ayah`.
3. Rewrite ayah numbers in the docx line text from Arabic-Indic digits to the `U+FC00` mark so both sources agree, and keep the no-break space before it.
4. Assign ayah keys to lines by consuming the JSON ayah tokens in order (split on space/U+00A0, ignore `۞`). Set `first/last_surah/ayah` per line.
5. Assertions: 604 pages; 602 pages × 15 lines + 2 × 8; 114 `surah` lines; 112 `basmala` lines (Al-Fatihah and At-Tawbah have none); token count per page equals the JSON's; every ayah's derived `(line_start, line_end)` equals the JSON's; ayah count equals 6236 / 6214 / 6214 / 6217 / 6236 / 6217.

### 3.2 QUL layouts (mode B and Qatar)

1. Read `pages` from `qpc-v2-15-lines.db`, `qpc-v4-tajweed-15-lines.db`, `mushaf-qatar-layout.db` → `line_words` plus `pages` rows with `kind`/`centered`/`surah`.
2. Build `words` from the KFGQPC Hafs tokens (ayah marks as words) and align to QUL ids: the totals differ by two words on pages 262, 378, 441, 451. Inspect those four pages by hand once, record the fix as a small override table in `words.py`, and assert that per-page word counts then match on all 604 pages.
3. **V4 line text**: parse `pages-KFGQPC-v4/{page}.docx`; paragraph i is ayah line i of that page (skip `surah`/`basmala` rows when zipping with the DB). Store the code string as `text`. Assert the number of paragraphs equals the number of `ayah` rows for every page and that every code is in the page font's cmap.
4. **V2 line text**: reuse the V4 strings for the 602 pages where the V2 and V4 `U+FC41…` runs have the same length; for pages 256 and 270 obtain QUL's per-word V2 codes (missing resource) or, until then, mark those two pages as "render with V4 codes, verify visually" and log a TODO.
5. **Qatar**: `text` per line = join of the Hafs words `first_word_id..last_word_id` (from `words`), with a space between words and U+00A0 before ayah marks. Mode A with the KFGQPC Hafs font.

### 3.3 Metadata

- `surahs`: from the Hafs JSON (`sura_no`, `sura_name_ar`, `sura_name_en`, count of ayahs).
- `juz`: first ayah with each `jozz` value in Hafs (30 rows). Cross-check with the other riwayat (ayah numbers differ, so store per-mushaf juz start pages in a `mushaf_juz_pages` table derived from `ayahs`).
- `hizb_quarters`, `sajdahs`: not in the resources. Fetch Tanzil `quran-data.xml` (or quran.com metadata) into `resources/meta/` and check that the 199 `۞` positions in Hafs are a subset of the quarter starts.

### 3.4 Fonts

Bundled (`assets/fonts/`, declared in `pubspec.yaml`):

| asset file | family declared in pubspec | source |
|---|---|---|
| `KFGQPC-Hafs.ttf` | `KFGQPC Hafs` | `qul/fonts/UthmanicHafs_V22.ttf` (or Complex v2.0 if spike 1 prefers it) |
| `KFGQPC-Warsh.ttf` … `KFGQPC-Sousi.ttf` | `KFGQPC Warsh` … | `qul/fonts/uthmanic-*-v2x.ttf` (or the Complex builds) |
| `SurahName-v2.ttf` | `SurahNameV2` | `qul/fonts/surah-name-v2.ttf` |
| `QuranCommon.ttf` | `QuranCommon` | `qul/fonts/quran-common.ttf` |
| `AlQuranIndoPak.ttf` | `AlQuran IndoPak` | `qul/font.ttf` (for `indopak_9_gaba`; bundle from v1.2) |

Packs (`build/packs/`, not bundled):

- `qcf_v2/p1.ttf … p604.ttf` from `QPC V2 Font.ttf/`; `qcf_v4/p1.ttf …` from `ttf/`.
- Optional hint stripping with fontTools (`font['fpgm']`, `prep`, `cvt `, `hdmx`, `VDMX`, `LTSH` removed; keep `COLR`/`CPAL` in V4). Re-verify cmap unchanged.
- Zip per pack; write `manifest.json` `{ "id", "version", "bytes", "sha256", "fonts": 604 }`.
- The app registers page fonts under family `QCF2_p{n}` / `QCF4_p{n}` at load time; the file name is the contract.

### 3.5 Indopak 9-line Gaba (mode A)

1. Read `indopak-9-lines-gaba.db` → `pages` rows (`surah` rows carry the surah number; the print has one `basmallah` row, all other basmalas are inline text).
2. Parse `pages.zip/{page}.docx`: paragraph i is ayah line i of the page (line counts match the DB on all 1890 pages); `w:jc` `center` → `centered`. Store the text verbatim (it must keep the PUA markers).
3. Ayah keys per line: scan the text for ayah-number glyphs `U+F500 + n − 1` (and the variant codes listed in inventory §5.3); the current surah comes from the last `surah` row. Cross-check the total against 6236 and the per-surah counts.
4. Assertions: 1890 pages; per-page line counts equal the DB; every code point of every line is in the font's cmap (418 distinct today).
5. Optional (only for the 15/13-line Indopak layouts): tokenise lines with the two rules from inventory §3.1, apply the 32-line override list, and assert the per-line counts equal `last_word_id − first_word_id + 1`; then store IndoPak `text` per word id in `words`.

### 3.6 Validation suite (`tools/checks.py`)

- Structural counts listed in §3.1 and §3.2 for every mushaf.
- Every `pages.text` in mode A contains only code points the mushaf font maps (use fontTools cmap); every mode B code is in its page font.
- Round trip: concatenating all ayah lines of a mode A mushaf reproduces the JSON `aya_text` sequence (after normalising the ayah-mark form).
- Spot-render a few pages to PNG for eyeballing. Pillow on this machine is built with Raqm (HarfBuzz) and shapes Arabic correctly (`ImageFont.truetype(..., layout_engine=ImageFont.Layout.RAQM)`, `draw.text(..., direction='rtl', language='ar')`); `pango-view` is also available. ImageMagick alone does not shape Arabic.

## 4. Runtime contract for the app

- Open `quran_reader.db` read-only; query `pages WHERE mushaf_id=? AND page=? ORDER BY line`.
- Mode A: `TextStyle(fontFamily: mushafs.font_family)`; Mode B: `TextStyle(fontFamily: '${prefix}${page}')` after `FontRegistry.ensurePageFont(mushaf, page)`.
- Surah header row: draw frame + `SurahNameV2` glyph `String.fromCharCode(0xE000 + surah)` (surah 102 → `0xE102`).
- Basmala row (mode A): the mushaf font renders `بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ` centred; (mode B): the page's basmala codes if present in the line string, else `QuranCommon` `U+FDFD`.

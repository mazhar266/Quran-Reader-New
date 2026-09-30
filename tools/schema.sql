-- Content database of Quran Reader (read-only in the app).
-- Built by `python3 -m tools.build`; see docs/03-data-pipeline.md.

CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);

CREATE TABLE mushafs (
  id TEXT PRIMARY KEY,              -- 'madinah_hafs', 'indopak_9_gaba', ...
  name TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  description TEXT NOT NULL,        -- one line for the picker
  riwayah TEXT NOT NULL,            -- 'hafs', 'warsh', ... (ayah numbering family)
  script TEXT NOT NULL,             -- 'uthmani' | 'indopak'
  pages INTEGER NOT NULL,
  lines_per_page INTEGER NOT NULL,
  mode TEXT NOT NULL,               -- 'unicode' | 'glyph'
  font_family TEXT NOT NULL,        -- family declared in pubspec.yaml
  pack_id TEXT,                     -- NULL when bundled
  font_scale REAL NOT NULL,         -- K: fontSize = textWidth / K
  line_scale REAL NOT NULL,         -- L: minimum line pitch in em
  header_basmala INTEGER NOT NULL,  -- 1: the surah header slot also carries the basmala
  basmala TEXT NOT NULL,            -- basmala in this mushaf's script and font
  edition_note TEXT NOT NULL,
  source TEXT NOT NULL,
  sort INTEGER NOT NULL
);

CREATE TABLE surahs (
  number INTEGER PRIMARY KEY,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  ayah_count INTEGER NOT NULL       -- Hafs count
);

CREATE TABLE pages (
  mushaf_id TEXT NOT NULL,
  page INTEGER NOT NULL,
  line INTEGER NOT NULL,
  kind TEXT NOT NULL,               -- 'ayah' | 'surah' | 'basmala'
  centered INTEGER NOT NULL,        -- 1 = centre, 0 = justify
  surah INTEGER,                    -- surah and basmala rows
  text TEXT,                        -- ayah rows (and KFGQPC basmala/header text)
  first_surah INTEGER, first_ayah INTEGER, last_surah INTEGER, last_ayah INTEGER,
  PRIMARY KEY (mushaf_id, page, line)
) WITHOUT ROWID;

CREATE TABLE ayahs (
  mushaf_id TEXT NOT NULL,
  surah INTEGER NOT NULL,
  ayah INTEGER NOT NULL,            -- numbering of that mushaf's riwayah
  page INTEGER NOT NULL,
  line INTEGER NOT NULL,
  juz INTEGER NOT NULL,
  PRIMARY KEY (mushaf_id, surah, ayah)
) WITHOUT ROWID;
CREATE INDEX ayahs_page ON ayahs (mushaf_id, page);

CREATE TABLE mushaf_surahs (        -- where each surah starts in a mushaf
  mushaf_id TEXT NOT NULL,
  surah INTEGER NOT NULL,
  page INTEGER NOT NULL,
  ayah_count INTEGER NOT NULL,
  PRIMARY KEY (mushaf_id, surah)
) WITHOUT ROWID;

CREATE TABLE mushaf_juz (           -- where each juz starts in a mushaf
  mushaf_id TEXT NOT NULL,
  juz INTEGER NOT NULL,
  page INTEGER NOT NULL,
  surah INTEGER NOT NULL,
  ayah INTEGER NOT NULL,
  PRIMARY KEY (mushaf_id, juz)
) WITHOUT ROWID;

CREATE TABLE ayah_text (            -- plain (imla'i) Hafs text, for accessibility and later search
  surah INTEGER NOT NULL,
  ayah INTEGER NOT NULL,
  text TEXT NOT NULL,
  PRIMARY KEY (surah, ayah)
) WITHOUT ROWID;

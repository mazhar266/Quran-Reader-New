# Quran Reader · planning docs

A Flutter app for reading the Quran page by page in several mushafs. Reading only: no tafsir, translation or audio.

- App name: **Quran Reader**
- Application id: `fi.mazhar.quran.reader`

| document | what it answers |
|---|---|
| [01-resource-inventory.md](01-resource-inventory.md) | What exactly is in `resources/` (KFGQPC + QUL), formats, encodings, measured counts, quirks, and what is missing |
| [02-app-plan.md](02-app-plan.md) | Scope, mushaf catalog, architecture, rendering strategy, milestones, spikes, risks |
| [03-data-pipeline.md](03-data-pipeline.md) | How to turn the resources into the app's SQLite database and font assets, with validation |
| [04-implementation.md](04-implementation.md) | What is built, how it was verified, and what the implementation learned about the data |
| [images/](images/) | Shaped test renders: Gaba 9-line pages 1 and 1000 with `font.ttf`, and its private-use marker glyphs |
| [ereader-pdf/](ereader-pdf/README.md) | Second series: generating 6-inch e-reader PDF books (Kindle, Kobo, PocketBook) from the same data |

## Key findings in one screen

1. **Six riwayat are fully buildable today**: the KFGQPC packages for Hafs, Warsh, Qaloun, Douri, Shu'bah and Sousi each contain a Unicode font *and* a Word document whose explicit page/line breaks give the exact 604-page, 15-line Madinah layout. Verified against the packages' own ayah line data.
2. **QCF V2 and V4 (tajweed) are buildable as downloadable packs**: QUL provides the 1421H line layout, per-page fonts (198 MB and 159 MB), and per-line glyph strings for V4. V2 and V4 fonts share the same glyph codes on 602 of 604 pages (pages 256 and 270 need QUL's V2 word codes).
3. **The two layout sources are different editions**: KFGQPC lines differ from the QUL 1421H lines on about one line in six. They must be separate mushafs in the app.
4. **QUL word ids** (1 … 83,668, ayah markers included) align with KFGQPC Hafs words except on four pages (262, 378, 441, 451), so a small override table gives word→ayah mapping for the QCF mushafs.
5. **Indopak 9-line (Gaba) is buildable**: `qul/font.ttf` (AlQuran IndoPak by QuranWBW) covers every code point of the 1890 page files and renders them correctly with HarfBuzz shaping (see `images/`). **Not buildable yet**: Indopak 15/13-line (fonts missing, word text derivable), Digital Khatt and QPC Nastaleeq; the SVG colour surah-name font is unusable in Flutter. Hizb/rub' metadata must be fetched (Tanzil).
6. **Main technical risks**: COLR v0 colour-font support in Flutter (tajweed), Flutter's inability to justify a one-line paragraph (solved with a custom line layout), and keeping the base app small by shipping per-page fonts as packs.

## Suggested order of work

Milestone 0 (setup + spikes) → 1 (pipeline) → 2 (Hafs reader) → 3 (all six riwayat) → 4 (release 1.0) → 5 (QCF packs) → 6 (Qatar, tablets) → backlog.

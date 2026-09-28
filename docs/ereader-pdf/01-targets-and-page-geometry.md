# 01 · Targets and page geometry

## 1. Target devices

All mainstream 6-inch e-ink readers share one physical panel format: 3:4 aspect, about 90.8 × 122.6 mm.

| device family | panel | ppi | notes |
|---|---|---|---|
| Kindle (2019–2024 basic), Kindle Paperwhite 6" (2018 and older) | 1072 × 1448 (300 ppi) or 758 × 1024 (212 ppi) | 212–300 | PDF viewer has no reflow; landscape needs a manual toggle; shows PDF outline under "Go to" |
| Kobo Clara HD / 2E / BW / Colour, Kobo Nia | 1072 × 1448 or 758 × 1024 | 212–300 | good PDF viewer, outline supported, KOReader installable |
| PocketBook Basic / Verse / Touch Lux (6") | 758 × 1024 or 1072 × 1448 | 212–300 | PDF outline supported |
| Tolino Page / Shine (6") | 1072 × 1448 | 300 | Kobo-based |
| any device running KOReader | as above | | best PDF engine (MuPDF), supports custom zoom, margins crop, contrast |

Design once for the **6-inch profile**: page size **90.8 × 122.6 mm** (exactly 1072 × 1448 px at 300 ppi). A 7-inch profile (Kobo Libra, Kindle Paperwhite 2021+: 1264 × 1680, 300 ppi, 107 × 142 mm) can be added later by changing two numbers; every other rule stays.

## 2. E-ink constraints that shape the design

- **Grayscale (16 levels).** Colour carries no information; tajweed colouring (QCF V4) becomes shades of gray. Use black text on white only.
- **No reflow for Arabic PDF.** Kindle/Kobo PDF reflow is unreliable for RTL text, so every book is a sequence of fixed screens sized exactly to the panel. Readers show it at "fit page" with no scaling artefacts.
- **Sharp vector text at any ppi.** Embed subsetted TrueType fonts; never rasterise pages.
- **Slow page turns.** Fewer, denser screens are better than many sparse ones, but not at the cost of font size. Avoid per-page decorations that force full refreshes (large black areas).
- **Reader-added margins.** Kindle keeps a small border around PDF pages; keep the page's own margins at 3 mm so the text block stays as large as possible.
- **Navigation.** Readers support PDF outlines (bookmarks). A surah/juz outline replaces a printed index; internal links work on Kobo/KOReader and partially on Kindle.

## 3. Page anatomy

```
┌──────────────── 90.8 mm ────────────────┐
│ 3 mm margin                              │
│ header 4.5 mm: juz · surah · page label  │
│                                          │
│ text block 84.8 × 107.6 mm               │  122.6 mm
│   N lines of height 107.6 / N mm         │
│                                          │
│ footer 4.5 mm: printed page number       │
│ 3 mm margin                              │
└──────────────────────────────────────────┘
```

Header and footer use the mushaf's own font at 2.6–2.8 mm (about 7.5 pt) so no extra font is embedded.

## 4. Reading modes

| mode | what a screen shows | keeps printed line breaks | keeps printed page numbers |
|---|---|---|---|
| **F · faithful** | one printed page (15 lines Madinah, 9 lines Gaba) | yes | yes, one to one |
| **S · split** | half a printed page: lines 1–8, then 9–15 | yes | yes, labelled `50 (1/2)`, `50 (2/2)` |
| **L · rotated** | a third of a printed page (5 lines) laid out along the long side of the screen; the PDF page carries `/Rotate 90`, so the reader shows it as a portrait page and the user turns the device sideways | yes | yes, labelled `50 (1/3)` … `50 (3/3)` |
| **R · reflow** | continuous text wrapped by the renderer | no | as inline markers `[50]` where each printed page begins, plus the header showing the current printed page |

## 5. Measured typography (re-analysed)

All measurements use HarfBuzz shaping (Pillow/Raqm) on the extracted resources; widths and heights are in em (multiples of the font size). The first analysis used a flat 1.9 em line pitch and the maximum line width; this pass measured both limits and found that **the widest line, not the height, decides the size in every exact-line mode**, which is why half-page screens looked empty while the text stayed small.

### 5.1 Vertical limit: how close can lines sit?

| font | max ascent above baseline | max descent | max of (descent of a line + ascent of the next) | safe pitch |
|---|---|---|---|---|
| KFGQPC Hafs v2.2 (8,932 lines) | 1.22 em | 0.62 em | 1.79 em | **1.80 em** |
| KFGQPC Warsh v2.1 (8,932 lines) | 1.16 em | 0.61 em | 1.73 em | 1.75 em |
| QCF V2 page fonts (12 sample pages) | 1.46 em | 0.70 em | 2.03 em | **2.05 em** |
| AlQuran IndoPak, Gaba lines (1,687 lines) | 1.27 em | 0.66 em | 1.81 em | **1.85 em** |

At these pitches consecutive lines never touch (the value is the worst pair in the whole text). The tight faithful page at 1.78 em renders cleanly (`images/hafs-faithful-tight-11pt-page-507.png`, the page with the widest Hafs line).

### 5.2 Horizontal limit: the widest line

| font | widest | 99 % | 95 % | 90 % | median |
|---|---|---|---|---|---|
| KFGQPC Hafs | 22.54 em | 20.37 | 18.95 | 18.31 | 15.96 |
| KFGQPC Warsh | 23.75 em | 20.86 | 19.51 | 18.88 | 16.51 |
| QCF V2 (sum of word advances, no spaces) | 18.05 em (lines beside headers) | | | | 15.7 typical |
| AlQuran IndoPak, Gaba | 13.22 em | 10.76 | 10.14 | 9.73 | 8.57 |

Size rule: `size = block width / W`, where `W` is the widest line the book must show at full size. Allowing a **per-line shrink of at most 16 % on the widest 5 % of lines** lets `W` be the 95th percentile instead of the maximum. Shrinking more lines, or by more, becomes visible as uneven text.

### 5.3 Resulting sizes per mode

Text block: 84.8 × 107.6 mm portrait, 116.6 × 75.8 mm rotated (3 mm margins, 4.5 mm header and footer).

| mode | lines / screen | pitch | height allows | width allows | **result** | tier |
|---|---|---|---|---|---|---|
| F · Hafs, 15 lines | 15 | 7.17 mm (1.78 em) | 3.99 mm | 3.76 mm without shrink; 4.47 with | **3.99 mm ≈ 11.3 pt** (< 1 % of lines shrunk ≤ 7 %) | small (pocket mushaf) |
| F · Warsh and the other riwayat | 15 | 7.17 mm | 3.99 mm | 3.57 without; 4.35 with | **≈ 11.3 pt** (≈ 3 % of lines shrunk ≤ 11 %) | small |
| F · QCF V2, 15 lines | 15 | 7.17 mm | 3.50 mm (2.05 em) | 5.3 mm | **3.5 mm ≈ 10 pt** | small |
| S · Hafs, 8 + 7 | 8 | 13.45 mm | 7.47 mm | 4.47 mm | **12.7 pt**, lower half of the pitch empty | standard, but wasteful: use L instead |
| S · QCF V2, 8 + 7 | 8 | 13.45 mm | 6.56 mm | 5.3 mm (15.75 em + ink overhang) | **5.3 mm ≈ 15 pt** (outliers beside headers shrunk ≤ 13 %) | comfortable |
| F · Gaba, 9 lines | 9 | 11.96 mm | 6.46 mm | 6.2 mm (13.22 em + 0.46 em overhang) | **6.2 mm ≈ 17.6 pt** | large |
| L · Hafs, 5 lines rotated | 5 | 15.16 mm (2.46 em) | 8.4 mm | 6.15 mm (95th pct.) | **6.15 mm ≈ 17.4 pt** (5 % of lines shrunk ≤ 16 %) | large |
| L · QCF V2, 5 lines rotated | 5 | 15.16 mm (2.07 em) | 7.4 mm | 7.3 mm | **7.3 mm ≈ 20.5 pt** | large |
| R · reflow, Hafs and riwayat | 8–11 | 1.85 em | n/a | n/a | **14 pt ≈ 750 screens · 16 pt ≈ 1,000 (measured) · 18 pt ≈ 1,180 · 20 pt ≈ 1,480** | standard to large |

Screens per mushaf: F 604; S 1,206; L 1,808 (5 + 5 + 5, pages 1–2 have 8 lines → 2 screens); Gaba F 1,890.

**Readability tiers** used above, for fully vocalised Uthmani script on a 300 ppi panel: below 11 pt *small* (pocket-mushaf size, fine for reference and memorisation checks, tiring for long reading); 11–13 pt *standard* (about the glyph size of the common 14 × 20 cm printed mushaf); 13–16 pt *comfortable*; above 16 pt *large print*. For comparison, e-readers set Latin body text at 10–11 pt, and vocalised Arabic needs roughly 1.3× that to read equally well.

**Conclusion**: in portrait, exact-line books cannot get past 11–13 pt (Hafs) or 15 pt (QCF) no matter how few lines a screen holds. Larger exact-line text needs the long side of the screen (mode L: 17–20 pt) and larger free-flowing text needs reflow (mode R at 16–20 pt). Half-page portrait screens (mode S) only pay off for QCF.

### 5.4 Two rendering pitfalls found on the way

- **QCF V2 page fonts map no space character.** Their character maps start at U+F777, so a browser substitutes a fallback font's space (about 0.25 em instead of the 0.04 em a measurement tool assumes) and every justified line overflows by about 10 mm. Lay out each word in its own span inside a flex line with `justify-content: space-between`; no space glyphs are rendered and the last line of a paragraph justifies without `text-align-last`. Verified: ink ends 0.7 mm inside the margin, which is exactly the glyph overhang below.
- **Ink extends beyond the advance width at line ends**: up to 0.12 em (QCF), 0.22 em (Hafs, Warsh) and 0.46 em (Gaba). Fit lines by ink extent (sum of word advances plus both overhangs), not by advance alone, or reserve that much extra margin.

## 6. Which mushaf gets which mode

| mushaf | F (portrait, exact) | S (portrait, half page) | L (rotated, exact) | R (reflow) |
|---|---|---|---|---|
| Madinah Hafs (KFGQPC font) | 11.3 pt, reference | skip | **17.4 pt**, for exact lines at a large size | **16 pt primary, 20 pt large print** |
| Madinah Warsh, Qaloun, Douri, Shu'bah, Sousi | 11.3 pt, reference | skip | 17 pt | 16 pt primary |
| QCF V2 (1421H, per-page fonts) | 10 pt, reference only if asked | **15 pt primary** | **20.5 pt** large print | not possible (glyph codes cannot reflow) |
| Indopak 9-line Gaba (`font.ttf`) | **17.6 pt primary** | not needed | not needed | optional |
| QCF V4 tajweed | colour e-ink only | colour e-ink only | colour e-ink only | not possible |
| Mushaf Qatar | optional | optional | optional | same text as Hafs |

# 04 · QA and device testing

## 1. Pre-release checklist per book

1. `pdfinfo`: page size 257.04 × 347.53 pt (90.8 × 122.6 mm), page count as expected, PDF 1.5+ and no encryption.
2. `pdffonts`: all fonts `emb=yes sub=yes`; list matches the book's expected font set (mushaf font, optional surah-name/common fonts, one Latin font for numerals if allowed).
3. Outline present: surah entries (114) and juz entries (30), titles in Arabic, targets land on the right screen (spot-check 10).
4. Metadata: Title, Author, Language `ar`, Subject contains mushaf id, mode, profile and data build id.
5. Front matter: sources/licence screen present; surah and juz indexes link to the correct screens.
6. Text round trip passes (03 §5); no overflow warnings; ayah count of the book equals the riwayah's count (6236 / 6214 / 6217).
7. Visual golden set unchanged, or changes reviewed.
8. File size within the target (reflow/faithful < 10 MB; QCF split as measured; anything over 50 MB documented as "USB transfer only").

## 2. Device matrix

| device | firmware viewer | what to check |
|---|---|---|
| Kindle (2022 basic or Paperwhite 6") | native | fit-page shows the whole screen without cropping; text sharp; outline in "Go to"; page turn speed; margins not doubled |
| Kobo Clara (any) | native + KOReader | same; internal links from the surah index; contrast; landscape auto-rotate off |
| PocketBook 6" | native | outline; zoom mode "fit width" vs "fit page" |
| KOReader (any device) | MuPDF | set zoom "page", no crop; verify no re-rendering delay on QCF book |
| Desktop sanity | Chrome, Firefox, Okular/Evince | shaping and marks render identically to the 300 ppi previews |

Test screens: front matter, page 1 (Fatihah, 8 lines), page 2, page 3 (dense), page 50 (surah header mid-page), page 77, page 255, page 507 (widest Hafs line), page 604 (three surahs), a juz boundary, a sajdah ayah, a hizb ornament.

## 3. Getting books onto devices

- **USB**: copy to `documents/` (Kindle) or the root/`books` folder (Kobo, PocketBook). Works for any size.
- **Send to Kindle**: e-mail (50 MB limit) or the web/app uploader (200 MB); keep "convert" off so the PDF stays a PDF.
- **Kobo**: Dropbox/Google Drive sync on newer firmware; KOReader can fetch over Wi-Fi from a local server.
- Publish with a checksum file and the version in the file name; keep the previous version available.

## 4. Known reader quirks and mitigations

- **Kindle PDF border**: Kindle draws its own margin; our 3 mm margins are already minimal. Do not add decorative frames that would be clipped.
- **Kindle and RTL**: page order is linear; readers turn pages with the same gesture regardless of script, so no special handling. Kindle's "book" direction setting does not apply to PDFs.
- **Rotated books (mode L)**: pages carry `/Rotate 90`, which every tested viewer honours, so the reader shows a portrait page with the lines running along its long side; the user turns the device a quarter turn (page-turn buttons then sit at the bottom or top). Check on each device that the viewer does not add its own auto-rotation on top, and that "fit page" still fills the screen.
- **Zoom persistence**: Kobo/Kindle remember zoom per book; ship pages that need no zoom (fit page = 100 %).
- **Gray levels**: very thin strokes in the QCF fonts can look light on 212 ppi devices; if so, add a light `-webkit-text-stroke: 0.05mm` on QCF text and re-test (do not use on Unicode fonts, it thickens marks).
- **Hairline borders**: 0.35 mm double borders render fine; anything under 0.2 mm may disappear at 212 ppi.
- **Large files**: the QCF V2 book opens slower and page thumbnails may lag; state this in the catalogue.
- **Colour e-ink (Kaleido)**: 4096 colours at reduced resolution; tajweed colours are visible but text is softer. Offer QCF V4 only as a separate optional book.

## 5. Reading recommendations to include in the download page

- Reflow books (16 pt, or the 20 pt large-print edition) for daily reading; rotated books (`-rotated-`, 17–20 pt) for the exact printed lines at a large size, holding the device sideways; faithful (`-pages-`, 11 pt) books for memorisation by page; the QCF split book (15 pt) for the printed Madinah lines in portrait.
- On Kindle choose "Fit page"; on Kobo disable "Landscape"; on KOReader set zoom mode to "page" and disable "crop".
- All books are free and unaltered reproductions of the King Fahd Complex and QUL texts; the sources screen lists versions.

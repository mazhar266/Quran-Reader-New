# E-reader books (6-inch)

Ready-to-read PDF mushafs for 6-inch e-ink readers (Kindle, Kobo, PocketBook, Tolino, KOReader),
built by `tools/ereader/` (`python3 -m tools.ereader.build`). Screens are 90.8 × 122.6 mm, the text is
vector with embedded fonts, and each book has an outline (surahs, juz) and linked surah and juz
indexes. The smallest Quran text in any book is 16 pt.

| file | a screen shows | text |
|---|---|---|
| `quran-hafs-madinah-reflow-16pt-6in.pdf` | flowing text, 10 lines | 16 pt |
| `quran-hafs-madinah-reflow-20pt-6in.pdf` | flowing text, 8 lines (large print) | 20 pt |
| `quran-hafs-madinah-rotated-6in.pdf` | 5 printed lines, sideways | 17.1 pt |
| `quran-{warsh,qaloun,douri,shuba,sousi}-madinah-reflow-16pt-6in.pdf` | flowing text, 10 lines | 16 pt |
| `quran-{warsh,qaloun,douri,shuba,sousi}-madinah-rotated-6in.pdf` | 5 printed lines, sideways | 16.6–16.9 pt |
| `quran-indopak-gaba-9-lines-6in.pdf` | one printed 9-line page | 17.8 pt |
| `quran-hafs-madinah-reflow-16pt-tajweed-6in.pdf` | as the Hafs 16 pt book, with tajwid colours | 16 pt |
| `quran-hafs-madinah-reflow-20pt-tajweed-6in.pdf` | as the Hafs 20 pt book, with tajwid colours | 20 pt |
| `quran-hafs-madinah-rotated-tajweed-6in.pdf` | as the Hafs sideways book, with tajwid colours | 17.1 pt |
| `quran-indopak-gaba-9-lines-tajweed-6in.pdf` | as the Gaba book, with tajwid colours | 17.8 pt |

- **Daily reading**: the 16 pt flowing book of your riwayah, or the 20 pt book for large print. Small
  boxed numbers mark where each printed page begins, and the footer shows the printed pages on the screen.
- **The printed lines, large**: the sideways book; hold the reader in landscape. Each printed page is
  three screens.
- **Indopak readers**: the Gaba book, one printed page per screen.
- **Tajwid colours**: the `-tajweed-` books are the same screens with the letters coloured by the rule of
  recitation that applies to them (hamzat al-wasl and silent letters grey, madd blues, ghunnah orange, ikhfa
  purple, idgham greens, iqlab light blue, qalqalah red), with a legend after the title screen. Only the Hafs
  books have them: the annotation (KFGQPC's QPC Hafs tajwid text, through QUL) describes the Hafs recitation.
  They are meant for colour e-ink readers (Kobo Clara Colour and Libra Colour, Kindle Colorsoft, PocketBook
  Color); a greyscale screen shows the colours as shades of grey.

Copy a file to the reader over USB, or send it with Send to Kindle (every file is under 10 MB).
How the books are made and checked: [docs/ereader-pdf/05-generated-books.md](../docs/ereader-pdf/05-generated-books.md).

Quran text and fonts: King Fahd Glorious Quran Printing Complex (KFGQPC). Page layouts, IndoPak text,
tajwid annotation, surah-name and ornament fonts: Quranic Universal Library (QUL) by Tarteel. AlQuran IndoPak font:
QuranWBW. Each book's sources screen gives the full credits. Free of charge; not for sale.

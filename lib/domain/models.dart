/// Plain data classes shared by the data layer and the UI.
library;

/// A mushaf: one printed edition with its own page layout and font.
class Mushaf {
  const Mushaf({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.description,
    required this.riwayah,
    required this.script,
    required this.pages,
    required this.linesPerPage,
    required this.fontFamily,
    required this.fontScale,
    required this.lineScale,
    required this.headerBasmala,
    required this.basmala,
    required this.editionNote,
    required this.source,
  });

  final String id;
  final String name;
  final String nameAr;
  final String description;

  /// 'hafs', 'warsh', ...: ayah numbers are only comparable within a riwayah.
  final String riwayah;

  /// 'uthmani' or 'indopak'.
  final String script;
  final int pages;
  final int linesPerPage;
  final String fontFamily;

  /// K: the text block is K em wide (`fontSize = textWidth / K`).
  final double fontScale;

  /// L: the smallest line pitch, in em, that keeps adjacent lines apart.
  final double lineScale;

  /// Whether the surah header slot also carries the basmala (Indopak prints).
  final bool headerBasmala;
  final String basmala;
  final String editionNote;
  final String source;
}

class Surah {
  const Surah({required this.number, required this.nameAr, required this.nameEn, required this.ayahCount});

  final int number;
  final String nameAr;
  final String nameEn;

  /// Hafs count; a mushaf's own count is in [SurahStart.ayahCount].
  final int ayahCount;
}

class AyahKey implements Comparable<AyahKey> {
  const AyahKey(this.surah, this.ayah);

  final int surah;
  final int ayah;

  @override
  int compareTo(AyahKey other) => surah != other.surah ? surah - other.surah : ayah - other.ayah;

  @override
  bool operator ==(Object other) => other is AyahKey && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => '$surah:$ayah';
}

enum LineKind { ayah, surah, basmala }

class PageLine {
  const PageLine({
    required this.line,
    required this.kind,
    required this.centered,
    this.surah,
    this.text,
    this.first,
    this.last,
  });

  /// 1-based slot on the page.
  final int line;
  final LineKind kind;
  final bool centered;

  /// Surah number of a header or basmala line.
  final int? surah;
  final String? text;

  /// First and last ayah (of this mushaf's numbering) on an ayah line.
  final AyahKey? first;
  final AyahKey? last;

  /// Every ayah that has a word on this line.
  List<AyahKey> get ayahs => first == null || last == null
      ? const []
      : [for (var a = first!.ayah; a <= last!.ayah; a++) AyahKey(first!.surah, a)];
}

class MushafPage {
  const MushafPage({
    required this.mushafId,
    required this.page,
    required this.lines,
    required this.surah,
    required this.juz,
  });

  final String mushafId;
  final int page;
  final List<PageLine> lines;

  /// Surah shown in the page header: the surah of the first line.
  final int surah;
  final int juz;
}

class SurahStart {
  const SurahStart({required this.surah, required this.page, required this.ayahCount});

  final int surah;
  final int page;
  final int ayahCount;
}

class JuzStart {
  const JuzStart({required this.juz, required this.page, required this.key});

  final int juz;
  final int page;
  final AyahKey key;
}

class Bookmark {
  const Bookmark({required this.id, required this.mushafId, required this.page, this.ayah, required this.createdAt});

  final int id;
  final String mushafId;
  final int page;

  /// Null for a page bookmark.
  final AyahKey? ayah;
  final DateTime createdAt;
}

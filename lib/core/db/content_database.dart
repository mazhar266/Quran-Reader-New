import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models.dart';

/// Read-only access to `assets/db/quran_reader.db` (built by `tools/build.py`).
///
/// The asset is copied once to the application support directory because
/// SQLite needs a real file. The file name carries [version], so a new
/// content database in an app update replaces the old copy.
class ContentDatabase {
  ContentDatabase._(this._db);

  /// Must match `DB_VERSION` in tools/build.py.
  static const version = 1;
  static const _asset = 'assets/db/quran_reader.db';

  final Database _db;
  final _pageCache = <(String, int), MushafPage>{};
  final _juzCache = <String, List<JuzStart>>{};

  static Future<ContentDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'quran_reader_v$version.db'));
    if (!file.existsSync()) {
      final data = await rootBundle.load(_asset);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      await tmp.rename(file.path);
      for (final old in dir.listSync().whereType<File>()) {
        final name = p.basename(old.path);
        if (name.startsWith('quran_reader_v') && old.path != file.path) old.deleteSync();
      }
    }
    return openFile(file.path);
  }

  /// Opens a database file directly (tests, tools).
  static ContentDatabase openFile(String path) => ContentDatabase._(sqlite3.open(path, mode: OpenMode.readOnly));

  void close() => _db.close();

  List<Mushaf> mushafs() => [
    for (final r in _db.select('SELECT * FROM mushafs ORDER BY sort'))
      Mushaf(
        id: r['id'] as String,
        name: r['name'] as String,
        nameAr: r['name_ar'] as String,
        description: r['description'] as String,
        riwayah: r['riwayah'] as String,
        script: r['script'] as String,
        pages: r['pages'] as int,
        linesPerPage: r['lines_per_page'] as int,
        fontFamily: r['font_family'] as String,
        fontScale: (r['font_scale'] as num).toDouble(),
        lineScale: (r['line_scale'] as num).toDouble(),
        headerBasmala: r['header_basmala'] == 1,
        basmala: r['basmala'] as String,
        editionNote: r['edition_note'] as String,
        source: r['source'] as String,
      ),
  ];

  List<Surah> surahs() => [
    for (final r in _db.select('SELECT * FROM surahs ORDER BY number'))
      Surah(
        number: r['number'] as int,
        nameAr: r['name_ar'] as String,
        nameEn: r['name_en'] as String,
        ayahCount: r['ayah_count'] as int,
      ),
  ];

  List<SurahStart> surahStarts(String mushafId) => [
    for (final r in _db.select('SELECT surah, page, ayah_count FROM mushaf_surahs WHERE mushaf_id = ? ORDER BY surah', [
      mushafId,
    ]))
      SurahStart(surah: r['surah'] as int, page: r['page'] as int, ayahCount: r['ayah_count'] as int),
  ];

  List<JuzStart> juzStarts(String mushafId) => _juzCache.putIfAbsent(
    mushafId,
    () => [
      for (final r in _db.select('SELECT juz, page, surah, ayah FROM mushaf_juz WHERE mushaf_id = ? ORDER BY juz', [
        mushafId,
      ]))
        JuzStart(juz: r['juz'] as int, page: r['page'] as int, key: AyahKey(r['surah'] as int, r['ayah'] as int)),
    ],
  );

  /// Page of an ayah in a mushaf (its first line), or null if unknown.
  int? pageOfAyah(String mushafId, AyahKey key) {
    final rs = _db.select('SELECT page FROM ayahs WHERE mushaf_id = ? AND surah = ? AND ayah = ?', [
      mushafId,
      key.surah,
      key.ayah,
    ]);
    return rs.isEmpty ? null : rs.first['page'] as int;
  }

  MushafPage page(String mushafId, int page) =>
      _pageCache.putIfAbsent((mushafId, page), () => _loadPage(mushafId, page));

  MushafPage _loadPage(String mushafId, int page) {
    final rows = _db.select('SELECT * FROM pages WHERE mushaf_id = ? AND page = ? ORDER BY line', [mushafId, page]);
    final lines = [
      for (final r in rows)
        PageLine(
          line: r['line'] as int,
          kind: LineKind.values.byName(r['kind'] as String),
          centered: r['centered'] == 1,
          surah: r['surah'] as int?,
          text: r['text'] as String?,
          first: r['first_surah'] == null ? null : AyahKey(r['first_surah'] as int, r['first_ayah'] as int),
          last: r['last_surah'] == null ? null : AyahKey(r['last_surah'] as int, r['last_ayah'] as int),
        ),
    ];
    final first = lines.first;
    final surah = first.surah ?? first.first?.surah ?? 1;
    final firstAyah = lines.firstWhere((l) => l.first != null).first!;
    return MushafPage(mushafId: mushafId, page: page, lines: lines, surah: surah, juz: _juzOfAyah(mushafId, firstAyah));
  }

  int _juzOfAyah(String mushafId, AyahKey key) {
    final rs = _db.select('SELECT juz FROM ayahs WHERE mushaf_id = ? AND surah = ? AND ayah = ?', [
      mushafId,
      key.surah,
      key.ayah,
    ]);
    return rs.isEmpty ? 1 : rs.first['juz'] as int;
  }

  /// Plain Hafs spelling of an ayah (accessibility labels).
  String? plainText(AyahKey key) {
    final rs = _db.select('SELECT text FROM ayah_text WHERE surah = ? AND ayah = ?', [key.surah, key.ayah]);
    return rs.isEmpty ? null : rs.first['text'] as String;
  }
}

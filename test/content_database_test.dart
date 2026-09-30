import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/core/db/content_database.dart';
import 'package:quran_reader/domain/models.dart';

void main() {
  late ContentDatabase db;
  setUpAll(() => db = ContentDatabase.openFile('assets/db/quran_reader.db'));
  tearDownAll(() => db.close());

  test('ships eight mushafs in picker order', () {
    final ids = db.mushafs().map((m) => m.id).toList();
    expect(ids, [
      'madinah_hafs',
      'madinah_warsh',
      'madinah_qaloun',
      'madinah_douri',
      'madinah_shuba',
      'madinah_sousi',
      'qatar',
      'indopak_9_gaba',
    ]);
    expect(db.surahs(), hasLength(114));
  });

  test('every mushaf has complete navigation data', () {
    for (final m in db.mushafs()) {
      expect(db.surahStarts(m.id), hasLength(114), reason: m.id);
      expect(db.juzStarts(m.id), hasLength(30), reason: m.id);
      expect(db.surahStarts(m.id).last.page, m.pages, reason: m.id);
      expect(m.fontScale, greaterThan(5));
      expect(m.lineScale, inInclusiveRange(1.2, 2.5));
    }
  });

  test('Hafs page 2 starts Al-Baqarah', () {
    final page = db.page('madinah_hafs', 2);
    expect(page.lines.first.kind, LineKind.surah);
    expect(page.lines.first.surah, 2);
    expect(page.lines[1].kind, LineKind.basmala);
    expect(page.lines[2].first, const AyahKey(2, 1));
    expect(page.juz, 1);
  });

  test('ayah numbering follows the riwayah', () {
    // Al-Baqarah ends with ayah 286 in Hafs (Kufi count) and 285 in Warsh.
    expect(db.surahStarts('madinah_hafs')[1].ayahCount, 286);
    expect(db.surahStarts('madinah_warsh')[1].ayahCount, 285);
    expect(db.pageOfAyah('madinah_hafs', const AyahKey(2, 255)), 42);
  });

  test('pages are full', () {
    for (final (id, page, lines) in [('madinah_hafs', 604, 15), ('qatar', 262, 15), ('indopak_9_gaba', 1000, 9)]) {
      expect(db.page(id, page).lines, hasLength(lines), reason: '$id p$page');
    }
  });
}

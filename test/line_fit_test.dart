import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/app/theme.dart';
import 'package:quran_reader/core/db/content_database.dart';
import 'package:quran_reader/features/reader/mushaf_page.dart';
import 'package:quran_reader/features/reader/quran_line.dart';

import 'support/fonts.dart';

/// The pipeline derives each mushaf's width constant K from Pillow/HarfBuzz
/// measurements. Flutter shapes with HarfBuzz too, so justified lines should
/// fit their slot without being squeezed by more than a hair.
void main() {
  late ContentDatabase db;
  setUpAll(() async {
    await loadAppFonts();
    db = ContentDatabase.openFile('assets/db/quran_reader.db');
  });

  testWidgets('printed lines fit the page width in every mushaf', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final worst = <String, double>{};
    final counted = <String, int>{};
    for (final mushaf in db.mushafs()) {
      final step = mushaf.pages ~/ 40;
      for (var p = 1; p <= mushaf.pages; p += step) {
        await tester.pumpWidget(
          MaterialApp(
            home: MushafPageView(mushaf: mushaf, page: db.page(mushaf.id, p), palette: PagePalette.light),
          ),
        );
        for (final line in tester.renderObjectList<RenderQuranLine>(find.byType(QuranLine))) {
          worst[mushaf.id] = math.min(worst[mushaf.id] ?? 1, line.scaleX);
          counted[mushaf.id] = (counted[mushaf.id] ?? 0) + 1;
        }
      }
    }
    // ignore: avoid_print
    print('smallest horizontal scale per mushaf: $worst over $counted lines');
    expect(worst.keys, hasLength(db.mushafs().length));
    for (final entry in worst.entries) {
      expect(entry.value, greaterThan(0.97), reason: entry.key);
    }
  });
}

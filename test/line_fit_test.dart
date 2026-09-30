import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/app/theme.dart';
import 'package:quran_reader/core/db/content_database.dart';
import 'package:quran_reader/features/reader/mushaf_page.dart';
import 'package:quran_reader/features/reader/quran_line.dart';

import 'support/fonts.dart';

/// Renders pages of every mushaf on a phone and checks how lines are filled:
/// the text size comes from the pipeline's K (99.9th percentile of line
/// widths), so almost no line may need squeezing, and kashida must keep the
/// spaces between words close to normal.
void main() {
  late ContentDatabase db;
  setUpAll(() async {
    await loadAppFonts();
    db = ContentDatabase.openFile('assets/db/quran_reader.db');
  });

  testWidgets('printed lines fill the page width with kashida, not gaps', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    for (final mushaf in db.mushafs()) {
      final step = mushaf.pages ~/ 40;
      var lines = 0, squeezed = 0, elongated = 0;
      var minScale = 1.0;
      final gaps = <double>[];
      for (var p = 3; p <= mushaf.pages; p += step) {
        await tester.pumpWidget(
          MaterialApp(
            home: MushafPageView(mushaf: mushaf, page: db.page(mushaf.id, p), palette: PagePalette.light),
          ),
        );
        final fontSize = tester.widget<QuranLine>(find.byType(QuranLine).first).style.fontSize!;
        for (final e in find.byType(QuranLine).evaluate()) {
          final widget = e.widget as QuranLine;
          final line = e.renderObject! as RenderQuranLine;
          if (widget.centered || line.wordCount < 2) continue;
          lines++;
          minScale = math.min(minScale, line.scaleX);
          if (line.scaleX < 0.999) squeezed++;
          if (line.kashidaCount > 0) elongated++;
          gaps.add(line.gap / fontSize);
        }
      }
      gaps.sort();
      final median = gaps[gaps.length ~/ 2];
      final p95 = gaps[gaps.length * 95 ~/ 100];
      // ignore: avoid_print
      print(
        '${mushaf.id}: $lines lines, squeezed ${(100 * squeezed / lines).toStringAsFixed(1)} % '
        '(min scale ${minScale.toStringAsFixed(3)}), kashida in ${(100 * elongated / lines).round()} %, '
        'gap median ${median.toStringAsFixed(2)} em, p95 ${p95.toStringAsFixed(2)} em',
      );
      expect(squeezed / lines, lessThan(0.01), reason: mushaf.id);
      expect(minScale, greaterThan(0.9), reason: mushaf.id);
      expect(elongated / lines, greaterThan(0.5), reason: mushaf.id);
      expect(median, lessThan(0.42), reason: mushaf.id);
      expect(p95, lessThan(0.5), reason: mushaf.id);
    }
  });
}

// Renders sample pages to build/preview/*.png for eyeballing (not a golden test).
@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/app/theme.dart';
import 'package:quran_reader/core/db/content_database.dart';
import 'package:quran_reader/features/reader/mushaf_page.dart';

import 'support/fonts.dart';

void main() {
  late ContentDatabase db;
  setUpAll(() async {
    await loadAppFonts();
    db = ContentDatabase.openFile('assets/db/quran_reader.db');
  });

  final samples =
      (Platform.environment['PREVIEW'] ??
              'madinah_hafs:1,madinah_hafs:50,madinah_warsh:50,qatar:262,indopak_9_gaba:1,indopak_9_gaba:2,indopak_9_gaba:1000')
          .split(',');
  for (final s in samples) {
    final parts = s.split(':');
    testWidgets('preview $s', (tester) async {
      final mushaf = db.mushafs().firstWhere((m) => m.id == parts[0]);
      final page = db.page(mushaf.id, int.parse(parts[1]));
      // iPhone-sized window (393 × 852 pt).
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: MushafPageView(
              mushaf: mushaf,
              page: page,
              palette: Platform.environment.containsKey('PREVIEW_DARK') ? PagePalette.dark : PagePalette.light,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      Directory('build/preview').createSync(recursive: true);
      File('build/preview/${parts[0]}_${parts[1]}.png').writeAsBytesSync(bytes!);
    });
  }
}

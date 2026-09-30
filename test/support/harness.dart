import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/app/app.dart';
import 'package:quran_reader/app/providers.dart';
import 'package:quran_reader/core/db/content_database.dart';
import 'package:quran_reader/core/db/user_database.dart';
import 'package:quran_reader/core/prefs/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

final screenshotKey = GlobalKey();

/// The app wired to the real content database and in-memory user data.
Future<Widget> testApp({
  String initialLocation = '/',
  Map<String, Object> prefs = const {},
  ContentDatabase? content,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = SettingsStore(await SharedPreferences.getInstance());
  return RepaintBoundary(
    key: screenshotKey,
    child: ProviderScope(
      overrides: [
        contentDbProvider.overrideWithValue(content ?? ContentDatabase.openFile('assets/db/quran_reader.db')),
        userDbProvider.overrideWithValue(UserDatabase.memory()),
        settingsStoreProvider.overrideWithValue(store),
      ],
      child: QuranReaderApp(initialLocation: initialLocation),
    ),
  );
}

/// A phone-sized test window (1080 × 2340 px at 2.75).
void usePhone(WidgetTester tester, {bool landscape = false}) {
  tester.view.physicalSize = landscape ? const Size(2560, 1600) : const Size(1080, 2340);
  tester.view.devicePixelRatio = landscape ? 2 : 2.75;
  addTearDown(tester.view.reset);
}

/// Saves the current frame to `build/screens/<name>.png` when SCREENSHOTS is set.
Future<void> screenshot(WidgetTester tester, String name) async {
  if (!Platform.environment.containsKey('SCREENSHOTS')) return;
  final boundary = screenshotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  Directory('build/screens').createSync(recursive: true);
  File('build/screens/$name.png').writeAsBytesSync(bytes!);
}

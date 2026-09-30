import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the bundled fonts declared in pubspec.yaml so that widget tests
/// render real glyphs instead of the test font.
Future<void> loadAppFonts() async {
  const families = {
    'KFGQPC Hafs': 'KFGQPC-Hafs.ttf',
    'KFGQPC Warsh': 'KFGQPC-Warsh.ttf',
    'KFGQPC Qaloun': 'KFGQPC-Qaloun.ttf',
    'KFGQPC Douri': 'KFGQPC-Douri.ttf',
    'KFGQPC Shuba': 'KFGQPC-Shuba.ttf',
    'KFGQPC Sousi': 'KFGQPC-Sousi.ttf',
    'AlQuran IndoPak': 'AlQuranIndoPak.ttf',
    'SurahNameV2': 'SurahNameV2.ttf',
    'QuranCommon': 'QuranCommon.ttf',
  };
  for (final entry in families.entries) {
    await _load(entry.key, ['assets/fonts/${entry.value}']);
  }
}

/// Real fonts for the Material chrome (screenshots only): Roboto, the icon
/// font, and DejaVu Sans as a fallback for Arabic UI text.
Future<void> loadUiFonts() async {
  final material = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  if (!Directory(material).existsSync()) return;
  await _load('Roboto', ['$material/Roboto-Regular.ttf', '$material/Roboto-Medium.ttf', '$material/Roboto-Bold.ttf']);
  await _load('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
  const dejavu = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  if (File(dejavu).existsSync()) await _load('DejaVu Sans', [dejavu]);
}

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

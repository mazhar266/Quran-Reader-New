import 'package:flutter/material.dart';

import '../core/prefs/settings.dart';

const _seed = Color(0xFF1F6F50);

ThemeData appTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
  );
}

/// Colours of the mushaf page itself, independent of the app chrome.
class PagePalette {
  const PagePalette({
    required this.paper,
    required this.ink,
    required this.frame,
    required this.muted,
    required this.brightness,
  });

  final Color paper;
  final Color ink;

  /// Surah header frames.
  final Color frame;

  /// Page number, surah and juz labels.
  final Color muted;
  final Brightness brightness;

  static const light = PagePalette(
    paper: Color(0xFFFFFFFF),
    ink: Color(0xFF111111),
    frame: Color(0xFF1F6F50),
    muted: Color(0xFF6B6B6B),
    brightness: Brightness.light,
  );

  static const sepia = PagePalette(
    paper: Color(0xFFF6EEDC),
    ink: Color(0xFF2B2118),
    frame: Color(0xFF8A5A2B),
    muted: Color(0xFF7D6A55),
    brightness: Brightness.light,
  );

  static const dark = PagePalette(
    paper: Color(0xFF121212),
    ink: Color(0xFFE8E6E1),
    frame: Color(0xFF7FC4A4),
    muted: Color(0xFF9E9E9E),
    brightness: Brightness.dark,
  );

  static PagePalette of(PageTheme theme, Brightness platform) => switch (theme) {
    PageTheme.light => light,
    PageTheme.sepia => sepia,
    PageTheme.dark => dark,
    PageTheme.system => platform == Brightness.dark ? dark : light,
  };
}

import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

enum PageTheme { system, light, sepia, dark }

enum FitMode {
  /// All lines on screen: the font is limited by both width and height.
  page,

  /// The font fills the width; the page scrolls if it is taller than the screen.
  width,
}

class Settings {
  const Settings({
    this.theme = PageTheme.system,
    this.keepScreenOn = true,
    this.fitMode = FitMode.page,
    this.twoPages = true,
    this.showPageInfo = true,
    this.kashida = true,
    this.locale,
  });

  final PageTheme theme;
  final bool keepScreenOn;
  final FitMode fitMode;
  final bool twoPages;
  final bool showPageInfo;

  /// Fill justified lines by elongating letter joins (kashida), as printed
  /// mushafs do; otherwise only the spaces grow.
  final bool kashida;

  /// Null follows the system language.
  final Locale? locale;

  Settings copyWith({
    PageTheme? theme,
    bool? keepScreenOn,
    FitMode? fitMode,
    bool? twoPages,
    bool? showPageInfo,
    bool? kashida,
    Locale? Function()? locale,
  }) => Settings(
    theme: theme ?? this.theme,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    fitMode: fitMode ?? this.fitMode,
    twoPages: twoPages ?? this.twoPages,
    showPageInfo: showPageInfo ?? this.showPageInfo,
    kashida: kashida ?? this.kashida,
    locale: locale == null ? this.locale : locale(),
  );
}

/// Persists [Settings] and reading positions in shared preferences.
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _theme = 'theme';
  static const _keepScreenOn = 'keep_screen_on';
  static const _fitMode = 'fit_mode';
  static const _twoPages = 'two_pages';
  static const _showPageInfo = 'show_page_info';
  static const _kashida = 'kashida';
  static const _locale = 'locale';
  static const _lastMushaf = 'last_mushaf';
  static const _pagePrefix = 'page.';

  Settings load() {
    const d = Settings();
    final locale = _prefs.getString(_locale);
    return Settings(
      theme: PageTheme.values.asNameMap()[_prefs.getString(_theme)] ?? d.theme,
      keepScreenOn: _prefs.getBool(_keepScreenOn) ?? d.keepScreenOn,
      fitMode: FitMode.values.asNameMap()[_prefs.getString(_fitMode)] ?? d.fitMode,
      twoPages: _prefs.getBool(_twoPages) ?? d.twoPages,
      showPageInfo: _prefs.getBool(_showPageInfo) ?? d.showPageInfo,
      kashida: _prefs.getBool(_kashida) ?? d.kashida,
      locale: locale == null ? null : Locale(locale),
    );
  }

  Future<void> save(Settings s) async {
    await _prefs.setString(_theme, s.theme.name);
    await _prefs.setBool(_keepScreenOn, s.keepScreenOn);
    await _prefs.setString(_fitMode, s.fitMode.name);
    await _prefs.setBool(_twoPages, s.twoPages);
    await _prefs.setBool(_showPageInfo, s.showPageInfo);
    await _prefs.setBool(_kashida, s.kashida);
    if (s.locale == null) {
      await _prefs.remove(_locale);
    } else {
      await _prefs.setString(_locale, s.locale!.languageCode);
    }
  }

  String? get lastMushaf => _prefs.getString(_lastMushaf);

  int? lastPage(String mushafId) => _prefs.getInt('$_pagePrefix$mushafId');

  Future<void> savePosition(String mushafId, int page) async {
    await _prefs.setString(_lastMushaf, mushafId);
    await _prefs.setInt('$_pagePrefix$mushafId', page);
  }
}

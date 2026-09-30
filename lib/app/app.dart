import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/prefs/settings.dart';
import '../domain/models.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class QuranReaderApp extends ConsumerStatefulWidget {
  const QuranReaderApp({super.key, this.initialLocation = '/'});

  final String initialLocation;

  @override
  ConsumerState<QuranReaderApp> createState() => _QuranReaderAppState();
}

class _QuranReaderAppState extends ConsumerState<QuranReaderApp> {
  late final GoRouter _router = buildRouter(widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: switch (settings.theme) {
        PageTheme.system => ThemeMode.system,
        PageTheme.dark => ThemeMode.dark,
        PageTheme.light || PageTheme.sepia => ThemeMode.light,
      },
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}

bool isArabicUi(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';

/// Mushaf name in the UI language.
String mushafName(BuildContext context, Mushaf m) => isArabicUi(context) ? m.nameAr : m.name;

/// Surah name in the UI language.
String surahName(BuildContext context, Surah s) => isArabicUi(context) ? s.nameAr : s.nameEn;

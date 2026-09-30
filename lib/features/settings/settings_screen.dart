import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/prefs/settings.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          header(l.pageTheme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final t in PageTheme.values)
                  _ThemeSwatch(
                    theme: t,
                    label: switch (t) {
                      PageTheme.system => l.themeSystem,
                      PageTheme.light => l.themeLight,
                      PageTheme.sepia => l.themeSepia,
                      PageTheme.dark => l.themeDark,
                    },
                    selected: s.theme == t,
                    onTap: () => notifier.update((x) => x.copyWith(theme: t)),
                  ),
              ],
            ),
          ),
          header(l.pageFit),
          RadioGroup<FitMode>(
            groupValue: s.fitMode,
            onChanged: (v) => notifier.update((x) => x.copyWith(fitMode: v)),
            child: Column(
              children: [
                RadioListTile<FitMode>(value: FitMode.page, title: Text(l.fitPage), subtitle: Text(l.fitPageHint)),
                RadioListTile<FitMode>(value: FitMode.width, title: Text(l.fitWidth), subtitle: Text(l.fitWidthHint)),
              ],
            ),
          ),
          header(l.reader),
          SwitchListTile(
            title: Text(l.kashida),
            subtitle: Text(l.kashidaHint),
            value: s.kashida,
            onChanged: (v) => notifier.update((x) => x.copyWith(kashida: v)),
          ),
          SwitchListTile(
            title: Text(l.keepScreenOn),
            value: s.keepScreenOn,
            onChanged: (v) => notifier.update((x) => x.copyWith(keepScreenOn: v)),
          ),
          SwitchListTile(
            title: Text(l.showPageInfo),
            value: s.showPageInfo,
            onChanged: (v) => notifier.update((x) => x.copyWith(showPageInfo: v)),
          ),
          SwitchListTile(
            title: Text(l.twoPages),
            value: s.twoPages,
            onChanged: (v) => notifier.update((x) => x.copyWith(twoPages: v)),
          ),
          header(l.language),
          RadioGroup<String>(
            groupValue: s.locale?.languageCode ?? '',
            onChanged: (v) =>
                notifier.update((x) => x.copyWith(locale: () => v == null || v.isEmpty ? null : Locale(v))),
            child: Column(
              children: [
                RadioListTile<String>(value: '', title: Text(l.languageSystem)),
                const RadioListTile<String>(value: 'en', title: Text('English')),
                const RadioListTile<String>(value: 'ar', title: Text('العربية')),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.label, required this.selected, required this.onTap});

  final PageTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = PagePalette.of(theme, MediaQuery.platformBrightnessOf(context));
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 84,
              decoration: BoxDecoration(
                color: palette.paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 3 : 1),
              ),
              alignment: Alignment.center,
              child: Text(
                'بِسۡمِ',
                style: TextStyle(fontFamily: 'KFGQPC Hafs', fontSize: 22, color: palette.ink),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

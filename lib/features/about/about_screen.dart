import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

/// About and sources, with the attributions KFGQPC and QUL ask for.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const appVersion = '1.0.0';

  static const _fonts = [
    (
      'KFGQPC Uthmanic Script (Hafs v2.2, Warsh v2.1, Qaloun v2.1, Douri, Shu\'bah, Sousi v2.0)',
      'King Fahd Glorious Quran Printing Complex, via the Quranic Universal Library',
    ),
    ('AlQuran IndoPak', 'QuranWBW (credits Al Qalam, Ghandhara and KFGQPC), via the Quranic Universal Library'),
    ('surah-name-v2, quran-common', 'Quranic Universal Library (Tarteel)'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mushafs = ref.watch(mushafsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.about)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Center(
            child: Text(
              '\uE076',
              style: TextStyle(fontFamily: 'QuranCommon', fontSize: 96, color: theme.colorScheme.primary),
            ),
          ),
          Center(child: Text(l.appTitle, style: theme.textTheme.headlineSmall)),
          Center(child: Text(l.version(appVersion), style: theme.textTheme.bodySmall)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.aboutBody, style: theme.textTheme.bodyLarge),
          ),
          _Header(l.sources),
          for (final m in mushafs)
            ListTile(
              title: Text(mushafName(context, m)),
              subtitle: Text('${m.editionNote}\n${m.source}'),
              isThreeLine: true,
            ),
          _Header(l.fonts),
          for (final (name, by) in _fonts) ListTile(title: Text(name), subtitle: Text(by)),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The Quran text and fonts of the King Fahd Glorious Quran Printing Complex are used '
              'unaltered, free of charge and with attribution, as its terms of use require.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(MaterialLocalizations.of(context).licensesPageTitle),
            onTap: () => showLicensePage(context: context, applicationName: l.appTitle, applicationVersion: appVersion),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

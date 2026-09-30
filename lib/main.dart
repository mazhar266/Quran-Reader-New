import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'core/db/content_database.dart';
import 'core/db/user_database.dart';
import 'core/prefs/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final content = await ContentDatabase.open();
  final user = await UserDatabase.open();
  final store = SettingsStore(prefs);

  // First launch opens the mushaf picker; afterwards the last page read.
  final last = store.lastMushaf;
  final known = last != null && content.mushafs().any((m) => m.id == last);
  final initial = known ? readerLocation(last, store.lastPage(last) ?? 1) : '/';

  runApp(
    ProviderScope(
      overrides: [
        contentDbProvider.overrideWithValue(content),
        userDbProvider.overrideWithValue(user),
        settingsStoreProvider.overrideWithValue(store),
      ],
      child: QuranReaderApp(initialLocation: initial),
    ),
  );
}

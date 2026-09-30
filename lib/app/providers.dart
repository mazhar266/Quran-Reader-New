import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/content_database.dart';
import '../core/db/user_database.dart';
import '../core/prefs/settings.dart';
import '../domain/models.dart';

/// Overridden in `main()` once the databases are open.
final contentDbProvider = Provider<ContentDatabase>((ref) => throw UnimplementedError());
final userDbProvider = Provider<UserDatabase>((ref) => throw UnimplementedError());
final settingsStoreProvider = Provider<SettingsStore>((ref) => throw UnimplementedError());

final mushafsProvider = Provider<List<Mushaf>>((ref) => ref.watch(contentDbProvider).mushafs());

final mushafProvider = Provider.family<Mushaf, String>(
  (ref, id) => ref.watch(mushafsProvider).firstWhere((m) => m.id == id),
);

final surahsProvider = Provider<List<Surah>>((ref) => ref.watch(contentDbProvider).surahs());

final surahStartsProvider = Provider.family<List<SurahStart>, String>(
  (ref, mushafId) => ref.watch(contentDbProvider).surahStarts(mushafId),
);

final juzStartsProvider = Provider.family<List<JuzStart>, String>(
  (ref, mushafId) => ref.watch(contentDbProvider).juzStarts(mushafId),
);

/// One page of a mushaf. The database caches pages, so this is cheap.
final pageProvider = Provider.family<MushafPage, (String, int)>(
  (ref, key) => ref.watch(contentDbProvider).page(key.$1, key.$2),
);

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => ref.watch(settingsStoreProvider).load();

  void update(Settings Function(Settings) change) {
    state = change(state);
    ref.read(settingsStoreProvider).save(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

/// Last page read per mushaf, plus the last mushaf opened.
class PositionsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    final store = ref.watch(settingsStoreProvider);
    return {for (final m in ref.watch(mushafsProvider)) m.id: ?store.lastPage(m.id)};
  }

  String? get lastMushaf => ref.read(settingsStoreProvider).lastMushaf;

  void save(String mushafId, int page) {
    if (state[mushafId] == page && lastMushaf == mushafId) return;
    state = {...state, mushafId: page};
    ref.read(settingsStoreProvider).savePosition(mushafId, page);
  }
}

final positionsProvider = NotifierProvider<PositionsNotifier, Map<String, int>>(PositionsNotifier.new);

class BookmarksNotifier extends Notifier<List<Bookmark>> {
  @override
  List<Bookmark> build() => ref.watch(userDbProvider).bookmarks();

  UserDatabase get _db => ref.read(userDbProvider);

  void add(String mushafId, int page, {AyahKey? ayah}) {
    _db.add(mushafId, page, ayah: ayah);
    state = _db.bookmarks();
  }

  void remove(int id) {
    _db.remove(id);
    state = _db.bookmarks();
  }

  Bookmark? pageBookmark(String mushafId, int page) {
    for (final b in state) {
      if (b.mushafId == mushafId && b.page == page && b.ayah == null) return b;
    }
    return null;
  }
}

final bookmarksProvider = NotifierProvider<BookmarksNotifier, List<Bookmark>>(BookmarksNotifier.new);

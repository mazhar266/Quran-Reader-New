import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models.dart';

/// The writable database for the user's own data. It is kept apart from the
/// content database so that content updates never touch bookmarks.
class UserDatabase {
  UserDatabase._(this._db) {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY,
        mushaf_id TEXT NOT NULL,
        page INTEGER NOT NULL,
        surah INTEGER NOT NULL DEFAULT 0,   -- 0: page bookmark
        ayah INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        UNIQUE (mushaf_id, page, surah, ayah)
      )
    ''');
  }

  final Database _db;

  static Future<UserDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    return UserDatabase._(sqlite3.open(p.join(dir.path, 'user.db')));
  }

  /// In-memory database (tests).
  factory UserDatabase.memory() => UserDatabase._(sqlite3.openInMemory());

  void close() => _db.close();

  List<Bookmark> bookmarks() => [
    for (final r in _db.select('SELECT * FROM bookmarks ORDER BY created_at DESC, id DESC'))
      Bookmark(
        id: r['id'] as int,
        mushafId: r['mushaf_id'] as String,
        page: r['page'] as int,
        ayah: r['surah'] == 0 ? null : AyahKey(r['surah'] as int, r['ayah'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      ),
  ];

  void add(String mushafId, int page, {AyahKey? ayah}) {
    _db.execute('INSERT OR REPLACE INTO bookmarks (mushaf_id, page, surah, ayah, created_at) VALUES (?, ?, ?, ?, ?)', [
      mushafId,
      page,
      ayah?.surah ?? 0,
      ayah?.ayah ?? 0,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  void remove(int id) => _db.execute('DELETE FROM bookmarks WHERE id = ?', [id]);
}

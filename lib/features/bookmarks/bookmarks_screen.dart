import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../l10n/app_localizations.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final bookmarks = ref.watch(bookmarksProvider);
    final mushafs = {for (final m in ref.watch(mushafsProvider)) m.id: m};
    final surahs = ref.watch(surahsProvider);
    final db = ref.watch(contentDbProvider);
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());

    return Scaffold(
      appBar: AppBar(title: Text(l.bookmarks)),
      body: bookmarks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border, size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(l.noBookmarks, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListView.separated(
              itemCount: bookmarks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = bookmarks[i];
                final mushaf = mushafs[b.mushafId];
                if (mushaf == null || b.page > mushaf.pages) return const SizedBox.shrink();
                final surah = surahs[(b.ayah?.surah ?? db.page(b.mushafId, b.page).surah) - 1];
                final what = b.ayah == null
                    ? '${surahName(context, surah)} · ${l.pageN(b.page)}'
                    : '${surahName(context, surah)} · ${l.ayahRef(b.ayah!.surah, b.ayah!.ayah)} · ${l.pageN(b.page)}';
                return Dismissible(
                  key: ValueKey(b.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => ref.read(bookmarksProvider.notifier).remove(b.id),
                  child: ListTile(
                    leading: Icon(b.ayah == null ? Icons.bookmark : Icons.format_quote),
                    title: Text(what),
                    subtitle: Text('${mushafName(context, mushaf)} · ${date.format(b.createdAt)}'),
                    trailing: IconButton(
                      tooltip: l.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref.read(bookmarksProvider.notifier).remove(b.id),
                    ),
                    onTap: () => context.go(readerLocation(b.mushafId, b.page)),
                  ),
                );
              },
            ),
    );
  }
}

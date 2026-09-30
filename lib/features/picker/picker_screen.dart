import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../reader/mushaf_page.dart';

/// Home: choose which mushaf to read.
class PickerScreen extends ConsumerWidget {
  const PickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mushafs = ref.watch(mushafsProvider);
    final positions = ref.watch(positionsProvider);
    final lastId = ref.read(positionsProvider.notifier).lastMushaf;
    final last = mushafs.where((m) => m.id == lastId).firstOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            tooltip: l.bookmarks,
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => context.push('/bookmarks'),
          ),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(tooltip: l.about, icon: const Icon(Icons.info_outline), onPressed: () => context.push('/about')),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (last != null && positions[last.id] != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _ContinueCard(mushaf: last, page: positions[last.id]!),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.chooseMushaf, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(l.chooseMushafHint, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 196,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: mushafs.length,
              itemBuilder: (context, i) =>
                  MushafCard(mushaf: mushafs[i], lastPage: positions[mushafs[i].id], current: mushafs[i].id == lastId),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.mushaf, required this.page});

  final Mushaf mushaf;
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final clampedPage = page.clamp(1, mushaf.pages);
    final data = ref.watch(pageProvider((mushaf.id, clampedPage)));
    final surah = ref.watch(surahsProvider)[data.surah - 1];
    return Card.filled(
      color: scheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(readerLocation(mushaf.id, clampedPage)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.auto_stories, size: 36, color: scheme.onPrimaryContainer),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.continueReading,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${mushafName(context, mushaf)}\n${surahName(context, surah)} · ${l.pageN(clampedPage)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// A mushaf in the picker, with a live rendering of its first page.
class MushafCard extends ConsumerWidget {
  const MushafCard({super.key, required this.mushaf, this.lastPage, this.current = false});

  final Mushaf mushaf;
  final int? lastPage;
  final bool current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final palette = PagePalette.of(settings.theme, MediaQuery.platformBrightnessOf(context));
    final arabic = isArabicUi(context);

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: current ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: current ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.go(readerLocation(mushaf.id, lastPage ?? 1)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Thumbnail(mushaf: mushaf, palette: palette),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            arabic ? mushaf.nameAr : mushaf.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (current)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 6),
                            child: Chip(
                              label: Text(l.current),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                    if (!arabic)
                      Text(
                        mushaf.nameAr,
                        textDirection: TextDirection.rtl,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      mushaf.description,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          lastPage == null ? Icons.circle_outlined : Icons.history,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lastPage == null ? l.notStarted : l.lastRead(lastPage!),
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: l.mushafInfo,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.info_outline, size: 20),
                          onPressed: () => showMushafInfo(context, mushaf),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.mushaf, required this.palette});

  final Mushaf mushaf;
  final PagePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(pageProvider((mushaf.id, 1)));
    return AspectRatio(
      aspectRatio: 0.64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: IgnorePointer(
            child: FittedBox(
              child: SizedBox(
                width: 320,
                height: 500,
                child: MushafPageView(mushaf: mushaf, page: page, palette: palette, showInfo: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showMushafInfo(BuildContext context, Mushaf mushaf) {
  final l = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(mushafName(context, mushaf)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mushaf.description),
            const SizedBox(height: 4),
            Text(l.pagesAndLines(mushaf.pages, mushaf.linesPerPage)),
            const SizedBox(height: 12),
            Text(l.edition, style: Theme.of(context).textTheme.titleSmall),
            Text(mushaf.editionNote),
            const SizedBox(height: 12),
            Text(l.source, style: Theme.of(context).textTheme.titleSmall),
            Text(mushaf.source),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );
}

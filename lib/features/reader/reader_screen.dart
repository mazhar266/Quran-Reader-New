import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/app.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../navigate/goto_sheet.dart';
import 'mushaf_page.dart';

/// Page-by-page reader. Pages advance right to left: page n + 1 lies to the
/// left of page n, as in a printed mushaf.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.mushafId, this.initialPage});

  final String mushafId;

  /// Page to open; defaults to the last page read in this mushaf.
  final int? initialPage;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late int _page;
  PageController? _controller;
  bool? _spread;
  bool _chrome = false;
  AyahKey? _highlight;

  Mushaf get _mushaf => ref.read(mushafProvider(widget.mushafId));

  @override
  void initState() {
    super.initState();
    final saved = ref.read(positionsProvider)[widget.mushafId];
    _page = (widget.initialPage ?? saved ?? 1).clamp(1, _mushaf.pages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(positionsProvider.notifier).save(widget.mushafId, _page);
    });
    _applyWakelock(ref.read(settingsProvider).keepScreenOn);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _applyWakelock(false);
    super.dispose();
  }

  /// Best effort: platforms without the plugin simply keep their default.
  void _applyWakelock(bool on) =>
      unawaited((on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((Object _) {}));

  int _indexOf(int page, bool spread) => spread ? (page - 1) ~/ 2 : page - 1;

  PageController _controllerFor(bool spread) {
    if (_spread != spread || _controller == null) {
      final old = _controller;
      if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      _spread = spread;
      _controller = PageController(initialPage: _indexOf(_page, spread));
    }
    return _controller!;
  }

  void _onPageChanged(int index) {
    final page = _spread! ? (index * 2 + 1) : index + 1;
    // In a spread keep the page the reader was on if it is still visible.
    final moved = !_spread! || (_page - 1) ~/ 2 != index;
    setState(() {
      if (moved) _page = page;
      _highlight = null;
    });
    ref.read(positionsProvider.notifier).save(widget.mushafId, _page);
  }

  void jumpTo(int page) {
    final p = page.clamp(1, _mushaf.pages);
    setState(() => _page = p);
    _controller?.jumpToPage(_indexOf(p, _spread ?? false));
    ref.read(positionsProvider.notifier).save(widget.mushafId, p);
  }

  Future<void> _openGoTo() async {
    final page = await showGoToSheet(context, mushafId: widget.mushafId, currentPage: _page);
    if (page != null) jumpTo(page);
  }

  void _toggleBookmark() {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(bookmarksProvider.notifier);
    final existing = notifier.pageBookmark(widget.mushafId, _page);
    if (existing != null) {
      notifier.remove(existing.id);
    } else {
      notifier.add(widget.mushafId, _page);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(existing != null ? l.bookmarkRemoved : l.bookmarkAdded),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _onLongPressAyah(int page, PageLine line, AyahKey ayah) async {
    HapticFeedback.selectionClick();
    setState(() => _highlight = ayah);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _AyahSheet(mushaf: _mushaf, page: page, ayah: ayah),
    );
    if (mounted) setState(() => _highlight = null);
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafProvider(widget.mushafId));
    final settings = ref.watch(settingsProvider);
    ref.listen(settingsProvider.select((s) => s.keepScreenOn), (_, on) => _applyWakelock(on));
    final palette = PagePalette.of(settings.theme, MediaQuery.platformBrightnessOf(context));
    final overlayStyle = palette.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: palette.paper,
        body: LayoutBuilder(
          builder: (context, c) {
            final spread = settings.twoPages && c.maxWidth > c.maxHeight && c.maxWidth >= 600;
            final controller = _controllerFor(spread);
            final count = spread ? (mushaf.pages + 1) ~/ 2 : mushaf.pages;

            Widget pageAt(int page) {
              if (page > mushaf.pages) return ColoredBox(color: palette.paper);
              return MushafPageView(
                mushaf: mushaf,
                page: ref.watch(pageProvider((mushaf.id, page))),
                palette: palette,
                fit: settings.fitMode,
                showInfo: settings.showPageInfo,
                kashida: settings.kashida,
                highlight: _highlight,
                onLongPressAyah: (line, ayah) => _onLongPressAyah(page, line, ayah),
              );
            }

            return Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _chrome = !_chrome),
                  child: SafeArea(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: PageView.builder(
                        controller: controller,
                        // Lay out the neighbouring pages ahead of the swipe.
                        allowImplicitScrolling: true,
                        itemCount: count,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) => spread
                            ? Row(
                                children: [
                                  Expanded(child: pageAt(index * 2 + 1)),
                                  VerticalDivider(width: 1, color: palette.muted.withValues(alpha: 0.3)),
                                  Expanded(child: pageAt(index * 2 + 2)),
                                ],
                              )
                            : pageAt(index + 1),
                      ),
                    ),
                  ),
                ),
                _Chrome(
                  visible: _chrome,
                  mushaf: mushaf,
                  page: _page,
                  onGoTo: _openGoTo,
                  onBookmark: _toggleBookmark,
                  onJump: jumpTo,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Translucent top and bottom bars shown after a tap on the page.
class _Chrome extends ConsumerWidget {
  const _Chrome({
    required this.visible,
    required this.mushaf,
    required this.page,
    required this.onGoTo,
    required this.onBookmark,
    required this.onJump,
  });

  final bool visible;
  final Mushaf mushaf;
  final int page;
  final VoidCallback onGoTo;
  final VoidCallback onBookmark;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final data = ref.watch(pageProvider((mushaf.id, page)));
    final surah = ref.watch(surahsProvider)[data.surah - 1];
    final bookmarked = ref
        .watch(bookmarksProvider)
        .any((b) => b.mushafId == mushaf.id && b.page == page && b.ayah == null);
    final bar = scheme.surfaceContainer.withValues(alpha: 0.96);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Column(
          children: [
            Material(
              color: bar,
              elevation: 2,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l.changeMushaf,
                        icon: const BackButtonIcon(),
                        onPressed: () => context.go('/'),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${surahName(context, surah)} · ${l.juzN(data.juz)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${mushafName(context, mushaf)} · ${l.pageN(page)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(tooltip: l.goTo, icon: const Icon(Icons.menu_book_outlined), onPressed: onGoTo),
                      IconButton(
                        tooltip: bookmarked ? l.removePageBookmark : l.bookmarkPage,
                        icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border),
                        onPressed: onBookmark,
                      ),
                      PopupMenuButton<String>(
                        tooltip: l.menu,
                        onSelected: (route) => context.push(route),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: '/bookmarks', child: Text(l.bookmarks)),
                          PopupMenuItem(value: '/settings', child: Text(l.settings)),
                          PopupMenuItem(value: '/about', child: Text(l.about)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            Material(
              color: bar,
              elevation: 2,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Text(l.pageOf(page, mushaf.pages), style: Theme.of(context).textTheme.labelLarge),
                      Expanded(
                        child: Directionality(
                          // Page 1 on the right, like the book.
                          textDirection: TextDirection.rtl,
                          child: _PageSlider(page: page, pages: mushaf.pages, onJump: onJump),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageSlider extends StatefulWidget {
  const _PageSlider({required this.page, required this.pages, required this.onJump});

  final int page;
  final int pages;
  final ValueChanged<int> onJump;

  @override
  State<_PageSlider> createState() => _PageSliderState();
}

class _PageSliderState extends State<_PageSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = _dragging ?? widget.page.toDouble();
    return Slider(
      min: 1,
      max: widget.pages.toDouble(),
      value: value.clamp(1, widget.pages.toDouble()),
      label: '${value.round()}',
      divisions: widget.pages - 1,
      onChanged: (v) => setState(() => _dragging = v),
      onChangeEnd: (v) {
        setState(() => _dragging = null);
        widget.onJump(v.round());
      },
    );
  }
}

class _AyahSheet extends ConsumerWidget {
  const _AyahSheet({required this.mushaf, required this.page, required this.ayah});

  final Mushaf mushaf;
  final int page;
  final AyahKey ayah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final surah = ref.watch(surahsProvider)[ayah.surah - 1];
    // The plain spelling uses Hafs numbering; only show it where it applies.
    final plain = mushaf.riwayah == 'hafs' ? ref.read(contentDbProvider).plainText(ayah) : null;
    final bookmarked = ref.watch(bookmarksProvider).any((b) => b.mushafId == mushaf.id && b.ayah == ayah);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${surahName(context, surah)} · ${l.ayahRef(ayah.surah, ayah.ayah)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (plain != null) ...[
              const SizedBox(height: 12),
              Text(plain, textDirection: TextDirection.rtl, style: Theme.of(context).textTheme.bodyLarge),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: Icon(bookmarked ? Icons.bookmark_added : Icons.bookmark_add_outlined),
              label: Text(l.bookmarkAyah(ayah.surah, ayah.ayah)),
              onPressed: bookmarked
                  ? null
                  : () {
                      ref.read(bookmarksProvider.notifier).add(mushaf.id, page, ayah: ayah);
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(content: Text(l.bookmarkAdded), duration: const Duration(seconds: 2)),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}

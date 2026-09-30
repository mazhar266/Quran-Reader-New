import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../reader/mushaf_page.dart';

/// Surah / Juz / Page navigation. Resolves to the chosen page, or null.
Future<int?> showGoToSheet(BuildContext context, {required String mushafId, required int currentPage}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => GoToSheet(mushafId: mushafId, currentPage: currentPage, scroll: scroll),
      ),
    );

class GoToSheet extends ConsumerWidget {
  const GoToSheet({super.key, required this.mushafId, required this.currentPage, this.scroll});

  final String mushafId;
  final int currentPage;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l.surahs),
              Tab(text: l.juzList),
              Tab(text: l.page),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SurahList(mushafId: mushafId, currentPage: currentPage, scroll: scroll),
                _JuzList(mushafId: mushafId, currentPage: currentPage),
                _PageField(mushafId: mushafId, currentPage: currentPage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahList extends ConsumerWidget {
  const _SurahList({required this.mushafId, required this.currentPage, this.scroll});

  final String mushafId;
  final int currentPage;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final surahs = ref.watch(surahsProvider);
    final starts = ref.watch(surahStartsProvider(mushafId));
    // The surah being read: the last one that starts on or before this page.
    final current = starts.lastIndexWhere((s) => s.page <= currentPage);
    final theme = Theme.of(context);
    return ListView.builder(
      controller: scroll,
      itemCount: starts.length,
      itemBuilder: (context, i) {
        final start = starts[i];
        final surah = surahs[start.surah - 1];
        return ListTile(
          selected: i == current,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text('${surah.number}', style: theme.textTheme.labelMedium),
          ),
          title: Text(isArabicUi(context) ? surah.nameAr : surah.nameEn),
          subtitle: Text('${l.ayahCount(start.ayahCount)} · ${l.pageN(start.page)}'),
          trailing: isArabicUi(context)
              ? null
              : Text(surah.nameAr, textDirection: TextDirection.rtl, style: theme.textTheme.titleMedium),
          onTap: () => Navigator.pop(context, start.page),
        );
      },
    );
  }
}

class _JuzList extends ConsumerWidget {
  const _JuzList({required this.mushafId, required this.currentPage});

  final String mushafId;
  final int currentPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final juz = ref.watch(juzStartsProvider(mushafId));
    final surahs = ref.watch(surahsProvider);
    final current = juz.lastIndexWhere((j) => j.page <= currentPage);
    return ListView.builder(
      itemCount: juz.length,
      itemBuilder: (context, i) {
        final j = juz[i];
        return ListTile(
          selected: i == current,
          leading: CircleAvatar(radius: 16, child: Text('${j.juz}')),
          title: Text(l.juzN(j.juz)),
          subtitle: Text(
            '${surahName(context, surahs[j.key.surah - 1])} ${j.key.surah}:${j.key.ayah} · ${l.pageN(j.page)}',
          ),
          trailing: Text(
            String.fromCharCode(0xE000 + j.juz),
            style: TextStyle(fontFamily: 'QuranCommon', fontSize: 26, color: Theme.of(context).colorScheme.primary),
          ),
          onTap: () => Navigator.pop(context, j.page),
        );
      },
    );
  }
}

class _PageField extends ConsumerStatefulWidget {
  const _PageField({required this.mushafId, required this.currentPage});

  final String mushafId;
  final int currentPage;

  @override
  ConsumerState<_PageField> createState() => _PageFieldState();
}

class _PageFieldState extends ConsumerState<_PageField> {
  late final _controller = TextEditingController(text: '${widget.currentPage}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(int pages) {
    final page = int.tryParse(_controller.text.trim());
    if (page == null || page < 1 || page > pages) {
      setState(() => _error = AppLocalizations.of(context).invalidPage(pages));
      return;
    }
    Navigator.pop(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mushaf = ref.watch(mushafProvider(widget.mushafId));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l.goToPageHint(mushaf.pages),
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(mushaf.pages),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => _submit(mushaf.pages), child: Text(l.go)),
        const SizedBox(height: 24),
        Center(
          child: Text(
            arabicDigits(widget.currentPage),
            style: TextStyle(fontFamily: 'KFGQPC Hafs', fontSize: 40, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader/features/picker/picker_screen.dart';
import 'package:quran_reader/features/reader/mushaf_page.dart';
import 'package:quran_reader/features/reader/reader_screen.dart';

import 'support/fonts.dart';
import 'support/harness.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await loadUiFonts();
  });

  testWidgets('first launch shows the mushaf picker with every mushaf', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(await testApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose a mushaf'), findsOneWidget);
    expect(find.text('Continue reading'), findsNothing);
    expect(find.text('Madinah Mushaf · Hafs'), findsOneWidget);
    await screenshot(tester, 'picker');

    for (final name in ['Mushaf Qatar · Hafs', 'Indopak · 9 lines (Gaba)']) {
      await tester.scrollUntilVisible(find.text(name), 300);
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byType(MushafCard, skipOffstage: false), findsWidgets);
  });

  testWidgets('choosing a mushaf opens it, and navigation, bookmarks and position work', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(await testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Madinah Mushaf · Warsh'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(find.byType(MushafPageView), findsOneWidget);
    await screenshot(tester, 'reader_warsh_p1');

    // Swipe to the next page: it lies to the left, so drag left-to-right.
    await tester.fling(find.byType(PageView), const Offset(400, 0), 2000);
    await tester.pumpAndSettle();

    // Tap shows the chrome.
    await tester.tapAt(const Offset(200, 420));
    await tester.pumpAndSettle();
    expect(find.text('Madinah Mushaf · Warsh · Page 2'), findsOneWidget);
    await screenshot(tester, 'reader_chrome');

    // Bookmark the page.
    await tester.tap(find.byTooltip('Bookmark this page'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove page bookmark'), findsOneWidget);

    // Go to Al-Imran through the surah index.
    await tester.tap(find.byTooltip('Go to'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'goto_surahs');
    await tester.tap(find.textContaining('Imrān'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Page 50'), findsWidgets);
    await screenshot(tester, 'reader_warsh_p50');

    // Juz tab and page field.
    await tester.tap(find.byTooltip('Go to'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Page').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '604');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Page 604'), findsWidgets);

    // Back to the picker: the position is remembered.
    await tester.tap(find.byTooltip('Change mushaf'));
    await tester.pumpAndSettle();
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Last read: page 604'), findsOneWidget);
    await screenshot(tester, 'picker_after');

    // The bookmark is listed.
    await tester.tap(find.byTooltip('Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Page 2'), findsOneWidget);
    await screenshot(tester, 'bookmarks');
  });

  testWidgets('long-press on a word offers to bookmark its ayah', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(await testApp(initialLocation: '/read/madinah_hafs?page=50'));
    await tester.pumpAndSettle();
    final page = tester.getRect(find.byType(MushafPageView));
    await tester.longPressAt(Offset(page.right - 40, page.top + page.height * 0.45));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bookmark ayah 3:'), findsOneWidget);
    await screenshot(tester, 'ayah_sheet');
  });

  testWidgets('reader opens the IndoPak mushaf and its settings apply', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(
      await testApp(initialLocation: '/read/indopak_9_gaba?page=1000', prefs: {'theme': 'sepia'}),
    );
    await tester.pumpAndSettle();
    await screenshot(tester, 'reader_gaba_sepia');

    await tester.tapAt(const Offset(200, 420));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await screenshot(tester, 'settings');
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await screenshot(tester, 'reader_gaba_dark');
  });

  testWidgets('landscape shows two pages side by side', (tester) async {
    usePhone(tester, landscape: true);
    await tester.pumpWidget(await testApp(initialLocation: '/read/qatar?page=3'));
    await tester.pumpAndSettle();
    expect(find.byType(MushafPageView), findsNWidgets(2));
    await screenshot(tester, 'spread_qatar');
  });

  testWidgets('the UI is available in Arabic', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(await testApp(prefs: {'locale': 'ar'}));
    await tester.pumpAndSettle();
    expect(find.text('اختر المصحف'), findsOneWidget);
    await screenshot(tester, 'picker_ar');
  });
}

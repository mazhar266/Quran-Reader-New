// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Quran Reader';

  @override
  String get chooseMushaf => 'Choose a mushaf';

  @override
  String get chooseMushafHint => 'Each mushaf remembers its own reading position.';

  @override
  String get continueReading => 'Continue reading';

  @override
  String pageN(int page) {
    return 'Page $page';
  }

  @override
  String pageOf(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String juzN(int juz) {
    return 'Juz $juz';
  }

  @override
  String pagesAndLines(int pages, int lines) {
    return '$pages pages · $lines lines';
  }

  @override
  String ayahCount(int count) {
    return 'Ayahs: $count';
  }

  @override
  String lastRead(int page) {
    return 'Last read: page $page';
  }

  @override
  String get notStarted => 'Not opened yet';

  @override
  String get current => 'Current';

  @override
  String get read => 'Read';

  @override
  String get changeMushaf => 'Change mushaf';

  @override
  String get mushafInfo => 'About this mushaf';

  @override
  String get edition => 'Edition';

  @override
  String get source => 'Source';

  @override
  String get goTo => 'Go to';

  @override
  String get surahs => 'Surahs';

  @override
  String get juzList => 'Juz';

  @override
  String get page => 'Page';

  @override
  String goToPageHint(int pages) {
    return 'Page number (1 – $pages)';
  }

  @override
  String invalidPage(int pages) {
    return 'Enter a page between 1 and $pages';
  }

  @override
  String get go => 'Go';

  @override
  String get cancel => 'Cancel';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get noBookmarks =>
      'No bookmarks yet. While reading, tap the bookmark button to mark a page, or long-press a line to mark an ayah.';

  @override
  String get bookmarkPage => 'Bookmark this page';

  @override
  String get removePageBookmark => 'Remove page bookmark';

  @override
  String get bookmarkAdded => 'Bookmark added';

  @override
  String get bookmarkRemoved => 'Bookmark removed';

  @override
  String bookmarkAyah(int surah, int ayah) {
    return 'Bookmark ayah $surah:$ayah';
  }

  @override
  String ayahRef(int surah, int ayah) {
    return 'Ayah $surah:$ayah';
  }

  @override
  String get ayahsOnLine => 'Ayahs on this line';

  @override
  String get allMushafs => 'All mushafs';

  @override
  String get delete => 'Delete';

  @override
  String get settings => 'Settings';

  @override
  String get pageTheme => 'Page colour';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSepia => 'Sepia';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get keepScreenOn => 'Keep the screen on while reading';

  @override
  String get pageFit => 'Page fit';

  @override
  String get fitPage => 'Whole page';

  @override
  String get fitPageHint => 'All lines fit on the screen';

  @override
  String get fitWidth => 'Full width';

  @override
  String get fitWidthHint => 'Largest text, scroll if the page is taller than the screen';

  @override
  String get twoPages => 'Two pages side by side in landscape';

  @override
  String get showPageInfo => 'Show surah, juz and page number';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get about => 'About';

  @override
  String get aboutBody =>
      'Quran Reader shows the Quran page by page, line by line, as in the printed mushafs. It works offline and collects no data.';

  @override
  String get sources => 'Sources and credits';

  @override
  String get fonts => 'Fonts';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get loadError => 'Could not open the Quran data.';

  @override
  String get menu => 'Menu';

  @override
  String get reader => 'Reader';

  @override
  String get kashida => 'Fill lines by elongating letters (kashida)';

  @override
  String get kashidaHint => 'As in printed mushafs. Off: lines are filled with wider spaces.';
}

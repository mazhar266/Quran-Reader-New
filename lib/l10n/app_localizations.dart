import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Quran Reader'**
  String get appTitle;

  /// No description provided for @chooseMushaf.
  ///
  /// In en, this message translates to:
  /// **'Choose a mushaf'**
  String get chooseMushaf;

  /// No description provided for @chooseMushafHint.
  ///
  /// In en, this message translates to:
  /// **'Each mushaf remembers its own reading position.'**
  String get chooseMushafHint;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get continueReading;

  /// No description provided for @pageN.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String pageN(int page);

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String pageOf(int page, int pages);

  /// No description provided for @juzN.
  ///
  /// In en, this message translates to:
  /// **'Juz {juz}'**
  String juzN(int juz);

  /// No description provided for @pagesAndLines.
  ///
  /// In en, this message translates to:
  /// **'{pages} pages · {lines} lines'**
  String pagesAndLines(int pages, int lines);

  /// No description provided for @ayahCount.
  ///
  /// In en, this message translates to:
  /// **'Ayahs: {count}'**
  String ayahCount(int count);

  /// No description provided for @lastRead.
  ///
  /// In en, this message translates to:
  /// **'Last read: page {page}'**
  String lastRead(int page);

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'Not opened yet'**
  String get notStarted;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @changeMushaf.
  ///
  /// In en, this message translates to:
  /// **'Change mushaf'**
  String get changeMushaf;

  /// No description provided for @mushafInfo.
  ///
  /// In en, this message translates to:
  /// **'About this mushaf'**
  String get mushafInfo;

  /// No description provided for @edition.
  ///
  /// In en, this message translates to:
  /// **'Edition'**
  String get edition;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @goTo.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goTo;

  /// No description provided for @surahs.
  ///
  /// In en, this message translates to:
  /// **'Surahs'**
  String get surahs;

  /// No description provided for @juzList.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get juzList;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// No description provided for @goToPageHint.
  ///
  /// In en, this message translates to:
  /// **'Page number (1 – {pages})'**
  String goToPageHint(int pages);

  /// No description provided for @invalidPage.
  ///
  /// In en, this message translates to:
  /// **'Enter a page between 1 and {pages}'**
  String invalidPage(int pages);

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet. While reading, tap the bookmark button to mark a page, or long-press a line to mark an ayah.'**
  String get noBookmarks;

  /// No description provided for @bookmarkPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this page'**
  String get bookmarkPage;

  /// No description provided for @removePageBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove page bookmark'**
  String get removePageBookmark;

  /// No description provided for @bookmarkAdded.
  ///
  /// In en, this message translates to:
  /// **'Bookmark added'**
  String get bookmarkAdded;

  /// No description provided for @bookmarkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed'**
  String get bookmarkRemoved;

  /// No description provided for @bookmarkAyah.
  ///
  /// In en, this message translates to:
  /// **'Bookmark ayah {surah}:{ayah}'**
  String bookmarkAyah(int surah, int ayah);

  /// No description provided for @ayahRef.
  ///
  /// In en, this message translates to:
  /// **'Ayah {surah}:{ayah}'**
  String ayahRef(int surah, int ayah);

  /// No description provided for @ayahsOnLine.
  ///
  /// In en, this message translates to:
  /// **'Ayahs on this line'**
  String get ayahsOnLine;

  /// No description provided for @allMushafs.
  ///
  /// In en, this message translates to:
  /// **'All mushafs'**
  String get allMushafs;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @pageTheme.
  ///
  /// In en, this message translates to:
  /// **'Page colour'**
  String get pageTheme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get themeSepia;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @keepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen on while reading'**
  String get keepScreenOn;

  /// No description provided for @pageFit.
  ///
  /// In en, this message translates to:
  /// **'Page fit'**
  String get pageFit;

  /// No description provided for @fitPage.
  ///
  /// In en, this message translates to:
  /// **'Whole page'**
  String get fitPage;

  /// No description provided for @fitPageHint.
  ///
  /// In en, this message translates to:
  /// **'All lines fit on the screen'**
  String get fitPageHint;

  /// No description provided for @fitWidth.
  ///
  /// In en, this message translates to:
  /// **'Full width'**
  String get fitWidth;

  /// No description provided for @fitWidthHint.
  ///
  /// In en, this message translates to:
  /// **'Largest text, scroll if the page is taller than the screen'**
  String get fitWidthHint;

  /// No description provided for @twoPages.
  ///
  /// In en, this message translates to:
  /// **'Two pages side by side in landscape'**
  String get twoPages;

  /// No description provided for @showPageInfo.
  ///
  /// In en, this message translates to:
  /// **'Show surah, juz and page number'**
  String get showPageInfo;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get languageSystem;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Quran Reader shows the Quran page by page, line by line, as in the printed mushafs. It works offline and collects no data.'**
  String get aboutBody;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources and credits'**
  String get sources;

  /// No description provided for @fonts.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get fonts;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Quran data.'**
  String get loadError;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @reader.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get reader;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'قارئ القرآن';

  @override
  String get chooseMushaf => 'اختر المصحف';

  @override
  String get chooseMushafHint => 'يحفظ كل مصحف موضع القراءة الخاص به.';

  @override
  String get continueReading => 'متابعة القراءة';

  @override
  String pageN(int page) {
    return 'صفحة $page';
  }

  @override
  String pageOf(int page, int pages) {
    return 'صفحة $page من $pages';
  }

  @override
  String juzN(int juz) {
    return 'الجزء $juz';
  }

  @override
  String pagesAndLines(int pages, int lines) {
    return '$pages صفحة · $lines سطرًا';
  }

  @override
  String ayahCount(int count) {
    return 'عدد الآيات: $count';
  }

  @override
  String lastRead(int page) {
    return 'آخر قراءة: صفحة $page';
  }

  @override
  String get notStarted => 'لم يُفتح بعد';

  @override
  String get current => 'الحالي';

  @override
  String get read => 'اقرأ';

  @override
  String get changeMushaf => 'تغيير المصحف';

  @override
  String get mushafInfo => 'عن هذا المصحف';

  @override
  String get edition => 'الطبعة';

  @override
  String get source => 'المصدر';

  @override
  String get goTo => 'انتقال';

  @override
  String get surahs => 'السور';

  @override
  String get juzList => 'الأجزاء';

  @override
  String get page => 'الصفحة';

  @override
  String goToPageHint(int pages) {
    return 'رقم الصفحة (١ – $pages)';
  }

  @override
  String invalidPage(int pages) {
    return 'أدخل رقم صفحة بين ١ و$pages';
  }

  @override
  String get go => 'انتقال';

  @override
  String get cancel => 'إلغاء';

  @override
  String get bookmarks => 'العلامات';

  @override
  String get noBookmarks =>
      'لا توجد علامات بعد. أثناء القراءة اضغط زر العلامة لتعليم الصفحة، أو اضغط مطولًا على سطر لتعليم آية.';

  @override
  String get bookmarkPage => 'ضع علامة على هذه الصفحة';

  @override
  String get removePageBookmark => 'أزل علامة الصفحة';

  @override
  String get bookmarkAdded => 'أُضيفت العلامة';

  @override
  String get bookmarkRemoved => 'حُذفت العلامة';

  @override
  String bookmarkAyah(int surah, int ayah) {
    return 'ضع علامة على الآية $surah:$ayah';
  }

  @override
  String ayahRef(int surah, int ayah) {
    return 'الآية $surah:$ayah';
  }

  @override
  String get ayahsOnLine => 'آيات هذا السطر';

  @override
  String get allMushafs => 'كل المصاحف';

  @override
  String get delete => 'حذف';

  @override
  String get settings => 'الإعدادات';

  @override
  String get pageTheme => 'لون الصفحة';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSepia => 'عاجي';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get keepScreenOn => 'إبقاء الشاشة مضاءة أثناء القراءة';

  @override
  String get pageFit => 'ملاءمة الصفحة';

  @override
  String get fitPage => 'الصفحة كاملة';

  @override
  String get fitPageHint => 'تظهر كل الأسطر على الشاشة';

  @override
  String get fitWidth => 'كامل العرض';

  @override
  String get fitWidthHint => 'أكبر خط، مع التمرير إذا كانت الصفحة أطول من الشاشة';

  @override
  String get twoPages => 'صفحتان متجاورتان في الوضع الأفقي';

  @override
  String get showPageInfo => 'إظهار اسم السورة والجزء ورقم الصفحة';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'لغة النظام';

  @override
  String get about => 'حول التطبيق';

  @override
  String get aboutBody =>
      'يعرض قارئ القرآن المصحف صفحةً صفحة وسطرًا سطرًا كما في المصاحف المطبوعة. يعمل دون اتصال بالإنترنت ولا يجمع أي بيانات.';

  @override
  String get sources => 'المصادر والشكر';

  @override
  String get fonts => 'الخطوط';

  @override
  String version(String version) {
    return 'الإصدار $version';
  }

  @override
  String get loadError => 'تعذّر فتح بيانات القرآن.';

  @override
  String get menu => 'القائمة';

  @override
  String get reader => 'القارئ';

  @override
  String get kashida => 'ملء الأسطر بمدّ الحروف (الكشيدة)';

  @override
  String get kashidaHint => 'كما في المصاحف المطبوعة. عند الإيقاف تُملأ الأسطر بتوسيع المسافات.';
}

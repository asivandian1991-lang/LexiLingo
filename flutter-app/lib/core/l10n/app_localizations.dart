// App Localizations Helper
// Usage anywhere:
//   - 'common.loading'.tr()
//   - 'home.greeting'.tr(namedArgs: {'name': 'An'})
//   - 'plural.days'.plural(5)
//   - context.locale  → current Locale
//   - LocaleService.updateAppLocale(context, 'en') → change language

export 'package:easy_localization/easy_localization.dart'
    show EasyLocalization, BuildContextEasyLocalizationExtension;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Supported locales with metadata
class AppLocales {
  static const List<Locale> supportedLocales = [
    Locale('vi'),
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('fr'),
    Locale('es'),
  ];

  static const Locale fallback = Locale('en');

  static const Map<String, Map<String, String>> metadata = {
    'vi': {'flagCode': 'vn', 'flagExt': 'png', 'name': 'Tiếng Việt', 'nameEn': 'Vietnamese'},
    'en': {'flagCode': 'us', 'flagExt': 'png', 'name': 'English', 'nameEn': 'English'},
    'ja': {'flagCode': 'jp', 'flagExt': 'png', 'name': '日本語', 'nameEn': 'Japanese'},
    'ko': {'flagCode': 'kr', 'flagExt': 'png', 'name': '한국어', 'nameEn': 'Korean'},
    'zh': {'flagCode': 'cn', 'flagExt': 'png', 'name': '中文', 'nameEn': 'Chinese'},
    'fr': {'flagCode': 'fr', 'flagExt': 'png', 'name': 'Français', 'nameEn': 'French'},
    'es': {'flagCode': 'es', 'flagExt': 'png', 'name': 'Español', 'nameEn': 'Spanish'},
    'de': {'flagCode': 'de', 'flagExt': 'svg', 'name': 'Deutsch', 'nameEn': 'German'},
    'it': {'flagCode': 'it', 'flagExt': 'svg', 'name': 'Italiano', 'nameEn': 'Italian'},
    'pt': {'flagCode': 'pt', 'flagExt': 'svg', 'name': 'Português', 'nameEn': 'Portuguese'},
    'ar': {'flagCode': 'ar', 'flagExt': 'svg', 'name': 'العربية', 'nameEn': 'Arabic'},
    'fa': {'flagCode': 'ir', 'flagExt': 'svg', 'name': 'فارسی', 'nameEn': 'Persian'},
    'tr': {'flagCode': 'tr', 'flagExt': 'svg', 'name': 'Türkçe', 'nameEn': 'Turkish'},
    'ru': {'flagCode': 'ru', 'flagExt': 'svg', 'name': 'Русский', 'nameEn': 'Russian'},
    'hi': {'flagCode': 'in', 'flagExt': 'svg', 'name': 'हिन्दी', 'nameEn': 'Hindi'},
    'nl': {'flagCode': 'nl', 'flagExt': 'svg', 'name': 'Nederlands', 'nameEn': 'Dutch'},
    'pl': {'flagCode': 'pl', 'flagExt': 'svg', 'name': 'Polski', 'nameEn': 'Polish'},
    'sv': {'flagCode': 'se', 'flagExt': 'svg', 'name': 'Svenska', 'nameEn': 'Swedish'},
    'no': {'flagCode': 'no', 'flagExt': 'svg', 'name': 'Norsk', 'nameEn': 'Norwegian'},
    'da': {'flagCode': 'dk', 'flagExt': 'svg', 'name': 'Dansk', 'nameEn': 'Danish'},
    'fi': {'flagCode': 'fi', 'flagExt': 'svg', 'name': 'Suomi', 'nameEn': 'Finnish'},
    'el': {'flagCode': 'gr', 'flagExt': 'svg', 'name': 'Ελληνικά', 'nameEn': 'Greek'},
    'id': {'flagCode': 'id', 'flagExt': 'svg', 'name': 'Bahasa Indonesia', 'nameEn': 'Indonesian'},
  };

  static String flagCodeOf(String code) => metadata[code]?['flagCode'] ?? 'us';
  static String flagAssetOf(String code) {
    final flagCode = flagCodeOf(code);
    final ext = metadata[code]?['flagExt'] ?? 'png';
    return 'assets/flags/$flagCode.$ext';
  }
  static String nameOf(String code) => metadata[code]?['name'] ?? code;
  static String nameEnOf(String code) => metadata[code]?['nameEn'] ?? code;
}

/// Extension on BuildContext for concise locale switching
extension LocaleHelper on BuildContext {
  /// Current language code e.g. 'vi', 'en'
  String get languageCode => locale.languageCode;

  /// Check if current locale matches code
  bool isLocale(String code) => locale.languageCode == code;
}

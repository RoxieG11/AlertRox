import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/constants/translations.dart';
import '../scripts/check_i18n.dart' as validator;

void main() {
  test('Strict translation parity test: all 10 languages have identical non-empty keys', () {
    final languages = AppTranslations.supportedLocales.map((l) => l['code']!).toList();
    expect(languages.length, 10);

    final translationsFile = File('lib/constants/translations.dart');
    final content = translationsFile.readAsStringSync();
    final translations = validator.parseTranslations(content);

    final allKeys = translations['en']!.keys.toList();
    expect(allKeys.length >= 176, true);

    for (final lang in languages) {
      for (final key in allKeys) {
        final val = AppTranslations.get(key, lang);
        expect(val.isNotEmpty, true, reason: 'Key "$key" is empty in language $lang');
        expect(val.startsWith('‼'), false, reason: 'Key "$key" is missing in language $lang');
      }
    }
  });

  test('Check RTL support for Arabic', () {
    expect(AppTranslations.isRTL('ar'), true);
    expect(AppTranslations.isRTL('en'), false);
    expect(AppTranslations.isRTL('tr'), false);
  });
}

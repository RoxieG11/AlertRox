import 'package:flutter_test/flutter_test.dart';
import 'package:app/constants/translations.dart';

void main() {
  test('Translations sanity test for all 10 languages', () {
    expect(AppTranslations.supportedLocales.length, 10);

    for (final loc in AppTranslations.supportedLocales) {
      final code = loc['code']!;
      expect(AppTranslations.get('app_title', code), 'AlertRox');
      expect(AppTranslations.get('act_lock', code).isNotEmpty, true);
      expect(AppTranslations.get('status_online', code).isNotEmpty, true);
    }

    expect(AppTranslations.isRTL('ar'), true);
    expect(AppTranslations.isRTL('en'), false);
    expect(AppTranslations.isRTL('tr'), false);
  });
}

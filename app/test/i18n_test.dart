import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../scripts/check_i18n.dart' as validator;

void main() {
  test('Complete i18n Parity, Non-Empty, Placeholder, and Untranslated Copy Validator', () {
    final translationsFile = File('lib/constants/translations.dart');
    expect(translationsFile.existsSync(), true,
        reason: 'translations.dart must exist at lib/constants/translations.dart');

    final content = translationsFile.readAsStringSync();
    final translations = validator.parseTranslations(content);

    // 1. All 10 languages
    expect(translations.keys.length, validator.supportedLanguages.length);
    for (final lang in validator.supportedLanguages) {
      expect(translations.containsKey(lang), true,
          reason: 'Language dictionary for "$lang" is missing');
    }

    final enMap = translations['en']!;
    final allKeys = enMap.keys.toSet();

    // 2. Parity & non-empty
    for (final lang in validator.supportedLanguages) {
      final langMap = translations[lang]!;
      final missing = allKeys.difference(langMap.keys.toSet());
      expect(missing.isEmpty, true,
          reason: 'Language "$lang" is missing keys: $missing');

      for (final entry in langMap.entries) {
        expect(entry.value.trim().isNotEmpty, true,
            reason: 'Language "$lang" key "${entry.key}" is empty');
      }
    }

    // 3. Placeholders
    final placeholderRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');
    for (final key in allKeys) {
      final enPlaceholders = placeholderRegex
          .allMatches(enMap[key]!)
          .map((m) => m.group(1)!)
          .toSet();

      for (final lang in validator.supportedLanguages) {
        final placeholders = placeholderRegex
            .allMatches(translations[lang]![key]!)
            .map((m) => m.group(1)!)
            .toSet();

        expect(placeholders, enPlaceholders,
            reason: 'Mismatch in placeholders for key "$key" in lang "$lang"');
      }
    }

    // 4. Non-Latin untranslated English copies
    for (final lang in ['ru', 'ar', 'zh', 'ja']) {
      final langMap = translations[lang]!;
      for (final entry in langMap.entries) {
        final key = entry.key;
        final val = entry.value;
        final enVal = enMap[key]!;

        if (!validator.allowlist.contains(val)) {
          expect(val != enVal, true,
              reason: 'Untranslated English copy found in "$lang": "$key" = "$val"');
        }
      }
    }

    // 5. Hardcoded UI scan
    final libDir = Directory('lib');
    final hardcodedErrors = validator.scanHardcodedStrings(libDir);
    expect(hardcodedErrors.isEmpty, true,
        reason: 'Hardcoded UI strings detected in lib/:\n${hardcodedErrors.join('\n')}');
  });
}

import 'dart:io';

const allowlist = <String>{
  'AlertRox',
  'Wi-Fi',
  'MAC',
  'IP',
  'WoL',
  'PID',
  'URL',
  'Anon Key',
  'Supabase',
  'Supabase URL',
  'Xiaomi',
  'Realme',
  'Oppo',
  'Samsung',
  'Android',
  'Pictures/AlertRox',
  'Download/AlertRox',
  'pictures',
  'calc.exe',
  'KDE Connect',
  'Linux',
  'Windows',
  'PipeWire',
  'PulseAudio',
  'ALSA',
  'ADB',
  'MIUI',
  'HyperOS',
  'SHA-256',
  'Vol +5%',
  'Vol -5%',
  '+5%',
  '-5%',
  'OK',
  '✓',
  'ONLINE',
  'OFFLINE',
  's',
  'm',
  'h',
};

const supportedLanguages = [
  'tr', 'en', 'de', 'ru', 'es', 'ar', 'fr', 'pt', 'zh', 'ja'
];

void main() {
  print('========================================================');
  print('🔍 AlertRox i18n & Static Localization Validator');
  print('========================================================');

  final scriptDir = File(Platform.script.toFilePath()).parent;
  final appDir = scriptDir.path.endsWith('scripts') ? scriptDir.parent : Directory.current;
  final translationsFile = File('${appDir.path}/lib/constants/translations.dart');

  if (!translationsFile.existsSync()) {
    print('❌ Error: translations.dart not found at ${translationsFile.path}');
    exit(1);
  }

  final content = translationsFile.readAsStringSync();
  final translations = parseTranslations(content);

  bool hasError = false;

  // 1. Language count check
  print('\n[1/5] Checking supported languages (${supportedLanguages.length})...');
  for (final lang in supportedLanguages) {
    if (!translations.containsKey(lang)) {
      print('❌ Missing language dictionary: $lang');
      hasError = true;
    }
  }

  final enMap = translations['en'] ?? {};
  final trMap = translations['tr'] ?? {};
  print('  ✓ English keys: ${enMap.length}, Turkish keys: ${trMap.length}');

  // 2. Key completeness & non-empty check
  print('\n[2/5] Checking key parity & non-empty values across all languages...');
  final allKeys = <String>{...enMap.keys, ...trMap.keys};

  for (final lang in supportedLanguages) {
    final langMap = translations[lang] ?? {};
    final missing = allKeys.difference(langMap.keys.toSet());
    if (missing.isNotEmpty) {
      print('❌ [$lang] Missing ${missing.length} keys: ${missing.take(5).join(', ')}...');
      hasError = true;
    }

    for (final entry in langMap.entries) {
      if (entry.value.trim().isEmpty) {
        print('❌ [$lang] Key "${entry.key}" has empty value!');
        hasError = true;
      }
    }
  }

  // 3. Placeholder match check ({name}, {url}, etc.)
  print('\n[3/5] Validating parameter placeholders ({param})...');
  final placeholderRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');

  for (final key in allKeys) {
    final enVal = enMap[key] ?? '';
    final enPlaceholders = placeholderRegex
        .allMatches(enVal)
        .map((m) => m.group(1)!)
        .toSet();

    for (final lang in supportedLanguages) {
      final val = translations[lang]?[key] ?? '';
      final placeholders = placeholderRegex
          .allMatches(val)
          .map((m) => m.group(1)!)
          .toSet();

      if (placeholders.length != enPlaceholders.length ||
          !placeholders.containsAll(enPlaceholders)) {
        print('❌ [$lang] Placeholder mismatch in "$key": expected $enPlaceholders, found $placeholders');
        hasError = true;
      }
    }
  }

  // 4. Untranslated English copies in non-Latin languages
  print('\n[4/5] Checking for untranslated English copies in non-Latin languages (ru, ar, zh, ja)...');
  final nonLatinLangs = ['ru', 'ar', 'zh', 'ja'];
  for (final lang in nonLatinLangs) {
    final langMap = translations[lang] ?? {};
    int untranslatedCount = 0;
    for (final entry in langMap.entries) {
      final key = entry.key;
      final val = entry.value;
      final enVal = enMap[key] ?? '';

      if (val == enVal && !allowlist.contains(val)) {
        print('❌ [$lang] Untranslated English string copied: "$key" = "$val"');
        untranslatedCount++;
        hasError = true;
      }
    }
    if (untranslatedCount == 0) {
      print('  ✓ [$lang] 0 untranslated strings found.');
    }
  }

  // 5. Static code scanner for hardcoded UI strings in lib/
  print('\n[5/5] Scanning lib/ for hardcoded UI strings in Text/SnackBar...');
  final libDir = Directory('${appDir.path}/lib');
  final hardcodedErrors = scanHardcodedStrings(libDir);
  if (hardcodedErrors.isNotEmpty) {
    print('❌ Found ${hardcodedErrors.length} hardcoded string(s) in source code:');
    for (final err in hardcodedErrors) {
      print('  - $err');
    }
    hasError = true;
  } else {
    print('  ✓ 0 hardcoded UI strings detected in lib/');
  }

  print('\n========================================================');
  if (hasError) {
    print('❌ VALIDATION FAILED: Please fix the localization issues listed above.');
    print('========================================================');
    exit(1);
  } else {
    print('✅ ALL I18N CHECKS PASSED: 10 languages fully translated and verified!');
    print('========================================================');
    exit(0);
  }
}

Map<String, Map<String, String>> parseTranslations(String content) {
  final Map<String, Map<String, String>> result = {};
  String? currentLang;

  final lines = content.split('\n');
  for (final rawLine in lines) {
    final line = rawLine.trim();
    final langMatch = RegExp(r"^'([a-z]{2})':\s*\{").firstMatch(line);
    if (langMatch != null) {
      currentLang = langMatch.group(1);
      result[currentLang!] = {};
      continue;
    }

    if (currentLang != null && line.startsWith("'") && line.contains(':')) {
      final colonIdx = line.indexOf(':');
      final key = line.substring(0, colonIdx).trim().replaceAll("'", '').replaceAll('"', '');
      var val = line.substring(colonIdx + 1).trim();
      if (val.endsWith(',') || val.endsWith('},')) {
        val = val.substring(0, val.length - 1).trim();
      }
      if (val.endsWith('}')) {
        val = val.substring(0, val.length - 1).trim();
      }
      if (val.startsWith("'") && val.endsWith("'") && val.length >= 2) {
        val = val.substring(1, val.length - 1);
      } else if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
        val = val.substring(1, val.length - 1);
      }
      // Unescape
      val = val.replaceAll(r"\'", "'").replaceAll(r'\"', '"').replaceAll(r'\$', r'$');
      result[currentLang]![key] = val;
    }
  }
  return result;
}

List<String> scanHardcodedStrings(Directory libDir) {
  final errors = <String>[];
  if (!libDir.existsSync()) return errors;

  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('constants/translations.dart'));

  final rawTextRegex = RegExp(r"""Text\(\s*'([^'\$]+)'\s*[,|\)]""");

  // Allowed strings in Text widget (e.g. icons, math symbols, technical IDs)
  final textAllowlist = <String>{
    '+', '-', '%', '✓', '✕', '!', '?', ':', '/', '|', '...', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'AlertRox', 'Supabase', 'Linux', 'Windows', 'PipeWire', 'PulseAudio', 'ALSA',
    '10s', '30s', '60s', '5m', '10m', '30m', '1h', '2h', '4h',
  };

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Exclude comments and debug prints
      final trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.contains('debugPrint(')) {
        continue;
      }

      for (final match in rawTextRegex.allMatches(line)) {
        final literal = match.group(1)!.trim();
        // Skip short non-alpha or allowlisted symbols
        if (literal.length <= 2 && !RegExp(r'[a-zA-Z]').hasMatch(literal)) continue;
        if (textAllowlist.contains(literal)) continue;
        if (literal.startsWith('http://') || literal.startsWith('https://')) continue;
        if (literal.contains('/') && !literal.contains(' ')) continue;

        final relativePath = file.path.split('lib/').last;
        errors.add('lib/$relativePath:${i + 1} -> Text(\'$literal\')');
      }
    }
  }

  return errors;
}

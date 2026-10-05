import 'package:flutter/material.dart';

class ThemePreset {
  final String id;
  final String name;
  final Color primary;
  final Color secondary;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
  });
}

class AppTheme {
  // Preset list
  static const List<ThemePreset> presets = [
    ThemePreset(
      id: 'cyberpunk_cyan',
      name: 'AlertRox Cyan',
      primary: Color(0xFF00F0FF),
      secondary: Color(0xFF10B981),
    ),
    ThemePreset(
      id: 'neon_emerald',
      name: 'Zümrüt Yeşili',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF06B6D4),
    ),
    ThemePreset(
      id: 'cyberpunk_pink',
      name: 'Cyberpunk Neon',
      primary: Color(0xFFFF007F),
      secondary: Color(0xFF9D4EDD),
    ),
    ThemePreset(
      id: 'sunset_orange',
      name: 'Gün Batımı Turuncu',
      primary: Color(0xFFFF6B00),
      secondary: Color(0xFFF59E0B),
    ),
    ThemePreset(
      id: 'electric_blue',
      name: 'Elektrik Mavisi',
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF60A5FA),
    ),
    ThemePreset(
      id: 'matrix_green',
      name: 'Matrix Yeşili',
      primary: Color(0xFF00FF66),
      secondary: Color(0xFF10B981),
    ),
    ThemePreset(
      id: 'crimson_red',
      name: 'Kızıl Kırmızı',
      primary: Color(0xFFEF4444),
      secondary: Color(0xFFDC2626),
    ),
  ];

  // Dark Colors
  static const Color darkBg = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF161F30);
  static const Color darkCardBorder = Color(0xFF1F293D);
  static const Color primaryTeal = Color(0xFF10B981);
  static const Color accentCyan = Color(0xFF00F0FF);
  static const Color darkText = Color(0xFFF3F4F6);
  static const Color darkTextMuted = Color(0xFF9CA3AF);

  // Light Colors (High Contrast & Crisp)
  static const Color lightBg = Color(0xFFF1F5F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFCBD5E1);
  static const Color lightPrimary = Color(0xFF0D9488);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF475569);

  // Status Colors
  static const Color statusOnline = Color(0xFF10B981);
  static const Color statusOffline = Color(0xFFEF4444);
  static const Color statusWarning = Color(0xFFF59E0B);

  static ThemeData getTheme(
    Brightness brightness, {
    Color primary = accentCyan,
    Color secondary = primaryTeal,
    bool isGlassmorphic = false,
  }) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? darkBg : lightBg;
    final surface = isDark ? darkSurface : lightSurface;
    final text = isDark ? darkText : lightText;
    final textMuted = isDark ? darkTextMuted : lightTextMuted;

    // Glassmorphic styling adjustments
    final cardColor = isGlassmorphic
        ? (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.65))
        : (isDark ? darkCard : lightCard);

    final cardBorder = isGlassmorphic
        ? (isDark
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.8))
        : (isDark ? darkCardBorder : lightCardBorder);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: text,
        error: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isGlassmorphic ? Colors.transparent : bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isGlassmorphic ? 0 : (isDark ? 0 : 2),
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: cardBorder,
            width: isGlassmorphic ? 1.4 : 1.0,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: isGlassmorphic ? 0 : 1,
          backgroundColor: isGlassmorphic
              ? primary.withValues(alpha: 0.18)
              : primary,
          foregroundColor: isGlassmorphic
              ? primary
              : (isDark ? Colors.black : Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: isGlassmorphic
              ? BorderSide(color: primary.withValues(alpha: 0.5), width: 1.2)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isGlassmorphic
            ? (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.7))
            : (isDark ? darkSurface : Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.8),
        ),
        hintStyle: TextStyle(color: textMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isGlassmorphic
            ? (isDark
                ? darkSurface.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.75))
            : surface,
        elevation: isDark ? 0 : 3,
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primary,
            );
          }
          return TextStyle(fontSize: 12, color: textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return IconThemeData(color: textMuted);
        }),
      ),
    );
  }

  // Backwards compatibility getters
  static ThemeData get darkTheme => getTheme(Brightness.dark);
  static ThemeData get lightTheme => getTheme(Brightness.light);
}

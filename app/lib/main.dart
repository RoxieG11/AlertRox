import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'constants/theme.dart';
import 'constants/translations.dart';
import 'providers/app_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'services/supabase_service.dart';
import 'services/foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService().initialize();
  AlertRoxForegroundService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppProvider()..initialize(),
        ),
      ],
      child: const AlertRoxApp(),
    ),
  );
}

class AlertRoxApp extends StatelessWidget {
  const AlertRoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return MaterialApp(
      title: 'AlertRox',
      theme: AppTheme.getTheme(
        Brightness.light,
        primary: provider.accentColor,
        secondary: provider.secondaryColor,
        isGlassmorphic: provider.glassmorphicMode,
      ),
      darkTheme: AppTheme.getTheme(
        Brightness.dark,
        primary: provider.accentColor,
        secondary: provider.secondaryColor,
        isGlassmorphic: provider.glassmorphicMode,
      ),
      themeMode: provider.themeMode,
      locale: Locale(provider.currentLanguage),
      supportedLocales: AppTranslations.supportedLocales
          .map((l) => Locale(l['code']!))
          .toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (!provider.glassmorphicMode) {
          return child ?? const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF0A0E1A), Color(0xFF1A0B2E)]
                        : const [
                            Color(0xFFF0F4F8),
                            Color(0xFFE2E8F0),
                            Color(0xFFFCE7F3),
                          ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80,
              right: -80,
              width: 280,
              height: 280,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: provider.accentColor
                      .withValues(alpha: isDark ? 0.35 : 0.38),
                ),
              ),
            ),
            Positioned(
              bottom: 140,
              left: -90,
              width: 320,
              height: 320,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: provider.secondaryColor
                      .withValues(alpha: isDark ? 0.28 : 0.32),
                ),
              ),
            ),
            Positioned(
              top: 320,
              right: -50,
              width: 220,
              height: 220,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: provider.accentColor
                      .withValues(alpha: isDark ? 0.20 : 0.28),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                child: const SizedBox.expand(),
              ),
            ),
            ?child,
          ],
        );
      },
      home: const MainNavigationScreen(),
    );
  }
}

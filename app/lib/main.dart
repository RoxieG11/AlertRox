import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'constants/theme.dart';
import 'constants/translations.dart';
import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
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
    return Selector<AppProvider, ({
      ThemeMode mode,
      Color primary,
      Color secondary,
      bool isGlass,
      String lang,
    })>(
      selector: (_, p) => (
        mode: p.themeMode,
        primary: p.accentColor,
        secondary: p.secondaryColor,
        isGlass: p.glassmorphicMode,
        lang: p.currentLanguage,
      ),
      builder: (context, cfg, _) {
        return MaterialApp(
          title: 'AlertRox',
          theme: AppTheme.getTheme(
            Brightness.light,
            primary: cfg.primary,
            secondary: cfg.secondary,
            isGlassmorphic: cfg.isGlass,
          ),
          darkTheme: AppTheme.getTheme(
            Brightness.dark,
            primary: cfg.primary,
            secondary: cfg.secondary,
            isGlassmorphic: cfg.isGlass,
          ),
          themeMode: cfg.mode,
          locale: Locale(cfg.lang),
          supportedLocales: AppTranslations.supportedLocales
              .map((l) => Locale(l['code']!))
              .toList(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            if (!cfg.isGlass) {
              return child ?? const SizedBox.shrink();
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? const [
                                        Color(0xFF0A0E1A),
                                        Color(0xFF1A0B2E)
                                      ]
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
                          width: 320,
                          height: 320,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  cfg.primary
                                      .withValues(alpha: isDark ? 0.35 : 0.38),
                                  cfg.primary.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 120,
                          left: -90,
                          width: 360,
                          height: 360,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  cfg.secondary
                                      .withValues(alpha: isDark ? 0.28 : 0.32),
                                  cfg.secondary.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 300,
                          right: -60,
                          width: 260,
                          height: 260,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  cfg.primary
                                      .withValues(alpha: isDark ? 0.20 : 0.25),
                                  cfg.primary.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ?child,
              ],
            );
          },
          home: Consumer<AppProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && !provider.isAuthenticated) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return provider.isAuthenticated
                  ? const MainNavigationScreen()
                  : const LoginScreen();
            },
          ),
        );
      },
    );
  }
}

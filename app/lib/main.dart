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
      home: const MainNavigationScreen(),
    );
  }
}

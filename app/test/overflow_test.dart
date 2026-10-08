import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/providers/app_provider.dart';
import 'package:app/constants/translations.dart';
import 'package:app/widgets/volume_control_sheet.dart';
import 'package:app/widgets/permission_onboarding_dialog.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:app/screens/appearance_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testLanguages = ['ru', 'de', 'tr', 'en', 'ar', 'zh', 'ja'];
  final textScales = [1.0, 1.3];

  testWidgets('Overflow test: VolumeControlSheet renders cleanly on 360dp without RenderFlex overflow', (tester) async {
    for (final lang in testLanguages) {
      for (final textScale in textScales) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = AppProvider();
        provider.setLanguage(lang);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 640),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: Scaffold(
                  body: VolumeControlSheet(
                    targetId: 'dummy-id',
                    provider: provider,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull,
            reason: 'Overflow in VolumeControlSheet for lang $lang at scale $textScale');
      }
    }
  });

  testWidgets('Overflow test: SettingsScreen renders cleanly on 360dp without RenderFlex overflow', (tester) async {
    for (final lang in ['ru', 'de']) {
      for (final textScale in textScales) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = AppProvider();
        provider.setLanguage(lang);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 640),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: const SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Overflow in SettingsScreen for lang $lang at scale $textScale');
      }
    }
  });

  testWidgets('Overflow test: AppearanceScreen renders cleanly on 360dp without RenderFlex overflow', (tester) async {
    for (final lang in ['ru', 'de']) {
      for (final textScale in textScales) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = AppProvider();
        provider.setLanguage(lang);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 640),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: const AppearanceScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Overflow in AppearanceScreen for lang $lang at scale $textScale');
      }
    }
  });

  testWidgets('Overflow test: PermissionOnboardingDialog renders cleanly on 360dp without RenderFlex overflow', (tester) async {
    for (final lang in ['ru', 'de', 'tr', 'en']) {
      for (final textScale in textScales) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = AppProvider();
        provider.setLanguage(lang);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 640),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: Scaffold(
                  body: PermissionOnboardingDialog(
                    langCode: lang,
                    accentColor: const Color(0xFF00F0FF),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'Overflow in PermissionOnboardingDialog for lang $lang at scale $textScale');
      }
    }
  });
}

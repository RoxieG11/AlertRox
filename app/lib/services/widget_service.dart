import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../constants/translations.dart';

class WidgetService {
  static Future<void> updateWidget({
    required Map<String, dynamic>? device,
    required bool isOnline,
    String langCode = 'tr',
    bool isShuttingDown = false,
    String? shutdownCountdown,
    String widgetTheme = 'dark',
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final name = device?['name'] ?? device?['device_name'] ?? 'AlertRox PC';
      final statusOnlineText = AppTranslations.get('status_online', langCode);
      final statusOfflineText = AppTranslations.get('status_offline', langCode);
      final status = isOnline ? '● $statusOnlineText' : '● $statusOfflineText';
      final lastSeenLabel = AppTranslations.get('last_seen', langCode);

      String lastSeen = '--:--';
      if (device?['last_heartbeat'] != null) {
        try {
          final dt = DateTime.parse(device!['last_heartbeat']).toLocal();
          lastSeen =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }

      await HomeWidget.saveWidgetData<String>('device_name', name.toString());
      await HomeWidget.saveWidgetData<String>('device_status', status);
      await HomeWidget.saveWidgetData<String>(
          'last_seen', '$lastSeenLabel: $lastSeen');
      await HomeWidget.saveWidgetData<bool>('is_online', isOnline);
      await HomeWidget.saveWidgetData<bool>('is_shutting_down', isShuttingDown);
      await HomeWidget.saveWidgetData<String>(
          'shutdown_countdown', shutdownCountdown ?? '');
      await HomeWidget.saveWidgetData<String>('widget_theme', widgetTheme);

      await HomeWidget.updateWidget(
        name: 'AlertRoxWidgetProvider',
        androidName: 'AlertRoxWidgetProvider',
        qualifiedAndroidName: 'com.roxie.alertrox.app.AlertRoxWidgetProvider',
      );
    } catch (e) {
      debugPrint('Home widget update error: $e');
    }
  }
}

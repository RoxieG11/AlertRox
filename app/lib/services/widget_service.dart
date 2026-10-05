import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static Future<void> updateWidget({
    required Map<String, dynamic>? device,
    required bool isOnline,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final name = device?['name'] ?? device?['device_name'] ?? 'AlertRox PC';
      final status = isOnline ? '● ÇEVRİMİÇİ' : '● ÇEVRİMDışı';
      
      String lastSeen = '--:--';
      if (device?['last_heartbeat'] != null) {
        try {
          final dt = DateTime.parse(device!['last_heartbeat']).toLocal();
          lastSeen = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }

      await HomeWidget.saveWidgetData<String>('device_name', name.toString());
      await HomeWidget.saveWidgetData<String>('device_status', status);
      await HomeWidget.saveWidgetData<String>('last_seen', lastSeen);
      await HomeWidget.saveWidgetData<bool>('is_online', isOnline);

      await HomeWidget.updateWidget(
        name: 'AlertRoxWidgetProvider',
        androidName: 'AlertRoxWidgetProvider',
      );
    } catch (e) {
      debugPrint('Home widget update error: $e');
    }
  }
}

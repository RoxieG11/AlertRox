import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(WatchdogTaskHandler());
}

class WatchdogTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class AlertRoxForegroundService {
  static void init() {
    if (kIsWeb || !Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'alertrox_watchdog_channel',
        channelName: 'AlertRox Gözcü Servisi',
        channelDescription: 'PC bağlantısını arka planda uyanık tutar',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> start() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      if (await FlutterForegroundTask.isRunningService) return true;

      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'AlertRox Gözcü Aktif',
        notificationText: 'PC açılışı ve bağlantı durumu izleniyor',
        callback: startCallback,
      );
      return result is ServiceRequestSuccess;
    } catch (e) {
      debugPrint('Foreground service start error: $e');
      return false;
    }
  }

  static Future<bool> stop() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await FlutterForegroundTask.stopService();
      return result is ServiceRequestSuccess;
    } catch (e) {
      debugPrint('Foreground service stop error: $e');
      return false;
    }
  }

  static Future<bool> isRunning() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }
}

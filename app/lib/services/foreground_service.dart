import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(WatchdogTaskHandler());
}

class WatchdogTaskHandler extends TaskHandler {
  SupabaseClient? _supabaseClient;
  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      // 1. Initialize Supabase in background isolate using stored or default credentials
      final url =
          await FlutterForegroundTask.getData<String>(key: 'supabase_url') ??
              SupabaseService.defaultUrl;
      final key =
          await FlutterForegroundTask.getData<String>(key: 'supabase_key') ??
              SupabaseService.defaultKey;

      _supabaseClient = SupabaseClient(url.trim(), key.trim());

      // 2. Initialize local notifications plugin in background isolate
      _notificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      await _notificationsPlugin?.initialize(
        settings: const InitializationSettings(android: androidSettings),
      );

      final androidImplementation =
          _notificationsPlugin?.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      const AndroidNotificationChannel statusChannel =
          AndroidNotificationChannel(
        'alertrox_device_status',
        'Cihaz Durum Bildirimleri',
        description:
            'Bilgisayar açıldığında ve çevrimiçi olduğunda gelen bildirimler',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation?.createNotificationChannel(statusChannel);
    } catch (_) {
      // Graceful error handling - never crash isolate
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    try {
      if (_supabaseClient == null) return;

      final response = await _supabaseClient!
          .from('devices')
          .select()
          .order('last_heartbeat', ascending: false);

      final devices = List<Map<String, dynamic>>.from(response);
      if (devices.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();

      for (final dev in devices) {
        final deviceId = (dev['device_id'] ?? dev['id']).toString();
        final devName = (dev['name'] ?? dev['device_name'] ?? 'PC').toString();
        final isOnlineNow = _isDeviceOnline(dev);

        final prevOnlineKey = 'device_online_$deviceId';
        final wasOnline = prefs.getBool(prevOnlineKey);

        // Check if device booted recently (last_boot within 90 seconds)
        bool isRecentBoot = false;
        final lastBootStr = dev['last_boot'] as String?;
        if (lastBootStr != null) {
          final dt = DateTime.tryParse(lastBootStr);
          if (dt != null) {
            final diff = DateTime.now()
                .toUtc()
                .difference(dt.toUtc())
                .inSeconds
                .abs();
            if (diff <= 90) {
              isRecentBoot = true;
            }
          }
        }

        final lastNotifiedBootKey = 'last_notified_boot_$deviceId';
        final lastNotifiedBoot = prefs.getString(lastNotifiedBootKey);
        final currentBootId = lastBootStr ?? 'boot_$deviceId';

        // Notify conditions:
        // (a) was offline and now online OR (first seen wasOnline == null, is online, and recent boot)
        // (b) and not already notified for this exact boot
        final shouldNotify = isOnlineNow &&
            ((wasOnline == false) || (wasOnline == null && isRecentBoot)) &&
            (lastNotifiedBoot != currentBootId);

        if (shouldNotify) {
          await _showDeviceOnlineNotification(devName);
          await prefs.setString(lastNotifiedBootKey, currentBootId);
        }

        await prefs.setBool(prevOnlineKey, isOnlineNow);
      }
    } catch (_) {
      // Gracefully catch network / socket / format errors so service never crashes
    }
  }

  bool _isDeviceOnline(Map<String, dynamic> device) {
    final status = device['status']?.toString();
    if (status == 'offline') return false;

    final lastHeartbeat = device['last_heartbeat'] as String?;
    if (lastHeartbeat == null) return false;

    try {
      final lastTime = DateTime.parse(lastHeartbeat).toUtc();
      final now = DateTime.now().toUtc();
      return now.difference(lastTime).inSeconds.abs() <= 45;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showDeviceOnlineNotification(String deviceName) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'alertrox_device_status',
      'Cihaz Durum Bildirimleri',
      channelDescription:
          'Bilgisayar açıldığında ve çevrimiçi olduğunda gelen bildirimler',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    await _notificationsPlugin?.show(
      id: 1001,
      title: '💻 AlertRox: $deviceName Açıldı!',
      body: 'Bilgisayarınız çevrimiçi oldu ve bağlantı kuruldu.',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (isTimeout) {
      // Attempt restart if service times out or is destroyed
      await AlertRoxForegroundService.start();
    }
  }
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
      // 1. Pass Supabase credentials to background isolate via saveData (without logging secrets)
      final creds = await SupabaseService().getSavedCredentials();
      await FlutterForegroundTask.saveData(
        key: 'supabase_url',
        value: creds['url'] ?? SupabaseService.defaultUrl,
      );
      await FlutterForegroundTask.saveData(
        key: 'supabase_key',
        value: creds['key'] ?? SupabaseService.defaultKey,
      );

      // 2. Check and request notification permissions
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // 3. Do not re-start if service is already running
      if (await FlutterForegroundTask.isRunningService) return true;

      // 4. Start foreground service with specialUse type for Android 14/15 compatibility
      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'AlertRox Gözcü Aktif',
        notificationText: 'PC açılışı ve bağlantı durumu izleniyor',
        serviceTypes: [ForegroundServiceTypes.specialUse],
        callback: startCallback,
      );
      if (result is! ServiceRequestSuccess) {
        debugPrint('Foreground service start failed: $result');
        return false;
      }
      return true;
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

  static Future<void> syncCredentials(String url, String key) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await FlutterForegroundTask.saveData(key: 'supabase_url', value: url);
    await FlutterForegroundTask.saveData(key: 'supabase_key', value: key);
  }
}

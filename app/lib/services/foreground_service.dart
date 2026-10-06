import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/translations.dart';
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
      // 1. Initialize Supabase in background isolate using encrypted storage
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final url = await secureStorage.read(key: SupabaseService.keyUrl);
      final anonKey = await secureStorage.read(key: SupabaseService.keyAnonKey);
      final token = await secureStorage.read(key: SupabaseService.keyAccessToken);

      if (url != null && url.isNotEmpty && anonKey != null && anonKey.isNotEmpty) {
        final headers = <String, String>{};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        _supabaseClient = SupabaseClient(
          url.trim(),
          anonKey.trim(),
          headers: headers,
        );
      }

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
      if (_supabaseClient == null) {
        const secureStorage = FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );
        final url = await secureStorage.read(key: SupabaseService.keyUrl);
        final anonKey = await secureStorage.read(key: SupabaseService.keyAnonKey);
        final token = await secureStorage.read(key: SupabaseService.keyAccessToken);

        if (url != null && url.isNotEmpty && anonKey != null && anonKey.isNotEmpty) {
          final headers = <String, String>{};
          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
          }
          _supabaseClient = SupabaseClient(
            url.trim(),
            anonKey.trim(),
            headers: headers,
          );
        }
      }

      if (_supabaseClient == null) return;

      final response = await _supabaseClient!
          .from('devices')
          .select('id, device_id, name, status, last_heartbeat, last_boot')
          .order('last_heartbeat', ascending: false);

      final devices = List<Map<String, dynamic>>.from(response);
      if (devices.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

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

        // Laptop Pil & Güç Durumu Bildirimlerini Kontrol Et (activity_log)
        try {
          final logResp = await _supabaseClient!
              .from('activity_log')
              .select('id, event_type, message, created_at')
              .eq('device_id', deviceId)
              .inFilter('event_type', ['power_unplugged', 'battery_critical_low'])
              .order('created_at', ascending: false)
              .limit(1);

          final logs = List<Map<String, dynamic>>.from(logResp);
          if (logs.isNotEmpty) {
            final latestLog = logs.first;
            final logId = latestLog['id'].toString();
            final lastHandledLogKey = 'last_handled_power_log_$deviceId';
            final lastHandledId = prefs.getString(lastHandledLogKey);

            if (lastHandledId != logId) {
              final evType = latestLog['event_type'];
              final msg = latestLog['message'] ?? '';
              final createdAtStr = latestLog['created_at'] as String?;
              bool isFresh = true;
              if (createdAtStr != null) {
                final dt = DateTime.tryParse(createdAtStr);
                if (dt != null) {
                  // Son 3 dakika içinde oluşmuş olayları bildir
                  isFresh = DateTime.now().toUtc().difference(dt.toUtc()).inSeconds.abs() <= 180;
                }
              }

              if (isFresh) {
                if (evType == 'power_unplugged') {
                  await _showPowerNotification(
                    id: 2001,
                    title: '⚡ AlertRox: $devName Şarjdan Çekildi!',
                    body: msg.isNotEmpty ? msg : 'Laptop prizden çekildi, pille çalışıyor.',
                  );
                } else if (evType == 'battery_critical_low') {
                  await _showPowerNotification(
                    id: 2002,
                    title: '🚨 AlertRox: Kritik Düşük Pil Uyarısı!',
                    body: msg.isNotEmpty ? msg : '$devName pili %20 altına düştü! Lütfen şarja takın.',
                  );
                }
              }
              await prefs.setString(lastHandledLogKey, logId);
            }
          }
        } catch (_) {}
      }

      // Update Home Screen Widget in background isolate
      try {
        final selectedDevId = prefs.getString('selected_device_id');
        Map<String, dynamic> targetDev = devices.first;
        if (selectedDevId != null) {
          targetDev = devices.firstWhere(
            (d) => (d['device_id'] ?? d['id']).toString() == selectedDevId,
            orElse: () => devices.first,
          );
        }

        final isDevOnline = _isDeviceOnline(targetDev);
        final devName =
            (targetDev['name'] ?? targetDev['device_name'] ?? 'AlertRox PC')
                .toString();
        final langCode = prefs.getString('app_language') ?? 'tr';

        String lastSeenMinute = '--:--';
        if (targetDev['last_heartbeat'] != null) {
          try {
            final dt = DateTime.parse(targetDev['last_heartbeat']).toLocal();
            lastSeenMinute =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } catch (_) {}
        }

        final lastWidgetOnline = prefs.getBool('widget_cached_online');
        final lastWidgetMinute = prefs.getString('widget_cached_minute');
        final lastWidgetName = prefs.getString('widget_cached_name');

        final widgetNeedsUpdate = lastWidgetOnline != isDevOnline ||
            lastWidgetMinute != lastSeenMinute ||
            lastWidgetName != devName;

        if (widgetNeedsUpdate) {
          final statusOnlineText = AppTranslations.get('status_online', langCode);
          final statusOfflineText = AppTranslations.get('status_offline', langCode);
          final status =
              isDevOnline ? '● $statusOnlineText' : '● $statusOfflineText';
          final lastSeenLabel = AppTranslations.get('last_seen', langCode);

          final widgetMode = prefs.getString('widget_mode') ?? 'dark';
          final widgetGlass = prefs.getBool('widget_glass') ?? true;
          final widgetOpacity = prefs.getInt('widget_opacity') ?? 85;

          final widgetColorMode = prefs.getString('widget_color_mode') ?? 'same_as_app';
          final appAccent = prefs.getInt('theme_accent') ?? 0xFF00F0FF;
          final appSecondary = prefs.getInt('theme_secondary') ?? 0xFF10B981;
          final customAccent = prefs.getInt('widget_accent') ?? 0xFF00F0FF;
          final customSecondary = prefs.getInt('widget_secondary') ?? 0xFF10B981;

          final effectiveAccent = widgetColorMode == 'same_as_app' ? appAccent : customAccent;
          final effectiveSecondary = widgetColorMode == 'same_as_app' ? appSecondary : customSecondary;

          await HomeWidget.saveWidgetData<String>('device_name', devName);
          await HomeWidget.saveWidgetData<String>('device_status', status);
          await HomeWidget.saveWidgetData<String>(
              'last_seen', '$lastSeenLabel: $lastSeenMinute');
          await HomeWidget.saveWidgetData<bool>('is_online', isDevOnline);
          await HomeWidget.saveWidgetData<String>('widget_theme', widgetMode);
          await HomeWidget.saveWidgetData<String>('widget_mode', widgetMode);
          await HomeWidget.saveWidgetData<bool>('widget_glass', widgetGlass);
          await HomeWidget.saveWidgetData<int>('widget_opacity', widgetOpacity);
          await HomeWidget.saveWidgetData<int>('widget_accent', effectiveAccent);
          await HomeWidget.saveWidgetData<int>(
              'widget_secondary', effectiveSecondary);

          await HomeWidget.updateWidget(
            name: 'AlertRoxWidgetProvider',
            androidName: 'AlertRoxWidgetProvider',
            qualifiedAndroidName:
                'com.roxie.alertrox.app.AlertRoxWidgetProvider',
          );

          await prefs.setBool('widget_cached_online', isDevOnline);
          await prefs.setString('widget_cached_minute', lastSeenMinute);
          await prefs.setString('widget_cached_name', devName);
        }
      } catch (_) {}
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

  Future<void> _showPowerNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'alertrox_power_channel',
      'Güç ve Pil Bildirimleri',
      channelDescription:
          'Laptop şarjdan çekildiğinde veya pil azaldığında gönderilen acil bildirimler',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    await _notificationsPlugin?.show(
      id: id,
      title: title,
      body: body,
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
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> start() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      // 1. Check and request notification permissions
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // 2. Do not re-start if service is already running
      if (await FlutterForegroundTask.isRunningService) return true;

      // 3. Start foreground service with specialUse type for Android 14/15 compatibility
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
}

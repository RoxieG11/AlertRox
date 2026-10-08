import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/translations.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String _currentLang = 'tr';

  void updateLanguage(String langCode) {
    _currentLang = langCode;
  }

  Future<void> init([String? langCode]) async {
    if (langCode != null) _currentLang = langCode;
    if (_initialized) return;

    if (!kIsWeb && Platform.isAndroid) {
      // 1. Android Yerel Bildirim Kanalı Yapılandırması
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        linux: LinuxInitializationSettings(defaultActionName: 'Open AlertRox'),
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // 2. Android Bildirim Kanallarını Kaydet
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final statusName = AppTranslations.get('notif_channel_status_name', _currentLang);
      final statusDesc = AppTranslations.get('notif_channel_status_desc', _currentLang);
      final shutdownName = AppTranslations.get('notif_channel_shutdown_name', _currentLang);
      final shutdownDesc = AppTranslations.get('notif_channel_shutdown_desc', _currentLang);

      final AndroidNotificationChannel statusChannel = AndroidNotificationChannel(
        'alertrox_device_status',
        statusName,
        description: statusDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final AndroidNotificationChannel shutdownChannel = AndroidNotificationChannel(
        'alertrox_shutdown_status',
        shutdownName,
        description: shutdownDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation?.createNotificationChannel(statusChannel);
      await androidImplementation?.createNotificationChannel(shutdownChannel);

      // 3. Android 13+ (API 33+) Çalışma zamanı bildirim izni iste
      await androidImplementation?.requestNotificationsPermission();

      _initialized = true;
    }
  }

  Future<void> showTestNotification([String? langCode]) async {
    if (kIsWeb) return;
    final lang = langCode ?? _currentLang;
    final title = AppTranslations.get('notif_test_title', lang);
    final body = AppTranslations.get('notif_test_body', lang);
    final channelName = AppTranslations.get('notif_channel_status_name', lang);
    final channelDesc = AppTranslations.get('notif_channel_status_desc', lang);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'alertrox_device_status',
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      linux: const LinuxNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: 9999,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> showDeviceOnlineNotification(String deviceName, [String? langCode]) async {
    if (kIsWeb) return;
    final lang = langCode ?? _currentLang;
    final title = AppTranslations.get('notif_device_boot_title', lang).replaceAll('{device}', deviceName);
    final body = AppTranslations.get('notif_device_boot_desc', lang);
    final channelName = AppTranslations.get('notif_channel_status_name', lang);
    final channelDesc = AppTranslations.get('notif_channel_status_desc', lang);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'alertrox_device_status',
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      linux: const LinuxNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: 1001,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> showShutdownWarningNotification(
      String deviceName, int seconds, [String? langCode]) async {
    if (kIsWeb) return;
    final lang = langCode ?? _currentLang;
    final title = AppTranslations.get('notif_shutdown_warning_title', lang).replaceAll('{device}', deviceName);
    final body = AppTranslations.get('notif_shutdown_seconds', lang).replaceAll('{seconds}', seconds.toString());
    final channelName = AppTranslations.get('notif_channel_shutdown_name', lang);
    final channelDesc = AppTranslations.get('notif_channel_shutdown_desc', lang);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'alertrox_shutdown_status',
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id: 1002,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}

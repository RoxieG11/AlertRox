import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (!kIsWeb && Platform.isAndroid) {
      // 1. Android 13+ Çalışma zamanı bildirim izni iste
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }

      // 2. Android Yerel Bildirim Kanalı Yapılandırması
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

      _initialized = true;
    }
  }

  Future<void> showDeviceOnlineNotification(String deviceName) async {
    if (kIsWeb) return;

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

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      linux: LinuxNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: 1001,
      title: '💻 AlertRox: $deviceName Açıldı!',
      body: 'Bilgisayarınız çevrimiçi oldu ve bağlantı kuruldu.',
      notificationDetails: details,
    );
  }

  Future<void> showShutdownWarningNotification(
      String deviceName, int seconds) async {
    if (kIsWeb) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'alertrox_shutdown_status',
      'Kapatma Bildirimleri',
      channelDescription: 'Bilgisayar kapanırken gösterilen uyarılar',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id: 1002,
      title: '⚠️ AlertRox: $deviceName Kapatılıyor',
      body: 'Bilgisayarın kapanmasına son $seconds saniye.',
      notificationDetails: details,
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/translations.dart';
import '../services/supabase_service.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';

class AppProvider extends ChangeNotifier {
  static const String prefLanguage = 'app_language';
  static const String prefThemeMode = 'app_theme_mode';

  String _currentLanguage = 'tr';
  ThemeMode _themeMode = ThemeMode.dark;
  Map<String, dynamic>? _selectedDevice;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, bool> _previousOnlineState = {};
  StreamSubscription? _deviceSubscription;

  String get currentLanguage => _currentLanguage;
  ThemeMode get themeMode => _themeMode;
  Map<String, dynamic>? get selectedDevice => _selectedDevice;
  List<Map<String, dynamic>> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRTL => AppTranslations.isRTL(_currentLanguage);

  String tr(String key) => AppTranslations.get(key, _currentLanguage);

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguage = prefs.getString(prefLanguage) ?? 'tr';

      final savedTheme = prefs.getString(prefThemeMode) ?? 'dark';
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.dark;
      }

      await NotificationService().init();
      await loadDevices();
      _listenToDeviceStream();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToDeviceStream() {
    _deviceSubscription?.cancel();
    _deviceSubscription = SupabaseService().streamDevices().listen((list) {
      if (list.isNotEmpty) {
        _devices = list;
        if (_selectedDevice != null) {
          final found = _devices.firstWhere(
            (d) => d['id'] == _selectedDevice!['id'],
            orElse: () => _devices.first,
          );
          _selectedDevice = found;
        } else {
          _selectedDevice = _devices.first;
        }

        // Check if any device turned from offline to online
        for (final dev in _devices) {
          final id = (dev['device_id'] ?? dev['id']).toString();
          final isOnlineNow = isDeviceOnline(dev);
          final wasOnline = _previousOnlineState[id];

          if (wasOnline == false && isOnlineNow) {
            final name = dev['name'] ?? dev['device_name'] ?? 'PC';
            NotificationService().showDeviceOnlineNotification(name.toString());
          }
          _previousOnlineState[id] = isOnlineNow;
        }

        notifyListeners();
        WidgetService.updateWidget(
          device: _selectedDevice,
          isOnline: isDeviceOnline(_selectedDevice),
          langCode: _currentLanguage,
        );
      }
    });
  }

  Future<void> setLanguage(String langCode) async {
    _currentLanguage = langCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefLanguage, langCode);

    // Update widget in real time with new language!
    WidgetService.updateWidget(
      device: _selectedDevice,
      isOnline: isDeviceOnline(_selectedDevice),
      langCode: langCode,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String themeStr = 'dark';
    if (mode == ThemeMode.light) themeStr = 'light';
    if (mode == ThemeMode.system) themeStr = 'system';
    await prefs.setString(prefThemeMode, themeStr);
  }

  void setSelectedDevice(Map<String, dynamic>? device) {
    _selectedDevice = device;
    notifyListeners();
    WidgetService.updateWidget(
      device: _selectedDevice,
      isOnline: isDeviceOnline(_selectedDevice),
      langCode: _currentLanguage,
    );
  }

  Future<void> loadDevices() async {
    _errorMessage = null;
    try {
      final list = await SupabaseService().getDevices();
      _devices = list;
      if (_devices.isNotEmpty) {
        if (_selectedDevice != null) {
          final found = _devices.firstWhere(
            (d) => d['id'] == _selectedDevice!['id'],
            orElse: () => _devices.first,
          );
          _selectedDevice = found;
        } else {
          _selectedDevice = _devices.first;
        }
      } else {
        _selectedDevice = null;
      }

      // Record initial online status
      for (final dev in _devices) {
        final id = (dev['device_id'] ?? dev['id']).toString();
        _previousOnlineState[id] = isDeviceOnline(dev);
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
    WidgetService.updateWidget(
      device: _selectedDevice,
      isOnline: isDeviceOnline(_selectedDevice),
      langCode: _currentLanguage,
    );
  }

  bool isDeviceOnline(Map<String, dynamic>? device) {
    if (device == null || device['last_heartbeat'] == null) return false;
    try {
      final lastSeen = DateTime.parse(device['last_heartbeat']);
      final diff =
          DateTime.now().toUtc().difference(lastSeen.toUtc()).inSeconds;
      return diff <= 45; // Online if heartbeat was within last 45s
    } catch (_) {
      return false;
    }
  }
}

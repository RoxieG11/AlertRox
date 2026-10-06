import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/translations.dart';
import '../services/supabase_service.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';
import '../services/foreground_service.dart';

class AppProvider extends ChangeNotifier {
  static const String prefLanguage = 'app_language';
  static const String prefThemeMode = 'app_theme_mode';
  static const String prefAccentColor = 'app_accent_color';
  static const String prefSecondaryColor = 'app_secondary_color';
  static const String prefGlassmorphic = 'app_glassmorphic';
  static const String prefAllowPcCancel = 'app_allow_pc_cancel';
  static const String prefWidgetTheme = 'app_widget_theme';
  static const String prefForegroundService = 'app_foreground_service';

  String _currentLanguage = 'tr';
  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = const Color(0xFF00F0FF);
  Color _secondaryColor = const Color(0xFF10B981);
  bool _glassmorphicMode = false;
  bool _allowPcCancel = false;
  String _widgetTheme = 'dark';
  bool _foregroundServiceEnabled = true;

  Map<String, dynamic>? _selectedDevice;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, bool> _previousOnlineState = {};
  final Set<String> _notifiedBootDeviceIds = {};
  StreamSubscription? _deviceSubscription;
  Timer? _periodicEvaluationTimer;

  String get currentLanguage => _currentLanguage;
  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  Color get secondaryColor => _secondaryColor;
  bool get glassmorphicMode => _glassmorphicMode;
  bool get allowPcCancel => _allowPcCancel;
  String get widgetTheme => _widgetTheme;
  bool get foregroundServiceEnabled => _foregroundServiceEnabled;

  Map<String, dynamic>? get selectedDevice => _selectedDevice;
  List<Map<String, dynamic>> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRTL => AppTranslations.isRTL(_currentLanguage);

  String tr(String key) => AppTranslations.get(key, _currentLanguage);

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _periodicEvaluationTimer?.cancel();
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

      final savedAccent = prefs.getInt(prefAccentColor);
      if (savedAccent != null) {
        _accentColor = Color(savedAccent);
      }

      final savedSecondary = prefs.getInt(prefSecondaryColor);
      if (savedSecondary != null) {
        _secondaryColor = Color(savedSecondary);
      }

      _glassmorphicMode = prefs.getBool(prefGlassmorphic) ?? false;
      _allowPcCancel = prefs.getBool(prefAllowPcCancel) ?? false;
      _widgetTheme = prefs.getString(prefWidgetTheme) ?? 'dark';
      _foregroundServiceEnabled = prefs.getBool(prefForegroundService) ?? true;

      await NotificationService().init();

      // Foreground service setup
      if (_foregroundServiceEnabled) {
        await AlertRoxForegroundService.start();
      }

      await loadDevices();
      _listenToDeviceStream();

      // Periodic evaluation every 10 seconds to recalculate online/offline states
      _periodicEvaluationTimer?.cancel();
      _periodicEvaluationTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _evaluateOnlineStates(),
      );
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
        debugPrint('[AppProvider] First device row: ${list.first}');
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

        _evaluateOnlineStates();
      }
    });
  }

  void _evaluateOnlineStates() {
    if (_devices.isEmpty) return;

    for (final dev in _devices) {
      final id = (dev['device_id'] ?? dev['id']).toString();
      final isOnlineNow = isDeviceOnline(dev);
      final wasOnline = _previousOnlineState[id];

      // Check if device booted recently (last_boot within 90 seconds)
      bool isRecentBoot = false;
      final lastBootStr = dev['last_boot'] as String?;
      if (lastBootStr != null) {
        final dt = DateTime.tryParse(lastBootStr);
        if (dt != null) {
          final diff = DateTime.now().toUtc().difference(dt.toUtc()).inSeconds.abs();
          if (diff <= 90) {
            isRecentBoot = true;
          }
        }
      }

      // Conditions:
      // (a) was offline, now online
      // (b) initial data arrived (wasOnline == null), device online AND last_boot within 90 seconds
      final shouldNotify = (wasOnline == false && isOnlineNow) ||
          (wasOnline == null && isOnlineNow && isRecentBoot);

      if (shouldNotify && !_notifiedBootDeviceIds.contains(id)) {
        // Fallback: If foreground service is disabled, AppProvider fires the notification.
        // If foreground service is enabled, WatchdogTaskHandler handles it to prevent duplicates.
        if (!_foregroundServiceEnabled) {
          final name = dev['name'] ?? dev['device_name'] ?? 'PC';
          NotificationService().showDeviceOnlineNotification(name.toString());
        }
        _notifiedBootDeviceIds.add(id);

        final currentBootId = lastBootStr ?? 'boot_$id';
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('last_notified_boot_$id', currentBootId);
        });
      }

      if (!isOnlineNow) {
        _notifiedBootDeviceIds.remove(id);
      }

      _previousOnlineState[id] = isOnlineNow;
    }

    notifyListeners();
    WidgetService.updateWidget(
      device: _selectedDevice,
      isOnline: isDeviceOnline(_selectedDevice),
      langCode: _currentLanguage,
      widgetTheme: _widgetTheme,
    );
  }

  Future<void> setLanguage(String langCode) async {
    _currentLanguage = langCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefLanguage, langCode);

    WidgetService.updateWidget(
      device: _selectedDevice,
      isOnline: isDeviceOnline(_selectedDevice),
      langCode: langCode,
      widgetTheme: _widgetTheme,
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

  Future<void> setThemeColors(Color primary, [Color? secondary]) async {
    _accentColor = primary;
    _secondaryColor = secondary ?? primary;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefAccentColor, primary.toARGB32());
    await prefs.setInt(prefSecondaryColor, _secondaryColor.toARGB32());
  }

  Future<void> setGlassmorphicMode(bool enabled) async {
    _glassmorphicMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefGlassmorphic, enabled);
  }

  Future<void> setAllowPcCancel(bool allowed) async {
    _allowPcCancel = allowed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefAllowPcCancel, allowed);
  }

  Future<void> setWidgetTheme(String theme) async {
    _widgetTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefWidgetTheme, theme);

    WidgetService.updateWidget(
      device: _selectedDevice,
      isOnline: isDeviceOnline(_selectedDevice),
      langCode: _currentLanguage,
      widgetTheme: theme,
    );
  }

  Future<void> setForegroundServiceEnabled(bool enabled) async {
    _foregroundServiceEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefForegroundService, enabled);

    if (enabled) {
      await AlertRoxForegroundService.start();
    } else {
      await AlertRoxForegroundService.stop();
    }
  }

  void setSelectedDevice(Map<String, dynamic>? device) {
    _selectedDevice = device;
    notifyListeners();
    WidgetService.updateWidget(
      device: _selectedDevice,
      isOnline: isDeviceOnline(_selectedDevice),
      langCode: _currentLanguage,
      widgetTheme: _widgetTheme,
    );
  }

  Future<void> loadDevices() async {
    _errorMessage = null;
    try {
      _devices = await SupabaseService().getDevices();
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

        _evaluateOnlineStates();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  bool isDeviceOnline(Map<String, dynamic>? device) {
    if (device == null) return false;
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
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/translations.dart';
import '../services/supabase_service.dart';
import '../services/widget_service.dart';

class AppProvider extends ChangeNotifier {
  static const String prefLanguage = 'app_language';
  static const String prefThemeMode = 'app_theme_mode';

  String _currentLanguage = 'tr';
  ThemeMode _themeMode = ThemeMode.dark;
  Map<String, dynamic>? _selectedDevice;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;

  String get currentLanguage => _currentLanguage;
  ThemeMode get themeMode => _themeMode;
  Map<String, dynamic>? get selectedDevice => _selectedDevice;
  List<Map<String, dynamic>> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRTL => AppTranslations.isRTL(_currentLanguage);

  String tr(String key) => AppTranslations.get(key, _currentLanguage);

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

      await loadDevices();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String langCode) async {
    _currentLanguage = langCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefLanguage, langCode);
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
    WidgetService.updateWidget(device: _selectedDevice, isOnline: isDeviceOnline(_selectedDevice));
  }

  Future<void> loadDevices() async {
    try {
      final list = await SupabaseService().getDevices();
      _devices = list;
      if (_devices.isNotEmpty) {
        // If current device was already selected, update it; otherwise pick first
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
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
    WidgetService.updateWidget(device: _selectedDevice, isOnline: isDeviceOnline(_selectedDevice));
  }

  bool isDeviceOnline(Map<String, dynamic>? device) {
    if (device == null || device['last_heartbeat'] == null) return false;
    try {
      final lastSeen = DateTime.parse(device['last_heartbeat']);
      final diff = DateTime.now().toUtc().difference(lastSeen.toUtc()).inSeconds;
      return diff <= 45; // Consider online if heartbeat was within last 45s
    } catch (_) {
      return false;
    }
  }
}

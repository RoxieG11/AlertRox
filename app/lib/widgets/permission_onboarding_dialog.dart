import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../constants/translations.dart';
import '../services/notification_service.dart';

class PermissionOnboardingDialog extends StatefulWidget {
  final String langCode;
  final Color accentColor;

  const PermissionOnboardingDialog({
    super.key,
    required this.langCode,
    required this.accentColor,
  });

  static const String prefDoneKey = 'onboarding_permissions_done';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(prefDoneKey) ?? false);
  }

  static Future<void> show(
    BuildContext context, {
    required String langCode,
    required Color accentColor,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PermissionOnboardingDialog(
        langCode: langCode,
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<PermissionOnboardingDialog> createState() =>
      _PermissionOnboardingDialogState();
}

class _PermissionOnboardingDialogState
    extends State<PermissionOnboardingDialog> {
  bool _notificationGranted = false;
  bool _batteryExempt = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final battery =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    final notif =
        await FlutterForegroundTask.checkNotificationPermission();
    if (mounted) {
      setState(() {
        _batteryExempt = battery;
        _notificationGranted =
            notif == NotificationPermission.granted;
      });
    }
  }

  Future<void> _requestAll() async {
    if (kIsWeb || !Platform.isAndroid) return;

    // 1. Notification
    await NotificationService().init();
    await FlutterForegroundTask.requestNotificationPermission();

    // 2. Battery Optimization
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();

    await Future.delayed(const Duration(milliseconds: 600));
    await _checkStatus();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PermissionOnboardingDialog.prefDoneKey, true);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _markDoneAndClose() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PermissionOnboardingDialog.prefDoneKey, true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _tr(String key) => AppTranslations.get(key, widget.langCode);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141926) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: widget.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _tr('onboarding_title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _tr('onboarding_desc'),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 18),

            // Item 1: Notifications
            _buildPermissionRow(
              icon: Icons.notifications_active_rounded,
              title: _tr('permission_notification_title'),
              desc: _tr('permission_notification_desc'),
              isGranted: _notificationGranted,
              onTap: () async {
                await FlutterForegroundTask
                    .requestNotificationPermission();
                await _checkStatus();
              },
            ),
            const SizedBox(height: 10),

            // Item 2: Battery Optimization
            _buildPermissionRow(
              icon: Icons.battery_saver_rounded,
              title: _tr('permission_battery_title'),
              desc: _tr('permission_battery_desc'),
              isGranted: _batteryExempt,
              onTap: () async {
                await FlutterForegroundTask
                    .requestIgnoreBatteryOptimization();
                await _checkStatus();
              },
            ),
            const SizedBox(height: 10),

            // Item 3: Auto-start
            _buildPermissionRow(
              icon: Icons.power_settings_new_rounded,
              title: _tr('permission_autostart_title'),
              desc: _tr('permission_autostart_desc'),
              isGranted: null,
              onTap: () async {
                await FlutterForegroundTask
                    .openIgnoreBatteryOptimizationSettings();
              },
            ),
            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _markDoneAndClose,
                    child: Text(_tr('btn_continue')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _requestAll,
                    child: Text(
                      _tr('btn_setup_now'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool? isGranted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: widget.accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.darkTextMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isGranted == true)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.statusOnline.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _tr('permission_active'),
                  style: const TextStyle(
                    color: AppTheme.statusOnline,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    );
  }
}

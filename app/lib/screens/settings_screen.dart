import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../constants/translations.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../constants/theme.dart';
import '../widgets/glass_card.dart';
import 'appearance_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  String _userEmail = '';
  bool _isIgnoringBattery = false;
  bool _notificationGranted = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
    _checkSystemPermissions();
  }

  Future<void> _checkSystemPermissions() async {
    if (!kIsWeb && Platform.isAndroid) {
      final battery =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      final notif =
          await FlutterForegroundTask.checkNotificationPermission();
      if (mounted) {
        setState(() {
          _isIgnoringBattery = battery;
          _notificationGranted =
              notif == NotificationPermission.granted;
        });
      }
    }
  }

  Future<void> _loadCurrentConfig() async {
    final cfg = await SupabaseService().getSavedConfig();
    if (mounted) {
      setState(() {
        _urlController.text = cfg['url'] ?? '';
        _keyController.text = cfg['anon_key'] ?? '';
        _userEmail = cfg['email'] ?? SupabaseService().currentUser?.email ?? '';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.tr('settings_sign_out')),
        content: Text(provider.tr('settings_sign_out_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(provider.tr('btn_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusOffline),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(provider.tr('settings_sign_out'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _openGitHubProfile() async {
    const url = 'https://github.com/RoxieG11';
    final uri = Uri.parse(url);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Clipboard.setData(const ClipboardData(text: url));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link panoya kopyalandı: $url'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link panoya kopyalandı: $url'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showLanguageDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.tr('settings_language')),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppTranslations.supportedLocales.length,
            itemBuilder: (ctx, index) {
              final loc = AppTranslations.supportedLocales[index];
              final code = loc['code']!;
              final isSelected = provider.currentLanguage == code;

              return ListTile(
                leading: Text(
                  loc['flag']!,
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(
                  loc['name']!,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? provider.accentColor : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: provider.accentColor)
                    : null,
                onTap: () {
                  provider.setLanguage(code);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.tr('nav_settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. Görünüm & Tema (Appearance Page Nav) ──
          _buildSectionHeader(provider.tr('settings_appearance_theme')),
          GlassCard(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: provider.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.palette_rounded, color: provider.accentColor),
              ),
              title: Text(
                provider.tr('settings_appearance_nav'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                provider.tr('settings_appearance_nav_desc'),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppearanceScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── 2. Bildirim & Gözcü Servisi ──
          _buildSectionHeader(provider.tr('settings_foreground')),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: provider.foregroundServiceEnabled,
                  title: Text(provider.tr('settings_foreground')),
                  subtitle: Text(
                    provider.tr('settings_foreground_desc'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  secondary:
                      const Icon(Icons.notifications_active_outlined),
                  activeThumbColor: provider.accentColor,
                  onChanged: (val) =>
                      provider.setForegroundServiceEnabled(val),
                ),
                if (!kIsWeb && Platform.isAndroid && !_notificationGranted) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notification_important_rounded,
                        color: AppTheme.statusWarning),
                    title: Text(
                      provider.tr('permission_notification_title'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      provider.tr('permission_notification_desc'),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: () async {
                        await FlutterForegroundTask
                            .requestNotificationPermission();
                        await _checkSystemPermissions();
                      },
                      child: Text(
                        provider.tr('permission_inactive'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.ring_volume_outlined),
                  title: Text(provider.tr('settings_test_notification')),
                  subtitle: Text(
                    provider.tr('settings_test_notification_desc'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onPressed: () async {
                      await NotificationService().showTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              provider.tr('settings_test_notification_sent'),
                            ),
                            backgroundColor: AppTheme.statusOnline,
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.send_rounded, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 3. Arka Planda Çalışmayı Garantile ──
          _buildSectionHeader(provider.tr('settings_battery_optimization')),
          GlassCard(
            child: Column(
              children: [
                // Battery Optimization ListTile (fixed wrapping)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _isIgnoringBattery
                            ? Icons.battery_charging_full_rounded
                            : Icons.battery_alert_rounded,
                        color: _isIgnoringBattery
                            ? AppTheme.statusOnline
                            : AppTheme.statusWarning,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.tr('settings_battery_ignore'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              provider.tr('settings_battery_ignore_desc'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.darkTextMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_isIgnoringBattery)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.statusOnline
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.statusOnline
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            provider.tr('settings_battery_status_unrestricted'),
                            style: const TextStyle(
                              color: AppTheme.statusOnline,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                          onPressed: () async {
                            await FlutterForegroundTask
                                .requestIgnoreBatteryOptimization();
                            await Future.delayed(
                                const Duration(milliseconds: 800));
                            await _checkSystemPermissions();
                          },
                          child: Text(
                            provider.tr('settings_battery_status_restricted'),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Auto-start ListTile (fixed wrapping)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.settings_suggest_outlined,
                        size: 24,
                        color: AppTheme.primaryTeal,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.tr('settings_autostart_title'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              provider.tr('settings_autostart_desc'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.darkTextMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        onPressed: () async {
                          await FlutterForegroundTask
                              .openIgnoreBatteryOptimizationSettings();
                        },
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: Text(
                          provider.tr('settings_open_system_settings'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 4. Güvenlik & Kapatma Ayarları ──
          _buildSectionHeader(provider.tr('settings_security_shutdown')),
          GlassCard(
            child: SwitchListTile(
              value: provider.allowPcCancel,
              title: Text(provider.tr('settings_allow_pc_cancel')),
              subtitle: Text(
                provider.tr('settings_allow_pc_cancel_desc'),
                style: const TextStyle(fontSize: 12),
              ),
              secondary: const Icon(Icons.lock_clock_outlined),
              activeThumbColor: provider.accentColor,
              onChanged: (val) => provider.setAllowPcCancel(val),
            ),
          ),
          const SizedBox(height: 20),

          // ── 5. Dil Seçimi (Single-line ListTile with Dialog) ──
          _buildSectionHeader(provider.tr('settings_language')),
          GlassCard(
            child: Builder(
              builder: (ctx) {
                final currentLocale = AppTranslations.supportedLocales
                    .firstWhere(
                      (l) => l['code'] == provider.currentLanguage,
                      orElse: () => AppTranslations.supportedLocales.first,
                    );
                return ListTile(
                  leading: Text(
                    currentLocale['flag']!,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    currentLocale['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(provider.tr('settings_language')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showLanguageDialog(context, provider),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── 6. Hesap ve Güvenlik (Account & Security) ──
          _buildSectionHeader(provider.tr('settings_account_security')),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: provider.accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield_outlined, color: provider.accentColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userEmail.isNotEmpty ? _userEmail : provider.tr('settings_logged_in'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _urlController.text.isNotEmpty
                                  ? _urlController.text
                                  : 'Supabase Cloud',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.darkTextMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: AppTheme.statusOnline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.tr('settings_security_rls_active'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.statusOffline,
                        side: BorderSide(color: AppTheme.statusOffline.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(provider.tr('settings_sign_out'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _handleSignOut,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── 7. Açık Kaynak ve Ücretsiz Bildirim Kartı ──
          GlassCard(
            color: provider.accentColor.withValues(alpha: 0.08),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: provider.accentColor.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: provider.accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: provider.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.tr('open_source_title'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: provider.accentColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.tr('open_source_notice'),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 8. Geliştirici İmzası & GitHub Profili ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _openGitHubProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: provider.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: provider.accentColor.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.code_rounded,
                            size: 18,
                            color: provider.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            provider.tr('developer_credit'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  provider.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'GitHub',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 12,
                                  color: provider.accentColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AlertRox v1.4.1 • Open Source Security',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.darkTextMuted,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../constants/translations.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../constants/theme.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final creds = await SupabaseService().getSavedCredentials();
    _urlController.text = creds['url'] ?? '';
    _keyController.text = creds['key'] ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    setState(() => _isSaving = true);

    try {
      final url = _urlController.text.trim();
      final key = _keyController.text.trim();
      await SupabaseService().saveCredentials(url, key);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.tr('settings_saved')),
            backgroundColor: AppTheme.statusOnline,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetDefaults() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await SupabaseService().resetCredentials();
    _urlController.text = SupabaseService.defaultUrl;
    _keyController.text = SupabaseService.defaultKey;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.tr('settings_saved')),
          backgroundColor: AppTheme.statusOnline,
        ),
      );
    }
  }

  Future<void> _openGitHubProfile() async {
    final uri = Uri.parse('https://github.com/RoxieG11');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('GitHub profile launch error: $e');
    }
  }

  void _showRgbColorPickerDialog(BuildContext context, AppProvider provider) {
    int r = (provider.accentColor.r * 255).round();
    int g = (provider.accentColor.g * 255).round();
    int b = (provider.accentColor.b * 255).round();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentColor = Color.fromARGB(255, r, g, b);
            final hex =
                '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
                    .toUpperCase();

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.colorize_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(provider.tr('settings_custom_rgb')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: currentColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        hex,
                        style: TextStyle(
                          color: (r * 0.299 + g * 0.587 + b * 0.114) > 186
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text('R: $r',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent)),
                        ),
                        Expanded(
                          child: Slider(
                            value: r.toDouble(),
                            min: 0,
                            max: 255,
                            activeColor: Colors.redAccent,
                            onChanged: (v) =>
                                setDialogState(() => r = v.round()),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text('G: $g',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent)),
                        ),
                        Expanded(
                          child: Slider(
                            value: g.toDouble(),
                            min: 0,
                            max: 255,
                            activeColor: Colors.greenAccent,
                            onChanged: (v) =>
                                setDialogState(() => g = v.round()),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text('B: $b',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.lightBlueAccent)),
                        ),
                        Expanded(
                          child: Slider(
                            value: b.toDouble(),
                            min: 0,
                            max: 255,
                            activeColor: Colors.lightBlueAccent,
                            onChanged: (v) =>
                                setDialogState(() => b = v.round()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(provider.tr('btn_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    provider.setThemeColors(currentColor);
                    Navigator.pop(dialogCtx);
                  },
                  child: Text(provider.tr('apply_color')),
                ),
              ],
            );
          },
        );
      },
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
          // ── 1. Görünüm & Tema Bölümü ──
          _buildSectionHeader(provider.tr('settings_appearance_theme')),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: provider.themeMode,
                    title: Text(provider.tr('theme_dark')),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    onChanged: (mode) {
                      if (mode != null) provider.setThemeMode(mode);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: provider.themeMode,
                    title: Text(provider.tr('theme_light')),
                    secondary: const Icon(Icons.light_mode_outlined),
                    onChanged: (mode) {
                      if (mode != null) provider.setThemeMode(mode);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: provider.themeMode,
                    title: Text(provider.tr('theme_system')),
                    secondary: const Icon(Icons.settings_suggest_outlined),
                    onChanged: (mode) {
                      if (mode != null) provider.setThemeMode(mode);
                    },
                  ),
                  const Divider(height: 20),

                  // Saydam Mod (Glassmorphism)
                  SwitchListTile(
                    value: provider.glassmorphicMode,
                    title: Text(provider.tr('settings_glassmorphic')),
                    subtitle: Text(provider.tr('settings_glassmorphic_desc'),
                        style: const TextStyle(fontSize: 12)),
                    secondary: const Icon(Icons.blur_on_rounded),
                    activeThumbColor: provider.accentColor,
                    onChanged: (val) => provider.setGlassmorphicMode(val),
                  ),
                  const Divider(height: 20),

                  // Hazır Renk Paletleri
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      provider.tr('settings_theme_presets'),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextMuted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppTheme.presets.map((preset) {
                      final isSelected =
                          provider.accentColor.toARGB32() == preset.primary.toARGB32();
                      return ChoiceChip(
                        avatar: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: preset.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text(preset.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                            )),
                        selected: isSelected,
                        selectedColor: preset.primary.withValues(alpha: 0.25),
                        onSelected: (selected) {
                          if (selected) {
                            provider.setThemeColors(preset.primary, preset.secondary);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Özel RGB Renk Seçici Butonu
                  ListTile(
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: provider.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                      ),
                    ),
                    title: Text(provider.tr('settings_custom_rgb')),
                    subtitle: Text(
                        '#${provider.accentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showRgbColorPickerDialog(context, provider),
                  ),
                  const Divider(height: 20),

                  // Widget Teması
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          provider.tr('settings_widget_theme'),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextMuted),
                        ),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'dark',
                              label: Text(provider.tr('settings_widget_dark')),
                              icon: const Icon(Icons.dark_mode, size: 16),
                            ),
                            ButtonSegment(
                              value: 'light',
                              label: Text(provider.tr('settings_widget_light')),
                              icon: const Icon(Icons.light_mode, size: 16),
                            ),
                          ],
                          selected: {provider.widgetTheme},
                          onSelectionChanged: (set) {
                            provider.setWidgetTheme(set.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 2. Bildirim & Gözcü Servisi ──
          _buildSectionHeader(provider.tr('settings_foreground')),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    value: provider.foregroundServiceEnabled,
                    title: Text(provider.tr('settings_foreground')),
                    subtitle: Text(provider.tr('settings_foreground_desc'),
                        style: const TextStyle(fontSize: 12)),
                    secondary: const Icon(Icons.notifications_active_outlined),
                    activeThumbColor: provider.accentColor,
                    onChanged: (val) =>
                        provider.setForegroundServiceEnabled(val),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    leading: const Icon(Icons.ring_volume_outlined),
                    title: Text(provider.tr('settings_test_notification')),
                    subtitle: Text(
                        provider.tr('settings_test_notification_desc'),
                        style: const TextStyle(fontSize: 12)),
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
                              content: Text(provider
                                  .tr('settings_test_notification_sent')),
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
          ),
          const SizedBox(height: 24),

          // ── 3. Güvenlik & Kapatma Ayarları ──
          _buildSectionHeader(provider.tr('settings_security_shutdown')),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SwitchListTile(
                value: provider.allowPcCancel,
                title: Text(provider.tr('settings_allow_pc_cancel')),
                subtitle: Text(provider.tr('settings_allow_pc_cancel_desc'),
                    style: const TextStyle(fontSize: 12)),
                secondary: const Icon(Icons.lock_clock_outlined),
                activeThumbColor: provider.accentColor,
                onChanged: (val) => provider.setAllowPcCancel(val),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 4. Dil Seçimi Bölümü ──
          _buildSectionHeader(provider.tr('settings_language')),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: AppTranslations.supportedLocales.map((loc) {
                  final code = loc['code']!;
                  final isSelected = provider.currentLanguage == code;

                  return ListTile(
                    leading: Text(
                      loc['flag']!,
                      style: const TextStyle(fontSize: 24),
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
                    onTap: () => provider.setLanguage(code),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 5. Supabase Yapılandırması ──
          _buildSectionHeader(provider.tr('settings_supabase')),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: provider.tr('supabase_url'),
                      prefixIcon: const Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: provider.tr('supabase_key'),
                      prefixIcon: const Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetDefaults,
                          child: Text(provider.tr('reset_defaults')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveConfig,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(provider.tr('btn_save')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 6. Açık Kaynak ve Ücretsiz Bildirim Kartı ──
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

          // ── 7. Geliştirici İmzası & GitHub Profili ──
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
                    'AlertRox v1.3.0 • Open Source Security',
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
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppTheme.darkTextMuted,
        ),
      ),
    );
  }
}

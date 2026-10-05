import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../constants/translations.dart';
import '../services/supabase_service.dart';
import '../constants/theme.dart';

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
          // Appearance & Theme Section
          _buildSectionHeader(provider.tr('settings_appearance')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Language Selection Section
          _buildSectionHeader(provider.tr('settings_language')),
          Card(
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
                        color: isSelected ? AppTheme.primaryTeal : null,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppTheme.primaryTeal)
                        : null,
                    onTap: () => provider.setLanguage(code),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Supabase Configuration Section
          _buildSectionHeader(provider.tr('settings_supabase')),
          Card(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.black,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black),
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

          // Developer Credit
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.code_rounded,
                          size: 18,
                          color: AppTheme.primaryTeal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.tr('developer_credit'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AlertRox v1.2.0 • Open Source',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.darkTextMuted,
        ),
      ),
    );
  }
}

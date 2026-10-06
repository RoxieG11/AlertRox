import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/app_provider.dart';
import '../widgets/glass_card.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.tr('settings_appearance_nav')),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── 1. Canlı Widget Önizleme ──
          _buildSectionHeader(provider.tr('widget_preview_title')),
          _buildWidgetLivePreview(context, provider),
          const SizedBox(height: 20),

          // ── 2. Widget Ayarları ──
          _buildSectionHeader(provider.tr('widget_appearance_header')),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Widget Modu (Dark / Light / System)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.tr('widget_mode_title'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          segments: [
                            ButtonSegment(
                              value: 'dark',
                              icon: const Icon(Icons.dark_mode, size: 16),
                              label: Text(provider.tr('settings_widget_dark')),
                            ),
                            ButtonSegment(
                              value: 'light',
                              icon: const Icon(Icons.light_mode, size: 16),
                              label: Text(provider.tr('settings_widget_light')),
                            ),
                            ButtonSegment(
                              value: 'system',
                              icon: const Icon(Icons.settings_suggest, size: 16),
                              label: Text(provider.tr('theme_system')),
                            ),
                          ],
                          selected: {provider.widgetMode},
                          onSelectionChanged: (set) {
                            provider.setWidgetMode(set.first);
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Widget Cam / Saydam Mod
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: provider.widgetGlass,
                    title: Text(provider.tr('widget_glass_title')),
                    subtitle: Text(
                      provider.tr('widget_glass_desc'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: const Icon(Icons.blur_on_rounded),
                    activeThumbColor: provider.accentColor,
                    onChanged: (val) => provider.setWidgetGlass(val),
                  ),
                  const Divider(height: 24),

                  // Widget Opaklık Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        provider.tr('widget_opacity_title'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: provider.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '%${provider.widgetOpacity}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: provider.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: provider.widgetOpacity.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: provider.accentColor,
                    onChanged: (val) {
                      provider.setWidgetOpacity(val.round());
                    },
                  ),
                  const Divider(height: 24),

                  // Widget Renk Modu
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.tr('widget_colors_title'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: 'same_as_app',
                              label: Text(provider.tr('widget_color_same_as_app')),
                            ),
                            ButtonSegment(
                              value: 'custom',
                              label: Text(provider.tr('widget_color_custom')),
                            ),
                          ],
                          selected: {provider.widgetColorMode},
                          onSelectionChanged: (set) {
                            provider.setWidgetColorMode(set.first);
                          },
                        ),
                      ),
                    ],
                  ),

                  if (provider.widgetColorMode == 'custom') ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppTheme.presets.map((preset) {
                        final isSelected = provider.widgetAccentColor
                                .toARGB32() ==
                            preset.primary.toARGB32();
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
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                          selected: isSelected,
                          selectedColor:
                              preset.primary.withValues(alpha: 0.25),
                          onSelected: (selected) {
                            if (selected) {
                              provider.setWidgetColors(
                                  preset.primary, preset.secondary);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: provider.widgetAccentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                      ),
                      title: Text(
                        provider.tr('settings_custom_rgb'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showWidgetRgbDialog(context, provider),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── 3. Uygulama Tema Ayarları ──
          _buildSectionHeader(provider.tr('settings_appearance_theme')),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Uygulama Tema Modu
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.tr('app_theme_mode_title'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: const Icon(Icons.dark_mode, size: 16),
                              label: Text(provider.tr('settings_widget_dark')),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: const Icon(Icons.light_mode, size: 16),
                              label: Text(provider.tr('settings_widget_light')),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: const Icon(Icons.settings_suggest, size: 16),
                              label: Text(provider.tr('theme_system')),
                            ),
                          ],
                          selected: {provider.themeMode},
                          onSelectionChanged: (set) {
                            provider.setThemeMode(set.first);
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Saydam Mod (Glassmorphism)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: provider.glassmorphicMode,
                    title: Text(provider.tr('settings_glassmorphic')),
                    subtitle: Text(
                      provider.tr('settings_glassmorphic_desc'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: const Icon(Icons.auto_awesome_rounded),
                    activeThumbColor: provider.accentColor,
                    onChanged: (val) => provider.setGlassmorphicMode(val),
                  ),
                  const Divider(height: 24),

                  // Hazır Renk Paletleri
                  Text(
                    provider.tr('settings_theme_presets'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppTheme.presets.map((preset) {
                      final isSelected = provider.accentColor.toARGB32() ==
                          preset.primary.toARGB32();
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
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                        selected: isSelected,
                        selectedColor:
                            preset.primary.withValues(alpha: 0.25),
                        onSelected: (selected) {
                          if (selected) {
                            provider.setThemeColors(
                                preset.primary, preset.secondary);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Özel RGB Renk Seçici
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: provider.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    ),
                    title: Text(
                      provider.tr('settings_custom_rgb'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '#${provider.accentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showAppRgbDialog(context, provider),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
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

  Widget _buildWidgetLivePreview(BuildContext context, AppProvider provider) {
    final dev = provider.selectedDevice;
    final devName =
        (dev != null ? (dev['name'] ?? dev['device_name']) : 'AlertRox PC') ??
            'AlertRox PC';
    final isOnline = provider.isDeviceOnline(dev);

    final isSystemDark =
        Theme.of(context).brightness == Brightness.dark;
    final isLight = provider.widgetMode == 'light' ||
        (provider.widgetMode == 'system' && !isSystemDark);

    final effectiveAccent = provider.widgetColorMode == 'same_as_app'
        ? provider.accentColor
        : provider.widgetAccentColor;
    final effectiveSecondary = provider.widgetColorMode == 'same_as_app'
        ? provider.secondaryColor
        : provider.widgetSecondaryColor;

    final alpha = (provider.widgetOpacity * 2.55).round().clamp(0, 255);

    final Color bgColor;
    final Border border;

    if (provider.widgetGlass) {
      if (isLight) {
        bgColor = Color.fromARGB(alpha, 255, 255, 255);
        border = Border.all(
          color: effectiveAccent.withValues(alpha: 0.6),
          width: 1.5,
        );
      } else {
        bgColor = Color.fromARGB(alpha, 15, 23, 42);
        border = Border.all(
          color: effectiveAccent.withValues(alpha: 0.6),
          width: 1.5,
        );
      }
    } else {
      if (isLight) {
        bgColor = Color.fromARGB(alpha, 248, 250, 252);
        border = Border.all(color: const Color(0x33CBD5E1), width: 1.5);
      } else {
        bgColor = Color.fromARGB(alpha, 11, 15, 25);
        border = Border.all(color: const Color(0x33334155), width: 1.5);
      }
    }

    final textColor = isLight ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final brandColor = isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    final statusColor = isOnline
        ? (provider.widgetGlass ? effectiveAccent : const Color(0xFF10B981))
        : const Color(0xFFEF4444);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: border,
        boxShadow: [
          BoxShadow(
            color: effectiveAccent.withValues(
              alpha: provider.widgetGlass ? 0.25 : 0.08,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: effectiveAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ALERTRox',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: brandColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOnline ? provider.tr('online') : provider.tr('offline'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Device Name
          Text(
            devName.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          Container(
            height: 1,
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 8),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.tr('last_heartbeat')}: 12:45',
                style: TextStyle(
                  fontSize: 11,
                  color: brandColor,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: effectiveAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: effectiveSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAppRgbDialog(BuildContext context, AppProvider provider) {
    _showRgbSlidersDialog(
      context: context,
      title: provider.tr('settings_custom_rgb'),
      initialColor: provider.accentColor,
      onApply: (color) => provider.setThemeColors(color),
      provider: provider,
    );
  }

  void _showWidgetRgbDialog(BuildContext context, AppProvider provider) {
    _showRgbSlidersDialog(
      context: context,
      title: provider.tr('settings_custom_rgb'),
      initialColor: provider.widgetAccentColor,
      onApply: (color) => provider.setWidgetColors(color),
      provider: provider,
    );
  }

  void _showRgbSlidersDialog({
    required BuildContext context,
    required String title,
    required Color initialColor,
    required ValueChanged<Color> onApply,
    required AppProvider provider,
  }) {
    int r = (initialColor.r * 255).round();
    int g = (initialColor.g * 255).round();
    int b = (initialColor.b * 255).round();

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
                  Text(title),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 52,
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
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSliderRow('R: $r', r, Colors.redAccent, (v) {
                      setDialogState(() => r = v);
                    }),
                    _buildSliderRow('G: $g', g, Colors.greenAccent, (v) {
                      setDialogState(() => g = v);
                    }),
                    _buildSliderRow('B: $b', b, Colors.lightBlueAccent, (v) {
                      setDialogState(() => b = v);
                    }),
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
                    onApply(currentColor);
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

  static Widget _buildSliderRow(
      String label, int val, Color activeColor, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: activeColor,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: val.toDouble(),
            min: 0,
            max: 255,
            activeColor: activeColor,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../services/widget_service.dart';
import '../constants/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isActionLoading = false;
  List<Map<String, dynamic>> _activityLogs = [];
  bool _logsLoading = false;

  // Active Shutdown Timer state
  int? _shutdownRemainingSeconds;
  Timer? _shutdownTimer;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _shutdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final device = provider.selectedDevice;
    if (device == null) return;

    setState(() => _logsLoading = true);
    final targetId = (device['device_id'] ?? device['id']).toString();
    final logs = await SupabaseService().getActivityLogs(targetId);
    if (mounted) {
      setState(() {
        _activityLogs = logs;
        _logsLoading = false;
      });
    }
  }

  Future<void> _triggerCommand(String commandType,
      {Map<String, dynamic>? payload, bool requireConfirmation = false}) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final device = provider.selectedDevice;
    if (device == null) return;
    final targetId = (device['device_id'] ?? device['id']).toString();

    if (commandType == 'shutdown') {
      await _showShutdownBottomSheet(provider, targetId);
      return;
    }

    if (requireConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(provider.tr('dialog_confirm_title')),
          content: Text(provider.tr('dialog_logout_msg')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(provider.tr('btn_cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusOffline,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(provider.tr('btn_confirm')),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isActionLoading = true);
    try {
      await SupabaseService().sendCommand(targetId, commandType, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.tr('cmd_sent')),
            backgroundColor: AppTheme.statusOnline,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${provider.tr('cmd_failed')}$e'),
            backgroundColor: AppTheme.statusOffline,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
        _loadLogs();
      }
    }
  }

  Future<void> _showShutdownBottomSheet(
      AppProvider provider, String targetId) async {
    int selectedSeconds = 10;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            String formatDisplay(int s) {
              if (s < 60) return '$s ${provider.tr('seconds')}';
              final m = s ~/ 60;
              final r = s % 60;
              if (m < 60) {
                return r > 0
                    ? '$m ${provider.tr('minutes')} $r ${provider.tr('seconds')}'
                    : '$m ${provider.tr('minutes')}';
              }
              final h = m ~/ 60;
              final rm = m % 60;
              return rm > 0
                  ? '$h ${provider.tr('hours')} $rm ${provider.tr('minutes')}'
                  : '$h ${provider.tr('hours')}';
            }

            final presets = [
              {'label': '10 ${provider.tr('seconds')}', 'val': 10},
              {'label': '30 ${provider.tr('seconds')}', 'val': 30},
              {'label': '1 ${provider.tr('minutes')}', 'val': 60},
              {'label': '5 ${provider.tr('minutes')}', 'val': 300},
              {'label': '15 ${provider.tr('minutes')}', 'val': 900},
              {'label': '30 ${provider.tr('minutes')}', 'val': 1800},
              {'label': '1 ${provider.tr('hours')}', 'val': 3600},
              {'label': '2 ${provider.tr('hours')}', 'val': 7200},
              {'label': '4 ${provider.tr('hours')}', 'val': 14400},
              {'label': '8 ${provider.tr('hours')}', 'val': 28800},
              {'label': '12 ${provider.tr('hours')}', 'val': 43200},
              {'label': '24 ${provider.tr('hours')}', 'val': 86400},
            ];

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.statusOffline.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.power_settings_new,
                            color: AppTheme.statusOffline, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.tr('shutdown_timer_title'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              provider.tr('shutdown_select_time'),
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.darkTextMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((p) {
                      final val = p['val'] as int;
                      final isSelected = selectedSeconds == val;
                      return ChoiceChip(
                        label: Text(p['label'] as String),
                        selected: isSelected,
                        selectedColor: AppTheme.statusOffline,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => selectedSeconds = val);
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${provider.tr('shutdown_remaining')}:',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        formatDisplay(selectedSeconds),
                        style: const TextStyle(
                          color: AppTheme.statusOffline,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: selectedSeconds.toDouble(),
                    min: 10,
                    max: 86400,
                    divisions: 144,
                    activeColor: AppTheme.statusOffline,
                    onChanged: (val) {
                      setModalState(() => selectedSeconds = val.round());
                    },
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(provider.tr('btn_cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.statusOffline,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.timer_outlined, size: 18),
                          label: Text(
                              '${provider.tr('shutdown_start_btn')} (${formatDisplay(selectedSeconds)})'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _startShutdown(
                                selectedSeconds, targetId, provider);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startShutdown(
      int delaySeconds, String targetId, AppProvider provider) async {
    setState(() => _isActionLoading = true);
    try {
      await SupabaseService().sendCommand(targetId, 'shutdown', {
        'delay': delaySeconds,
        'allow_cancel': provider.allowPcCancel,
      });

      _shutdownTimer?.cancel();
      _shutdownRemainingSeconds = delaySeconds;

      _shutdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted ||
            _shutdownRemainingSeconds == null ||
            _shutdownRemainingSeconds! <= 0) {
          timer.cancel();
          setState(() {
            _shutdownRemainingSeconds = null;
          });
          WidgetService.updateWidget(
            device: provider.selectedDevice,
            isOnline: provider.isDeviceOnline(provider.selectedDevice),
            langCode: provider.currentLanguage,
            isShuttingDown: false,
          );
          return;
        }

        setState(() {
          _shutdownRemainingSeconds = _shutdownRemainingSeconds! - 1;
        });

        final s = _shutdownRemainingSeconds!;
        final m = s ~/ 60;
        final r = s % 60;
        final formatted = m > 0
            ? '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}'
            : '00:${r.toString().padLeft(2, '0')}';

        WidgetService.updateWidget(
          device: provider.selectedDevice,
          isOnline: provider.isDeviceOnline(provider.selectedDevice),
          langCode: provider.currentLanguage,
          isShuttingDown: true,
          shutdownCountdown: formatted,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.tr('cmd_sent')),
            backgroundColor: AppTheme.statusOnline,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${provider.tr('cmd_failed')}$e'),
            backgroundColor: AppTheme.statusOffline,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
        _loadLogs();
      }
    }
  }

  Future<void> _cancelShutdown(String targetId, AppProvider provider) async {
    _shutdownTimer?.cancel();
    setState(() {
      _shutdownRemainingSeconds = null;
    });

    try {
      await SupabaseService().sendCommand(targetId, 'cancel_shutdown');
      WidgetService.updateWidget(
        device: provider.selectedDevice,
        isOnline: provider.isDeviceOnline(provider.selectedDevice),
        langCode: provider.currentLanguage,
        isShuttingDown: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.tr('shutdown_cancelled')),
            backgroundColor: AppTheme.statusOnline,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${provider.tr('cmd_failed')}$e'),
            backgroundColor: AppTheme.statusOffline,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final device = provider.selectedDevice;
    final isOnline = provider.isDeviceOnline(device);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              provider.tr('app_title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: provider.tr('refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await provider.loadDevices();
              await _loadLogs();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadDevices();
          await _loadLogs();
        },
        child: device == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.devices_other,
                        size: 64, color: AppTheme.darkTextMuted),
                    const SizedBox(height: 16),
                    Text(
                      provider.tr('no_devices'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (provider.errorMessage != null &&
                        provider.errorMessage!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          provider.errorMessage!,
                          style: const TextStyle(
                              color: AppTheme.statusOffline, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.loadDevices(),
                      icon: const Icon(Icons.refresh),
                      label: Text(provider.tr('refresh')),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDeviceCard(provider, device, isOnline),
                  const SizedBox(height: 16),

                  if (_shutdownRemainingSeconds != null &&
                      _shutdownRemainingSeconds! > 0) ...[
                    _buildShutdownCountdownBanner(provider),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    provider.tr('quick_actions'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionsGrid(provider),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        provider.tr('recent_activity'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_logsLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildLogsList(provider),
                ],
              ),
      ),
    );
  }

  Widget _buildShutdownCountdownBanner(AppProvider provider) {
    final secs = _shutdownRemainingSeconds ?? 0;
    final hrs = secs ~/ 3600;
    final mins = (secs % 3600) ~/ 60;
    final remSecs = secs % 60;
    final formatted = hrs > 0
        ? '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${remSecs.toString().padLeft(2, '0')}'
        : '${mins.toString().padLeft(2, '0')}:${remSecs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusOffline.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.statusOffline, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.statusOffline.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.statusOffline, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.tr('shutdown_active_title'),
                      style: const TextStyle(
                        color: AppTheme.statusOffline,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      '${provider.tr('shutdown_remaining')}: $formatted',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusOffline,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: Text(provider.tr('shutdown_cancel_btn')),
              onPressed: () {
                final device = provider.selectedDevice;
                if (device != null) {
                  final targetId =
                      (device['device_id'] ?? device['id']).toString();
                  _cancelShutdown(targetId, provider);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
      AppProvider provider, Map<String, dynamic> device, bool isOnline) {
    final devName = device['name'] ?? device['device_name'] ?? 'PC-Device';
    final osName = device['os_info'] ?? device['os_type'] ?? 'Linux';
    final heartbeat = device['last_heartbeat'] ?? device['last_seen'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.desktop_windows,
                        color: AppTheme.primaryTeal, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          devName.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          osName.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? AppTheme.statusOnline.withValues(alpha: 0.15)
                        : AppTheme.statusOffline.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOnline
                          ? AppTheme.statusOnline
                          : AppTheme.statusOffline,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline
                              ? AppTheme.statusOnline
                              : AppTheme.statusOffline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline
                            ? provider.tr('status_online')
                            : provider.tr('status_offline'),
                        style: TextStyle(
                          color: isOnline
                              ? AppTheme.statusOnline
                              : AppTheme.statusOffline,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.network_check,
                    provider.tr('ip_address'),
                    device['ip_address'] ?? '127.0.0.1',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.access_time,
                    provider.tr('last_seen'),
                    _formatTime(heartbeat),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryTeal),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkTextMuted,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsGrid(AppProvider provider) {
    final actions = [
      {
        'id': 'lock',
        'icon': Icons.lock_outline,
        'label': provider.tr('act_lock'),
        'color': const Color(0xFF3B82F6),
        'danger': false,
      },
      {
        'id': 'logout',
        'icon': Icons.logout,
        'label': provider.tr('act_logout'),
        'color': const Color(0xFFF59E0B),
        'danger': true,
      },
      {
        'id': 'shutdown',
        'icon': Icons.power_settings_new,
        'label': provider.tr('act_shutdown'),
        'color': const Color(0xFFEF4444),
        'danger': true,
      },
      {
        'id': 'screenshot',
        'icon': Icons.camera_alt_outlined,
        'label': provider.tr('act_screenshot'),
        'color': const Color(0xFF10B981),
        'danger': false,
      },
      {
        'id': 'webcam',
        'icon': Icons.videocam_outlined,
        'label': provider.tr('act_webcam'),
        'color': const Color(0xFF8B5CF6),
        'danger': false,
      },
      {
        'id': 'mic_record',
        'icon': Icons.mic_none,
        'label': provider.tr('act_mic'),
        'color': const Color(0xFF06B6D4),
        'danger': false,
        'payload': {'duration': 10},
      },
      {
        'id': 'open_chat',
        'icon': Icons.chat_bubble_outline,
        'label': provider.tr('act_chat'),
        'color': const Color(0xFFEC4899),
        'danger': false,
      },
    ];

    final gridActions = actions.sublist(0, 6);
    final chatAction = actions[6];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 700 ? 4 : 2;

        return Column(
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemCount: gridActions.length,
              itemBuilder: (ctx, index) {
                final act = gridActions[index];
                final color = act['color'] as Color;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isActionLoading
                        ? null
                        : () => _triggerCommand(
                              act['id'] as String,
                              payload: act['payload'] as Map<String, dynamic>?,
                              requireConfirmation: act['danger'] as bool,
                            ),
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.darkCardBorder
                              : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                      ),
                      color: isDark ? const Color(0xFF161F30) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: 0.15),
                              ),
                              child: Icon(act['icon'] as IconData,
                                  color: color, size: 24),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              act['label'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Full Width "Masaüstü Sohbet" Card Button!
            _buildFullWidthChatButton(provider, chatAction, isDark),
          ],
        );
      },
    );
  }

  Widget _buildFullWidthChatButton(
      AppProvider provider, Map<String, dynamic> act, bool isDark) {
    final color = act['color'] as Color;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      color: isDark ? const Color(0xFF161F30) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isActionLoading
            ? null
            : () => _triggerCommand(act['id'] as String),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(act['icon'] as IconData, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  act['label'] as String,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 20,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogsList(AppProvider provider) {
    if (_activityLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            provider.tr('no_activity'),
            style: const TextStyle(color: AppTheme.darkTextMuted),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _activityLogs.length > 5 ? 5 : _activityLogs.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, index) {
          final log = _activityLogs[index];
          final event = log['event_type'] ?? 'log';
          final msg = log['message'] ?? '';
          final time = _formatTime(log['created_at']);

          return ListTile(
            leading: Icon(
              _getLogIcon(event),
              color: AppTheme.primaryTeal,
              size: 20,
            ),
            title: Text(
              msg,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            trailing: Text(
              time,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.darkTextMuted),
            ),
          );
        },
      ),
    );
  }

  IconData _getLogIcon(String event) {
    switch (event) {
      case 'boot':
        return Icons.power;
      case 'command_executed':
        return Icons.check_circle_outline;
      case 'heartbeat':
        return Icons.favorite_border;
      case 'chat_opened':
        return Icons.chat_bubble_outline;
      case 'shutdown_scheduled':
        return Icons.timer_outlined;
      case 'shutdown_cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '--:--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }
}

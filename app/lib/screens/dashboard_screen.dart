import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLogs();
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

    if (requireConfirmation) {
      final confirmMsg = commandType == 'shutdown'
          ? provider.tr('dialog_shutdown_msg')
          : provider.tr('dialog_logout_msg');

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(provider.tr('dialog_confirm_title')),
          content: Text(confirmMsg),
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
                    if (provider.errorMessage != null && provider.errorMessage!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          provider.errorMessage!,
                          style: const TextStyle(color: AppTheme.statusOffline, fontSize: 12),
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
                  // Device Status Card
                  _buildDeviceCard(provider, device, isOnline),
                  const SizedBox(height: 20),

                  // Quick Actions Grid Header
                  Text(
                    provider.tr('quick_actions'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Actions Grid
                  _buildActionsGrid(provider),
                  const SizedBox(height: 24),

                  // Recent Activity Header
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

                  // Logs List
                  _buildLogsList(provider),
                ],
              ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        devName.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${provider.tr('device_os')}: $osName',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.darkTextMuted,
                        ),
                      ),
                    ],
                  ),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 700 ? 4 : 2;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: actions.length,
          itemBuilder: (ctx, index) {
            final act = actions[index];
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
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: isDark ? 0.35 : 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : color.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(act['icon'] as IconData, size: 24, color: color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        act['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _activityLogs.length,
      itemBuilder: (ctx, index) {
        final log = _activityLogs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.history, color: AppTheme.primaryTeal),
            title: Text(
              log['event_type'] ?? log['activity_type'] ?? 'Action',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              log['message'] ?? log['details']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatTime(log['created_at']),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.darkTextMuted,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}

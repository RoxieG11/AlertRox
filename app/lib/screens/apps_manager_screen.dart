import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../constants/theme.dart';

class AppsManagerScreen extends StatefulWidget {
  const AppsManagerScreen({super.key});

  @override
  State<AppsManagerScreen> createState() => _AppsManagerScreenState();
}

class _AppsManagerScreenState extends State<AppsManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _runningProcesses = [];
  bool _isLoadingInstalled = false;
  bool _isLoadingRunning = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRunningProcesses();
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRunningProcesses() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dev = provider.selectedDevice;
    if (dev == null) return;
    final targetId = (dev['device_id'] ?? dev['id']).toString();

    setState(() => _isLoadingRunning = true);
    try {
      final cmd = await SupabaseService().sendCommand(targetId, 'get_running_apps');
      final cmdId = cmd['id']?.toString();

      // Sonucu bekle (poll for payload)
      if (cmdId != null) {
        for (int i = 0; i < 6; i++) {
          await Future.delayed(const Duration(milliseconds: 700));
          final res = await SupabaseService().getCommandStatus(cmdId);
          if (res != null && res['status'] == 'completed' && res['payload'] != null) {
            final payload = res['payload'] as Map<String, dynamic>;
            final procs = payload['processes'] as List?;
            if (procs != null && mounted) {
              setState(() {
                _runningProcesses = List<Map<String, dynamic>>.from(procs);
              });
              break;
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingRunning = false);
  }

  Future<void> _loadInstalledApps() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dev = provider.selectedDevice;
    if (dev == null) return;
    final targetId = (dev['device_id'] ?? dev['id']).toString();

    setState(() => _isLoadingInstalled = true);
    try {
      final cmd = await SupabaseService().sendCommand(targetId, 'get_installed_apps');
      final cmdId = cmd['id']?.toString();

      if (cmdId != null) {
        for (int i = 0; i < 7; i++) {
          await Future.delayed(const Duration(milliseconds: 700));
          final res = await SupabaseService().getCommandStatus(cmdId);
          if (res != null && res['status'] == 'completed' && res['payload'] != null) {
            final payload = res['payload'] as Map<String, dynamic>;
            final apps = payload['apps'] as List?;
            if (apps != null && mounted) {
              setState(() {
                _installedApps = List<Map<String, dynamic>>.from(apps);
              });
              break;
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingInstalled = false);
  }

  Future<void> _launchApp(String execCmd, String name) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dev = provider.selectedDevice;
    if (dev == null) return;
    final targetId = (dev['device_id'] ?? dev['id']).toString();

    try {
      await SupabaseService().sendCommand(targetId, 'launch_app', {
        'exec': execCmd,
        'name': name,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name başlatıldı!'),
            backgroundColor: AppTheme.statusOnline,
          ),
        );
        _loadRunningProcesses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Başlatılamadı: $e'), backgroundColor: AppTheme.statusOffline),
        );
      }
    }
  }

  Future<void> _killProcess(int pid, String name) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.tr('dialog_confirm_title')),
        content: Text('$name kapatılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(provider.tr('btn_cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusOffline, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(provider.tr('apps_kill')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final dev = provider.selectedDevice;
    if (dev == null) return;
    final targetId = (dev['device_id'] ?? dev['id']).toString();

    try {
      await SupabaseService().sendCommand(targetId, 'kill_process', {
        'pid': pid,
        'name': name,
      });
      setState(() {
        _runningProcesses.removeWhere((p) => p['pid'] == pid);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name sonlandırıldı'), backgroundColor: AppTheme.statusOnline),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.statusOffline),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredInstalled = _installedApps.where((a) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredRunning = _runningProcesses.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.tr('apps_title')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          labelColor: AppTheme.primaryTeal,
          tabs: [
            Tab(text: '${provider.tr('apps_running')} (${_runningProcesses.length})'),
            Tab(text: '${provider.tr('apps_installed')} (${_installedApps.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadRunningProcesses();
              _loadInstalledApps();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: provider.tr('apps_search_hint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Açık Olanlar (Running)
                _isLoadingRunning && _runningProcesses.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filteredRunning.isEmpty
                        ? Center(child: Text(provider.tr('apps_no_running'), style: const TextStyle(color: AppTheme.darkTextMuted)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredRunning.length,
                            itemBuilder: (ctx, i) {
                              final p = filteredRunning[i];
                              final pid = p['pid'] as int? ?? 0;
                              final name = p['name'] ?? 'Uygulama';
                              final mem = p['mem'] ?? 0;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    child: const Icon(Icons.laptop_chromebook, color: AppTheme.primaryTeal, size: 20),
                                  ),
                                  title: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('PID: $pid • Bellek: %$mem', style: const TextStyle(fontSize: 12, color: AppTheme.darkTextMuted)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close_rounded, color: AppTheme.statusOffline),
                                    tooltip: provider.tr('apps_kill'),
                                    onPressed: () => _killProcess(pid, name.toString()),
                                  ),
                                ),
                              );
                            },
                          ),

                // 2. Yüklü Uygulamalar (Installed)
                _isLoadingInstalled && _installedApps.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filteredInstalled.isEmpty
                        ? Center(child: Text(provider.tr('apps_no_installed'), style: const TextStyle(color: AppTheme.darkTextMuted)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredInstalled.length,
                            itemBuilder: (ctx, i) {
                              final app = filteredInstalled[i];
                              final name = app['name'] ?? '';
                              final execCmd = app['exec'] ?? '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    child: const Icon(Icons.apps_rounded, color: AppTheme.accentCyan, size: 20),
                                  ),
                                  title: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(execCmd.toString(), style: const TextStyle(fontSize: 11, color: AppTheme.darkTextMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryTeal,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                    label: Text(provider.tr('apps_launch')),
                                    onPressed: () => _launchApp(execCmd.toString(), name.toString()),
                                  ),
                                ),
                              );
                            },
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

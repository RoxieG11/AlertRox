import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../services/media_saver_service.dart';
import '../constants/theme.dart';
import '../widgets/glass_card.dart';

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
    final provider = Provider.of<AppProvider>(context, listen: false);
    final uri = Uri.parse(url);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) {
          final msg = provider.tr('clipboard_link_copied').replaceAll('{url}', url);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        final msg = provider.tr('clipboard_link_copied').replaceAll('{url}', url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

  void _showFullScreenImage(String name, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(imageUrl: url, title: name),
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

                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 14),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isImage && url.isNotEmpty)
                              GestureDetector(
                                onTap: () => _showFullScreenImage(name, url),
                                child: Container(
                                  height: 220,
                                  width: double.infinity,
                                  color: Colors.black26,
                                  child: Image.network(
                                    url,
                                    cacheWidth: 600,
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
                              AudioRecordingPlayer(
                                audioUrl: url,
                                title: name,
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
                                            tooltip: provider.tr('media_fullscreen'),
                                            icon: const Icon(Icons.fullscreen,
                                                size: 22),
                                            onPressed: () =>
                                                _showFullScreenImage(name, url),
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
                                          tooltip: provider.tr('media_open'),
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

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          clipBehavior: Clip.none,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stack) => const Center(
              child: Icon(
                Icons.broken_image,
                size: 64,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AudioRecordingPlayer extends StatefulWidget {
  final String audioUrl;
  final String title;

  const AudioRecordingPlayer({
    super.key,
    required this.audioUrl,
    required this.title,
  });

  @override
  State<AudioRecordingPlayer> createState() => _AudioRecordingPlayerState();
}

class _AudioRecordingPlayerState extends State<AudioRecordingPlayer> {
  late final AudioPlayer _player;
  PlayerState _state = PlayerState.stopped;
  Duration _duration = const Duration(seconds: 10);
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _state = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _state == PlayerState.playing;
    final provider = Provider.of<AppProvider>(context);

    final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 10000.0;
    final posMs = _position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentCyan.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                iconSize: 44,
                color: AppTheme.accentCyan,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                ),
                onPressed: widget.audioUrl.isNotEmpty ? _togglePlay : null,
                tooltip: isPlaying
                    ? provider.tr('media_pause')
                    : provider.tr('media_play'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.tr('media_audio_rec'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.darkTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppTheme.accentCyan,
              thumbColor: AppTheme.accentCyan,
            ),
            child: Slider(
              min: 0,
              max: maxMs,
              value: posMs,
              onChanged: (val) {
                _player.seek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
        ],
      ),
    );
  }
}


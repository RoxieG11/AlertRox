import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../constants/theme.dart';

class VolumeControlSheet extends StatefulWidget {
  final String targetId;
  final AppProvider provider;

  const VolumeControlSheet({
    super.key,
    required this.targetId,
    required this.provider,
  });

  static Future<void> show(BuildContext context, String targetId, AppProvider provider) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VolumeControlSheet(targetId: targetId, provider: provider),
    );
  }

  @override
  State<VolumeControlSheet> createState() => _VolumeControlSheetState();
}

class _VolumeControlSheetState extends State<VolumeControlSheet> {
  double _volume = 50.0;
  bool _isMuted = false;
  bool _isSending = false;

  Future<void> _setVolume(double val) async {
    setState(() => _volume = val);
    try {
      await SupabaseService().sendCommand(widget.targetId, 'set_volume', {
        'volume': val.toInt(),
      });
    } catch (_) {}
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    try {
      await SupabaseService().sendCommand(widget.targetId, 'toggle_mute');
    } catch (_) {}
  }

  Future<void> _sendMediaControl(String action) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await SupabaseService().sendCommand(widget.targetId, 'media_control', {
        'action': action,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.provider.tr('cmd_sent')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volume_up_rounded, color: AppTheme.primaryTeal, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.provider.tr('vol_title'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_volume.toInt()}% • ${_isMuted ? widget.provider.tr('vol_mute') : widget.provider.tr('vol_unmute')}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.darkTextMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: _isMuted ? AppTheme.statusOffline : AppTheme.primaryTeal,
                ),
                tooltip: _isMuted ? widget.provider.tr('vol_unmute') : widget.provider.tr('vol_mute'),
                onPressed: _toggleMute,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Volume Slider
          Row(
            children: [
              const Icon(Icons.volume_mute, size: 20, color: AppTheme.darkTextMuted),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  activeColor: AppTheme.primaryTeal,
                  inactiveColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  label: '${_volume.toInt()}%',
                  onChanged: (val) {
                    setState(() => _volume = val);
                  },
                  onChangeEnd: _setVolume,
                ),
              ),
              const Icon(Icons.volume_up, size: 20, color: AppTheme.primaryTeal),
            ],
          ),
          const SizedBox(height: 20),

          // Media Controls (Previous, Play/Pause, Next)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.skip_previous_rounded, size: 26),
                onPressed: () => _sendMediaControl('previous'),
              ),
              IconButton.filled(
                padding: const EdgeInsets.all(16),
                style: IconButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
                onPressed: () => _sendMediaControl('play_pause'),
              ),
              IconButton.filledTonal(
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.skip_next_rounded, size: 26),
                onPressed: () => _sendMediaControl('next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

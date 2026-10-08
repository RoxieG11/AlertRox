import 'dart:async';
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
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    try {
      final state = await SupabaseService().getDeviceState(widget.targetId);
      if (state != null && mounted) {
        setState(() {
          final volVal = state['volume'];
          if (volVal is num) {
            _volume = volVal.toDouble().clamp(0.0, 100.0);
          }
          if (state['muted'] is bool) {
            _isMuted = state['muted'] as bool;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _setVolume(double val) async {
    setState(() => _volume = val);
    try {
      await SupabaseService().sendCommand(widget.targetId, 'set_volume', {
        'volume': val.toInt().clamp(0, 100),
      });
    } catch (_) {}
  }

  void _onSliderChanged(double val) {
    setState(() => _volume = val);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _setVolume(val);
    });
  }

  Future<void> _stepVolume(int delta) async {
    final next = (_volume + delta).clamp(0.0, 100.0);
    setState(() => _volume = next);
    try {
      await SupabaseService().sendCommand(widget.targetId, 'volume_step', {
        'delta': delta,
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

          // Volume Slider + Step Buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.darkTextMuted),
                tooltip: widget.provider.tr('vol_step_down'),
                onPressed: () => _stepVolume(-5),
              ),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  activeColor: AppTheme.primaryTeal,
                  inactiveColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  label: '${_volume.toInt()}%',
                  onChanged: _onSliderChanged,
                  onChangeEnd: _setVolume,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryTeal),
                tooltip: widget.provider.tr('vol_step_up'),
                onPressed: () => _stepVolume(5),
              ),
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

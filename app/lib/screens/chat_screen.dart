import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../constants/theme.dart';

class ChatScreen extends StatefulWidget {
  final bool isActive;
  const ChatScreen({super.key, this.isActive = true});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isClearing = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages(showLoading: true);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted && widget.isActive) {
        _fetchMessages(showLoading: false);
      }
    });
  }

  Future<void> _fetchMessages({bool showLoading = false}) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dev = provider.selectedDevice;
    if (dev == null) return;
    final targetId = (dev['device_id'] ?? dev['id']).toString();

    if (showLoading && _messages.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final list = await SupabaseService().getMessages(targetId, limit: 100);
      if (!mounted) return;

      final bool hasChanged = list.length != _messages.length ||
          (list.isNotEmpty && _messages.isNotEmpty && list.last['id'] != _messages.last['id']);

      if (hasChanged || _isLoading) {
        setState(() {
          _messages = list;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearChat(String targetId, AppProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.tr('dialog_clear_chat_title')),
        content: Text(provider.tr('dialog_clear_chat_msg')),
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

    setState(() {
      _isClearing = true;
      _messages.clear();
    });
    try {
      await SupabaseService().clearMessages(targetId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.tr('chat_cleared')),
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
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final device = provider.selectedDevice;
    if (device == null) return;
    final targetId = (device['device_id'] ?? device['id']).toString();

    _msgController.clear();
    setState(() {
      _isSending = true;
      // Anlık iyimser UI güncellemesi (Optimistic Update)
      _messages.add({
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'device_id': targetId,
        'sender': 'mobile',
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      await SupabaseService().sendMessage(targetId, text);
      await _fetchMessages();
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
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final device = provider.selectedDevice;

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: Text(provider.tr('nav_chat'))),
        body: Center(child: Text(provider.tr('no_devices'))),
      );
    }

    final targetId = (device['device_id'] ?? device['id']).toString();
    final devName = device['name'] ?? device['device_name'] ?? 'PC';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(provider.tr('nav_chat')),
            Text(
              devName.toString(),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryTeal,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: provider.tr('act_chat'),
            icon: const Icon(Icons.open_in_new),
            onPressed: () async {
              await SupabaseService().sendCommand(targetId, 'open_chat');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.tr('cmd_sent'))),
                );
              }
            },
          ),
          IconButton(
            tooltip: provider.tr('chat_clear'),
            icon: _isClearing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep_outlined,
                    color: AppTheme.statusOffline),
            onPressed:
                _isClearing ? null : () => _clearChat(targetId, provider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 56,
                              color: AppTheme.darkTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              provider.tr('chat_empty'),
                              style: const TextStyle(color: AppTheme.darkTextMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender'] == 'mobile';
                          return _buildMessageBubble(provider, msg, isMe);
                        },
                      ),
          ),

          // Message Input Field
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: const Border(
                  top: BorderSide(color: AppTheme.darkCardBorder, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: provider.tr('chat_hint'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.black),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      AppProvider provider, Map<String, dynamic> msg, bool isMe) {
    final timeStr = _formatMsgTime(msg['created_at']);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.primaryTeal.withValues(alpha: 0.9)
              : (isDark ? const Color(0xFF161F30) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe
                ? AppTheme.primaryTeal
                : (isDark ? AppTheme.darkCardBorder : const Color(0xFFCBD5E1)),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              isMe
                  ? provider.tr('chat_sender_me')
                  : provider.tr('chat_sender_pc'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isMe
                    ? Colors.black87
                    : (isDark ? AppTheme.accentCyan : const Color(0xFF0F766E)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg['text'] ?? msg['message'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isMe
                    ? Colors.black
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 9,
                color: isMe
                    ? Colors.black54
                    : (isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMsgTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}


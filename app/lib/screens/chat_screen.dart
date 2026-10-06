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
  List<Map<String, dynamic>> _cachedMessages = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _fetchLatestMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && widget.isActive) {
        _fetchLatestMessages();
      }
    });
  }

  Future<void> _fetchLatestMessages() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dev = provider.selectedDevice;
    if (dev == null) return;
    final targetId = (dev['device_id'] ?? dev['id']).toString();
    final list = await SupabaseService().getMessages(targetId);
    if (!mounted) return;
    if (list.length != _cachedMessages.length ||
        (list.isNotEmpty &&
            _cachedMessages.isNotEmpty &&
            list.last['id'] != _cachedMessages.last['id'])) {
      setState(() {
        _cachedMessages = list;
      });
      _scrollToBottom();
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

    setState(() => _isClearing = true);
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final device = provider.selectedDevice;
    if (device == null) return;
    final targetId = (device['device_id'] ?? device['id']).toString();

    setState(() => _isSending = true);
    _msgController.clear();

    try {
      await SupabaseService().sendMessage(targetId, text);
      _scrollToBottom();
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
          // Messages Stream List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              initialData: _cachedMessages,
              stream: widget.isActive
                  ? SupabaseService().streamMessages(targetId)
                  : null,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _cachedMessages = snapshot.data!;
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData &&
                    _cachedMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? _cachedMessages;
                if (messages.isEmpty) {
                  return Center(
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
                  );
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (ctx, index) {
                    final msg = messages[index];
                    final isMe = msg['sender'] == 'mobile';
                    return _buildMessageBubble(provider, msg, isMe);
                  },
                );
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
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe ? AppTheme.primaryTeal : AppTheme.darkCardBorder,
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
                color: isMe ? Colors.black87 : AppTheme.accentCyan,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg['text'] ?? msg['message'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 9,
                color: isMe ? Colors.black54 : AppTheme.darkTextMuted,
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

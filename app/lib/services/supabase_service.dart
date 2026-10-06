import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String keyUrl = 'supabase_url';
  static const String keyAnonKey = 'supabase_anon_key';
  static const String keyEmail = 'supabase_user_email';
  static const String keyAccessToken = 'supabase_access_token';
  static const String keyRefreshToken = 'supabase_refresh_token';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser =>
      _isInitialized ? client.auth.currentUser : null;

  bool get isAuthenticated =>
      _isInitialized && client.auth.currentSession != null;

  Future<bool> initialize() async {
    try {
      final url = await _secureStorage.read(key: keyUrl);
      final anonKey = await _secureStorage.read(key: keyAnonKey);

      if (url == null ||
          url.trim().isEmpty ||
          anonKey == null ||
          anonKey.trim().isEmpty) {
        return false;
      }

      if (!_isInitialized) {
        await Supabase.initialize(
          url: url.trim(),
          anonKey: anonKey.trim(),
          debug: kDebugMode,
        );
        _isInitialized = true;
      }

      // Sync tokens to secure storage if session exists
      final session = client.auth.currentSession;
      if (session != null) {
        await _secureStorage.write(
            key: keyAccessToken, value: session.accessToken);
        if (session.refreshToken != null) {
          await _secureStorage.write(
              key: keyRefreshToken, value: session.refreshToken);
        }
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Supabase init error: $e');
      return false;
    }
  }

  Future<AuthResponse> signIn({
    required String url,
    required String anonKey,
    required String email,
    required String password,
  }) async {
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();

    if (!_isInitialized) {
      await Supabase.initialize(
        url: cleanUrl,
        anonKey: cleanKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
    }

    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.session != null) {
      await _secureStorage.write(key: keyUrl, value: cleanUrl);
      await _secureStorage.write(key: keyAnonKey, value: cleanKey);
      await _secureStorage.write(key: keyEmail, value: email.trim());
      await _secureStorage.write(
          key: keyAccessToken, value: response.session!.accessToken);
      if (response.session!.refreshToken != null) {
        await _secureStorage.write(
            key: keyRefreshToken, value: response.session!.refreshToken);
      }
    }

    return response;
  }

  Future<void> signOut() async {
    try {
      if (_isInitialized) {
        await client.auth.signOut();
      }
    } catch (_) {}

    await _secureStorage.delete(key: keyAccessToken);
    await _secureStorage.delete(key: keyRefreshToken);
  }

  Future<Map<String, String>> getSavedConfig() async {
    final url = await _secureStorage.read(key: keyUrl);
    final key = await _secureStorage.read(key: keyAnonKey);
    final email = await _secureStorage.read(key: keyEmail);
    return {
      'url': url ?? '',
      'anon_key': key ?? '',
      'email': email ?? '',
    };
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
      'owner_id': currentUser?.id,
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
      'owner_id': currentUser?.id,
    });
  }

  Future<void> clearMessages(String deviceId) async {
    try {
      await client.from('messages').delete().eq('device_id', deviceId);
    } catch (e) {
      debugPrint('Error clearing messages: $e');
      rethrow;
    }
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

      final response =
          await filter.order('created_at', ascending: false).limit(50);
      final List<Map<String, dynamic>> results = [];

      for (final cmd in response) {
        final rawUrl = cmd['result_url'] as String? ?? '';
        if (rawUrl.isEmpty) continue;

        final type = cmd['command_type'] as String? ?? '';
        final isImage = type == 'screenshot' || type == 'webcam';
        final isAudio = type == 'mic_record';

        // Extract relative storage path and generate fresh 600-second signed URL
        String finalUrl = rawUrl;
        if (rawUrl.contains('/alertrox-files/')) {
          try {
            final pathPart = rawUrl.split('/alertrox-files/')[1].split('?')[0];
            final freshUrl = await client.storage
                .from('alertrox-files')
                .createSignedUrl(pathPart, 600);
            if (freshUrl.isNotEmpty) finalUrl = freshUrl;
          } catch (_) {}
        }

        results.add({
          'id': cmd['id'],
          'name':
              '$type — ${_formatMediaTime(cmd['executed_at'] ?? cmd['created_at'])}',
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

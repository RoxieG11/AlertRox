import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MediaSaverService {
  static const MethodChannel _channel =
      MethodChannel('com.roxie.alertrox/media_saver');

  /// Downloads media file from [url] and:
  /// - If [isImage]: saves directly into the phone's Gallery (Pictures/AlertRox)
  /// - If [isAudio]: saves directly into the phone's Downloads directory (Download/AlertRox)
  /// On Desktop/Linux: saves into ~/Pictures/AlertRox or ~/Downloads/AlertRox
  static Future<String> downloadAndSaveMedia({
    required String url,
    required bool isImage,
    required String baseName,
  }) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: Failed to download file');
    }

    final bytes = response.bodyBytes;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = isImage ? 'png' : 'wav';
    final cleanName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeFilename = 'AlertRox_${cleanName}_$timestamp.$ext';

    if (!kIsWeb && Platform.isAndroid) {
      if (isImage) {
        final result = await _channel.invokeMethod<String>('saveImageToGallery', {
          'bytes': bytes,
          'filename': safeFilename,
        });
        return result ?? safeFilename;
      } else {
        final result =
            await _channel.invokeMethod<String>('saveAudioToDownloads', {
          'bytes': bytes,
          'filename': safeFilename,
        });
        return result ?? safeFilename;
      }
    } else {
      // Desktop / Linux / macOS / Windows fallback
      Directory? targetDir;
      final home = Platform.environment['HOME'] ?? '';

      if (isImage) {
        if (home.isNotEmpty) {
          targetDir = Directory('$home/Pictures/AlertRox');
        } else {
          targetDir = await getApplicationDocumentsDirectory();
        }
      } else {
        if (home.isNotEmpty) {
          targetDir = Directory('$home/Downloads/AlertRox');
        } else {
          targetDir = await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        }
      }

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final file = File('${targetDir.path}/$safeFilename');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }
}

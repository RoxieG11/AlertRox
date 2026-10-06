import 'dart:io';
import 'package:flutter/foundation.dart';

class WakeOnLanService {
  /// Standart Wake-on-LAN Sihirli Paketini (Magic Packet) UDP broadcast olarak gönderir.
  /// MAC Adresi formatı: AA:BB:CC:DD:EE:FF veya AA-BB-CC-DD-EE-FF
  static Future<bool> wakeDevice({
    required String macAddress,
    String broadcastIp = '255.255.255.255',
    int port = 9,
  }) async {
    try {
      final cleanMac = macAddress
          .replaceAll(':', '')
          .replaceAll('-', '')
          .replaceAll('.', '')
          .trim();

      if (cleanMac.length != 12) {
        debugPrint('Geçersiz MAC adresi uzunluğu: $macAddress');
        return false;
      }

      final macBytes = <int>[];
      for (int i = 0; i < 12; i += 2) {
        macBytes.add(int.parse(cleanMac.substring(i, i + 2), radix: 16));
      }

      // Magic Packet Yapısı: 6 adet 0xFF ardından 16 kez tekrarlanan MAC adresi (Toplam 102 byte)
      final packet = List<int>.filled(6, 0xFF) +
          List<int>.generate(16 * 6, (index) => macBytes[index % 6]);

      final rawDatagramSocket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      rawDatagramSocket.broadcastEnabled = true;

      final destinationAddress = InternetAddress(broadcastIp);
      rawDatagramSocket.send(packet, destinationAddress, port);
      rawDatagramSocket.close();

      debugPrint('WoL Sihirli Paketi başarıyla gönderildi: $macAddress ($broadcastIp:$port)');
      return true;
    } catch (e) {
      debugPrint('WoL paket gönderme hatası: $e');
      return false;
    }
  }

  /// os_info veya device objesinden MAC adresini ayıklar.
  static String? extractMacAddress(Map<String, dynamic> device) {
    // 1. Doğrudan mac alanı varsa
    if (device['mac_address'] != null &&
        device['mac_address'].toString().isNotEmpty) {
      return device['mac_address'].toString();
    }

    // 2. os_info içinde "MAC:b0:5c:da:38:c8:81" formatında arama
    final osInfo = device['os_info']?.toString() ?? '';
    final macMatch = RegExp(r'MAC:([0-9a-fA-F:]{17})').firstMatch(osInfo);
    if (macMatch != null) {
      return macMatch.group(1);
    }

    return null;
  }
}

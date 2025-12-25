// ===== FILE: lib/core/utils/network_utils.dart =====
// lib/core/utils/network_utils.dart
import 'dart:io';

class NetworkUtils {
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
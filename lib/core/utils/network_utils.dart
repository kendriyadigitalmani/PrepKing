// lib/core/utils/network_utils.dart
import 'dart:async';
import 'dart:io';

class NetworkUtils {
  /// Checks if the device has real internet access by:
  /// 1. Attempting DNS lookup to google.com (reliable global endpoint)
  /// 2. Attempting DNS lookup to your actual API domain (quizard.in)
  /// Both with a 5-second timeout to prevent hanging
  static Future<bool> hasInternet() async {
    try {
      // Step 1: Check connectivity to a reliable public DNS (Google)
      final googleCheck = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      if (googleCheck.isEmpty || googleCheck[0].rawAddress.isEmpty) {
        return false;
      }

      // Step 2: Check connectivity specifically to your backend domain
      // This catches cases where internet exists but your server is unreachable
      final apiCheck = await InternetAddress.lookup('quizard.in')
          .timeout(const Duration(seconds: 5));

      return apiCheck.isNotEmpty && apiCheck[0].rawAddress.isNotEmpty;
    } on SocketException {
      // No network connection at all
      return false;
    } on TimeoutException {
      // Took too long → treat as no internet
      return false;
    } catch (_) {
      // Any other error (e.g. permission issues, DNS failure)
      return false;
    }
  }
}
// lib/models/app_settings.dart
import 'dart:convert';

class AppSettings {
  final String version; // e.g., "1.0.0" from root "version"
  final int buildNumber; // e.g., 4 from root "build_number"
  final bool isUpdateMandatory; // true if "is_update_mandatory" == 1
  final String? apkUrl;               // NEW: direct APK download URL
  final String? appStoreUrl;          // NEW: App Store URL (for iOS)
  final Map<String, dynamic> appSettingsJson; // Full parsed "app_settings" object
  final Map<String, dynamic> firebaseSettings; // Full parsed "firebase_settings" object
  final List<Map<String, dynamic>> firebaseClients; // "firebase_clients" array

  AppSettings({
    required this.version,
    required this.buildNumber,
    required this.isUpdateMandatory,
    this.apkUrl,
    this.appStoreUrl,
    required this.appSettingsJson,
    required this.firebaseSettings,
    required this.firebaseClients,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // API response structure: {"success": true, "data": { ... }}
    final data = json['data'] as Map<String, dynamic>;

    // Safely decode fields that might be either String (JSON encoded) or already Map
    Map<String, dynamic> safeJsonDecode(dynamic value) {
      if (value == null) return {};
      if (value is Map<String, dynamic>) {
        return value; // Already decoded
      }
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (e) {
          // Invalid JSON string → return empty map
        }
      }
      return {};
    }

    // Parse firebase_clients – it's a List of Maps directly from the server
    List<Map<String, dynamic>> parseFirebaseClients(dynamic clients) {
      if (clients is List) {
        return clients
            .where((item) => item is Map<String, dynamic>)
            .cast<Map<String, dynamic>>()
            .toList();
      }
      return [];
    }

    return AppSettings(
      version: data['version'] as String? ?? '1.0.0',
      buildNumber: data['build_number'] as int? ?? 1,
      isUpdateMandatory: (data['is_update_mandatory'] as int? ?? 0) == 1,
      apkUrl: data['apk_url'] as String?,
      appStoreUrl: data['app_store_url'] as String?,
      appSettingsJson: safeJsonDecode(data['app_settings']),
      firebaseSettings: safeJsonDecode(data['firebase_settings']),
      firebaseClients: parseFirebaseClients(data['firebase_clients']),
    );
  }
}
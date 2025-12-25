// lib/core/models/app_settings.dart
class AppSettings {
  final String versionName;
  final int buildNumber;
  final String publishTo;

  AppSettings({
    required this.versionName,
    required this.buildNumber,
    required this.publishTo,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return AppSettings(
      versionName: data['version_name'] as String,
      buildNumber: data['build_number'] as int,
      publishTo: data['publish_to'] as String,
    );
  }
}
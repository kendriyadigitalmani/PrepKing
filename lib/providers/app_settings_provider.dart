// lib/providers/app_settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/services/api_service.dart';
import '../models/app_settings.dart';

/// Provides the app settings fetched from the server.
/// Dynamically uses the current app's package name (no hardcoding).
final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  // Get package info at runtime (works on Android & iOS)
  final packageInfo = await PackageInfo.fromPlatform();
  final String packageId = packageInfo.packageName;

  // Fetch app settings using the actual package ID
  final apiService = ref.read(apiServiceProvider);

  // Use the public method that returns the parsed AppSettings model
  return await apiService.getAppSettings(packageId: packageId);
});
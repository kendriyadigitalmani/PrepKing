// lib/core/utils/app_version_validator.dart
import 'package:package_info_plus/package_info_plus.dart';
import '../../models/app_settings.dart';

class AppVersionValidator {
  /// Determines if a forced update is required.
  ///
  /// Updated to use the new fields from the API response:
  /// - settings.version → server app version (e.g., "1.0.1")
  /// - settings.buildNumber → server build number (integer from root "build_number")
  /// - settings.isUpdateMandatory → whether the update should be forced (from "is_update_mandatory")
  ///
  /// Logic:
  /// 1. Compare version strings first (semantic version comparison is not strict here).
  /// 2. If versions differ OR server build number is higher → consider update needed.
  /// 3. Return true (force update) ONLY if isUpdateMandatory is true.
  ///
  /// This gives full control:
  /// - Set is_update_mandatory = 1 on server → forces update dialog even for minor changes.
  /// - Set is_update_mandatory = 0 → users can continue with older version.
  ///
  static Future<bool> isUpdateRequired(AppSettings settings) async {
    final packageInfo = await PackageInfo.fromPlatform();

    final String localVersion = packageInfo.version;
    final int localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    final String serverVersion = settings.version;
    final int serverBuild = settings.buildNumber;
    final bool mandatory = settings.isUpdateMandatory;

    // If server version is different OR build number is higher → update is available/needed
    final bool updateAvailable = (localVersion != serverVersion) || (serverBuild > localBuild);

    // Force the update dialog only if the server marks it as mandatory
    return updateAvailable && mandatory;
  }
}
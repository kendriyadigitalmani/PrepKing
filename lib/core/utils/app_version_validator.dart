// lib/core/utils/app_version_validator.dart
import 'package:package_info_plus/package_info_plus.dart';

import '../../models/app_settings.dart';

class AppVersionValidator {
  static Future<bool> isUpdateRequired(AppSettings settings) async {
    final info = await PackageInfo.fromPlatform();
    final localVersion = info.version;
    final localBuild = int.tryParse(info.buildNumber) ?? 0;

    // Update required if version name differs OR remote build number is higher
    if (settings.versionName != localVersion) return true;
    if (settings.buildNumber > localBuild) return true;

    return false;
  }
}
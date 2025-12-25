// lib/core/utils/user_preferences.dart

import 'package:shared_preferences/shared_preferences.dart';

/// A lightweight utility class for storing non-sensitive app preferences.
///
/// IMPORTANT BEST PRACTICE (for Google Play compliance & security):
/// - This class should ONLY store flags, settings, and non-personal data.
/// - NEVER store profile data like name, email, or user_id here for display.
///   Use providers (currentUserProvider / userWithProgressProvider) for all user profile data.
/// - Personal data in SharedPreferences is considered insecure and can cause Play Store rejections.
///
/// Current safe usage:
/// - seenOnboarding (flag)
/// - Future expansion: theme, notifications, etc.
class UserPreferences {
  // Keys – keep them private
  static const _seen_onboarding = 'seenOnboarding';
  // Removed deprecated personal data keys (name, email, user_id, etc.)
  // They caused data mixing bugs and compliance risks.

  /// Marks onboarding as seen – safe flag
  Future<void> saveOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seen_onboarding, true);
  }

  /// Checks if onboarding has been seen
  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seen_onboarding) ?? false;
  }

  /// Clears ALL preferences.
  /// Called during full logout to ensure clean state.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ────────────────────────────────────────────────────────────────
  // DEPRECATED METHODS (kept temporarily for backward compatibility)
  // These will be removed in future updates.
  // DO NOT USE THEM IN NEW CODE.
  // ────────────────────────────────────────────────────────────────

  @Deprecated('Use providers instead. This method stores personal data unsafely.')
  Future<void> saveUserData({
    required int userId,
    required String firebaseId,
    required String name,
    required String email,
    bool isFirstTime = false,
    bool isGuest = false,
  }) async {
    // No-op or minimal – do NOT save personal data
    await saveOnboardingSeen();
  }

  @Deprecated('Guest mode should not rely on local storage for profile data.')
  Future<void> saveGuestData({required String firebaseId}) async {
    await saveOnboardingSeen();
  }

  @Deprecated('Do not read profile data from SharedPreferences. Use currentUserProvider.')
  Future<Map<String, dynamic>?> getUserData() async {
    // Return only safe flags – never personal data
    return {
      'seenOnboarding': await hasSeenOnboarding(),
    };
  }

  @Deprecated('Use clearAll() instead.')
  Future<void> clear() async {
    await clearAll();
  }
}
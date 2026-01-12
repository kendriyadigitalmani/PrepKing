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
/// - language_id
/// - exam_ids
/// - user_id (only the integer ID – used for API userid injection, not for display)
class UserPreferences {
  // Keys – keep them private
  static const _seen_onboarding = 'seenOnboarding';

  // NEW: Language and Exams keys
  static const _language_id = 'language_id';
  static const _exam_ids = 'exam_ids';

  // NEW: User ID key (minimal integer only – used for API authentication flow)
  static const _user_id = 'user_id';

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

  // ───────── SELECTIVE CLEAR FOR LOGOUT (NEW) ────────────────────────
  /// Clears only authentication-related data on logout.
  /// This preserves user preferences like language and selected exams
  /// to avoid frustrating the user after they log in again.
  Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_user_id);
    // Note: We intentionally do NOT clear language_id, exam_ids, or onboarding flag
  }

  // ───────── NEW: Language and Exams ─────────────────────────────────
  /// Saves the selected language ID
  Future<void> saveLanguage(int languageId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_language_id, languageId);
  }

  /// Retrieves the saved language ID (returns null if not set)
  Future<int?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_language_id);
  }

  /// Saves the selected exam IDs (list of integers)
  Future<void> saveExams(List<int> examIds) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = examIds.map((id) => id.toString()).toList();
    await prefs.setStringList(_exam_ids, stringList);
  }

  /// Retrieves the saved exam IDs (returns empty list if none)
  Future<List<int>> getExams() async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = prefs.getStringList(_exam_ids) ?? [];
    return stringList
        .map((str) => int.tryParse(str) ?? 0)
        .where((id) => id > 0)
        .toList();
  }

  /// NEW: Checks if both language and at least one exam are selected
  /// Used to guard Course/Quiz screens from loading when preferences are incomplete
  Future<bool> isPreferencesReady() async {
    final languageId = await getLanguage();
    final examIds = await getExams();
    return languageId != null && examIds.isNotEmpty;
  }

  // ───────── NEW: User ID storage (for API userid injection) ─────────
  /// Saves the logged-in user ID (used for automatically adding ?userid= to API calls)
  Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_user_id, userId);
  }

  /// Retrieves the saved user ID (returns null if not logged in)
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_user_id);
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
// lib/core/utils/user_preferences.dart
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const _user_id = 'user_id';
  static const _firebase_id = 'firebase_id';
  static const _name = 'user_name';
  static const _email = 'user_email';
  static const _is_first_time = 'is_first_time';
  static const _seen_onboarding = 'seenOnboarding';
  static const _is_guest = 'is_guest';

  Future<void> saveUserData({
    required int userId,
    required String firebaseId,
    required String name,
    required String email,
    bool isFirstTime = false,
    bool isGuest = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_user_id, userId);
    await prefs.setString(_firebase_id, firebaseId);
    await prefs.setString(_name, name);
    await prefs.setString(_email, email);
    await prefs.setBool(_is_first_time, isFirstTime);
    await prefs.setBool(_seen_onboarding, true);
    await prefs.setBool(_is_guest, isGuest);
  }

  Future<void> saveGuestData({
    required String firebaseId,
  }) async {
    // For guest: no backend user ID yet, so use -1 or handle specially
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_user_id, -1); // or omit if you won't use it
    await prefs.setString(_firebase_id, firebaseId);
    await prefs.setString(_name, 'Guest');
    await prefs.setString(_email, '');
    await prefs.setBool(_is_first_time, true);
    await prefs.setBool(_seen_onboarding, true);
    await prefs.setBool(_is_guest, true);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseId = prefs.getString(_firebase_id);
    if (firebaseId == null) return null;

    return {
      'user_id': prefs.getInt(_user_id) ?? -1,
      'firebase_id': firebaseId,
      'name': prefs.getString(_name) ?? 'User',
      'email': prefs.getString(_email) ?? '',
      'is_first_time': prefs.getBool(_is_first_time) ?? true,
      'seenOnboarding': prefs.getBool(_seen_onboarding) ?? false,
      'is_guest': prefs.getBool(_is_guest) ?? false,
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // or remove specific keys
  }

  // Inside UserPreferences class
  Future<void> saveOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seen_onboarding, true);
  }
}
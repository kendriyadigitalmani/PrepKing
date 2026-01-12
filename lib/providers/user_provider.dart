// lib/providers/user_provider.dart
import 'package:dio/dio.dart'; // ← Required for DioException
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/api_service.dart';
import '../models/user_model.dart';
import '../core/utils/user_preferences.dart';
import '../core/utils/current_user_cache.dart';

/// ───────── API PROVIDER ─────────────────────────────────────────────
final apiProvider = Provider<ApiService>((ref) {
  return ref.read(apiServiceProvider);
});

/// 🔁 Real-time Firebase auth state stream (kept for any UI that needs it)
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// ───────── CURRENT USER (REAL DATA FROM /user?firebaseid={uid}) ───────
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    debugPrint("No Firebase user logged in");
    return null;
  }

  final api = ref.read(apiProvider);

  try {
    // Fetch user profile from backend using firebaseid
    final response = await api.get(
      '/user',
      query: {'firebaseid': firebaseUser.uid},
    );

    debugPrint("User API Response: $response");

    final data = response['data'];
    if (data is Map<String, dynamic> && data.isNotEmpty) {
      final user = UserModel.fromJson(data);

      // 🔥 Cache user ID for automatic API userid injection
      CurrentUserCache.setUserId(user.id);
      await UserPreferences().saveUserId(user.id);

      // Sync language & exam preferences to local storage (backup & fast access)
      final prefs = UserPreferences();
      if (user.languageId != null) {
        await prefs.saveLanguage(user.languageId!);
      }
      if (user.examIds.isNotEmpty) {
        await prefs.saveExams(user.examIds);
      }

      return user;
    }

    debugPrint("No user data found for uid: ${firebaseUser.uid}");
    return null;
  } on ApiException catch (apiEx) {
    debugPrint("API Error fetching user: ${apiEx.message}");

    // 🔥 CRITICAL FIX (Issue 3): Detect 401/404 when backend user is missing
    // ApiException is thrown from _handleResponse in ApiService when success == false
    // The original DioException (if any) is lost, so we rely on message content
    final lowerMessage = apiEx.message.toLowerCase();

    if (lowerMessage.contains('401') ||
        lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('403') ||
        lowerMessage.contains('forbidden') ||
        lowerMessage.contains('404') ||
        lowerMessage.contains('not found') ||
        lowerMessage.contains('resource')) {
      debugPrint("Backend user not found or unauthorized → signing out Firebase");
      await FirebaseAuth.instance.signOut();
      CurrentUserCache.clear();
      await UserPreferences().clearAuthData();
      return null; // Treat as logged out
    }

    // For other API errors, re-throw so splash screen can show retry dialog
    rethrow;
  } catch (e, stack) {
    debugPrint("Unexpected error fetching user: $e\n$stack");
    rethrow;
  }
});

/// ───────── CONTINUE COURSE PROGRESS ─────────────────────────────────
class UserProgressModel {
  final String courseTitle;
  final double progressPercentage;
  final String? courseImage;

  const UserProgressModel({
    required this.courseTitle,
    required this.progressPercentage,
    this.courseImage,
  });
}

final continueCourseProvider = FutureProvider<UserProgressModel?>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final response = await api.get('/user_progress');
    final data = response['data'];
    if (data != null && data is List && data.isNotEmpty) {
      final item = data[0] as Map<String, dynamic>;
      return UserProgressModel(
        courseTitle: item['course_title']?.toString() ?? "Continue Learning",
        progressPercentage: double.tryParse(item['progress']?.toString() ?? "0") ?? 0.0,
        courseImage: item['course_image'] as String?,
      );
    }
  } on ApiException catch (e) {
    debugPrint("API Error in continueCourseProvider: ${e.message}");
    // Graceful fallback – do not rethrow
  } catch (e) {
    debugPrint("Continue course error: $e");
  }

  // Consistent fallback for stable UI
  return const UserProgressModel(
    courseTitle: "Algebra Mastery 101",
    progressPercentage: 68.5,
  );
});

/// ───────── DAILY CHALLENGE QUIZ ─────────────────────────────────────
class DailyQuizModel {
  final int id;
  final String title;
  final int questionCount;
  final String? thumbnail;

  const DailyQuizModel({
    required this.id,
    required this.title,
    required this.questionCount,
    this.thumbnail,
  });
}

final dailyChallengeProvider = FutureProvider<DailyQuizModel?>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final response = await api.get('/course_quiz', query: {'type': 'daily'});
    final data = response['data'];
    if (data != null && data is List && data.isNotEmpty) {
      final quiz = data[0] as Map<String, dynamic>;
      return DailyQuizModel(
        id: int.tryParse(quiz['id'].toString()) ?? 0,
        title: quiz['title']?.toString() ?? "Today's Challenge",
        questionCount: int.tryParse(quiz['total_questions']?.toString() ?? "5") ?? 5,
        thumbnail: quiz['thumbnail'] as String?,
      );
    }
  } on ApiException catch (e) {
    debugPrint("API Error in dailyChallengeProvider: ${e.message}");
    // Graceful fallback – do not rethrow
  } catch (e) {
    debugPrint("Daily quiz fetch error: $e");
  }

  // Consistent fallback
  return const DailyQuizModel(
    id: 999,
    title: "Daily Challenge",
    questionCount: 10,
  );
});

/// ───────── ONE-TAP REFRESH ALL USER DATA ────────────────────────────
final refreshUserDataProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(currentUserProvider);
    ref.invalidate(continueCourseProvider);
    ref.invalidate(dailyChallengeProvider);
  };
});

/// 🔥 LOGOUT HELPER (PRESERVES USER PREFERENCES)
///
/// Call this function wherever logout is triggered (e.g., ProfileScreen, Settings).
/// It signs out from Firebase, clears only authentication data,
/// and preserves language/exam selections for better UX.
Future<void> performLogout(WidgetRef ref) async {
  await FirebaseAuth.instance.signOut();

  // Clear in-memory and persistent user ID (used for API userid injection)
  CurrentUserCache.clear();
  await UserPreferences().clearAuthData(); // ← Only removes user_id, keeps language/exams

  // Invalidate providers so fresh data is fetched on next login
  ref.invalidate(currentUserProvider);
  ref.invalidate(continueCourseProvider);
  ref.invalidate(dailyChallengeProvider);

  debugPrint("Logout completed: Auth cleared, preferences preserved");
}
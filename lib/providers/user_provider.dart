// ===== FILE: lib/providers/user_provider.dart =====
// lib/providers/user_provider.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/api_service.dart';
import '../models/user_model.dart';
import 'firebase_init_provider.dart';

/// ───────── API PROVIDER ─────────────────────────────────────────────
final apiProvider = Provider<ApiService>((ref) {
  return ref.read(apiServiceProvider);
});

/// 🔁 We KEEP authStateProvider for any UI that needs real-time auth state (e.g., logout listeners)
/// But currentUserProvider no longer depends on it for performance.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// ───────── CURRENT USER (REAL DATA FROM /user?firebaseid={uid}) ───────
/// ✨ Updated logic: Uses FirebaseAuth.instance.currentUser (synchronous, faster)
/// Still waits for Firebase to initialize to avoid race conditions.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    debugPrint("No Firebase user logged in");
    return null;
  }

  final api = ref.read(apiProvider);

  try {
    // Using query parameter firebaseid as per API documentation
    final response = await api.get(
      '/user',
      query: {'firebaseid': firebaseUser.uid},
    );
    debugPrint("User API Response: $response");

    final data = response['data'];
    if (data is Map<String, dynamic>?) {
      if (data != null) {
        return UserModel.fromJson(data);
      }
    }

    debugPrint("No user data found for uid: ${firebaseUser.uid}");
    return null;
  } catch (e, stack) {
    debugPrint("User fetch error: $e\n$stack");
    // Return null instead of rethrowing to avoid UI crash; FutureProvider handles error state
    return null;
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
  } catch (e) {
    debugPrint("Continue course error: $e");
  }

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
  } catch (e) {
    debugPrint("Daily quiz fetch error: $e");
  }

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
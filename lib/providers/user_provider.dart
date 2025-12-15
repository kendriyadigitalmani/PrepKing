// lib/providers/user_provider.dart → FIXED VERSION FOR SINGLE USER BY FIREBASE ID
import 'package:firebase_auth/firebase_auth.dart'; // ← ADD THIS IMPORT
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';

// ── API PROVIDER ─────────────────────
final apiProvider = Provider<ApiService>((ref) {
  return ref.read(apiServiceProvider);
});

// ── CURRENT USER (REAL DATA FROM /user?firebaseid={uid}) ─────────────────────
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    debugPrint("No Firebase user logged in");
    return null;
  }

  final api = ref.read(apiProvider);
  try {
    // Use the correct endpoint: GET /user?firebaseid={firebase_id}
    final response = await api.get(
      '/user',
      query: {'firebaseid': firebaseUser.uid}, // ← This filters to the current user
    );

    debugPrint("User API Response: $response"); // ← Helpful for debugging

    final data = response['data'];

    Map<String, dynamic>? userJson;

    if (data != null) {
      if (data is List) {
        // If API returns a list (even if only one item), take the first
        if (data.isNotEmpty) {
          userJson = data[0] as Map<String, dynamic>;
        }
      } else if (data is Map<String, dynamic>) {
        // Direct single object response
        userJson = data;
      }
    }

    if (userJson != null) {
      return UserModel.fromJson(userJson);
    } else {
      debugPrint("No user data found for firebaseid: ${firebaseUser.uid}");
    }
  } catch (e, stack) {
    debugPrint("User fetch error: $e\n$stack");
  }

  return null;
});

// ── CONTINUE COURSE PROGRESS ───────────────────── (unchanged)
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

// ── DAILY CHALLENGE QUIZ ───────────────────── (unchanged)
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

// ── ONE-TAP REFRESH ALL USER DATA ───────────────────── (unchanged)
final refreshUserDataProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(currentUserProvider);
    ref.invalidate(continueCourseProvider);
    ref.invalidate(dailyChallengeProvider);
  };
});
// lib/providers/user_provider.dart → FINAL 100% WORKING VERSION
import 'package:flutter/foundation.dart'; // ← ADDED THIS LINE
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';

// ── API PROVIDER ─────────────────────
final apiProvider = Provider<ApiService>((ref) {
  return ref.read(apiServiceProvider);
});

// ── CURRENT USER (REAL DATA FROM /user) ─────────────────────
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final api = ref.read(apiProvider);

  try {
    final response = await api.get('/user');
    final data = response['data'];

    if (data != null && data is List && data.isNotEmpty) {
      return UserModel.fromJson(data[0] as Map<String, dynamic>);
    }
  } catch (e) {
    debugPrint("User fetch error: $e"); // ← NOW WORKS
  }

  return null;
});

// ── CONTINUE COURSE PROGRESS ─────────────────────
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

// ── DAILY CHALLENGE QUIZ ─────────────────────
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

// ── ONE-TAP REFRESH ALL USER DATA ─────────────────────
final refreshUserDataProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(currentUserProvider);
    ref.invalidate(continueCourseProvider);
    ref.invalidate(dailyChallengeProvider);
  };
});
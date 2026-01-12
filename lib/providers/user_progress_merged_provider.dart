// lib/providers/user_progress_merged_provider.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';
import 'user_provider.dart'; // assuming currentUserProvider is here

/// ── Provider to fetch ALL course progress for a user (including per-content details) ──
final allUserCourseProgressProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
      (ref, userId) async {
    // Prevent unnecessary refetching when navigating back
    ref.keepAlive();

    final api = ref.read(apiServiceProvider);
    try {
      // This calls GET /course/progress?userid=X → returns all enrolled courses with content_progress
      final response = await api.get(
        '/course/progress',
        query: {'userid': userId.toString()},
      );

      if (response['success'] == true && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }

      debugPrint('allUserCourseProgressProvider: API success=false or no data for user $userId');
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error fetching all course progress for user $userId: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  },
);

/// ── FINAL MERGED PROVIDER: Current logged-in user + full progress data ──
final userWithProgressProvider = FutureProvider<UserModel?>((ref) async {
  // Keep provider alive to avoid refetching on every navigation
  ref.keepAlive();

  // Watch the base user (from auth + /user endpoint)
  final userAsync = ref.watch(currentUserProvider);

  // Handle loading/error states gracefully
  if (userAsync is AsyncLoading) return null;
  if (userAsync is AsyncError) {
    debugPrint('userWithProgressProvider: currentUser error - ${userAsync.error}');
    return null;
  }

  final user = userAsync.value;
  if (user == null) {
    debugPrint('userWithProgressProvider: No logged-in user');
    return null;
  }

  final userId = user.id;

  // Fetch all course progress (including detailed content_progress)
  final progressList = await ref.watch(allUserCourseProgressProvider(userId).future);

  final Map<String, double> courseProgress = {};
  final Set<String> completedContentIds = {};

  for (final courseAttempt in progressList) {
    // Prefer course_quiz_id, but fallback to 'id' if missing (defensive)
    final courseIdRaw = courseAttempt['course_quiz_id'] ?? courseAttempt['id'];
    final courseId = courseIdRaw?.toString();
    if (courseId == null) continue;

    // 1. Course-level progress percentage (normalized to 0.0 – 1.0)
    final rawPercentage = double.tryParse(
      courseAttempt['progress_percentage']?.toString() ?? '0',
    ) ??
        0.0;
    courseProgress[courseId] = (rawPercentage / 100.0).clamp(0.0, 1.0);

    // 2. Primary source: detailed content_progress records
    final contentProgressList = courseAttempt['content_progress'] as List<dynamic>? ?? [];
    for (final cp in contentProgressList) {
      final status = cp['status']?.toString().toLowerCase();
      final contentId = cp['content_id']?.toString();
      if (status == 'completed' && contentId != null) {
        completedContentIds.add(contentId);
      }
    }

    // 3. Critical fallback: progress_data.completed array (always present and up-to-date in backend)
    final progressData = courseAttempt['progress_data'];
    if (progressData is Map<String, dynamic>) {
      final completedList = progressData['completed'];
      if (completedList is List) {
        for (final id in completedList) {
          if (id != null) {
            completedContentIds.add(id.toString());
          }
        }
      }
    }
  }

  // Return updated user model with progress injected
  return user.copyWith(
    courseProgress: courseProgress,
    completedContentIds: completedContentIds,
  );
});
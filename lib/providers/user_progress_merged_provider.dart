// lib/providers/user_progress_merged_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import 'user_provider.dart';
import '../core/services/api_service.dart';

/// ── Global user progress provider (family) ─────────────────────
/// Fetches all progress entries for a given userId from /user_progress?user_id=...
final userProgressProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, userId) async {
  final api = ref.read(apiServiceProvider);

  try {
    final response = await api.get(
      '/user_progress',
      query: {'user_id': userId.toString()},
    );

    if (response['success'] == true) {
      final data = response['data'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    }

    debugPrint('user_progress API failed: ${response['message']}');
    return [];
  } catch (e) {
    debugPrint('Error fetching global user progress for user $userId: $e');
    return [];
  }
});

/// ── FINAL MERGED PROVIDER: Current user + progress ─────────────────────
/// Combines currentUserProvider (basic profile) with userProgressProvider (progress data)
///
/// Benefits of the update:
/// - Depends on currentUserProvider (which now uses authStateProvider)
/// - Automatically refreshes when the user logs out/in (thanks to authStateProvider)
/// - No stale progress data from previous user after logout/login
final userWithProgressProvider = FutureProvider<UserModel?>((ref) async {
  // Watch currentUserProvider – it will be null when not logged in
  final userAsync = ref.watch(currentUserProvider);

  if (userAsync is AsyncLoading || userAsync is AsyncError) {
    // Propagate loading/error state
    return null;
  }

  final user = userAsync.value;

  if (user == null) {
    debugPrint("userWithProgressProvider: No logged-in user");
    return null;
  }

  final userId = user.id;

  // Fetch progress for this user
  final globalProgressList = await ref.watch(userProgressProvider(userId).future);

  final Map<String, double> courseProgress = {};
  final Set<String> completedContentIds = <String>{};

  for (final p in globalProgressList) {
    final courseId = p['course_id']?.toString();
    final contentId = p['content_id']?.toString();
    final progressPercentage = double.tryParse(p['progress_percentage']?.toString() ?? '0') ?? 0.0;
    final isCompleted = p['completed'] == 1 || p['completed'] == true;

    if (contentId != null && isCompleted) {
      completedContentIds.add(contentId);
    }

    if (courseId != null) {
      courseProgress[courseId] = (progressPercentage / 100.0).clamp(0.0, 1.0);
    }
  }

  // Merge progress into the user model
  return user.copyWith(
    courseProgress: courseProgress,
    completedContentIds: completedContentIds,
  );
});
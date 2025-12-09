// lib/providers/user_progress_merged_provider.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'user_provider.dart';
import '../core/services/api_service.dart';

/// Global progress (fast, for My Courses list, dashboard etc.)
final userProgressProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, userId) async {
  final api = ref.read(apiServiceProvider);
  try {
    final response = await api.get('/user_progress', query: {'user_id': userId.toString()});
    if (response['success'] == true) {
      final data = response['data'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    }
    debugPrint('user_progress API failed: ${response['message']}');
    return [];
  } catch (e) {
    debugPrint('Error fetching global user progress: $e');
    return [];
  }
});

/// FINAL MERGED PROVIDER: Current user + progress
final userWithProgressProvider = FutureProvider<UserModel>((ref) async {
  final userAsync = await ref.watch(currentUserProvider.future);
  if (userAsync == null) throw Exception("User not logged in");

  final userId = userAsync.id;
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

  return userAsync.copyWith(
    courseProgress: courseProgress,
    completedContentIds: completedContentIds,
  );
});
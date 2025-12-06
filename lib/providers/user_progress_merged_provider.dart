// lib/providers/user_progress_merged_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'user_provider.dart';
import 'course_providers.dart';

final userWithProgressProvider = FutureProvider<UserModel>((ref) async {
  final userAsync = await ref.watch(currentUserProvider.future);
  if (userAsync == null) throw Exception("User not logged in");

  final userId = userAsync.id;

  // Fetch all progress entries
  final progressList = await ref.watch(userProgressProvider(userId).future);

  final Map<String, double> courseProgress = {};
  final Set<String> completedContentIds = {};

  for (final p in progressList) {
    final courseId = p['course_id']?.toString();
    final contentId = p['content_id']?.toString();
    final progressVal = double.tryParse(p['progress_percentage']?.toString() ?? '0') ?? 0.0;
    final completed = p['completed'] == 1 || p['completed'] == true;

    if (contentId != null && completed) {
      completedContentIds.add(contentId);
    }

    if (courseId != null) {
      final current = courseProgress[courseId] ?? 0.0;
      courseProgress[courseId] = (progressVal / 100.0).clamp(0.0, 1.0);
      if (progressVal > current * 100) {
        courseProgress[courseId] = progressVal / 100.0;
      }
    }
  }

  return userAsync.copyWith(
    courseProgress: courseProgress,
    completedContentIds: completedContentIds,
  );
});
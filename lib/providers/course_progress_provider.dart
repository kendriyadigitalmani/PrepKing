// lib/providers/course_progress_provider.dart
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

/// Updated preciseCourseProgressProvider
/// Reliably detects enrollment based on whether 'data' array has entries
/// Returns a consistent map with:
///   'isEnrolled': bool            → true if user has an active course attempt
///   'progress_percentage': double → current progress (0.0 if not enrolled)
///   'completed': List<int>        → list of completed content IDs
final preciseCourseProgressProvider = FutureProvider.family<Map<String, dynamic>, (int, int)>(
      (ref, params) async {
    final courseId = params.$1;
    final userId = params.$2;
    final api = ref.read(apiServiceProvider);

    try {
      final response = await api.get(
        '/course/$courseId/progress',
        query: {'userid': userId.toString()},
      );

      // Safely extract the data list
      final dataList = response['data'] as List? ?? [];
      final bool isEnrolled = dataList.isNotEmpty;

      if (!isEnrolled) {
        return {
          'isEnrolled': false,
          'progress_percentage': 0.0,
          'completed': <int>[],
        };
      }

      // When enrolled, extract from top-level 'progress' object
      final progress = response['progress'] as Map<String, dynamic>? ?? {};

      final double progressPercentage = double.tryParse(
        progress['progress_percentage']?.toString() ?? '0',
      ) ??
          0.0;

      final List<int> completed = (progress['completed'] as List?)
          ?.map((e) => int.tryParse(e.toString()) ?? 0)
          .where((id) => id > 0)
          .toList() ??
          <int>[];

      return {
        'isEnrolled': true,
        'progress_percentage': progressPercentage,
        'completed': completed,
      };
    } catch (e) {
      debugPrint('Error fetching precise progress for course $courseId, user $userId: $e');
      // On any error, assume not enrolled to avoid false positives
      return {
        'isEnrolled': false,
        'progress_percentage': 0.0,
        'completed': <int>[],
      };
    }
  },
);
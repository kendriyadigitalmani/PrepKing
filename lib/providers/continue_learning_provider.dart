// lib/providers/continue_learning_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';
import 'package:flutter/foundation.dart'; // for debugPrint

final continueLearningProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
      (ref, userId) async {
    // Keep alive to avoid refetching when navigating back
    ref.keepAlive();

    final api = ref.read(apiServiceProvider);

    try {
      final response = await api.get(
        '/user_progress/$userId',
        query: {'type': 'course'},
      );

      if (response['success'] == true && response['data'] is List) {
        final rawList = (response['data'] as List).cast<Map<String, dynamic>>();

        return rawList.map((e) {
          // Extract nested course data if present (adjust field names as per your API)
          final courseData = e['courses'] as Map<String, dynamic>? ?? {};

          return {
            // Normalized consistent keys
            'course_id': e['course_quiz_id'], // ← Actual course ID (used for navigation)
            'title': courseData['title'] ?? e['title'] ?? 'Untitled Course',
            'course_image': courseData['thumbnail'] ?? courseData['course_image'] ?? '',
            'progress_percentage': double.tryParse(
              e['progress_percentage']?.toString() ?? '0',
            ) ??
                0.0,

            // Optional: keep original fields if needed elsewhere
            // 'progress_id': e['id'],
            // 'course_quiz_id': e['course_quiz_id'],
            // 'raw_courses': courseData,
          };
        }).where((item) {
          final progress = item['progress_percentage'] as double;
          return progress > 0 && progress < 100; // Only in-progress courses
        }).toList();
      } else {
        debugPrint('continueLearningProvider: API success=false or invalid data');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('continueLearningProvider error for user $userId: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  },
);
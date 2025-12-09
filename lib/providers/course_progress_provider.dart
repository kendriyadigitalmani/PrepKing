// lib/providers/course_progress_provider.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

/// THIS IS THE CORRECT ONE — matches your real backend endpoint
final preciseCourseProgressProvider = FutureProvider.family<Map<String, dynamic>?, (int, int)>(
      (ref, params) async {
    final courseId = params.$1;
    final userId = params.$2;

    final api = ref.read(apiServiceProvider);

    try {
      final response = await api.get(
        '/course/$courseId/progress',
        query: {'userid': userId.toString(), 'courseid': courseId.toString()},
      );

      if (response['success'] == true && response['data'] is List && (response['data'] as List).isNotEmpty) {
        return (response['data'] as List).first as Map<String, dynamic>;
      }
      return null; // Not enrolled
    } catch (e) {
      debugPrint('Error fetching precise progress: $e');
      return null;
    }
  },
);
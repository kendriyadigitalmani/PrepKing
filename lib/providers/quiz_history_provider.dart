// lib/providers/quiz_history_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

final quizHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, userId) async {
  final api = ref.read(apiServiceProvider);

  try {
    final res = await api.get('/quiz_attempt', query: {'user_id': userId.toString()});
    final List<dynamic> rawAttempts = res['data'] ?? [];

    final List<Map<String, dynamic>> history = [];

    // Batch fetch quiz titles to reduce API calls
    final Set<int> quizIds = rawAttempts
        .map((a) => a['course_quiz_id'])
        .whereType<int>()
        .toSet();

    // Map of quiz_id -> title
    final Map<int, String> quizTitles = {};

    if (quizIds.isNotEmpty) {
      for (final id in quizIds) {
        try {
          final quizRes = await api.get('/course_quiz/$id');
          final data = quizRes['data'];
          if (data != null && data is Map) {
            quizTitles[id] = data['title']?.toString() ?? 'Untitled Quiz';
          }
        } catch (e) {
          quizTitles[id] = 'Untitled Quiz';
        }
      }
    }

    for (var attempt in rawAttempts) {
      final map = Map<String, dynamic>.from(attempt);
      final quizId = map['course_quiz_id'] as int?;

      map['quiz_title'] = quizId != null
          ? (quizTitles[quizId] ?? 'Untitled Quiz')
          : (map['type'] == 'course' ? 'Course Quiz' : 'Practice Quiz');

      // Additional helpful fields
      map['display_score'] = map['status'] == 'completed'
          ? '${map['obtained_marks'] ?? '0'} / ${map['total_marks'] ?? '?'}'
          : 'In Progress';

      map['display_date'] = map['completed_at']?.toString().split(' ').first
          ?? map['started_at']?.toString().split(' ').first
          ?? 'Unknown Date';

      history.add(map);
    }

    // Sort by most recent first
    history.sort((a, b) {
      final dateA = a['completed_at'] ?? a['started_at'] ?? '';
      final dateB = b['completed_at'] ?? b['started_at'] ?? '';
      return dateB.compareTo(dateA);
    });

    return history;
  } catch (e) {
    throw Exception('Failed to load quiz history');
  }
});
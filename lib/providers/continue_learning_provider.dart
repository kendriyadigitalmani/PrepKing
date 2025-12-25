// New file: lib/providers/continue_learning_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

final continueLearningProvider =
FutureProvider.family<List<Map<String, dynamic>>, int>((ref, userId) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get(
    '/user_progress/$userId',
    query: {'type': 'course'},
  );
  if (response['success'] == true && response['data'] is List) {
    return (response['data'] as List)
        .cast<Map<String, dynamic>>()
        .where((e) =>
    (double.tryParse(e['progress_percentage']?.toString() ?? '0') ?? 0) <
        100)
        .toList();
  }
  return [];
});
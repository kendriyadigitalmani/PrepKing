// lib/providers/exam_provider.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

/// Provides the list of all available exams from the server
/// Endpoint: GET /exam/all
/// Response: {"success": true, "data": [...], "count": 10}
final examsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    final response = await api.get('/exam/all');
    final List<dynamic> rawList = response['data'] ?? [];
    return rawList.cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('examsProvider error: $e');
    rethrow;
  }
});
// lib/providers/language_provider.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

/// Provides the list of all available languages from the server
/// Endpoint: GET /language/all
/// Response: {"success": true, "data": [...], "count": 10}
final languagesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    final response = await api.get('/language/all');
    final List<dynamic> rawList = response['data'] ?? [];
    return rawList.cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('languagesProvider error: $e');
    rethrow;
  }
});
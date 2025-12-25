// lib/providers/certificate_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

final certificatesProvider = FutureProvider.family<List<dynamic>, int>((ref, userId) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get('/certificate', query: {'user_id': userId.toString()});
  return res['data'] ?? [];
});
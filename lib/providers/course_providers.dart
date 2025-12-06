import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';

final apiServiceProvider = Provider((ref) => ApiService());

final classesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get('/class');
  return res['data'] ?? [];
});

final coursesProvider = FutureProvider.family<List<dynamic>, int>((ref, classId) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get('/course?class_id=$classId');
  return res['data'] ?? [];
});

final courseDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, courseId) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get('/course/$courseId');
  return res['data'] ?? {};
});

final contentListProvider = FutureProvider.family<List<dynamic>, int>((ref, courseId) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get('/content/course/$courseId');
  return res['data'] ?? [];
});

final userProgressProvider = FutureProvider.family<List<dynamic>, int>((ref, userId) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get('/user_progress?user_id=$userId');
  return res['data'] ?? [];
});
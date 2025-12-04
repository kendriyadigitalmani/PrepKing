// lib/providers/quiz_attempts_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';
import 'user_provider.dart';

/// 📋 Provider for all quiz attempts
final quizAttemptsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, quizId) async {
  // Watch user provider properly to handle loading states
  final userAsync = ref.watch(currentUserProvider);

  // Handle loading/error states gracefully
  if (!userAsync.hasValue || userAsync.value == null) {
    throw Exception('User not authenticated');
  }

  final user = userAsync.value!;
  final api = ref.read(apiServiceProvider);

  return api.getQuizAttempts(
    courseQuizId: quizId,
    userId: user.id,
  );
});

/// 🎯 Provider for latest quiz attempt
final latestQuizAttemptProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, quizId) async {
  final userAsync = ref.watch(currentUserProvider);

  if (!userAsync.hasValue || userAsync.value == null) {
    throw Exception('User not authenticated');
  }

  final user = userAsync.value!;
  final api = ref.read(apiServiceProvider);

  return api.getLatestQuizAttempt(
    courseQuizId: quizId,
    userId: user.id,
  );
});

/// 🔄 Provider for in-progress attempts (bonus)
final inProgressAttemptsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, quizId) async {
  final userAsync = ref.watch(currentUserProvider);

  if (!userAsync.hasValue || userAsync.value == null) {
    throw Exception('User not authenticated');
  }

  final user = userAsync.value!;
  final api = ref.read(apiServiceProvider);

  return api.getInProgressAttempts(
    courseQuizId: quizId,
    userId: user.id,
  );
});
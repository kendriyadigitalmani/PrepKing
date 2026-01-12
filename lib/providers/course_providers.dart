// lib/providers/course_providers.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

import '../core/services/api_service.dart';
import 'user_provider.dart'; // ← Make sure this is imported (for currentUserProvider)

/// Safe parsing helper for double values from API (handles String, int, double, null)
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

/// Fetch the full list of courses (used by Course List Screen & Continue Learning)
/// Now properly extracts progress_percentage and completed_content_ids from backend
final courseListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    debugPrint('Fetching course list via /course');
    final response = await api.get('/course');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load courses');
    }
    final rawData = response['data'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> courses = [];
    for (final item in rawData) {
      final course = Map<String, dynamic>.from(item as Map);
      final progressMap = course['progress'] as Map<String, dynamic>? ?? {};
      // Extract and normalize progress fields from backend
      final double progressPercentage = _parseDouble(progressMap['progress_percentage']);
      final List<int> completedContentIds = (progressMap['completed'] as List<dynamic>?)
          ?.map((e) => int.tryParse(e.toString()) ?? 0)
          .where((id) => id > 0)
          .toList() ??
          [];
      // Attach normalized progress to course map for easy access everywhere
      courses.add({
        ...course,
        'progress_percentage': progressPercentage,
        'completed_content_ids': completedContentIds,
      });
    }
    debugPrint('Successfully loaded ${courses.length} course(s) with progress');
    return courses;
  } on DioException catch (e) {
    debugPrint('DioException in courseListProvider: ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('Error in courseListProvider: $e');
    rethrow;
  }
});

/// Fetch a single course detail by ID (used by CourseDetailScreen & ContentListScreen)
/// Now includes normalized progress fields + autoDispose for memory safety
/// → Critical fix: Passes current userid in query params so backend returns correct progress
final courseDetailProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, int>((ref, courseId) async {
  final userAsync = ref.watch(currentUserProvider);
  final userId = userAsync.value?.id;

  final api = ref.read(apiServiceProvider);
  try {
    debugPrint('Fetching course detail for ID: $courseId with userid: $userId');
    final response = await api.get(
      '/course/$courseId',
      query: userId != null ? {'userid': userId.toString()} : null,
    );

    if (response['success'] != true) {
      final message = response['message'] ?? 'Unknown error';
      throw Exception('Failed to load course: $message');
    }

    final data = Map<String, dynamic>.from(response['data'] ?? {});
    final progressMap = data['progress'] as Map<String, dynamic>? ?? {};

    final double progressPercentage = _parseDouble(progressMap['progress_percentage']);
    final List<int> completedContentIds = (progressMap['completed'] as List<dynamic>?)
        ?.map((e) => int.tryParse(e.toString()) ?? 0)
        .where((id) => id > 0)
        .toList() ??
        [];

    debugPrint('Course loaded: ${data['title'] ?? 'No title'} - Progress: $progressPercentage%');

    return {
      ...data,
      'progress_percentage': progressPercentage,
      'completed_content_ids': completedContentIds,
    };
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    final raw = e.response?.data;
    final msg = e.message ?? 'Network error';
    debugPrint('DioException in courseDetailProvider: $status - $msg');
    throw Exception(
      'Network Error\nStatus: $status\nMessage: $msg\nResponse: ${raw is String ? raw : jsonEncode(raw)}',
    );
  } catch (e) {
    debugPrint('Unexpected error in courseDetailProvider: $e');
    rethrow;
  }
});

/// Fetch all contents (lessons) for a course
/// Now includes per-content progress_percentage and is_completed flag + autoDispose
final courseContentsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, int>((ref, courseId) async {
  final api = ref.read(apiServiceProvider);
  try {
    debugPrint('Fetching contents for course ID: $courseId');
    final response = await api.get('/course/$courseId/contents');
    if (response['success'] != true) {
      debugPrint('Contents API failed: ${response['message']}');
      return [];
    }
    final rawData = response['data'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> contents = [];
    for (final item in rawData) {
      final content = Map<String, dynamic>.from(item as Map);
      final progressMap = content['progress'] as Map<String, dynamic>? ?? {};
      final double contentProgress = _parseDouble(progressMap['progress_percentage']);
      final bool isCompleted = contentProgress >= 100.0;
      contents.add({
        ...content,
        'progress_percentage': contentProgress,
        'is_completed': isCompleted,
      });
    }
    debugPrint('Successfully loaded ${contents.length} content item(s) with progress');
    return contents;
  } on DioException catch (dioError) {
    final statusCode = dioError.response?.statusCode;
    final rawBody = dioError.response?.data;
    final errorMsg = dioError.message;
    debugPrint('DioException while fetching course contents: $statusCode - $errorMsg');
    throw Exception(
      'Failed to load lessons\n\nStatus: $statusCode\nError: $errorMsg\nResponse: ${rawBody is String ? rawBody : jsonEncode(rawBody)}',
    );
  } catch (e) {
    debugPrint('Unexpected error in courseContentsProvider: $e');
    rethrow;
  }
});

// Existing providers (kept intact)
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
// lib/providers/course_providers.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../core/services/api_service.dart';

/// Fetch a single course detail by ID
final courseDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, courseId) async {
  final api = ref.read(apiServiceProvider);

  try {
    debugPrint('Fetching course detail for ID: $courseId');
    final response = await api.get('/course/$courseId');

    if (response['success'] == true) {
      final data = Map<String, dynamic>.from(response['data'] ?? {});
      debugPrint('Course loaded successfully: ${data['title'] ?? 'No title'}');
      return data;
    }

    // API returned error
    final message = response['message'] ?? 'Unknown error';
    final raw = jsonEncode(response);
    debugPrint('courseDetailProvider API failed → $message');
    debugPrint('Raw response: $raw');

    throw Exception('Failed to load course\n\n$message\n\nRaw: $raw');
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    final raw = e.response?.data;
    final msg = e.message ?? 'Network error';

    debugPrint('DioException in courseDetailProvider: $status - $msg');
    debugPrint('Raw response: $raw');

    throw Exception(
      'Network Error\n'
          'Status: $status\n'
          'Message: $msg\n'
          'Response: ${raw is String ? raw : jsonEncode(raw)}',
    );
  } catch (e) {
    debugPrint('Unexpected error in courseDetailProvider: $e');
    rethrow;
  }
});

/// Fetch all contents (lessons) for a course
final courseContentsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, courseId) async {
  final api = ref.read(apiServiceProvider);

  try {
    debugPrint('Fetching contents for course ID: $courseId');
    final response = await api.get('/course/$courseId/contents');

    if (response['success'] == true) {
      final rawData = response['data'] ?? [];
      final contents = List<Map<String, dynamic>>.from(rawData);
      debugPrint('Successfully loaded ${contents.length} lesson(s)');
      return contents;
    }

    final message = response['message'] ?? 'Unknown error';
    final rawResponse = jsonEncode(response);
    debugPrint('Contents API failed → $message');
    debugPrint('Raw API Response: $rawResponse');
    return [];
  } on DioException catch (dioError) {
    final statusCode = dioError.response?.statusCode;
    final rawBody = dioError.response?.data;
    final errorMsg = dioError.message;

    debugPrint('DioException while fetching course contents:');
    debugPrint('Status: $statusCode | Message: $errorMsg');
    debugPrint('Raw Response Body: $rawBody');

    throw Exception(
      'Failed to load lessons\n\n'
          'Status: $statusCode\n'
          'Error: $errorMsg\n'
          'Response: ${rawBody is String ? rawBody : jsonEncode(rawBody)}',
    );
  } catch (e) {
    debugPrint('Unexpected error in courseContentsProvider: $e');
    rethrow;
  }
});

// Optional: Keep other providers you already had
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
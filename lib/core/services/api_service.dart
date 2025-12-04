// lib/core/services/api_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

final apiServiceProvider = Provider((ref) => ApiService());

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl, // This already includes /api_002.php
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  ApiService() {
    _dio.interceptors.add(LogInterceptor(
      responseBody: true,
      requestBody: true,
      logPrint: (obj) => debugPrint(obj.toString()),
    ));
  }

  // ✅ FIXED: Generic GET - Use clean endpoints WITHOUT /api_002.php
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, dynamic>? query}) async {
    try {
      // Remove leading slash for cleaner logs
      final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
      debugPrint('🔍 GET Request: $cleanEndpoint ${query != null ? '?${Uri(queryParameters: query).query}' : ''}');

      final response = await _dio.get(endpoint, queryParameters: query);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ GET Error [$endpoint]: $e');
      rethrow;
    }
  }

  // ✅ Generic POST - Clean endpoints
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      debugPrint('📤 POST Request: $endpoint');
      debugPrint('📤 POST Data: ${jsonEncode(data)}');

      final response = await _dio.post(endpoint, data: data);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ POST Error [$endpoint]: $e');
      rethrow;
    }
  }

  // ✅ Generic PUT
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ PUT Error [$endpoint]: $e');
      rethrow;
    }
  }

  // ✅ Generic DELETE
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ DELETE Error [$endpoint]: $e');
      rethrow;
    }
  }

  /// 🚀 FIXED: Fetch quiz attempts - CORRECT ENDPOINT
  Future<List<Map<String, dynamic>>> getQuizAttempts({
    required int courseQuizId,
    required int userId,
  }) async {
    try {
      debugPrint('🔍 Fetching quiz attempts for quiz: $courseQuizId, user: $userId');

      // ✅ CORRECT: Use /quiz_attempt (NOT /api_002.php/quiz_attempt)
      final response = await get(
        '/quiz_attempt',  // ← FIXED: Clean endpoint
        query: {
          'course_quiz_id': courseQuizId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (response['success'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        final attempts = data.cast<Map<String, dynamic>>();
        debugPrint('✅ Found ${attempts.length} attempts');
        return attempts;
      }
      debugPrint('⚠️ No attempts found or API error: ${response['message']}');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching quiz attempts: $e');
      return [];
    }
  }

  /// 🚀 Get the latest attempt
  Future<Map<String, dynamic>?> getLatestQuizAttempt({
    required int courseQuizId,
    required int userId,
  }) async {
    try {
      final attempts = await getQuizAttempts(
        courseQuizId: courseQuizId,
        userId: userId,
      );
      if (attempts.isEmpty) {
        debugPrint('ℹ️ No attempts found for quiz $courseQuizId');
        return null;
      }
      final latestAttempt = attempts.reduce((a, b) {
        final idA = a['id'] as int;
        final idB = b['id'] as int;
        return idA > idB ? a : b;
      });
      debugPrint('🎯 Latest attempt found: ID ${latestAttempt['id']}, '
          'Attempt #${latestAttempt['attempt_number']}, '
          'Status: ${latestAttempt['status']}');
      return latestAttempt;
    } catch (e) {
      debugPrint('❌ Error getting latest quiz attempt: $e');
      return null;
    }
  }

  /// 🚀 Get in-progress attempts
  Future<List<Map<String, dynamic>>> getInProgressAttempts({
    required int courseQuizId,
    required int userId,
  }) async {
    try {
      final attempts = await getQuizAttempts(courseQuizId: courseQuizId, userId: userId);
      final inProgress = attempts.where((attempt) => attempt['status'] == 'in_progress').toList();
      debugPrint('🔄 Found ${inProgress.length} in-progress attempts');
      return inProgress;
    } catch (e) {
      debugPrint('❌ Error getting in-progress attempts: $e');
      return [];
    }
  }

  /// 🚀 Update quiz attempt
  Future<Map<String, dynamic>> updateQuizAttempt({
    required int attemptId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final payload = {'status': status, ...?additionalData};
      final response = await put('/quiz_attempt/$attemptId', payload);
      debugPrint('✅ Updated attempt $attemptId to status: $status');
      return response;
    } catch (e) {
      debugPrint('❌ Error updating quiz attempt $attemptId: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _handleResponse(Response response) {
    final data = response.data is String ? jsonDecode(response.data) : response.data;

    // ✅ Log full response for debugging
    debugPrint('📥 Response: ${jsonEncode(data)}');

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response format');
    }

    // ✅ Don't throw error for "Resource not found" - treat as empty result
    if (data['success'] == false) {
      final message = data['message'] ?? 'Unknown API Error';
      if (message == 'Resource not found') {
        debugPrint('ℹ️ Resource not found (expected for new quizzes): $message');
        return {'success': true, 'data': []}; // ✅ Return empty array instead of error
      }
      throw Exception('API Error: $message');
    }

    return data;
  }
}
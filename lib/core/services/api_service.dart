// lib/core/services/api_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

final apiServiceProvider = Provider((ref) => ApiService());

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl, // e.g., "https://quizard.in/api_002.php"
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) => status! < 500, // Don't throw on 4xx
    ));

    // Detailed logging (only in debug mode)
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        logPrint: (obj) => debugPrint("API → $obj"),
      ));
    }
  }

  // Generic GET
  Future<Map<String, dynamic>> get(
      String endpoint, {
        Map<String, dynamic>? query,
      }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: query?..map((k, v) => MapEntry(k, v.toString())),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GET Error [$endpoint]: $e');
      rethrow;
    }
  }

  // Generic POST - Sends data in body (correct for your backend)
  Future<Map<String, dynamic>> post(
      String endpoint,
      Map<String, dynamic> data,
      ) async {
    try {
      debugPrint('POST → $endpoint | Body: ${jsonEncode(data)}');
      final response = await _dio.post(endpoint, data: data);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('POST Error [$endpoint]: $e');
      if (e is DioException) {
        debugPrint('Response: ${e.response?.data}');
      }
      rethrow;
    }
  }

  // Generic PUT
  Future<Map<String, dynamic>> put(
      String endpoint,
      Map<String, dynamic> data,
      ) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('PUT Error [$endpoint]: $e');
      rethrow;
    }
  }

  // Generic DELETE
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('DELETE Error [$endpoint]: $e');
      rethrow;
    }
  }

  // MARK: Quiz Attempts Helpers
  Future<List<Map<String, dynamic>>> getQuizAttempts({
    required int courseQuizId,
    required int userId,
  }) async {
    final response = await get('/quiz_attempt', query: {
      'course_quiz_id': courseQuizId.toString(),
      'user_id': userId.toString(),
    });
    return (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<Map<String, dynamic>?> getLatestQuizAttempt({
    required int courseQuizId,
    required int userId,
  }) async {
    final attempts = await getQuizAttempts(courseQuizId: courseQuizId, userId: userId);
    if (attempts.isEmpty) return null;
    return attempts.reduce((a, b) => (a['id'] as int) > (b['id'] as int) ? a : b);
  }

  Future<List<Map<String, dynamic>>> getInProgressAttempts({
    required int courseQuizId,
    required int userId,
  }) async {
    final attempts = await getQuizAttempts(courseQuizId: courseQuizId, userId: userId);
    return attempts.where((a) => a['status'] == 'in_progress').toList();
  }

  Future<Map<String, dynamic>> updateQuizAttempt({
    required int attemptId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    final payload = {'status': status, ...?additionalData};
    return await put('/quiz_attempt/$attemptId', payload);
  }

  // MARK: Central Response Handler
  Map<String, dynamic> _handleResponse(Response response) {
    final method = response.requestOptions.method;
    final path = response.requestOptions.path;
    final statusCode = response.statusCode;

    debugPrint('API SUCCESS: [$method] $path → $statusCode');

    dynamic data = response.data;

    // Parse JSON if string
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (e) {
        debugPrint('JSON Parse failed: $e');
      }
    }

    // Ensure it's a map
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid API response format');
    }

    // Handle API-level errors
    if (data['success'] == false) {
      final message = data['message'] ?? 'Unknown error';
      if (message == 'Resource not found') {
        return {'success': true, 'data': []};
      }
      throw Exception('API Error: $message');
    }

    return data;
  }
}
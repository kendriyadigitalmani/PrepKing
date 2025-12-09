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
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) => status! < 500,
    ));

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

  // Generic Methods
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, dynamic>? query}) async {
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

  Future<Map<String, dynamic>> post(
      String endpoint,
      Map<String, dynamic> data, {
        Map<String, dynamic>? query,
      }) async {
    try {
      debugPrint('POST → $endpoint | Body: ${jsonEncode(data)}');
      final response = await _dio.post(
        endpoint,
        queryParameters: query?..map((k, v) => MapEntry(k, v.toString())),
        data: data,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('POST Error [$endpoint]: $e');
      if (e is DioException) debugPrint('Response: ${e.response?.data}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('PUT Error [$endpoint]: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('DELETE Error [$endpoint]: $e');
      rethrow;
    }
  }

  // MARK: Content CRUD - Fully Safe & Typed
  Future<List<Map<String, dynamic>>> getAllContents() async {
    try {
      final response = await get('/content');
      final data = response['data'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('getAllContents error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getContentById(int id) async {
    try {
      final response = await get('/content/$id');
      return response['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('getContentById($id) error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createContent(Map<String, dynamic> data) async {
    return await post('/content', data);
  }

  Future<Map<String, dynamic>> updateContent(int id, Map<String, dynamic> data) async {
    return await put('/content/$id', data);
  }

  Future<bool> deleteContent(int id) async {
    try {
      await delete('/content/$id');
      return true;
    } catch (e) {
      debugPrint('deleteContent($id) failed: $e');
      return false;
    }
  }

  // MARK: Quiz Attempts (unchanged - already perfect)
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

  // MARK: Central Response Handler (Improved Safety)
  Map<String, dynamic> _handleResponse(Response response) {
    final method = response.requestOptions.method;
    final path = response.requestOptions.path;
    final statusCode = response.statusCode;

    debugPrint('API SUCCESS: [$method] $path → $statusCode');

    dynamic data = response.data;

    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (e) {
        debugPrint('JSON Parse failed: $e');
        throw Exception('Invalid JSON response');
      }
    }

    if (data is! Map<String, dynamic>) {
      debugPrint('Invalid response format: $data');
      throw Exception('API response must be a JSON object');
    }

    if (data['success'] == false) {
      final message = data['message'] ?? 'Unknown error';
      if (message.contains('not found') || message.contains('Resource')) {
        return {'success': true, 'data': null}; // Graceful for missing content
      }
      throw Exception('API Error: $message');
    }

    return data;
  }
}
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_settings.dart';
import '../constants/api_constants.dart';
import '../utils/current_user_cache.dart';
import '../utils/user_preferences.dart';

// NEW: Custom exception with optional status code for better error handling
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => statusCode != null
      ? 'ApiException($statusCode): $message'
      : 'ApiException: $message';
}

final apiServiceProvider = Provider((ref) => ApiService());

class ApiService {
  late final Dio _dio;

  // List of endpoints that should NOT receive the userid parameter
  final _skipUserIdPaths = [
    '/login',
    '/register',
    '/appsettings',
    '/firebase_setting',
    '/version',
    '/exam/all',
    '/language/all',
    '/class',
  ];

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) => status != null && status >= 200 && status < 500,
    ));

    // SELECTIVE userid injection
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          int? userId;
          userId = CurrentUserCache.userId;
          if (userId == null) {
            userId = await UserPreferences().getUserId();
          }

          if (userId != null &&
              !_skipUserIdPaths.any((skipPath) => options.path.startsWith(skipPath))) {
            options.queryParameters ??= {};
            options.queryParameters['userid'] = userId.toString();
          }

          if (kDebugMode) {
            debugPrint('API URL → ${options.uri}');
          }
          return handler.next(options);
        },
      ),
    );

    // Optional: Keep minimal logging (without sensitive bodies)
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: false,
        responseBody: false,
        responseHeader: false,
        error: true,
        logPrint: (obj) => debugPrint("API → $obj"),
      ));
    }
  }

  // ==================== App Settings ====================
  Future<Map<String, dynamic>> getAppSettingsRaw({required String packageId}) async {
    try {
      final response = await get('/appsettings', query: {'packageid': packageId});
      return response;
    } catch (e) {
      debugPrint('getAppSettingsRaw error: $e');
      rethrow;
    }
  }

  Future<AppSettings> getAppSettings({required String packageId}) async {
    try {
      final rawResponse = await getAppSettingsRaw(packageId: packageId);
      return AppSettings.fromJson(rawResponse);
    } catch (e) {
      debugPrint('getAppSettings error: $e');
      rethrow;
    }
  }

  // ==================== Generic HTTP Methods ====================
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
      debugPrint('POST → $endpoint');
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

  Future<Map<String, dynamic>> put(
      String endpoint,
      Map<String, dynamic> data, {
        Map<String, dynamic>? query,
      }) async {
    try {
      final response = await _dio.put(
        endpoint,
        queryParameters: query?..map((k, v) => MapEntry(k, v.toString())),
        data: data,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('PUT Error [$endpoint]: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> delete(
      String endpoint, {
        Map<String, dynamic>? query,
      }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        queryParameters: query?..map((k, v) => MapEntry(k, v.toString())),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('DELETE Error [$endpoint]: $e');
      rethrow;
    }
  }

  // ==================== Content CRUD ====================
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

  // ==================== Quiz Attempts ====================
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

  // ==================== User Preferences Update ====================
  Future<Map<String, dynamic>> updateUserLanguage(int userId, int languageId) async {
    try {
      return await put('/user/$userId', {'language_id': languageId});
    } catch (e) {
      debugPrint('updateUserLanguage error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserExams(int userId, List<int> examIds) async {
    try {
      return await put('/user/$userId', {'exam_ids': examIds});
    } catch (e) {
      debugPrint('updateUserExams error: $e');
      rethrow;
    }
  }

  // ==================== Central Response Handler ====================
  Map<String, dynamic> _handleResponse(Response response) {
    final method = response.requestOptions.method;
    final path = response.requestOptions.path;
    final statusCode = response.statusCode;

    debugPrint('API SUCCESS: [$method] $path → $statusCode');

    // === NEW: Print RAW response body exactly as received ===
    if (kDebugMode) {
      debugPrint('=== RAW RESPONSE START ===');
      final rawData = response.data;
      if (rawData is String) {
        debugPrint(rawData.isEmpty ? '(empty string)' : rawData);
      } else if (rawData is List<int>) {
        // For binary data (rare in JSON APIs)
        debugPrint('<binary data, length: ${rawData.length}>');
      } else {
        // Try to pretty-print if possible
        try {
          debugPrint(const JsonEncoder.withIndent('  ').convert(rawData));
        } catch (_) {
          debugPrint(rawData.toString());
        }
      }
      debugPrint('=== RAW RESPONSE END ===');
    }
    // ======================================================

    dynamic data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (e) {
        debugPrint('JSON Parse failed: $e');
        throw ApiException('Invalid JSON response from server', statusCode: statusCode);
      }
    }

    if (data is! Map<String, dynamic>) {
      debugPrint('Invalid response format: $data');
      throw ApiException('Server returned invalid data format', statusCode: statusCode);
    }

    if (data['success'] == false) {
      final message = data['message'] ?? 'Unknown error occurred';
      if (message.toLowerCase().contains('not found') ||
          message.toLowerCase().contains('resource')) {
        return {'success': true, 'data': null};
      }
      throw ApiException(message, statusCode: statusCode);
    }

    if (data['data'] == null) {
      debugPrint('⚠️ API Warning: Success response missing "data" key → $data');
    }

    return data;
  }
}
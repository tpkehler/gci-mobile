import 'package:dio/dio.dart';

import '../core/config.dart';

/// Thin Dio wrapper: base URL, JSON defaults, and a JWT Bearer interceptor.
///
/// The token is provided by a callback so the client always reads the current
/// session without holding auth state itself.
class ApiClient {
  ApiClient({String? Function()? tokenProvider, Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
              // The API uses 4xx bodies for expected failures (e.g. 401 wrong
              // password); let callers branch on status instead of catching.
              validateStatus: (status) => status != null && status < 500,
            )) {
    if (tokenProvider != null) {
      this.dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ));
    }
  }

  final Dio dio;
}

/// Human-readable message out of a Dio error or an API error body.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'The server took too long to respond. Please try again.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check your connection.';
    }
    return 'Request failed (${error.response?.statusCode ?? 'network error'}).';
  }
  return error.toString();
}

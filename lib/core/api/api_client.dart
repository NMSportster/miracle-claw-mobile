import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/jwt_reader.dart';
import '../config/app_config.dart';

/// Holds the singleton Dio instance for the app. The auth interceptor reads
/// the JWT via a JwtReader callback to avoid a circular dependency with
/// AuthRepository (which needs Dio, which needs the reader).
class ApiClient {
  ApiClient(this._readToken)
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.defaultMaicApiUrl,
          connectTimeout: AppConfig.defaultRequestTimeout,
          receiveTimeout: AppConfig.chatRequestTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': AppConfig.userAgent,
          },
          // Important: don't throw on 4xx so the interceptor can react.
          validateStatus: (status) => status != null && status < 500,
        )) {
    dio.interceptors.add(_AuthInterceptor(_readToken));
  }

  final Dio dio;
  final JwtReader _readToken;
}

/// Provider exposing the singleton ApiClient via Riverpod.
final apiClientProvider = Provider<ApiClient>((ref) {
  final reader = ref.watch(jwtReaderProvider);
  return ApiClient(reader);
});

/// Interceptor that injects the JWT, and surfaces 4xx errors as typed
/// ApiException. Silent relogin on 401 is handled at the AuthRepository level
/// (a single refresh attempt before the call returns to the UI).
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._readToken);

  final JwtReader _readToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Typed API error. Caller can switch on [statusCode] for specific UX.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.body});
  final int? statusCode;
  final String message;
  final Object? body;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

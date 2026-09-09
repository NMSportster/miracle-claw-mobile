import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/jwt_reader.dart';
import '../config/app_config.dart';
import '../pairing/discovery_state.dart';
import '../pairing/session.dart';
import '../pairing/transport.dart';

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
  final client = ApiClient(reader);

  // Phase 3: attach the pairing interceptor so each request gets the
  // current ConnectionState's baseUrl + (when Paired) HMAC headers.
  client.dio.interceptors.add(_PairingInterceptor(ref: ref, ladder: const TransportLadder()));

  return client;
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

/// Interceptor that rewrites `baseUrl` per request from the current
/// ConnectionState (cloud MAIC vs paired desktop vs in-flight), and when
/// paired, attaches the HMAC signature headers the desktop verifies
/// (spec § "Subsequent requests").
///
/// Implementation note: we use a `Ref` directly so the interceptor can
/// read the current state synchronously without needing a context.
class _PairingInterceptor extends Interceptor {
  _PairingInterceptor({required this.ref, required this.ladder});

  final Ref ref;
  final TransportLadder ladder;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final state = ref.read(connectionStateProvider);
    options.baseUrl = ladder.pickBaseUrl(state);
    options.connectTimeout = ladder.pickConnectTimeout(state);

    if (state is Paired) {
      final body = _bodyBytes(options.data);
      final sig = await signRequestBody(session: state.session, body: body);
      options.headers['X-Miracle-Pair-Session'] =
          '${state.session.sessionId}:$sig';
      // device_id isn't stored in PairSession for v1 (see TODO in
      // pairing_service.dart); omit the device header for now.
    }
    handler.next(options);
  }

  Uint8List _bodyBytes(Object? data) {
    if (data == null) return Uint8List(0);
    if (data is String) return Uint8List.fromList(utf8.encode(data));
    if (data is List<int>) return Uint8List.fromList(data);
    return Uint8List.fromList(utf8.encode(jsonEncode(data)));
  }
}

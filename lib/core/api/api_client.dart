import 'dart:async';
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
///
/// Auth flow (2026-09-18): MAIC keeps an in-memory session registry that
/// can archive a JWT even when its `exp` is in the future. The phone
/// stores JWTs persistently (flutter_secure_storage), so any in-flight
/// 401 has to trigger a silent relogin + retry. That logic lives in
/// [_AuthInterceptor.onResponse].
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
    dio.interceptors.add(_AuthInterceptor(dio: dio, readToken: _readToken));
  }

  final JwtReader _readToken;
  final Dio dio;
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

/// Internal flag we attach to a request that has already been retried
/// after a relogin, so the interceptor doesn't loop forever.
const String _kReloginRetried = '_mcReloginRetried';

/// Interceptor that injects the JWT and, on 401, attempts one silent
/// relogin and retries the request once before surfacing the error.
///
/// Why: MAIC's session registry archives entries on its own schedule,
/// so a stored JWT can return "Session archived" even when its `exp`
/// is in the future. Curl always re-logs-in → fresh JWT → 200. The
/// phone, which stores the JWT persistently, must do the same on any
/// 401 — not just at bootstrap (which is where the original relogin
/// lived, in `AuthRepository.tryRestore`).
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({required this._dio, required this._readToken});

  final Dio _dio;
  final JwtReader _readToken;

  // Single-flight guard: when many requests fail 401 concurrently, only
  // one relogin runs and the rest wait for the fresh JWT.
  Completer<bool>? _inflightRelogin;

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

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final status = response.statusCode;
    final path = response.requestOptions.path;

    // Only handle 401. Skip the login + logout endpoints so we don't
    // infinite-loop on a bad password.
    final isAuthEndpoint = path.contains('/v1/users/login') ||
        path.contains('/v1/users/logout');

    final alreadyRetried =
        response.requestOptions.extra[_kReloginRetried] == true;

    if (status != 401 || isAuthEndpoint || alreadyRetried) {
      handler.next(response);
      return;
    }

    final ok = await _runRelogin();
    if (!ok) {
      // ignore: avoid_print
      print('[MC-AUTH] relogin failed for $path — surfacing 401');
      handler.next(response);
      return;
    }

    try {
      final fresh = await _readToken();
      // Rebuild the request: refresh the JWT, mark it so a second 401
      // surfaces instead of looping, and replay via the SAME dio so the
      // httpClientAdapter + baseUrl stay correct.
      response.requestOptions.headers['Authorization'] =
          fresh != null && fresh.isNotEmpty ? 'Bearer $fresh' : null;
      response.requestOptions.extra[_kReloginRetried] = true;

      final retryResponse = await _dio.fetch<dynamic>(response.requestOptions);
      // ignore: avoid_print
      print('[MC-AUTH] $path: relogin ok, retry status=${retryResponse.statusCode}');
      handler.resolve(retryResponse);
    } catch (e) {
      // ignore: avoid_print
      print('[MC-AUTH] $path: retry threw $e');
      handler.next(response);
    }
  }

  /// Run silentRelogin exactly once across concurrent callers.
  Future<bool> _runRelogin() {
    final inflight = _inflightRelogin;
    if (inflight != null) {
      return inflight.future;
    }

    final completer = Completer<bool>();
    _inflightRelogin = completer;
    () async {
      try {
        // Read the callback from the module-level holder (set by
        // authRepositoryProvider when it constructs AuthRepository).
        // This sidesteps the Riverpod static cycle
        // (apiClientProvider ↔ authRepositoryProvider) — the
        // interceptor never goes through Riverpod to find the
        // callback.
        final cb = getReloginCallback();
        final ok = await cb();
        completer.complete(ok);
      } catch (_) {
        completer.complete(false);
      } finally {
        _inflightRelogin = null;
      }
    }();
    return completer.future;
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
      // Spec § "Subsequent requests": X-Miracle-Pair-Device: <device_id>
      // on every paired request. Desktop uses this to associate the
      // session with a known device in its paired_devices audit table
      // and to honor per-device revocations.
      options.headers['X-Miracle-Pair-Device'] = state.session.deviceId;
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

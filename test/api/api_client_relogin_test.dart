// api_client_relogin_test.dart — verifies that ApiClient's auth interceptor
// performs a silent relogin + retry on a 401, addressing the MAIC
// session-archive bug found 2026-09-17 (commit d991316).
//
// The test stubs out:
//   - jwtReaderProvider: returns a fixed "expired" token (overridden via
//     ProviderContainer).
//   - The Dio HTTP transport: replaced with Dio's httpClientAdapter test
//     hook, returning 401 on first call, 200 on the second.
//   - The silent-relogin callback: installed via setReloginCallback()
//     directly. We don't override authRepositoryProvider because that
//     path goes through the Riverpod graph and the override would skip
//     the setReloginCallback side-effect that wires the callback in
//     production. setReloginCallback() is the same API the production
//     code uses.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miracle_claw_mobile/core/api/api_client.dart';
import 'package:miracle_claw_mobile/core/auth/jwt_reader.dart';

class _ReloginCounter {
  _ReloginCounter(this._result);
  final bool _result;
  int callCount = 0;
  Future<bool> call() async {
    callCount++;
    return _result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Clear any leftover callback from a previous test run.
    clearReloginCallbackForTest();
  });
  tearDown(() {
    clearReloginCallbackForTest();
  });

  test('401 triggers silentRelogin + retry on the same request', () async {
    // Track every Authorization header the adapter sees.
    final authHeaders = <String?>[];
    final relogin = _ReloginCounter(true);

    // Install the silent-relogin callback before constructing the API
    // client — same lifecycle as production (authRepositoryProvider
    // installs it during construction, before any 401 can fire).
    setReloginCallback(relogin.call);

    final container = ProviderContainer(overrides: [
      jwtReaderProvider.overrideWithValue(() async => 'expired-token'),
    ]);

    addTearDown(container.dispose);

    final api = container.read(apiClientProvider);

    // Override the adapter with our scriptable 401-then-200.
    api.dio.httpClientAdapter = _ScriptedAdapter(
      responses: [
        _scripted(
          401,
          body: jsonEncode({'detail': 'Session archived — please log in again'}),
        ),
        _scripted(
          200,
          body: jsonEncode({'ok': true}),
        ),
      ],
      onRequest: (req) {
        authHeaders.add(req.headers['Authorization']?.toString());
      },
    );

    final response = await api.dio.get<Map<String, dynamic>>('/v1/ping');

    expect(response.statusCode, 200);
    expect(response.data?['ok'], true);
    expect(relogin.callCount, 1,
        reason: 'silentRelogin should run exactly once on a 401');
    expect(authHeaders.length, 2,
        reason: 'first request + retry, both carrying Authorization');
    expect(authHeaders[0], 'Bearer expired-token');
    // The retry path in production re-reads the JWT from
    // flutter_secure_storage AFTER silentRelogin writes the fresh token;
    // this test stubs JwtReader to always return 'expired-token', so the
    // assertion above only verifies the relogin + retry count, not the
    // post-relogin Authorization header (covered by the production smoke
    // test on a real device).
  });

  test('relogin failure surfaces the original 401', () async {
    final relogin = _ReloginCounter(false);
    setReloginCallback(relogin.call);

    final container = ProviderContainer(overrides: [
      jwtReaderProvider.overrideWithValue(() async => 'expired-token'),
    ]);
    addTearDown(container.dispose);

    final api = container.read(apiClientProvider);
    api.dio.httpClientAdapter = _ScriptedAdapter(responses: [
      _scripted(401, body: jsonEncode({'detail': 'Session archived'})),
    ]);

    final response = await api.dio.get<Map<String, dynamic>>('/v1/ping');
    expect(response.statusCode, 401);
    expect(relogin.callCount, 1,
        reason: 'interceptor should attempt relogin on 401');
  });

  test('login endpoint 401 does NOT trigger relogin (avoids loop)',
      () async {
    final relogin = _ReloginCounter(true);
    setReloginCallback(relogin.call);

    final container = ProviderContainer(overrides: [
      jwtReaderProvider.overrideWithValue(() async => 'old-token'),
    ]);
    addTearDown(container.dispose);

    final api = container.read(apiClientProvider);
    api.dio.httpClientAdapter = _ScriptedAdapter(responses: [
      _scripted(401, body: jsonEncode({'detail': 'Invalid credentials'})),
    ]);

    final response = await api.dio.post<Map<String, dynamic>>(
        '/v1/users/login', data: {'email': 'x', 'password': 'y'});
    expect(response.statusCode, 401);
    expect(relogin.callCount, 0,
        reason: 'login failures must not loop into relogin');
  });
}

// ── Helpers ─────────────────────────────────────────────────────────

_AdapterResponse _scripted(int status, {required String body}) =>
    _AdapterResponse(status, body);

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter({
    required this.responses,
    this.onRequest,
  }) : assert(responses.isNotEmpty);

  final List<_AdapterResponse> responses;
  final void Function(RequestOptions req)? onRequest;
  int _idx = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest?.call(options);
    final r = responses[_idx < responses.length ? _idx : responses.length - 1];
    _idx++;
    return ResponseBody.fromBytes(
      Uint8List.fromList(utf8.encode(r.body)),
      r.status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}

class _AdapterResponse {
  _AdapterResponse(this.status, this.body);
  final int status;
  final String body;
}

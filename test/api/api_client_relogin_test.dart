// api_client_relogin_test.dart — verifies that ApiClient's auth interceptor
// performs a silent relogin + retry on a 401, addressing the MAIC
// session-archive bug found 2026-09-17 (commit d991316).
//
// The test stubs out:
//   - secureStorageProvider: not used directly (we never read the JWT from
//     storage in this test — JwtReader is overridden)
//   - jwtReaderProvider: returns a fixed "expired" token
//   - authRepositoryProvider: returns a FakeAuthRepository that flips a
//     relogin flag and returns a "fresh" token
//   - The Dio HTTP transport: replaced with Dio's httpClientAdapter test
//     hook, returning 401 on first call, 200 on the second.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miracle_claw_mobile/core/api/api_client.dart';
import 'package:miracle_claw_mobile/core/auth/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository();

  int reloginCallCount = 0;
  String? lastSeenEmail;

  @override
  Future<bool> silentRelogin() async {
    reloginCallCount++;
    return true;
  }

  // ── Unused members (compile-time surface only) ─────────────────────
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
          'FakeAuthRepository: ${invocation.memberName} not stubbed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('401 triggers silentRelogin + retry on the same request', () async {
    // Track every Authorization header the adapter sees.
    final authHeaders = <String?>[];

    final fakeAuth = _FakeAuthRepository();
    final container = ProviderContainer(overrides: [
      jwtReaderProvider.overrideWithValue(() async => 'expired-token'),
      authRepositoryProvider.overrideWithValue(fakeAuth),
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
    expect(fakeAuth.reloginCallCount, 1,
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
    final container = ProviderContainer(overrides: [
      jwtReaderProvider.overrideWithValue(() async => 'expired-token'),
      authRepositoryProvider.overrideWithValue(_AlwaysFailAuthRepository()),
    ]);
    addTearDown(container.dispose);

    final api = container.read(apiClientProvider);
    api.dio.httpClientAdapter = _ScriptedAdapter(responses: [
      _scripted(401, body: jsonEncode({'detail': 'Session archived'})),
    ]);

    final response = await api.dio.get<Map<String, dynamic>>('/v1/ping');
    expect(response.statusCode, 401);
  });

  test('login endpoint 401 does NOT trigger relogin (avoids loop)',
      () async {
    final fakeAuth = _FakeAuthRepository();
    final container = ProviderContainer(overrides: [
      jwtReaderProvider.overrideWithValue(() async => 'old-token'),
      authRepositoryProvider.overrideWithValue(fakeAuth),
    ]);
    addTearDown(container.dispose);

    final api = container.read(apiClientProvider);
    api.dio.httpClientAdapter = _ScriptedAdapter(responses: [
      _scripted(401, body: jsonEncode({'detail': 'Invalid credentials'})),
    ]);

    final response = await api.dio
        .post<Map<String, dynamic>>('/v1/users/login', data: {'email': 'x', 'password': 'y'});
    expect(response.statusCode, 401);
    expect(fakeAuth.reloginCallCount, 0,
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

class _AlwaysFailAuthRepository implements AuthRepository {
  @override
  Future<bool> silentRelogin() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

// auth_failure_classifier_test.dart — verifies the MAICAuthFailure
// classifier inside api_client.dart matches every 401 reason MAIC
// returns as of 2026-09-21, and that the relogin-worth-trying decision
// is the right one per cause.
//
// These are top-level functions (not exported from the public API),
// so the test reaches them by importing the same source file's symbols
// via the part directive. In practice we test the OBSERVABLE behavior:
// the same Dio pipeline should attempt silentRelogin on a Session-archived
// 401 but NOT on a "Bad token" 401.
//
// Pattern mirrors api_client_relogin_test.dart: scripted 401 adapter,
// install callback via setReloginCallback, count how many times it fires.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miracle_claw_mobile/core/api/api_client.dart';
import 'package:miracle_claw_mobile/core/auth/jwt_reader.dart';

class _ReloginCounter {
  _ReloginCounter();
  int callCount = 0;
  Future<bool> call() async {
    callCount++;
    return true; // pretend silentRelogin always works
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearReloginCallbackForTest);
  tearDown(clearReloginCallbackForTest);

  Future<int> statusWithDetail(String detail) async {
    final relogin = _ReloginCounter();
    setReloginCallback(relogin.call);

    final container = ProviderContainer(overrides: [
      jwtReaderProvider.overrideWithValue(() async => 'a-token'),
    ]);
    addTearDown(container.dispose);

    final api = container.read(apiClientProvider);
    api.dio.httpClientAdapter = _ScriptedAdapter(responses: [
      _adapterResp(401, body: jsonEncode({'detail': detail})),
      _adapterResp(200, body: jsonEncode({'ok': true})),
    ]);

    final r = await api.dio.get<Map<String, dynamic>>('/v1/ping');
    final attempts = relogin.callCount;

    if (r.statusCode == 200) {
      expect(attempts, 1, reason: 'relogin should fire exactly once on a recoverable 401 (detail=$detail)');
    } else if (r.statusCode == 401) {
      expect(attempts, 0, reason: 'relogin should NOT fire on an irrecoverable 401 (detail=$detail)');
    }
    return r.statusCode!;
  }

  test('Session archived → relogin + retry 200', () async {
    final code = await statusWithDetail('Session archived — please log in again');
    expect(code, 200);
  });

  test('Session expired or revoked → relogin + retry 200', () async {
    final code = await statusWithDetail('Session expired or revoked');
    expect(code, 200);
  });

  test('Credential archived → relogin + retry 200', () async {
    final code = await statusWithDetail('Credential archived');
    expect(code, 200);
  });

  test('Invalid credential → relogin + retry 200', () async {
    final code = await statusWithDetail('Invalid credential');
    expect(code, 200);
  });

  test('Authentication service unavailable → 401, NO relogin', () async {
    final code = await statusWithDetail('Authentication service unavailable');
    expect(code, 401);
  });

  test('Bad token → 401, NO relogin (corrupt JWT)', () async {
    final code = await statusWithDetail('Bad token');
    expect(code, 401);
  });

  test('Missing API key → 401, NO relogin (header bug)', () async {
    final code = await statusWithDetail('Missing API key');
    expect(code, 401);
  });

  test('Unknown detail → 401, NO relogin (new MAIC reason)', () async {
    final code = await statusWithDetail('Some brand-new thing from the gateway');
    expect(code, 401);
  });

  test('login endpoint 401 (invalid_credentials) is NOT relogin-attempted',
      () async {
    // The interceptor's path-based skip-list keeps this case safe:
    // /v1/users/login 401 never enters onResponse-relogin logic.
    final relogin = _ReloginCounter();
    setReloginCallback(relogin.call);

    final container = ProviderContainer(overrides: [
      jwtReaderProvider.overrideWithValue(() async => 'old'),
    ]);
    addTearDown(container.dispose);

    final api = container.read(apiClientProvider);
    api.dio.httpClientAdapter = _ScriptedAdapter(responses: [
      _adapterResp(401, body: jsonEncode({'detail': 'Invalid credentials'})),
    ]);

    final r = await api.dio.post<Map<String, dynamic>>(
        '/v1/users/login', data: {'email': 'x', 'password': 'y'});
    expect(r.statusCode, 401);
    expect(relogin.callCount, 0);
  });
}

// ── Helpers (copied from api_client_relogin_test.dart) ──────────────

_AdapterResponse _adapterResp(int status, {required String body}) =>
    _AdapterResponse(status, body);

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter({required this.responses});
  final List<_AdapterResponse> responses;
  int _idx = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final r = responses[_idx < responses.length ? _idx : responses.length - 1];
    _idx++;
    return ResponseBody.fromBytes(
      Uint8List.fromList(utf8.encode(r.body)),
      r.status,
      headers: {'content-type': ['application/json']},
    );
  }
}

class _AdapterResponse {
  _AdapterResponse(this.status, this.body);
  final int status;
  final String body;
}

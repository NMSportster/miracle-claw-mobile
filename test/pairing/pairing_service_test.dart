// pairing_service_test.dart — Unit tests for the pairing service orchestrator.
//
// Spec: docs/specs/mobile-desktop-pairing.md § "Handshake protocol".
//
// v1 scope: transport ladder URL selection + HMAC request signing. We don't
// network-test the discovery loop (that's covered by Phase 4 end-to-end on
// real hardware).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miracle_claw_mobile/core/pairing/discovery_state.dart';
import 'package:miracle_claw_mobile/core/pairing/session.dart';
import 'package:miracle_claw_mobile/core/pairing/transport.dart';

void main() {
  group('TransportLadder', () {
    const ladder = TransportLadder();

    test('CloudOnly → MAIC cloud URL', () {
      expect(
        ladder.pickBaseUrl(const CloudOnly(reason: 'first_run')),
        'https://api.maicserver.com',
      );
    });

    test('Paired (lan) → desktop endpoint with short connect timeout', () {
      final desktop = DesktopInstance(
        instanceId: 'inst_1',
        instanceName: 'Test',
        endpoint: 'http://192.168.1.50:28789',
        endpointKind: 'lan',
        fingerprint: 'fp',
        publicKey: 'pk',
        lastHeartbeatAt: DateTime.now(),
      );
      expect(ladder.pickBaseUrl(Paired(desktop: desktop, session: _dummySession())), 'http://192.168.1.50:28789');
      expect(ladder.pickConnectTimeout(Paired(desktop: desktop, session: _dummySession())),
          const Duration(milliseconds: 100));
    });

    test('Paired (relay) → desktop endpoint with normal timeout', () {
      final desktop = DesktopInstance(
        instanceId: 'inst_1',
        instanceName: 'Test',
        endpoint: 'https://relay.maicserver.com',
        endpointKind: 'relay',
        fingerprint: 'fp',
        publicKey: 'pk',
        lastHeartbeatAt: DateTime.now(),
      );
      expect(ladder.pickBaseUrl(Paired(desktop: desktop, session: _dummySession())),
          'https://relay.maicserver.com');
      expect(ladder.pickConnectTimeout(Paired(desktop: desktop, session: _dummySession())),
          const Duration(seconds: 5));
    });

    test('PairingInFlight → MAIC cloud (avoid hammering desktop mid-handshake)', () {
      final desktop = DesktopInstance(
        instanceId: 'inst_1',
        instanceName: 'Test',
        endpoint: 'http://192.168.1.50:28789',
        endpointKind: 'lan',
        fingerprint: 'fp',
        publicKey: 'pk',
        lastHeartbeatAt: DateTime.now(),
      );
      expect(ladder.pickBaseUrl(PairingInFlight(desktop: desktop)),
          'https://api.maicserver.com');
    });

    test('Paired with empty endpoint → MAIC cloud (graceful fallback)', () {
      final desktop = DesktopInstance(
        instanceId: 'inst_1',
        instanceName: 'Test',
        endpoint: '',
        endpointKind: 'relay',
        fingerprint: 'fp',
        publicKey: 'pk',
        lastHeartbeatAt: DateTime.now(),
      );
      expect(ladder.pickBaseUrl(Paired(desktop: desktop, session: _dummySession())),
          'https://api.maicserver.com');
    });
  });

  group('PairSession', () {
    test('can() returns true for granted capability, false otherwise', () {
      final s = _dummySession();
      expect(s.can('chat'), true);
      expect(s.can('sessions:rw'), true);
      expect(s.can('shell:execute'), false);
    });

    test('isExpired() handles past and future correctly', () {
      final past = PairSession(
        sessionId: 's',
        sessionSecret: Uint8List(32),
        instanceId: 'i',
        instanceName: 'n',
        endpoint: 'e',
        endpointKind: 'relay',
        capabilities: const [],
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final future = PairSession(
        sessionId: 's',
        sessionSecret: Uint8List(32),
        instanceId: 'i',
        instanceName: 'n',
        endpoint: 'e',
        endpointKind: 'relay',
        capabilities: const [],
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(past.isExpired(DateTime.now()), true);
      expect(future.isExpired(DateTime.now()), false);
    });
  });

  group('signRequestBody', () {
    test('HMAC over empty body is stable for same secret', () async {
      final s = _dummySession();
      final sig1 = await signRequestBody(session: s, body: Uint8List(0));
      final sig2 = await signRequestBody(session: s, body: Uint8List(0));
      expect(sig1, sig2);
      // 32 bytes raw → 44 chars base64 with padding.
      expect(sig1.length, greaterThanOrEqualTo(43));
    });

    test('HMAC over body differs from HMAC over empty body', () async {
      final s = _dummySession();
      final sigEmpty = await signRequestBody(session: s, body: Uint8List(0));
      final sigBody = await signRequestBody(
          session: s, body: Uint8List.fromList(utf8.encode('hello')));
      expect(sigEmpty, isNot(sigBody));
    });
  });
}

PairSession _dummySession() => PairSession(
      sessionId: 'session_1',
      sessionSecret: Uint8List.fromList(List.generate(32, (i) => i)),
      instanceId: 'inst_1',
      instanceName: 'Test desktop',
      endpoint: 'http://192.168.1.50:28789',
      endpointKind: 'lan',
      capabilities: const ['chat', 'sessions:rw', 'modules:invoke'],
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
